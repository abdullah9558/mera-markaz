import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import 'pakistan_data_point.dart';

final pakistanDataRepositoryProvider = Provider(
  (ref) => PakistanDataRepository(ref.watch(appDatabaseProvider)),
);

class PakistanDataRepository {
  const PakistanDataRepository(this.database);
  final AppDatabase database;
  Future<void> cache(PakistanDataPoint point) async {
    if (point.sourceName.trim().isEmpty ||
        point.sourceReference.trim().isEmpty ||
        point.configVersion.trim().isEmpty) {
      throw const FormatException(
        'Pakistan data requires a source, reference and version.',
      );
    }
    await database.database.insert('pakistan_data_points', {
      'series_key': point.seriesKey,
      'value': point.value,
      'unit': point.unit,
      'source_name': point.sourceName,
      'source_reference': point.sourceReference,
      'effective_at': point.effectiveAt.toUtc().toIso8601String(),
      'retrieved_at': point.retrievedAt.toUtc().toIso8601String(),
      'previous_value': point.previousValue,
      'freshness': point.freshness.name,
      'config_version': point.configVersion,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<PakistanDataPoint?> latest(String seriesKey, {DateTime? now}) async {
    final rows = await database.database.query(
      'pakistan_data_points',
      where: 'series_key = ?',
      whereArgs: [seriesKey],
      orderBy: 'effective_at DESC, retrieved_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.single).withComputedFreshness(now ?? DateTime.now());
  }

  Future<List<PakistanDataPoint>> history(
    String seriesKey, {
    DateTime? since,
    int limit = 366,
  }) async {
    final rows = await database.database.query(
      'pakistan_data_points',
      where: since == null
          ? 'series_key = ?'
          : 'series_key = ? AND effective_at >= ?',
      whereArgs: since == null
          ? [seriesKey]
          : [seriesKey, since.toUtc().toIso8601String()],
      orderBy: 'effective_at ASC',
      limit: limit.clamp(1, 2000),
    );
    final now = DateTime.now();
    return rows.map((row) => _fromRow(row).withComputedFreshness(now)).toList();
  }

  PakistanDataPoint _fromRow(Map<String, Object?> row) => PakistanDataPoint(
    id: row['id'] as int,
    seriesKey: row['series_key'] as String,
    value: (row['value'] as num).toDouble(),
    unit: row['unit'] as String,
    sourceName: row['source_name'] as String,
    sourceReference: row['source_reference'] as String,
    effectiveAt: DateTime.parse(row['effective_at'] as String),
    retrievedAt: DateTime.parse(row['retrieved_at'] as String),
    previousValue: (row['previous_value'] as num?)?.toDouble(),
    freshness: DataFreshness.values.byName(row['freshness'] as String),
    configVersion: row['config_version'] as String,
  );
}
