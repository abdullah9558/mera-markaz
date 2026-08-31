enum MarkazAlertCategory {
  budget,
  bills,
  udhaar,
  salary,
  savings,
  petrol,
  currency,
  gold,
  policyRate,
  kibor,
  inflation,
  electricity,
  solar,
  zakat,
  vehicle,
  safeToSpend,
  financialHealth,
  emergencyFund,
  security,
  cloudSync,
  localBackup,
  dailyBrief,
  eveningSummary,
}

enum NotificationPrivacy { private, detailed }

class QuietHours {
  const QuietHours({
    this.enabled = true,
    this.startMinute = 22 * 60,
    this.endMinute = 8 * 60,
  });

  final bool enabled;
  final int startMinute;
  final int endMinute;

  bool contains(DateTime time) {
    if (!enabled || startMinute == endMinute) return false;
    final minute = time.hour * 60 + time.minute;
    return startMinute < endMinute
        ? minute >= startMinute && minute < endMinute
        : minute >= startMinute || minute < endMinute;
  }

  DateTime nextEnd(DateTime time) {
    if (!contains(time)) return time;
    var result = DateTime(
      time.year,
      time.month,
      time.day,
      endMinute ~/ 60,
      endMinute % 60,
    );
    if (!result.isAfter(time)) result = result.add(const Duration(days: 1));
    return result;
  }
}

class AlertDecision {
  const AlertDecision({
    required this.shouldNotify,
    required this.deduplicationKey,
    this.deliverAt,
  });

  final bool shouldNotify;
  final String deduplicationKey;
  final DateTime? deliverAt;
}

class NotificationPolicy {
  const NotificationPolicy();

  AlertDecision thresholdCrossing({
    required MarkazAlertCategory category,
    required String subjectId,
    required double previousValue,
    required double currentValue,
    required double threshold,
    required bool triggersAbove,
    required DateTime now,
    required QuietHours quietHours,
    DateTime? lastDeliveredAt,
    Duration cooldown = const Duration(hours: 24),
    bool securityCritical = false,
  }) {
    final crossed = triggersAbove
        ? previousValue < threshold && currentValue >= threshold
        : previousValue > threshold && currentValue <= threshold;
    final cooldownPassed =
        lastDeliveredAt == null || now.difference(lastDeliveredAt) >= cooldown;
    final key = [
      category.name,
      subjectId,
      triggersAbove ? 'above' : 'below',
      threshold.toStringAsFixed(4),
      now.year,
      now.month,
      now.day,
    ].join(':');
    if (!crossed || !cooldownPassed) {
      return AlertDecision(shouldNotify: false, deduplicationKey: key);
    }
    return AlertDecision(
      shouldNotify: true,
      deduplicationKey: key,
      deliverAt: !securityCritical && quietHours.contains(now)
          ? quietHours.nextEnd(now)
          : now,
    );
  }

  String protectedBody({
    required NotificationPrivacy privacy,
    required String privateBody,
    required String detailedBody,
  }) => privacy == NotificationPrivacy.private ? privateBody : detailedBody;
}
