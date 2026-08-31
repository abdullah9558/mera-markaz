enum DataFreshness { current, recentlyUpdated, cached, stale, unavailable }

class PakistanDataPoint {
  const PakistanDataPoint({
    this.id,
    required this.seriesKey,
    required this.value,
    required this.unit,
    required this.sourceName,
    required this.sourceReference,
    required this.effectiveAt,
    required this.retrievedAt,
    this.previousValue,
    required this.freshness,
    required this.configVersion,
  });
  final int? id;
  final String seriesKey;
  final double value;
  final String unit;
  final String sourceName;
  final String sourceReference;
  final DateTime effectiveAt;
  final DateTime retrievedAt;
  final double? previousValue;
  final DataFreshness freshness;
  final String configVersion;
  double? get change => previousValue == null ? null : value - previousValue!;
  double? get percentageChange => previousValue == null || previousValue == 0
      ? null
      : (value - previousValue!) / previousValue! * 100;

  PakistanDataPoint withComputedFreshness(DateTime now) => PakistanDataPoint(
    id: id,
    seriesKey: seriesKey,
    value: value,
    unit: unit,
    sourceName: sourceName,
    sourceReference: sourceReference,
    effectiveAt: effectiveAt,
    retrievedAt: retrievedAt,
    previousValue: previousValue,
    freshness: _freshnessFor(now.difference(retrievedAt)),
    configVersion: configVersion,
  );

  static DataFreshness _freshnessFor(Duration age) {
    if (age <= const Duration(hours: 24)) return DataFreshness.current;
    if (age <= const Duration(days: 3)) return DataFreshness.recentlyUpdated;
    if (age <= const Duration(days: 7)) return DataFreshness.cached;
    return DataFreshness.stale;
  }
}
