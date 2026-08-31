import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/pakistan_data/pakistan_data_point.dart';
import '../../../core/pakistan_data/pakistan_data_service.dart';

import '../../analytics/data/financial_analytics_repository.dart';
import '../../analytics/domain/financial_analytics.dart';
import '../../expenses/data/budget_repository.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/budget_analytics.dart';
import '../../expenses/domain/finance_transaction.dart';
import '../../savings/data/savings_repository.dart';
import '../../savings/domain/savings_goal.dart';
import '../../recurring/data/recurring_repository.dart';
import '../../recurring/domain/recurring_transaction.dart';
import '../../udhaar/data/ledger_repository.dart';
import '../../udhaar/domain/ledger.dart';

final androidHomeBackgroundSyncProvider = Provider<bool>(
  (_) => defaultTargetPlatform == TargetPlatform.android,
);

class HomeDashboardData {
  const HomeDashboardData({
    required this.finance,
    required this.ledger,
    required this.budget,
    required this.categories,
    this.categoryBudgets = const [],
    this.newBudgetAlerts = const [],
    this.savingsGoals = const [],
    required this.recentTransactions,
    this.upcomingCommitments = const [],
    this.reserve = 0,
    this.pakistanToday = const [],
  });

  final FinancialPeriodSummary finance;
  final LedgerSummary ledger;
  final MonthlyBudget? budget;
  final List<CategorySpending> categories;
  final List<CategoryBudgetStatus> categoryBudgets;
  final List<BudgetThresholdAlert> newBudgetAlerts;
  final List<SavingsGoal> savingsGoals;
  final List<FinanceTransaction> recentTransactions;
  final List<RecurringTransaction> upcomingCommitments;
  final double reserve;
  final List<PakistanDataPoint> pakistanToday;

  double get budgetProgress => budget == null || budget!.amount <= 0
      ? 0
      : finance.expenses / budget!.amount;
  double? get budgetRemaining =>
      budget == null ? null : budget!.amount - finance.expenses;
  double get upcomingTotal => upcomingCommitments
      .where((item) => item.type == TransactionType.expense)
      .fold(0, (total, item) => total + item.amount);
  double get safeToSpend => finance.availableBalance - upcomingTotal - reserve;
}

final homeDashboardProvider = FutureProvider<HomeDashboardData>((ref) async {
  final now = DateTime.now();
  final analytics = ref.watch(financialAnalyticsRepositoryProvider);
  final transactions = ref.watch(expenseRepositoryProvider);
  final budgets = ref.watch(budgetRepositoryProvider);
  final recurring = await ref.watch(recurringRepositoryProvider).all();
  final monthEnd = DateTime(now.year, now.month + 1);
  final upcoming =
      recurring
          .where(
            (item) =>
                item.status == RecurringStatus.active &&
                !item.nextDueAt.isBefore(
                  DateTime(now.year, now.month, now.day),
                ) &&
                item.nextDueAt.isBefore(monthEnd),
          )
          .toList()
        ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
  return HomeDashboardData(
    finance: await analytics.monthlySummary(now),
    ledger: await ref.watch(ledgerRepositoryProvider).summary(),
    budget: await budgets.monthly(now),
    categories: await analytics.spendingByCategory(now),
    categoryBudgets: await budgets.categoryBudgets(now),
    newBudgetAlerts: await budgets.evaluateThresholds(now),
    savingsGoals: (await ref.watch(savingsRepositoryProvider).goals())
        .take(3)
        .toList(),
    recentTransactions: (await transactions.all()).take(5).toList(),
    upcomingCommitments: upcoming,
    reserve: ref.watch(safeToSpendReserveProvider),
    pakistanToday: await ref.watch(pakistanDataServiceProvider).dashboard(),
  );
});

final safeToSpendReserveProvider = NotifierProvider<SafeToSpendReserve, double>(
  SafeToSpendReserve.new,
);

class SafeToSpendReserve extends Notifier<double> {
  static const _key = 'safe_to_spend_reserve';
  @override
  double build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    state = (await SharedPreferences.getInstance()).getDouble(_key) ?? 0;
  }

  Future<void> set(double value) async {
    if (!value.isFinite || value < 0) {
      throw const FormatException('Reserve cannot be negative.');
    }
    state = value;
    await (await SharedPreferences.getInstance()).setDouble(_key, value);
    ref.invalidate(homeDashboardProvider);
  }
}

final privacyModeProvider = NotifierProvider<PrivacyModeController, bool>(
  PrivacyModeController.new,
);

class PrivacyModeController extends Notifier<bool> {
  static const _key = 'dashboard_privacy_mode';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    state = (await SharedPreferences.getInstance()).getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    await (await SharedPreferences.getInstance()).setBool(_key, state);
  }
}
