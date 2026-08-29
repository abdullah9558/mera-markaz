import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/calculators/calculator.dart';
import 'package:pakpocket/features/electricity/domain/electricity_calculator.dart';
import 'package:pakpocket/features/fuel/domain/fuel_calculator.dart';
import 'package:pakpocket/features/property/domain/property_calculator.dart';
import 'package:pakpocket/features/solar/domain/solar_calculator.dart';
import 'package:pakpocket/features/tax/domain/tax_calculator.dart';
import 'package:pakpocket/features/zakat/domain/zakat_calculator.dart';

void main() {
  group('salary tax', () {
    final calculator = TaxCalculator(taxYear2025_26);
    test('zero and tax-free boundary produce no tax', () {
      expect(
        calculator.calculate(const TaxInput(monthlySalary: 0)).annualTax,
        0,
      );
      expect(
        calculator.calculate(const TaxInput(monthlySalary: 50000)).annualTax,
        0,
      );
    });
    test('every slab boundary is continuous', () {
      expect(
        calculator.calculate(const TaxInput(monthlySalary: 100000)).annualTax,
        6000,
      );
      expect(
        calculator
            .calculate(const TaxInput(monthlySalary: 1200000 / 12))
            .annualTax,
        6000,
      );
      expect(
        calculator
            .calculate(const TaxInput(monthlySalary: 2200000 / 12))
            .annualTax,
        116000,
      );
      expect(
        calculator
            .calculate(const TaxInput(monthlySalary: 3200000 / 12))
            .annualTax,
        346000,
      );
      expect(
        calculator
            .calculate(const TaxInput(monthlySalary: 4100000 / 12))
            .annualTax,
        closeTo(616000, .01),
      );
    });
    test(
      'negative income is rejected',
      () => expect(
        () => calculator.calculate(const TaxInput(monthlySalary: -1)),
        throwsA(isA<CalculationException>()),
      ),
    );
  });

  group('electricity', () {
    final calculator = ElectricityCalculator(residentialTariff2026);
    test('slab boundary selects configured rate', () {
      final at100 = calculator.calculate(
        const ElectricityInput(units: 100, taxRate: 0),
      );
      final at101 = calculator.calculate(
        const ElectricityInput(units: 101, taxRate: 0),
      );
      expect(at100.energyCharges, 2244);
      expect(at101.energyCharges, closeTo(2919.91, .001));
    });
    test('tax and fixed charges are included', () {
      final result = calculator.calculate(const ElectricityInput(units: 0));
      expect(result.total, 354);
    });
    test('negative units and invalid percentages are rejected', () {
      expect(
        () => calculator.calculate(const ElectricityInput(units: -1)),
        throwsA(isA<CalculationException>()),
      );
      expect(
        () =>
            calculator.calculate(const ElectricityInput(units: 1, taxRate: 2)),
        throwsA(isA<CalculationException>()),
      );
    });
  });

  test('solar recommendation respects roof generation constraint', () {
    final result = SolarCalculator(
      defaultSolarAssumptions,
    ).calculate(const SolarInput(monthlyUnits: 500, roofAreaSquareFeet: 56));
    expect(result.panelCount, greaterThan(2));
    expect(result.monthlyGeneration, closeTo(147.42, .01));
  });

  group('property', () {
    test('configurable 272.25 square-foot Marla converts correctly', () {
      final result = const PropertyCalculator().calculate(
        const PropertyInput(length: 27.225, width: 10),
      );
      expect(result.marla, closeTo(1, .0001));
      expect(result.kanal, closeTo(.05, .0001));
    });
    test(
      'invalid dimensions are rejected',
      () => expect(
        () => const PropertyCalculator().calculate(
          const PropertyInput(length: 0, width: 10),
        ),
        throwsA(isA<CalculationException>()),
      ),
    );
  });

  group('fuel', () {
    test('calculates decimals and cost per km', () {
      final result = const FuelCalculator().calculate(
        const FuelInput(distanceKm: 125.5, liters: 10, fuelPrice: 280),
      );
      expect(result.averageKmPerLiter, 12.55);
      expect(result.costPerKm, closeTo(22.3107, .001));
    });
    test(
      'zero fuel is rejected',
      () => expect(
        () => const FuelCalculator().calculate(
          const FuelInput(distanceKm: 100, liters: 0),
        ),
        throwsA(isA<CalculationException>()),
      ),
    );
    test('trip cost supports very large values', () {
      final result = const TripCostCalculator().calculate(
        const TripCostInput(
          distanceKm: 1000000,
          averageKmPerLiter: 10,
          fuelPrice: 300,
        ),
      );
      expect(result.cost, 30000000);
    });
  });

  group('zakat', () {
    const calculator = ZakatCalculator();
    test(
      'exact Nisab boundary is eligible',
      () => expect(
        calculator
            .calculate(
              const ZakatInput(assets: 1000000, liabilities: 0, nisab: 1000000),
            )
            .zakatDue,
        25000,
      ),
    );
    test(
      'below Nisab has no Zakat',
      () => expect(
        calculator
            .calculate(
              const ZakatInput(assets: 999999, liabilities: 0, nisab: 1000000),
            )
            .zakatDue,
        0,
      ),
    );
    test(
      'liabilities cannot create a negative base',
      () => expect(
        calculator
            .calculate(
              const ZakatInput(assets: 100, liabilities: 200, nisab: 0),
            )
            .netZakatable,
        0,
      ),
    );
  });
}
