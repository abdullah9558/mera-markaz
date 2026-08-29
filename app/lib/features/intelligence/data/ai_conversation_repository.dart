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
    final now = DateTime.now().toIso8601String();
    return _database.database.insert('ai_conversations', {
      'title': 'Markaz AI',
      'created_at': now,
      'updated_at': now,
      'owner_id': _database.ownerId,
    });
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
