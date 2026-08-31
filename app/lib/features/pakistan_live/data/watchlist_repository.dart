import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../domain/watch_condition.dart';

final watchlistRepositoryProvider = Provider(
  (ref) => WatchlistRepository(ref.watch(appDatabaseProvider)),
);

class WatchlistRepository {
  const WatchlistRepository(this.database);
  final AppDatabase database;
  Future<List<WatchCondition>> all() async => (await database.database.query(
    'watch_conditions',
    where: 'owner_id = ?',
    whereArgs: [database.ownerId],
    orderBy: 'updated_at DESC',
  )).map(_fromRow).toList();

  Future<int> save({
    int? id,
    required String seriesKey,
    required WatchComparison comparison,
    required double targetValue,
    bool enabled = true,
    int cooldownMinutes = 1440,
  }) async {
    if (!targetValue.isFinite || targetValue <= 0 || cooldownMinutes < 0) {
      throw const FormatException('Enter a valid target and cooldown.');
    }
    final now = DateTime.now().toIso8601String();
    final values = {
      'series_key': seriesKey,
      'comparison': comparison.name,
      'target_value': targetValue,
      'enabled': enabled ? 1 : 0,
      'cooldown_minutes': cooldownMinutes,
      'updated_at': now,
      'owner_id': database.ownerId,
    };
    if (id == null) {
      return database.database.insert('watch_conditions', {
        ...values,
        'created_at': now,
      });
    }
    await database.database.update(
      'watch_conditions',
      values,
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, database.ownerId],
    );
    return id;
  }

  Future<void> setEnabled(int id, bool enabled) => database.database.update(
    'watch_conditions',
    {
      'enabled': enabled ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    },
    where: 'id = ? AND owner_id = ?',
    whereArgs: [id, database.ownerId],
  );
  Future<void> delete(int id) => database.database.delete(
    'watch_conditions',
    where: 'id = ? AND owner_id = ?',
    whereArgs: [id, database.ownerId],
  );

  Future<bool> evaluate(
    WatchCondition condition,
    double value,
    DateTime now,
  ) async {
    if (!condition.enabled) return false;
    final matching = condition.matches(value);
    final cooldownPassed =
        condition.lastTriggeredAt == null ||
        now.difference(condition.lastTriggeredAt!).inMinutes >=
            condition.cooldownMinutes;
    final trigger = matching && !condition.wasMatching && cooldownPassed;
    await database.database.update(
      'watch_conditions',
      {
        'was_matching': matching ? 1 : 0,
        if (trigger) 'last_triggered_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ? AND owner_id = ?',
      whereArgs: [condition.id, database.ownerId],
    );
    return trigger;
  }

  WatchCondition _fromRow(Map<String, Object?> row) => WatchCondition(
    id: row['id'] as int,
    seriesKey: row['series_key'] as String,
    comparison: WatchComparison.values.byName(row['comparison'] as String),
    targetValue: (row['target_value'] as num).toDouble(),
    enabled: row['enabled'] == 1,
    cooldownMinutes: row['cooldown_minutes'] as int,
    lastTriggeredAt: row['last_triggered_at'] == null
        ? null
        : DateTime.parse(row['last_triggered_at'] as String),
    wasMatching: row['was_matching'] == 1,
  );
}
