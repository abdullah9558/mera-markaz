class MonthlyBudget {
  const MonthlyBudget({this.id, required this.amount, required this.month});
  final int? id;
  final double amount;
  final DateTime month;
}

class CategoryTotal {
  const CategoryTotal({required this.category, required this.amount});
  final String category;
  final double amount;
}

class CategoryBudgetStatus {
  const CategoryBudgetStatus({
    this.budgetId,
    required this.categoryId,
    required this.category,
    required this.budget,
    required this.spent,
  });
  final int? budgetId;
  final int categoryId;
  final String category;
  final double budget;
  final double spent;
  double get remaining => budget - spent;
  double get progress => budget <= 0 ? 0 : spent / budget;
  bool get exceeded => budget > 0 && spent > budget;
}

class BudgetThresholdAlert {
  const BudgetThresholdAlert({
    required this.budgetId,
    this.category,
    required this.threshold,
    required this.spent,
    required this.budget,
  });
  final int budgetId;
  final String? category;
  final int threshold;
  final double spent;
  final double budget;
  bool get exceeded => spent > budget;
}
