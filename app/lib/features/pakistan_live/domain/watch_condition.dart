enum WatchComparison { above, below }

class WatchCondition {
  const WatchCondition({
    required this.id,
    required this.seriesKey,
    required this.comparison,
    required this.targetValue,
    required this.enabled,
    required this.cooldownMinutes,
    this.lastTriggeredAt,
    required this.wasMatching,
  });
  final int id;
  final String seriesKey;
  final WatchComparison comparison;
  final double targetValue;
  final bool enabled;
  final int cooldownMinutes;
  final DateTime? lastTriggeredAt;
  final bool wasMatching;
  bool matches(double value) => comparison == WatchComparison.above
      ? value >= targetValue
      : value <= targetValue;
}
