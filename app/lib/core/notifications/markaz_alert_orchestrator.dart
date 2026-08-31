import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../../features/expenses/data/budget_repository.dart';
import '../../features/personal_finance/data/personal_finance_repository.dart';
import '../../features/personal_finance/domain/personal_finance_models.dart';
import '../../features/savings/data/savings_repository.dart';
import 'markaz_alert_preferences.dart';
import 'notification_inbox_repository.dart';
import 'notification_policy.dart';
import 'notification_service.dart';

final markazAlertOrchestratorProvider = Provider(
  (ref) => MarkazAlertOrchestrator(
    budget: ref.watch(budgetRepositoryProvider),
    personalFinance: ref.watch(personalFinanceRepositoryProvider),
    savings: ref.watch(savingsRepositoryProvider),
    inbox: ref.watch(notificationInboxRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
  ),
);

class MarkazAlertOrchestrator {
  const MarkazAlertOrchestrator({
    required this.budget,
    required this.personalFinance,
    required this.savings,
    required this.inbox,
    required this.notifications,
  });

  final BudgetRepository budget;
  final PersonalFinanceRepository personalFinance;
  final SavingsRepository savings;
  final NotificationInboxRepository inbox;
  final NotificationService notifications;
  static const preferences = MarkazAlertPreferences();
  static const policy = NotificationPolicy();

  Future<void> refresh({DateTime? at}) async {
    final now = at ?? DateTime.now();
    await Future.wait([
      _budgetAlerts(now),
      _billAlerts(now),
      _savingsAlerts(now),
    ]);
  }

  Future<void> _budgetAlerts(DateTime now) async {
    if (!await preferences.enabled(MarkazAlertCategory.budget)) return;
    final privacy = await preferences.privacy();
    for (final alert in await budget.evaluateThresholds(now)) {
      final name = alert.category ?? 'monthly';
      final body = policy.protectedBody(
        privacy: privacy,
        privateBody: 'One of your budgets needs attention.',
        detailedBody:
            '${alert.category ?? 'Monthly'} budget reached ${alert.threshold}%.',
      );
      await _deliver(
        category: 'money',
        title: 'Budget update',
        body: body,
        key:
            'budget:${alert.budgetId}:${alert.threshold}:${now.year}-${now.month}',
        route: '/expenses',
        now: now,
        subject: name,
      );
    }
  }

  Future<void> _billAlerts(DateTime now) async {
    if (!await preferences.enabled(MarkazAlertCategory.bills)) return;
    final privacy = await preferences.privacy();
    for (final bill in await personalFinance.bills()) {
      if (bill.status == BillStatus.paid) continue;
      final days = DateTime(
        bill.dueDate.year,
        bill.dueDate.month,
        bill.dueDate.day,
      ).difference(DateTime(now.year, now.month, now.day)).inDays;
      if (![7, 3, 1, 0].contains(days) && days >= 0) continue;
      final stage = days < 0 ? 'overdue' : 'due-$days';
      final privateBody = days < 0
          ? 'One of your bills is overdue.'
          : days == 0
          ? 'One of your bills is due today.'
          : 'A bill is due in $days days.';
      final detailedBody = days < 0
          ? '${bill.provider} is overdue.'
          : days == 0
          ? '${bill.provider} is due today.'
          : '${bill.provider} is due in $days days.';
      await _deliver(
        category: 'reminders',
        title: 'Bill reminder',
        body: policy.protectedBody(
          privacy: privacy,
          privateBody: privateBody,
          detailedBody: detailedBody,
        ),
        key: 'bill:${bill.id}:$stage',
        route: '/personal-finance',
        now: now,
        subject: '${bill.id}',
        actionJson: jsonEncode({
          'type': 'mark_bill_paid',
          'billId': bill.id,
          'amount': bill.amount,
        }),
      );
    }
  }

  Future<void> _savingsAlerts(DateTime now) async {
    if (!await preferences.enabled(MarkazAlertCategory.savings)) return;
    final privacy = await preferences.privacy();
    for (final goal in await savings.goals()) {
      if (goal.targetAmount <= 0) continue;
      final percent = goal.savedAmount / goal.targetAmount * 100;
      for (final milestone in const [25, 50, 75, 90, 100]) {
        if (percent < milestone) continue;
        await _deliver(
          category: 'money',
          title: milestone == 100
              ? 'Savings goal completed'
              : 'Savings milestone',
          body: policy.protectedBody(
            privacy: privacy,
            privateBody: 'A savings goal reached a new milestone.',
            detailedBody: '${goal.name} reached $milestone%.',
          ),
          key: 'savings:${goal.id}:$milestone',
          route: '/savings',
          now: now,
          subject: '${goal.id}',
        );
      }
    }
  }

  Future<void> _deliver({
    required String category,
    required String title,
    required String body,
    required String key,
    required String route,
    required DateTime now,
    required String subject,
    String? actionJson,
  }) async {
    final inserted = await inbox.add(
      category: category,
      title: title,
      body: body,
      deduplicationKey: key,
      route: route,
      actionJson: actionJson,
    );
    if (!inserted) return;
    final quiet = await preferences.quietHours();
    final deliverAt = quiet.contains(now) ? quiet.nextEnd(now) : now;
    await notifications.scheduleAlert(
      id: key.hashCode & 0x7fffffff,
      channelId: 'markaz_$category',
      channelName: 'Markaz Alerts',
      title: title,
      body: body,
      deliverAt: deliverAt,
      payload: route,
    );
  }
}
