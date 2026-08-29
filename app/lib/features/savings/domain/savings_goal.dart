enum SavingsGoalStatus { active, completed, archived }

class SavingsGoal {
  const SavingsGoal({
    required this.id,
    required this.name,
    this.icon,
    required this.targetAmount,
    required this.savedAmount,
    this.targetDate,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String? icon;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;
  final String? notes;
  final SavingsGoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get remaining =>
      (targetAmount - savedAmount).clamp(0, double.infinity).toDouble();
  double get progress => targetAmount <= 0 ? 0 : savedAmount / targetAmount;
}

class GoalContribution {
  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.contributedAt,
    this.note,
  });

  final int id;
  final int goalId;
  final double amount;
  final DateTime contributedAt;
  final String? note;
  bool get isWithdrawal => amount < 0;
}

class GoalForecast {
  const GoalForecast({
    required this.averageMonthlySavings,
    required this.estimatedMonths,
    required this.requiredMonthlySavings,
  });

  final double averageMonthlySavings;
  final int? estimatedMonths;
  final double? requiredMonthlySavings;

  static GoalForecast calculate({
    required SavingsGoal goal,
    required List<GoalContribution> contributions,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    var average = 0.0;
    if (contributions.isNotEmpty) {
      final dates = contributions.map((item) => item.contributedAt).toList()
        ..sort();
      final months = _monthDifference(dates.first, dates.last) + 1;
      final net = contributions.fold<double>(
        0,
        (sum, item) => sum + item.amount,
      );
      average = (net / months).clamp(0, double.infinity).toDouble();
    }
    final estimated = goal.remaining <= 0
        ? 0
        : average <= 0
        ? null
        : (goal.remaining / average).ceil();
    double? required;
    if (goal.targetDate != null && goal.remaining > 0) {
      final months = _monthDifference(
        DateTime(today.year, today.month),
        DateTime(goal.targetDate!.year, goal.targetDate!.month),
      );
      if (months >= 0) required = goal.remaining / (months + 1);
    }
    return GoalForecast(
      averageMonthlySavings: average,
      estimatedMonths: estimated,
      requiredMonthlySavings: required,
    );
  }

  static int _monthDifference(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + to.month - from.month;
}
