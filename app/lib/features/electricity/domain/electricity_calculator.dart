import '../../../core/calculators/calculator.dart';
import '../../../core/config/rate_config.dart';

class ElectricityInput {
  const ElectricityInput({required this.units, this.taxRate = .18});
  final double units;
  final double taxRate;
}

class ElectricityResult {
  const ElectricityResult({
    required this.units,
    required this.energyCharges,
    required this.fixedCharges,
    required this.taxes,
    required this.config,
  });
  final double units;
  final double energyCharges;
  final double fixedCharges;
  final double taxes;
  final ElectricityTariffConfig config;
  double get total => energyCharges + fixedCharges + taxes;
}

class ElectricityCalculator
    implements Calculator<ElectricityInput, ElectricityResult> {
  const ElectricityCalculator(this.config);
  final ElectricityTariffConfig config;
  @override
  ElectricityResult calculate(ElectricityInput input) {
    if (input.units < 0) {
      throw const CalculationException('Units cannot be negative.');
    }
    if (input.taxRate < 0 || input.taxRate > 1) {
      throw const CalculationException(
        'Tax percentage must be between 0 and 100.',
      );
    }
    var rate = 0.0;
    for (final entry in config.unitRates.entries) {
      if (input.units <= entry.key) {
        rate = entry.value;
        break;
      }
    }
    if (rate == 0 && config.unitRates.isNotEmpty) {
      rate = config.unitRates.values.last;
    }
    final energy = input.units * rate;
    final taxes = (energy + config.fixedCharge) * input.taxRate;
    return ElectricityResult(
      units: input.units,
      energyCharges: energy,
      fixedCharges: config.fixedCharge,
      taxes: taxes,
      config: config,
    );
  }
}

final residentialTariff2026 = ElectricityTariffConfig(
  provider: 'XWDISCO / estimate',
  category: 'Residential non-protected',
  unitRates: {
    100: 22.44,
    200: 28.91,
    300: 33.10,
    400: 36.46,
    500: 38.95,
    600: 40.22,
    700: 41.85,
    double.infinity: 47.21,
  },
  fixedCharge: 300,
  taxRate: .18,
  metadata: RateMetadata(
    version: 'nepra-feb-2026-v1',
    effectiveFrom: DateTime(2026, 2, 1),
    updatedAt: DateTime(2026, 2, 11),
    sourceLabel: 'NEPRA national uniform tariff, Feb 2026',
  ),
);
