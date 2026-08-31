import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/features/advanced_finance/domain/advanced_finance_models.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/advanced_finance/data/advanced_finance_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  test('fixed financing produces a complete zero-balance amortization', () {
    final result = FinancingCalculator.calculate(
      const FinancingInput(
        amount: 1200000,
        downPayment: 200000,
        annualRate: 12,
        months: 24,
      ),
    );
    expect(result.schedule, hasLength(24));
    expect(result.schedule.last.balance, closeTo(0, .01));
    expect(result.totalRepayment, greaterThan(1000000));
    expect(result.financingCost, greaterThan(0));
  });

  test('variable financing combines KIBOR and spread transparently', () {
    final result = FinancingCalculator.calculate(
      const FinancingInput(
        amount: 1000000,
        annualRate: 0,
        months: 12,
        rateType: FinancingRateType.variable,
        kiborRate: 11,
        spread: 3,
      ),
    );
    final fixed = FinancingCalculator.calculate(
      const FinancingInput(amount: 1000000, annualRate: 14, months: 12),
    );
    expect(result.monthlyPayment, closeTo(fixed.monthlyPayment, .01));
  });

  test('historical inflation and future purchasing power stay distinct', () {
    final historical = InflationCalculator.historical(
      amount: 100000,
      annualRates: const [10, 10],
    );
    final future = InflationCalculator.futureScenario(
      savings: 100000,
      assumedRates: const [10, 10],
    );
    expect(historical.adjustedAmount, closeTo(121000, .01));
    expect(future.adjustedAmount, closeTo(82644.63, .02));
    expect(historical.type, InflationCalculationType.historical);
    expect(future.type, InflationCalculationType.futureScenario);
  });

  test('financial health score is bounded and fully explainable', () {
    final result = FinancialHealthCalculator.calculate(
      const FinancialHealthInput(
        monthlyIncome: 200000,
        monthlyExpenses: 140000,
        budgetAdherence: .9,
        savingsRate: .2,
        emergencyMonths: 4,
        debtPaymentRate: .1,
        billPaymentRate: 1,
      ),
    );
    expect(result.score, inInclusiveRange(0, 100));
    expect(
      result.components.keys,
      containsAll([
        'Cash flow',
        'Budget adherence',
        'Savings consistency',
        'Emergency fund',
        'Debt obligations',
        'Bill reliability',
      ]),
    );
    expect(result.explanations, isNotEmpty);
  });

  test('Phase 7 scenarios persist owner-scoped results', () async {
    final database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
    await database.startGuestSession('phase-seven');
    final repository = AdvancedFinanceRepository(database);
    await repository.saveFinancing(
      name: 'Car option',
      financingType: 'car',
      input: const FinancingInput(
        amount: 2000000,
        downPayment: 500000,
        annualRate: 14,
        months: 36,
      ),
    );
    final result = InflationCalculator.futureScenario(
      savings: 500000,
      assumedRates: const [8, 8, 8],
    );
    await repository.saveInflation(
      name: 'Three year plan',
      result: result,
      rates: const [8, 8, 8],
    );
    expect(await repository.financingScenarios(), hasLength(1));
    expect(await repository.inflationScenarios(), hasLength(1));
    await database.close();
  });
}
