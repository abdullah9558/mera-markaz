import 'dart:math' as math;

enum FinancingRateType { fixed, variable }

class FinancingInput {
  const FinancingInput({
    required this.amount,
    this.downPayment = 0,
    required this.annualRate,
    required this.months,
    this.rateType = FinancingRateType.fixed,
    this.kiborRate,
    this.spread = 0,
  });
  final double amount, downPayment, annualRate, spread;
  final int months;
  final FinancingRateType rateType;
  final double? kiborRate;
  double get principal => amount - downPayment;
  double get effectiveAnnualRate => rateType == FinancingRateType.variable
      ? (kiborRate ?? annualRate) + spread
      : annualRate;
}

class AmortizationEntry {
  const AmortizationEntry({
    required this.month,
    required this.payment,
    required this.principal,
    required this.interest,
    required this.balance,
  });
  final int month;
  final double payment, principal, interest, balance;
}

class FinancingResult {
  const FinancingResult({
    required this.monthlyPayment,
    required this.totalRepayment,
    required this.financingCost,
    required this.schedule,
  });
  final double monthlyPayment, totalRepayment, financingCost;
  final List<AmortizationEntry> schedule;
}

class FinancingCalculator {
  static FinancingResult calculate(FinancingInput input) {
    if (input.amount <= 0 ||
        input.downPayment < 0 ||
        input.principal <= 0 ||
        input.annualRate < 0 ||
        input.months <= 0 ||
        input.spread < 0 ||
        (input.kiborRate != null && input.kiborRate! < 0)) {
      throw const FormatException('Enter valid financing values.');
    }
    final rate = input.effectiveAnnualRate / 1200;
    final payment = rate == 0
        ? input.principal / input.months
        : input.principal *
              rate *
              math.pow(1 + rate, input.months) /
              (math.pow(1 + rate, input.months) - 1);
    var balance = input.principal;
    final schedule = <AmortizationEntry>[];
    for (var month = 1; month <= input.months; month++) {
      final interest = balance * rate;
      final principal = month == input.months ? balance : payment - interest;
      balance = (balance - principal).clamp(0, double.infinity).toDouble();
      schedule.add(
        AmortizationEntry(
          month: month,
          payment: principal + interest,
          principal: principal,
          interest: interest,
          balance: balance,
        ),
      );
    }
    final total = schedule.fold<double>(0, (sum, item) => sum + item.payment);
    return FinancingResult(
      monthlyPayment: payment,
      totalRepayment: total,
      financingCost: total - input.principal,
      schedule: schedule,
    );
  }
}

enum InflationCalculationType { historical, futureScenario }

class PurchasingPowerResult {
  const PurchasingPowerResult({
    required this.nominalAmount,
    required this.adjustedAmount,
    required this.cumulativeInflation,
    required this.type,
    required this.yearlyValues,
  });
  final double nominalAmount, adjustedAmount, cumulativeInflation;
  final InflationCalculationType type;
  final List<double> yearlyValues;
}

class InflationCalculator {
  static PurchasingPowerResult historical({
    required double amount,
    required List<double> annualRates,
  }) => _calculate(
    amount,
    annualRates,
    InflationCalculationType.historical,
    grow: true,
  );
  static PurchasingPowerResult futureScenario({
    required double savings,
    required List<double> assumedRates,
  }) => _calculate(
    savings,
    assumedRates,
    InflationCalculationType.futureScenario,
    grow: false,
  );
  static PurchasingPowerResult _calculate(
    double amount,
    List<double> rates,
    InflationCalculationType type, {
    required bool grow,
  }) {
    if (amount < 0 || rates.any((rate) => rate <= -100)) {
      throw const FormatException('Enter valid inflation assumptions.');
    }
    var value = amount;
    final values = <double>[amount];
    var factor = 1.0;
    for (final annual in rates) {
      factor *= 1 + annual / 100;
      value = grow ? amount * factor : amount / factor;
      values.add(value);
    }
    return PurchasingPowerResult(
      nominalAmount: amount,
      adjustedAmount: value,
      cumulativeInflation: (factor - 1) * 100,
      type: type,
      yearlyValues: values,
    );
  }
}

class FinancialHealthInput {
  const FinancialHealthInput({
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.budgetAdherence,
    required this.savingsRate,
    required this.emergencyMonths,
    required this.debtPaymentRate,
    required this.billPaymentRate,
  });
  final double monthlyIncome,
      monthlyExpenses,
      budgetAdherence,
      savingsRate,
      emergencyMonths,
      debtPaymentRate,
      billPaymentRate;
}

class FinancialHealthResult {
  const FinancialHealthResult({
    required this.score,
    required this.components,
    required this.explanations,
  });
  final int score;
  final Map<String, double> components;
  final List<String> explanations;
  String get status => score >= 80
      ? 'Strong'
      : score >= 60
      ? 'Stable'
      : score >= 40
      ? 'Needs attention'
      : 'At risk';
}

class FinancialHealthCalculator {
  static FinancialHealthResult calculate(FinancialHealthInput input) {
    if ([
      input.monthlyIncome,
      input.monthlyExpenses,
      input.emergencyMonths,
    ].any((v) => v < 0)) {
      throw const FormatException(
        'Financial health values cannot be negative.',
      );
    }
    double normalized(double value) => value.clamp(0, 1).toDouble();
    final cashFlow = input.monthlyIncome <= 0
        ? 0.0
        : normalized(
            (input.monthlyIncome - input.monthlyExpenses) /
                input.monthlyIncome /
                .3,
          );
    final components = <String, double>{
      'Cash flow': cashFlow * 25,
      'Budget adherence': normalized(input.budgetAdherence) * 15,
      'Savings consistency': normalized(input.savingsRate / .2) * 20,
      'Emergency fund': normalized(input.emergencyMonths / 6) * 20,
      'Debt obligations': normalized(1 - input.debtPaymentRate / .4) * 10,
      'Bill reliability': normalized(input.billPaymentRate) * 10,
    };
    final score = components.values.fold<double>(0, (a, b) => a + b).round();
    final weakest = components.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
    return FinancialHealthResult(
      score: score,
      components: components,
      explanations: [
        'Your score is calculated only from the six visible components.',
        '$weakest is currently the largest improvement opportunity.',
      ],
    );
  }
}
