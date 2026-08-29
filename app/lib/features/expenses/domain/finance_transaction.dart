enum TransactionType { income, expense }

/// Identifies the module that owns a financial record. A non-manual source
/// should also provide [FinanceTransaction.sourceRecordId] so integrations can
/// update one linked transaction instead of creating duplicates.
enum TransactionSource {
  manual,
  salary,
  fuel,
  electricity,
  udhaar,
  savings,
  zakat,
  recurring,
  receipt,
  other,
}

class FinanceTransaction {
  const FinanceTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.occurredAt,
    required this.description,
    this.paymentMethod,
    this.note,
    this.source = TransactionSource.manual,
    this.sourceRecordId,
  });
  final int? id;
  final TransactionType type;
  final double amount;
  final int categoryId;
  final String categoryName;
  final DateTime occurredAt;
  final String description;
  final String? paymentMethod;
  final String? note;
  final TransactionSource source;
  final String? sourceRecordId;
}

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.type,
  });
  final int id;
  final String name;
  final TransactionType type;
}

class FinanceSummary {
  const FinanceSummary({
    required this.todayExpense,
    required this.weekExpense,
    required this.monthExpense,
    required this.monthIncome,
  });
  final double todayExpense;
  final double weekExpense;
  final double monthExpense;
  final double monthIncome;
  double get balance => monthIncome - monthExpense;
}

/// Accounting rules shared by dashboard, analytics and reports.
abstract final class FinanceAccounting {
  /// Spendable balance includes posted income and expenses only. Udhaar,
  /// savings goals and calculator estimates do not affect it unless they create
  /// an explicit linked income/expense transaction.
  static double availableBalance({
    required double income,
    required double expenses,
  }) => income - expenses;

  static double savings({required double income, required double expenses}) =>
      (income - expenses).clamp(0, double.infinity).toDouble();

  static double savingsRate({
    required double income,
    required double expenses,
  }) =>
      income <= 0 ? 0 : (savings(income: income, expenses: expenses) / income);
}
