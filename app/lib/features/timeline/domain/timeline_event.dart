enum TimelineEventType { income, expense, udhaar, savings }

class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
  });
  final String id;
  final TimelineEventType type;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;
  bool get positive => amount >= 0;
}

class TimelineFilter {
  const TimelineFilter({
    this.types = const {},
    this.from,
    this.to,
    this.minimumAmount,
    this.maximumAmount,
    this.query = '',
  });
  final Set<TimelineEventType> types;
  final DateTime? from;
  final DateTime? to;
  final double? minimumAmount;
  final double? maximumAmount;
  final String query;
}
