import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/features/analytics/domain/financial_analytics.dart';
import 'package:pakpocket/features/expenses/domain/budget_analytics.dart';
import 'package:pakpocket/features/home/presentation/dashboard_provider.dart';
import 'package:pakpocket/features/expenses/domain/finance_transaction.dart';
import 'package:pakpocket/features/recurring/domain/recurring_transaction.dart';
import 'package:pakpocket/features/udhaar/domain/ledger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('dashboard derives budget progress and remaining from real totals', () {
    final dashboard = HomeDashboardData(
      finance: FinancialPeriodSummary(
        start: DateTime(2026, 8),
        end: DateTime(2026, 9),
        income: 175000,
        expenses: 90500,
        previousIncome: 160000,
        previousExpenses: 85000,
      ),
      ledger: const LedgerSummary(toReceive: 35000, toPay: 12000),
      budget: MonthlyBudget(amount: 120000, month: DateTime(2026, 8)),
      categories: const [],
      recentTransactions: const [],
    );

    expect(dashboard.finance.availableBalance, 84500);
    expect(dashboard.budgetProgress, closeTo(0.754166, 0.00001));
    expect(dashboard.budgetRemaining, 29500);
  });

  test('Safe to Spend subtracts upcoming expenses and user reserve', () {
    final dashboard = HomeDashboardData(
      finance: FinancialPeriodSummary(
        start: DateTime(2026, 8),
        end: DateTime(2026, 9),
        income: 150000,
        expenses: 50000,
        previousIncome: 0,
        previousExpenses: 0,
      ),
      ledger: const LedgerSummary(toReceive: 0, toPay: 0),
      budget: null,
      categories: const [],
      recentTransactions: const [],
      reserve: 20000,
      upcomingCommitments: [
        RecurringTransaction(
          id: 1,
          type: TransactionType.expense,
          amount: 15000,
          categoryId: 1,
          categoryName: 'Rent',
          description: 'Internet and rent',
          frequency: RecurringFrequency.monthly,
          intervalCount: 1,
          nextDueAt: DateTime(2026, 8, 28),
          status: RecurringStatus.active,
        ),
      ],
    );
    expect(dashboard.upcomingTotal, 15000);
    expect(dashboard.safeToSpend, 65000);
  });

  test('privacy mode is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    var container = ProviderContainer();
    expect(container.read(privacyModeProvider), isFalse);
    await container.read(privacyModeProvider.notifier).toggle();
    expect(container.read(privacyModeProvider), isTrue);
    container.dispose();

    container = ProviderContainer();
    container.read(privacyModeProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(privacyModeProvider), isTrue);
    container.dispose();
  });
}
