import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/timeline_event.dart';

final timelineRepositoryProvider = Provider(
  (ref) => TimelineRepository(ref.watch(appDatabaseProvider)),
);

class TimelineRepository {
  const TimelineRepository(this._database);
  final AppDatabase _database;

  Future<List<TimelineEvent>> events(
    TimelineFilter filter, {
    int limit = 200,
    int offset = 0,
  }) async {
    final rows = await _database.database.rawQuery(
      '''
      SELECT event_id, event_type, title, subtitle, amount, event_date FROM (
        SELECT 'transaction:' || t.id event_id, t.type event_type,
          t.description title, c.name subtitle,
          CASE WHEN t.type = 'income' THEN t.amount ELSE -t.amount END amount,
          t.occurred_at event_date
        FROM transactions t JOIN categories c ON c.id = t.category_id
        WHERE t.owner_id = ?
        UNION ALL
        SELECT 'udhaar:' || l.id, 'udhaar', l.description, p.name,
          CASE WHEN l.direction = 'gave' THEN -l.amount ELSE l.amount END,
          l.occurred_at
        FROM ledger_transactions l JOIN ledger_people p ON p.id = l.person_id
        WHERE p.owner_id = ?
        UNION ALL
        SELECT 'saving:' || g.id || ':' || c.id, 'savings', g.name,
          CASE WHEN c.amount < 0 THEN 'Withdrawal' ELSE 'Contribution' END,
          -c.amount, c.contributed_at
        FROM goal_contributions c JOIN savings_goals g ON g.id = c.goal_id
        WHERE c.owner_id = ?
        UNION ALL
        SELECT 'bill:' || b.id, 'expense', b.provider, 'Upcoming bill',
          -b.amount, b.due_date
        FROM bills b
        WHERE b.owner_id = ? AND b.status = 'unpaid'
      ) ORDER BY event_date DESC LIMIT ? OFFSET ?
      ''',
      [
        _database.ownerId,
        _database.ownerId,
        _database.ownerId,
        _database.ownerId,
        limit,
        offset,
      ],
    );
    final query = filter.query.trim().toLowerCase();
    return rows
        .map(
          (row) => TimelineEvent(
            id: row['event_id'] as String,
            type: TimelineEventType.values.byName(row['event_type'] as String),
            title: row['title'] as String,
            subtitle: row['subtitle'] as String,
            amount: (row['amount'] as num).toDouble(),
            date: DateTime.parse(row['event_date'] as String),
          ),
        )
        .where((event) {
          if (filter.types.isNotEmpty && !filter.types.contains(event.type)) {
            return false;
          }
          if (filter.from != null && event.date.isBefore(filter.from!)) {
            return false;
          }
          if (filter.to != null && event.date.isAfter(filter.to!)) return false;
          final absolute = event.amount.abs();
          if (filter.minimumAmount != null &&
              absolute < filter.minimumAmount!) {
            return false;
          }
          if (filter.maximumAmount != null &&
              absolute > filter.maximumAmount!) {
            return false;
          }
          return query.isEmpty ||
              event.title.toLowerCase().contains(query) ||
              event.subtitle.toLowerCase().contains(query);
        })
        .toList();
  }
}
