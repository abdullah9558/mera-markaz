import 'dart:math' as math;

import '../../expenses/domain/finance_transaction.dart';

enum RecurringFrequency { weekly, monthly, customDays }

enum RecurringStatus { active, paused }

class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.frequency,
    required this.intervalCount,
    required this.nextDueAt,
    required this.status,
  });
  final int id;
  final TransactionType type;
  final double amount;
  final int categoryId;
  final String categoryName;
  final String description;
  final RecurringFrequency frequency;
  final int intervalCount;
  final DateTime nextDueAt;
  final RecurringStatus status;
  bool dueAt(DateTime now) =>
      status == RecurringStatus.active &&
      !nextDueAt.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59));

  DateTime followingDate() => switch (frequency) {
    RecurringFrequency.weekly => nextDueAt.add(
      Duration(days: 7 * intervalCount),
    ),
    RecurringFrequency.monthly => _followingMonth(),
    RecurringFrequency.customDays => nextDueAt.add(
      Duration(days: intervalCount),
    ),
  };

  DateTime _followingMonth() {
    final first = DateTime(nextDueAt.year, nextDueAt.month + intervalCount);
    final lastDay = DateTime(first.year, first.month + 1, 0).day;
    return DateTime(first.year, first.month, math.min(nextDueAt.day, lastDay));
  }
}
