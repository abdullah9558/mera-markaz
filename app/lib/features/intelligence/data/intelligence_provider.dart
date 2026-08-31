import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/presentation/dashboard_provider.dart';
import '../../analytics/data/financial_analytics_repository.dart';
import '../../udhaar/data/ledger_repository.dart';
import '../domain/financial_intelligence.dart';

final intelligenceSnapshotProvider = FutureProvider<IntelligenceSnapshot>((
  ref,
) async {
  final dashboard = await ref.watch(homeDashboardProvider.future);
  final now = DateTime.now();
  return IntelligenceSnapshot(
    period: dashboard.finance,
    categories: dashboard.categories,
    categoryBudgets: dashboard.categoryBudgets,
    ledger: dashboard.ledger,
    goals: dashboard.savingsGoals,
    safeToSpend: dashboard.safeToSpend,
    upcomingCommitments: dashboard.upcomingTotal,
    reserve: dashboard.reserve,
    pakistanIndicators: dashboard.pakistanToday,
    ledgerPeople: await ref.watch(ledgerRepositoryProvider).people(),
    previousCategories: await ref
        .watch(financialAnalyticsRepositoryProvider)
        .spendingByCategory(DateTime(now.year, now.month - 1)),
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
    'savingsGoals': snapshot.goals.indexed
        .take(5)
        .map(
          (entry) => {
            'goalNumber': entry.$1 + 1,
            'target': entry.$2.targetAmount,
            'saved': entry.$2.savedAmount,
          },
        )
        .toList(),
    'safeToSpend': snapshot.safeToSpend,
    'upcomingCommitments': snapshot.upcomingCommitments,
    'safetyReserve': snapshot.reserve,
    'pakistanIndicators': snapshot.pakistanIndicators
        .take(10)
        .map(
          (point) => {
            'series': point.seriesKey,
            'value': point.value,
            'unit': point.unit,
            'source': point.sourceName,
            'effectiveAt': point.effectiveAt.toIso8601String(),
            'freshness': point.freshness.name,
          },
        )
        .toList(),
  };
}
