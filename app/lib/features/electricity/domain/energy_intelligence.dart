class ApplianceUsage {
  const ApplianceUsage({
    required this.name,
    required this.quantity,
    required this.wattage,
    required this.hoursPerDay,
    required this.daysPerMonth,
    required this.tariffPerKwh,
  });
  final String name;
  final int quantity, daysPerMonth;
  final double wattage, hoursPerDay, tariffPerKwh;
  double get monthlyKwh =>
      quantity * wattage * hoursPerDay * daysPerMonth / 1000;
  double get estimatedCost => monthlyKwh * tariffPerKwh;
  ApplianceUsage withHours(double value) => ApplianceUsage(
    name: name,
    quantity: quantity,
    wattage: wattage,
    hoursPerDay: value.clamp(0, 24),
    daysPerMonth: daysPerMonth,
    tariffPerKwh: tariffPerKwh,
  );
}

class ElectricityReading {
  const ElectricityReading({
    this.id,
    required this.provider,
    required this.billingMonth,
    this.previousReading,
    this.currentReading,
    required this.units,
    this.actualBill,
    this.estimatedBill,
    required this.isActual,
    this.notes,
  });
  final int? id;
  final String provider;
  final DateTime billingMonth;
  final double? previousReading, currentReading, actualBill, estimatedBill;
  final double units;
  final bool isActual;
  final String? notes;
}

class SolarRecommendation {
  const SolarRecommendation({
    required this.averageMonthlyKwh,
    required this.peakMonthlyKwh,
    required this.systemKw,
    required this.panelCount,
    required this.estimatedAnnualGeneration,
    required this.gridReductionPercent,
  });
  final double averageMonthlyKwh,
      peakMonthlyKwh,
      systemKw,
      estimatedAnnualGeneration,
      gridReductionPercent;
  final int panelCount;
  static SolarRecommendation fromHistory(
    List<ElectricityReading> history, {
    double panelWattage = 585,
    double annualKwhPerKw = 1500,
    double designCoverage = .8,
  }) {
    if (history.isEmpty || panelWattage <= 0 || annualKwhPerKw <= 0) {
      throw const FormatException(
        'Electricity history and assumptions are required.',
      );
    }
    final average =
        history.fold<double>(0, (sum, item) => sum + item.units) /
        history.length;
    final peak = history
        .map((item) => item.units)
        .reduce((a, b) => a > b ? a : b);
    final annualNeed = average * 12 * designCoverage.clamp(0, 1);
    final system = annualNeed / annualKwhPerKw;
    final panels = (system * 1000 / panelWattage).ceil().clamp(1, 10000);
    final practicalKw = panels * panelWattage / 1000;
    final generation = practicalKw * annualKwhPerKw;
    final reduction = average <= 0
        ? 0.0
        : (generation / (average * 12) * 100).clamp(0, 100).toDouble();
    return SolarRecommendation(
      averageMonthlyKwh: average,
      peakMonthlyKwh: peak,
      systemKw: practicalKw,
      panelCount: panels,
      estimatedAnnualGeneration: generation,
      gridReductionPercent: reduction,
    );
  }
}

class SolarRoiSummary {
  const SolarRoiSummary({
    required this.investment,
    required this.accumulatedSavings,
    required this.monthlyAverageSavings,
  });
  final double investment, accumulatedSavings, monthlyAverageSavings;
  double get progress => investment <= 0
      ? 1
      : (accumulatedSavings / investment).clamp(0, 1).toDouble();
  double? get remainingMonths => monthlyAverageSavings <= 0
      ? null
      : ((investment - accumulatedSavings).clamp(0, double.infinity) /
                monthlyAverageSavings)
            .toDouble();
}

class SolarSystemProfile {
  const SolarSystemProfile({
    required this.id,
    required this.name,
    required this.installed,
    required this.systemKw,
    required this.panelCount,
    required this.panelWattage,
    required this.installationCost,
    required this.maintenanceCost,
    this.inverter,
    this.battery,
  });
  final int id, panelCount;
  final String name;
  final DateTime installed;
  final double systemKw, panelWattage, installationCost, maintenanceCost;
  final String? inverter, battery;
}
