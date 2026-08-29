import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/data/financial_analytics_repository.dart';
import '../../expenses/data/budget_repository.dart';
import '../../savings/data/savings_repository.dart';
import '../../udhaar/data/ledger_repository.dart';
import '../domain/financial_intelligence.dart';

final intelligenceSnapshotProvider = FutureProvider<IntelligenceSnapshot>((
  ref,
) async {
  final now = DateTime.now();
  final analytics = ref.watch(financialAnalyticsRepositoryProvider);
  return IntelligenceSnapshot(
    period: await analytics.monthlySummary(now),
    categories: await analytics.spendingByCategory(now),
    categoryBudgets: await ref
        .watch(budgetRepositoryProvider)
        .categoryBudgets(now),
    ledger: await ref.watch(ledgerRepositoryProvider).summary(),
    goals: await ref.watch(savingsRepositoryProvider).goals(),
  );
});

final financialInsightsProvider = FutureProvider<List<FinancialInsight>>(
  (ref) async => const FinancialIntelligenceEngine().insights(
    await ref.watch(intelligenceSnapshotProvider.future),
  ),
);

final markazScoreProvider = FutureProvider<MarkazScore>(
  (ref) async => const FinancialIntelligenceEngine().score(
    await ref.watch(intelligenceSnapshotProvider.future),
  ),
);

/// Builds the only financial context that may be shared with online AI.
/// It intentionally excludes identity, contacts, notes, receipts and
/// individual transaction details.
Map<String, Object?> safeAiSummary(IntelligenceSnapshot snapshot) {
  return {
    'currency': 'PKR',
    'periodStart': snapshot.period.start.toIso8601String(),
    'periodEnd': snapshot.period.end.toIso8601String(),
    'monthlyIncome': snapshot.period.income,
    'monthlyExpenses': snapshot.period.expenses,
    'availableBalance': snapshot.period.availableBalance,
    'savings': snapshot.period.savings,
    'savingsRatePercent': snapshot.period.savingsRate * 100,
    'previousMonthExpenses': snapshot.period.previousExpenses,
    'spendingByCategory': snapshot.categories
        .take(10)
        .map(
          (category) => {
            'category': category.categoryName,
            'amount': category.amount,
          },
        )
        .toList(),
    'categoryBudgets': snapshot.categoryBudgets
        .take(10)
        .map(
          (budget) => {
            'category': budget.category,
            'limit': budget.budget,
            'spent': budget.spent,
            'remaining': budget.remaining,
            'exceeded': budget.exceeded,
          },
        )
        .toList(),
    'udhaar': {
      'toReceive': snapshot.ledger.toReceive,
      'toPay': snapshot.ledger.toPay,
    },
    'savingsGoals': snapshot.goals
        .take(5)
        .map(
          (goal) => {
            'name': goal.name,
            'target': goal.targetAmount,
            'saved': goal.savedAmount,
          },
        )
        .toList(),
  };
}
