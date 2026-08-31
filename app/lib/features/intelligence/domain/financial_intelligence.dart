import '../../analytics/domain/financial_analytics.dart';
import '../../expenses/domain/budget_analytics.dart';
import '../../savings/domain/savings_goal.dart';
import '../../udhaar/domain/ledger.dart';
import '../../../core/pakistan_data/pakistan_data_point.dart';

enum InsightKind { positive, warning, neutral }

class FinancialInsight {
  const FinancialInsight({
    required this.code,
    required this.message,
    required this.urduMessage,
    required this.kind,
  });
  final String code;
  final String message;
  final String urduMessage;
  final InsightKind kind;
}

class ScoreFactor {
  const ScoreFactor({
    required this.code,
    required this.label,
    required this.points,
    required this.maximum,
    required this.positive,
  });
  final String code;
  final String label;
  final int points;
  final int maximum;
  final bool positive;
}

class MarkazScore {
  const MarkazScore({
    required this.value,
    required this.factors,
    required this.improvements,
  });
  final int value;
  final List<ScoreFactor> factors;
  final List<String> improvements;
  String get status => factors.isEmpty
      ? 'Not enough data'
      : switch (value) {
          >= 80 => 'Excellent',
          >= 65 => 'Good',
          >= 45 => 'Fair',
          _ => 'Needs attention',
        };
}

class IntelligenceSnapshot {
  const IntelligenceSnapshot({
    required this.period,
    required this.categories,
    required this.categoryBudgets,
    required this.ledger,
    required this.goals,
    this.safeToSpend = 0,
    this.upcomingCommitments = 0,
    this.reserve = 0,
    this.pakistanIndicators = const [],
    this.ledgerPeople = const [],
    this.previousCategories = const [],
  });
  final FinancialPeriodSummary period;
  final List<CategorySpending> categories;
  final List<CategoryBudgetStatus> categoryBudgets;
  final LedgerSummary ledger;
  final List<SavingsGoal> goals;
  final double safeToSpend;
  final double upcomingCommitments;
  final double reserve;
  final List<PakistanDataPoint> pakistanIndicators;
  final List<LedgerPerson> ledgerPeople;
  final List<CategorySpending> previousCategories;
}

class FinancialIntelligenceEngine {
  const FinancialIntelligenceEngine();

  List<FinancialInsight> insights(IntelligenceSnapshot input) {
    if (input.period.income == 0 && input.period.expenses == 0) return const [];
    final values = <FinancialInsight>[];
    final change = input.period.expenseChange;
    if (change != null && change.abs() >= .05) {
      values.add(
        FinancialInsight(
          code: 'expense_change',
          message:
              'You spent ${(change.abs() * 100).toStringAsFixed(0)}% ${change > 0 ? 'more' : 'less'} this month than last month.',
          urduMessage:
              'آپ نے پچھلے ماہ کے مقابلے میں ${(change.abs() * 100).toStringAsFixed(0)}% ${change > 0 ? 'زیادہ' : 'کم'} خرچ کیا۔',
          kind: change > 0 ? InsightKind.warning : InsightKind.positive,
        ),
      );
    }
    if (input.categories.isNotEmpty) {
      final largest = input.categories.first;
      values.add(
        FinancialInsight(
          code: 'largest_category',
          message:
              '${largest.categoryName} is your largest expense category this month at Rs. ${largest.amount.toStringAsFixed(0)}.',
          urduMessage:
              'اس ماہ ${largest.categoryName} سب سے بڑا خرچ ہے: Rs. ${largest.amount.toStringAsFixed(0)}۔',
          kind: InsightKind.neutral,
        ),
      );
    }
    if (input.period.income > 0) {
      values.add(
        FinancialInsight(
          code: 'savings_rate',
          message:
              'You saved ${(input.period.savingsRate * 100).toStringAsFixed(0)}% of recorded income this month.',
          urduMessage:
              'آپ نے اس ماہ ریکارڈ شدہ آمدنی کا ${(input.period.savingsRate * 100).toStringAsFixed(0)}% بچایا۔',
          kind: input.period.savingsRate >= .1
              ? InsightKind.positive
              : InsightKind.warning,
        ),
      );
    }
    final exceeded = input.categoryBudgets.where((budget) => budget.exceeded);
    for (final budget in exceeded.take(2)) {
      values.add(
        FinancialInsight(
          code: 'budget_${budget.categoryId}',
          message:
              '${budget.category} budget exceeded by Rs. ${budget.remaining.abs().toStringAsFixed(0)}.',
          urduMessage:
              '${budget.category} کا بجٹ Rs. ${budget.remaining.abs().toStringAsFixed(0)} سے تجاوز کر گیا۔',
          kind: InsightKind.warning,
        ),
      );
    }
    if (input.ledger.toReceive > 0) {
      values.add(
        FinancialInsight(
          code: 'udhaar_receivable',
          message:
              'You have Rs. ${input.ledger.toReceive.toStringAsFixed(0)} to receive in Udhaar.',
          urduMessage:
              'آپ نے ادھار میں Rs. ${input.ledger.toReceive.toStringAsFixed(0)} وصول کرنے ہیں۔',
          kind: InsightKind.neutral,
        ),
      );
    }
    return values;
  }

  MarkazScore score(IntelligenceSnapshot input) {
    if (input.period.income == 0 && input.period.expenses == 0) {
      return const MarkazScore(
        value: 0,
        factors: [],
        improvements: [
          'Record income and expenses to calculate your Markaz Score.',
        ],
      );
    }
    final factors = <ScoreFactor>[];
    final improvements = <String>[];
    final savingsRate = input.period.savingsRate;
    final savingsPoints = savingsRate >= .2
        ? 30
        : savingsRate >= .1
        ? 20
        : savingsRate > 0
        ? 10
        : 0;
    factors.add(
      ScoreFactor(
        code: 'savings_rate',
        label: savingsPoints >= 20 ? 'Good savings rate' : 'Low savings rate',
        points: savingsPoints,
        maximum: 30,
        positive: savingsPoints >= 20,
      ),
    );
    if (savingsPoints < 20) {
      improvements.add('Work toward saving at least 10% of recorded income.');
    }

    final ratio = input.period.income <= 0
        ? double.infinity
        : input.period.expenses / input.period.income;
    final ratioPoints = ratio <= .7
        ? 20
        : ratio <= .9
        ? 10
        : 0;
    factors.add(
      ScoreFactor(
        code: 'expense_ratio',
        label: ratioPoints >= 10
            ? 'Expenses are controlled'
            : 'Expenses are high compared with income',
        points: ratioPoints,
        maximum: 20,
        positive: ratioPoints >= 10,
      ),
    );
    if (ratioPoints == 0) {
      improvements.add('Reduce expenses relative to recorded monthly income.');
    }

    final configured = input.categoryBudgets.isNotEmpty;
    final exceeded = input.categoryBudgets
        .where((value) => value.exceeded)
        .length;
    final budgetPoints = !configured
        ? 10
        : exceeded == 0
        ? 20
        : (20 - exceeded * 5).clamp(0, 20);
    factors.add(
      ScoreFactor(
        code: 'budgets',
        label: !configured
            ? 'No category budgets configured'
            : exceeded == 0
            ? 'Staying within category budgets'
            : 'Some category budgets are exceeded',
        points: budgetPoints,
        maximum: 20,
        positive: configured && exceeded == 0,
      ),
    );
    if (!configured) {
      improvements.add('Set category budgets to improve spending control.');
    } else if (exceeded > 0) {
      improvements.add('Bring exceeded categories back within budget.');
    }

    final debtRatio = input.period.income <= 0
        ? (input.ledger.toPay > 0 ? double.infinity : 0)
        : input.ledger.toPay / input.period.income;
    final udhaarPoints = debtRatio == 0
        ? 15
        : debtRatio <= .1
        ? 10
        : 0;
    factors.add(
      ScoreFactor(
        code: 'udhaar',
        label: udhaarPoints == 15
            ? 'No outstanding Udhaar payable'
            : 'Outstanding Udhaar payable',
        points: udhaarPoints,
        maximum: 15,
        positive: udhaarPoints == 15,
      ),
    );
    if (udhaarPoints == 0) {
      improvements.add('Reduce outstanding Udhaar payable where practical.');
    }

    final goalSavings = input.goals.fold<double>(
      0,
      (sum, goal) => sum + goal.savedAmount,
    );
    final emergencyMonths = input.period.expenses <= 0
        ? 0
        : goalSavings / input.period.expenses;
    final emergencyPoints = emergencyMonths >= 3
        ? 10
        : emergencyMonths >= 1
        ? 5
        : 0;
    factors.add(
      ScoreFactor(
        code: 'reserves',
        label: emergencyPoints >= 5
            ? 'Savings reserve recorded'
            : 'Limited savings reserve',
        points: emergencyPoints,
        maximum: 10,
        positive: emergencyPoints >= 5,
      ),
    );
    if (emergencyPoints == 0) {
      improvements.add(
        'Build savings equal to at least one month of expenses.',
      );
    }

    final change = input.period.expenseChange?.abs();
    final consistencyPoints = change == null
        ? 2
        : change <= .1
        ? 5
        : change <= .25
        ? 3
        : 0;
    factors.add(
      ScoreFactor(
        code: 'consistency',
        label: consistencyPoints >= 3
            ? 'Spending is relatively consistent'
            : 'Spending changed significantly',
        points: consistencyPoints,
        maximum: 5,
        positive: consistencyPoints >= 3,
      ),
    );
    final total = factors.fold<int>(0, (sum, factor) => sum + factor.points);
    return MarkazScore(
      value: total.clamp(0, 100),
      factors: factors,
      improvements: improvements,
    );
  }
}
