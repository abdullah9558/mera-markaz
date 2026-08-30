import 'dart:math' as math;
import '../../../core/calculators/calculator.dart';
import '../../../core/config/rate_config.dart';

class SolarInput {
  const SolarInput({
    required this.monthlyUnits,
    required this.roofAreaSquareFeet,
    this.essentialLoadKw = 0,
    this.backupHours = 0,
  });
  final double monthlyUnits;
  final double roofAreaSquareFeet;
  final double essentialLoadKw;
  final double backupHours;
}

class SolarResult {
  const SolarResult({
    required this.systemKw,
    required this.panelCount,
    required this.monthlyGeneration,
    required this.roofAreaRequired,
    required this.monthlySavings,
    required this.inverterKw,
    required this.usableBatteryKwh,
    required this.nominalBatteryKwh,
    required this.config,
  });
  final double systemKw;
  final int panelCount;
  final double monthlyGeneration;
  final double roofAreaRequired;
  final double monthlySavings;
  final double inverterKw;
  final double usableBatteryKwh;
  final double nominalBatteryKwh;
  final SolarAssumptions config;
  double get annualSavings => monthlySavings * 12;
  double get estimatedCost => systemKw * 1000 * config.systemCostPerWatt;
  double get paybackYears =>
      annualSavings <= 0 ? 0 : estimatedCost / annualSavings;
}

class SolarCalculator implements Calculator<SolarInput, SolarResult> {
  const SolarCalculator(this.config);
  final SolarAssumptions config;
  @override
  SolarResult calculate(SolarInput input) {
    if (input.monthlyUnits < 0 ||
        input.roofAreaSquareFeet < 0 ||
        input.essentialLoadKw < 0 ||
        input.backupHours < 0) {
      throw const CalculationException(
        'Consumption and roof area cannot be negative.',
      );
    }
    final generationPerKw = config.dailyYieldPerKw * 30;
    final desiredKw = input.monthlyUnits == 0
        ? 0
        : input.monthlyUnits / generationPerKw;
    final panels = desiredKw == 0
        ? 0
        : math.max(1, (desiredKw * 1000 / config.panelWatts).ceil());
    final systemKw = panels * config.panelWatts / 1000;
    final roofRequired = panels * 28;
    final usablePanels = input.roofAreaSquareFeet == 0
        ? panels
        : math.min(panels, (input.roofAreaSquareFeet / 28).floor());
    final generation =
        usablePanels * config.panelWatts / 1000 * generationPerKw;
    final inverterKw = _nextCommonInverter(
      math.max(systemKw / 1.3, input.essentialLoadKw * 1.25),
    );
    final usableBattery = input.essentialLoadKw * input.backupHours;
    return SolarResult(
      systemKw: systemKw,
      panelCount: panels,
      monthlyGeneration: generation.toDouble(),
      roofAreaRequired: roofRequired.toDouble(),
      monthlySavings:
          math.min(generation, input.monthlyUnits) * config.electricityRate,
      inverterKw: inverterKw,
      usableBatteryKwh: usableBattery,
      nominalBatteryKwh: usableBattery == 0 ? 0 : usableBattery / .8,
      config: config,
    );
  }

  double _nextCommonInverter(double required) {
    const sizes = [1.2, 2.0, 3.0, 5.0, 6.0, 8.0, 10.0, 12.0, 15.0, 20.0];
    return sizes.firstWhere(
      (size) => size >= required,
      orElse: () => required.ceilToDouble(),
    );
  }
}

final defaultSolarAssumptions = SolarAssumptions(
  panelWatts: 585,
  dailyYieldPerKw: 4.2,
  systemCostPerWatt: 115,
  electricityRate: 45,
  metadata: RateMetadata(
    version: 'manual-assumptions-v1',
    effectiveFrom: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sourceLabel: 'Editable planning assumptions',
  ),
);
