import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';
import '../domain/markaz_ai.dart';
import 'firebase_markaz_ai_gateway.dart';

final aiConversationRepositoryProvider = Provider(
  (ref) => AiConversationRepository(ref.watch(appDatabaseProvider)),
);
final externalAiGatewayProvider = Provider<ExternalAiGateway>(
  (_) => FirebaseMarkazAiGateway(),
);

class AiPrivacyConsent {
  static const _key = 'external_ai_financial_data_consent_v1';
  Future<bool> granted() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;
  Future<void> setGranted(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_key, value);
}

class AiConversationRepository {
  const AiConversationRepository(this._database);
  final AppDatabase _database;

  Future<List<AiConversation>> conversations({String query = ''}) async {
    final search = query.trim();
    final rows = await _database.database.query(
      'ai_conversations',
      where: search.isEmpty
          ? 'owner_id = ?'
          : 'owner_id = ? AND title LIKE ? COLLATE NOCASE',
      whereArgs: search.isEmpty
          ? [_database.ownerId]
          : [_database.ownerId, '%$search%'],
      orderBy: 'updated_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => AiConversation(
            id: row['id'] as int,
            title: (row['title'] as String?)?.trim().isNotEmpty == true
                ? row['title'] as String
                : 'New chat',
            createdAt: DateTime.parse(row['created_at'] as String),
            updatedAt: DateTime.parse(row['updated_at'] as String),
          ),
        )
        .toList();
  }

  Future<int> createConversation({String title = 'New chat'}) async {
    final now = DateTime.now().toIso8601String();
    return _database.database.insert('ai_conversations', {
      'title': title.trim().isEmpty ? 'New chat' : title.trim(),
      'created_at': now,
      'updated_at': now,
      'owner_id': _database.ownerId,
    });
  }

  Future<int> currentConversation() async {
    final rows = await _database.database.query(
      'ai_conversations',
      columns: ['id'],
      where: 'owner_id = ?',
      whereArgs: [_database.ownerId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return createConversation();
  }

  Future<void> renameConversation(int id, String title) async {
    final value = title.trim();
    if (value.isEmpty) return;
    await _database.database.update(
      'ai_conversations',
      {'title': value, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _database.ownerId],
    );
  }

  Future<void> deleteConversation(int id) async {
    await _database.database.delete(
      'ai_conversations',
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _database.ownerId],
    );
  }

  Future<void> titleFromFirstMessage(int id, String message) async {
    final rows = await _database.database.rawQuery(
      'SELECT COUNT(*) AS count FROM ai_messages WHERE conversation_id = ? AND owner_id = ?',
      [id, _database.ownerId],
    );
    if ((rows.first['count'] as int) != 1) return;
    final compact = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    final title = compact.length <= 42
        ? compact
        : '${compact.substring(0, 39).trimRight()}...';
    await renameConversation(id, title);
  }

  Future<List<AiChatMessage>> messages(int conversationId) async {
    final rows = await _database.database.query(
      'ai_messages',
      where: 'conversation_id = ? AND owner_id = ?',
      whereArgs: [conversationId, _database.ownerId],
      orderBy: 'created_at, id',
    );
    return rows
        .map(
          (row) => AiChatMessage(
            id: row['id'] as int,
            role: row['role'] as String,
            content: row['content'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> addMessage(
    int conversationId,
    String role,
    String content,
  ) async {
    if (!const {'user', 'assistant'}.contains(role) || content.trim().isEmpty) {
      throw const FormatException('Invalid AI conversation message.');
    }
    final now = DateTime.now().toIso8601String();
    await _database.database.transaction((txn) async {
      await txn.insert('ai_messages', {
        'conversation_id': conversationId,
        'role': role,
        'content': content.trim(),
        'created_at': now,
        'owner_id': _database.ownerId,
      });
      await txn.update(
        'ai_conversations',
        {'updated_at': now},
        where: 'id = ? AND owner_id = ?',
        whereArgs: [conversationId, _database.ownerId],
      );
    });
  }
}
