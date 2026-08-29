class FinancialPeriodSummary {
  const FinancialPeriodSummary({
    required this.start,
    required this.end,
    required this.income,
    required this.expenses,
    required this.previousIncome,
    required this.previousExpenses,
  });

  final DateTime start;
  final DateTime end;
  final double income;
  final double expenses;
  final double previousIncome;
  final double previousExpenses;

  double get availableBalance => income - expenses;
  double get savings => availableBalance.clamp(0, double.infinity).toDouble();
  double get savingsRate => income <= 0 ? 0 : savings / income;

  /// Null means there is no previous-period baseline, not a zero-percent move.
  double? get expenseChange {
    if (previousExpenses == 0) return expenses == 0 ? 0 : null;
    return (expenses - previousExpenses) / previousExpenses;
  }
}

class CategorySpending {
  const CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });

  final int categoryId;
  final String categoryName;
  final double amount;
}
