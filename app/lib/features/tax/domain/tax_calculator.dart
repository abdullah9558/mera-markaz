import '../../../core/calculators/calculator.dart';
import '../../../core/config/rate_config.dart';

class TaxInput {
  const TaxInput({required this.monthlySalary, this.otherAnnualIncome = 0});
  final double monthlySalary;
  final double otherAnnualIncome;
}

class TaxResult {
  const TaxResult({
    required this.annualIncome,
    required this.annualTax,
    required this.config,
  });
  final double annualIncome;
  final double annualTax;
  final TaxYearConfig config;
  double get monthlyTax => annualTax / 12;
  double get monthlyTakeHome => (annualIncome - annualTax) / 12;
  double get effectiveRate => annualIncome == 0 ? 0 : annualTax / annualIncome;
}

class TaxCalculator implements Calculator<TaxInput, TaxResult> {
  const TaxCalculator(this.config);
  final TaxYearConfig config;
  @override
  TaxResult calculate(TaxInput input) {
    if (input.monthlySalary < 0 || input.otherAnnualIncome < 0) {
      throw const CalculationException('Income cannot be negative.');
    }
    final income = input.monthlySalary * 12 + input.otherAnnualIncome;
    var tax = 0.0;
    for (final slab in config.slabs.reversed) {
      if (income > slab.from) {
        tax = slab.baseTax + (income - slab.from) * slab.rate;
        break;
      }
    }
    return TaxResult(annualIncome: income, annualTax: tax, config: config);
  }
}

final taxYear2025_26 = TaxYearConfig(
  year: '2025-26',
  slabs: const [
    TaxSlab(from: 0, to: 600000, baseTax: 0, rate: 0),
    TaxSlab(from: 600000, to: 1200000, baseTax: 0, rate: .01),
    TaxSlab(from: 1200000, to: 2200000, baseTax: 6000, rate: .11),
    TaxSlab(from: 2200000, to: 3200000, baseTax: 116000, rate: .23),
    TaxSlab(from: 3200000, to: 4100000, baseTax: 346000, rate: .30),
    TaxSlab(from: 4100000, baseTax: 616000, rate: .35),
  ],
  metadata: RateMetadata(
    version: 'fbr-fa-2025-v1',
    effectiveFrom: DateTime(2025, 7, 1),
    updatedAt: DateTime(2025, 6, 30),
    sourceLabel: 'FBR Finance Act 2025',
  ),
);
