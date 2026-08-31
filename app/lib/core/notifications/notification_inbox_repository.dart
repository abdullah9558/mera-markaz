import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

final notificationInboxRepositoryProvider = Provider(
  (ref) => NotificationInboxRepository(ref.watch(appDatabaseProvider)),
);

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.occurredAt,
    this.route,
    this.actionJson,
    this.readAt,
  });
  final int id;
  final String category;
  final String title;
  final String body;
  final DateTime occurredAt;
  final String? route;
  final String? actionJson;
  final DateTime? readAt;
  bool get isUnread => readAt == null;
}

class NotificationInboxRepository {
  const NotificationInboxRepository(this.database);
  final AppDatabase database;

  Future<bool> add({
    required String category,
    required String title,
    required String body,
    required String deduplicationKey,
    String? route,
    String? actionJson,
    DateTime? occurredAt,
  }) async {
    final id = await database.database.insert('notification_inbox', {
      'category': category,
      'title': title,
      'body': body,
      'route': route,
      'action_json': actionJson,
      'deduplication_key': deduplicationKey,
      'occurred_at': (occurredAt ?? DateTime.now()).toIso8601String(),
      'owner_id': database.ownerId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return id != 0;
  }

  Future<List<InboxNotification>> list({
    String? category,
    String? search,
    int limit = 100,
  }) async {
    final filters = <String>['owner_id = ?', 'deleted_at IS NULL'];
    final arguments = <Object?>[database.ownerId];
    if (category != null) {
      filters.add('category = ?');
      arguments.add(category);
    }
    if (search != null && search.trim().isNotEmpty) {
      filters.add('(title LIKE ? OR body LIKE ?)');
      final query = '%${search.trim()}%';
      arguments.addAll([query, query]);
    }
    final rows = await database.database.query(
      'notification_inbox',
      where: filters.join(' AND '),
      whereArgs: arguments,
      orderBy: 'occurred_at DESC',
      limit: limit.clamp(1, 500),
    );
    return rows
        .map(
          (row) => InboxNotification(
            id: row['id'] as int,
            category: row['category'] as String,
            title: row['title'] as String,
            body: row['body'] as String,
            occurredAt: DateTime.parse(row['occurred_at'] as String),
            route: row['route'] as String?,
            actionJson: row['action_json'] as String?,
            readAt: row['read_at'] == null
                ? null
                : DateTime.parse(row['read_at'] as String),
          ),
        )
        .toList();
  }

  Future<int> unreadCount() async {
    final rows = await database.database.rawQuery(
      'SELECT COUNT(*) count FROM notification_inbox WHERE owner_id = ? AND read_at IS NULL AND deleted_at IS NULL',
      [database.ownerId],
    );
    return (rows.single['count'] as num).toInt();
  }

  Future<void> markRead(int id) => database.database.update(
    'notification_inbox',
    {'read_at': DateTime.now().toIso8601String()},
    where: 'id = ? AND owner_id = ?',
    whereArgs: [id, database.ownerId],
  );
  Future<void> markAllRead() => database.database.update(
    'notification_inbox',
    {'read_at': DateTime.now().toIso8601String()},
    where: 'owner_id = ? AND read_at IS NULL AND deleted_at IS NULL',
    whereArgs: [database.ownerId],
  );
  Future<void> delete(int id) => database.database.update(
    'notification_inbox',
    {'deleted_at': DateTime.now().toIso8601String()},
    where: 'id = ? AND owner_id = ?',
    whereArgs: [id, database.ownerId],
  );
  Future<void> clearRead() => database.database.update(
    'notification_inbox',
    {'deleted_at': DateTime.now().toIso8601String()},
    where: 'owner_id = ? AND read_at IS NOT NULL AND deleted_at IS NULL',
    whereArgs: [database.ownerId],
  );
}
