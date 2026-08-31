import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/advanced_finance_models.dart';

final advancedFinanceRepositoryProvider = Provider(
  (ref) => AdvancedFinanceRepository(ref.watch(appDatabaseProvider)),
);

class AdvancedFinanceRepository {
  const AdvancedFinanceRepository(this.database);
  final AppDatabase database;

  Future<int> saveFinancing({
    required String name,
    required String financingType,
    required FinancingInput input,
  }) {
    final result = FinancingCalculator.calculate(input);
    return database.database.insert('financing_scenarios', {
      'name': name.trim(),
      'financing_type': financingType,
      'amount': input.amount,
      'down_payment': input.downPayment,
      'rate_type': input.rateType.name,
      'annual_rate': input.annualRate,
      'kibor_rate': input.kiborRate,
      'spread': input.spread,
      'tenure_months': input.months,
      'monthly_payment': result.monthlyPayment,
      'total_repayment': result.totalRepayment,
      'financing_cost': result.financingCost,
      'created_at': DateTime.now().toIso8601String(),
      'owner_id': database.ownerId,
    });
  }

  Future<List<Map<String, Object?>>> financingScenarios() =>
      database.database.query(
        'financing_scenarios',
        where: 'owner_id = ?',
        whereArgs: [database.ownerId],
        orderBy: 'created_at DESC',
      );

  Future<int> saveInflation({
    required String name,
    required PurchasingPowerResult result,
    required List<double> rates,
    int? startYear,
    int? endYear,
  }) => database.database.insert('inflation_scenarios', {
    'name': name.trim(),
    'calculation_type': result.type.name,
    'nominal_amount': result.nominalAmount,
    'adjusted_amount': result.adjustedAmount,
    'cumulative_inflation': result.cumulativeInflation,
    'rates_json': jsonEncode(rates),
    'start_year': startYear,
    'end_year': endYear,
    'created_at': DateTime.now().toIso8601String(),
    'owner_id': database.ownerId,
  });

  Future<List<Map<String, Object?>>> inflationScenarios() =>
      database.database.query(
        'inflation_scenarios',
        where: 'owner_id = ?',
        whereArgs: [database.ownerId],
        orderBy: 'created_at DESC',
      );

  Future<int> saveHealth(FinancialHealthResult result) =>
      database.database.insert('financial_health_snapshots', {
        'score': result.score,
        'status': result.status,
        'components_json': jsonEncode(result.components),
        'explanations_json': jsonEncode(result.explanations),
        'captured_at': DateTime.now().toIso8601String(),
        'owner_id': database.ownerId,
      });

  Future<List<Map<String, Object?>>> healthHistory() => database.database.query(
    'financial_health_snapshots',
    where: 'owner_id = ?',
    whereArgs: [database.ownerId],
    orderBy: 'captured_at ASC',
  );
}
