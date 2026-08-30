import '../../../core/calculators/calculator.dart';
import '../../../core/config/rate_config.dart';

class ElectricityInput {
  const ElectricityInput({
    required this.units,
    this.taxRate = .18,
    this.electricityDutyRate = 0,
    this.adjustments = 0,
    this.tvFee = 0,
  });
  final double units;
  final double taxRate;
  final double electricityDutyRate;
  final double adjustments;
  final double tvFee;
}

class ElectricityResult {
  const ElectricityResult({
    required this.units,
    required this.energyCharges,
    required this.fixedCharges,
    required this.taxes,
    required this.electricityDuty,
    required this.adjustments,
    required this.tvFee,
    required this.config,
  });
  final double units;
  final double energyCharges;
  final double fixedCharges;
  final double taxes;
  final double electricityDuty;
  final double adjustments;
  final double tvFee;
  final ElectricityTariffConfig config;
  double get total =>
      energyCharges +
      fixedCharges +
      taxes +
      electricityDuty +
      adjustments +
      tvFee;
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
    if (input.taxRate < 0 ||
        input.taxRate > 1 ||
        input.electricityDutyRate < 0 ||
        input.electricityDutyRate > 1 ||
        input.adjustments < 0 ||
        input.tvFee < 0) {
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
    var fixedCharge = config.fixedCharge;
    for (final entry in config.fixedChargesByUnits.entries) {
      if (input.units <= entry.key) {
        fixedCharge = entry.value;
        break;
      }
    }
    final energy = input.units * rate;
    final taxes = (energy + fixedCharge) * input.taxRate;
    final electricityDuty = energy * input.electricityDutyRate;
    return ElectricityResult(
      units: input.units,
      energyCharges: energy,
      fixedCharges: fixedCharge,
      taxes: taxes,
      electricityDuty: electricityDuty,
      adjustments: input.adjustments,
      tvFee: input.tvFee,
      config: config,
    );
  }
}

final residentialTariff2026 = ElectricityTariffConfig(
  provider: 'XWDISCO / national uniform tariff',
  category: 'Residential non-protected',
  unitRates: {
    100: 22.44,
    200: 28.91,
    300: 33.10,
    400: 37.99,
    500: 40.20,
    600: 41.63,
    700: 42.76,
    double.infinity: 47.69,
  },
  fixedCharge: 0,
  fixedChargesByUnits: {
    300: 0,
    400: 200,
    500: 400,
    600: 600,
    700: 800,
    double.infinity: 1000,
  },
  taxRate: .18,
  metadata: RateMetadata(
    version: 'nepra-jan-2026-v2',
    effectiveFrom: DateTime(2026, 1, 12),
    updatedAt: DateTime(2026, 1, 12),
    sourceLabel: 'NEPRA national uniform tariff decision, 12 Jan 2026',
  ),
);

final protectedResidentialTariff2026 = ElectricityTariffConfig(
  provider: 'XWDISCO / national uniform tariff',
  category: 'Residential protected',
  unitRates: {100: 10.84, double.infinity: 13.01},
  fixedCharge: 0,
  taxRate: .18,
  metadata: RateMetadata(
    version: 'nepra-jan-2026-protected-v1',
    effectiveFrom: DateTime(2026, 1, 12),
    updatedAt: DateTime(2026, 1, 12),
    sourceLabel: 'NEPRA national uniform tariff decision, 12 Jan 2026',
  ),
);
