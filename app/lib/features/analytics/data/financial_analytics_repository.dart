import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/financial_analytics.dart';

final financialAnalyticsRepositoryProvider = Provider(
  (ref) => FinancialAnalyticsRepository(ref.watch(appDatabaseProvider)),
);

class FinancialAnalyticsRepository {
  const FinancialAnalyticsRepository(this._database);
  final AppDatabase _database;

  Future<FinancialPeriodSummary> monthlySummary(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final previousStart = DateTime(month.year, month.month - 1);
    final totals = await _database.database.rawQuery(
      '''
      SELECT type,
        SUM(CASE WHEN occurred_at >= ? AND occurred_at < ? THEN amount ELSE 0 END) current_total,
        SUM(CASE WHEN occurred_at >= ? AND occurred_at < ? THEN amount ELSE 0 END) previous_total
      FROM transactions
      WHERE owner_id = ? AND occurred_at >= ? AND occurred_at < ?
      GROUP BY type
      ''',
      [
        start.toIso8601String(),
        end.toIso8601String(),
        previousStart.toIso8601String(),
        start.toIso8601String(),
        _database.ownerId,
        previousStart.toIso8601String(),
        end.toIso8601String(),
      ],
    );
    double current(String type) => _value(totals, type, 'current_total');
    double previous(String type) => _value(totals, type, 'previous_total');
    return FinancialPeriodSummary(
      start: start,
      end: end,
      income: current('income'),
      expenses: current('expense'),
      previousIncome: previous('income'),
      previousExpenses: previous('expense'),
    );
  }

  Future<List<CategorySpending>> spendingByCategory(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await _database.database.rawQuery(
      '''
      SELECT c.id category_id, c.name category_name, SUM(t.amount) total
      FROM transactions t
      JOIN categories c ON c.id = t.category_id
      WHERE t.owner_id = ? AND t.type = 'expense'
        AND t.occurred_at >= ? AND t.occurred_at < ?
      GROUP BY c.id, c.name
      ORDER BY total DESC
      ''',
      [_database.ownerId, start.toIso8601String(), end.toIso8601String()],
    );
    return rows
        .map(
          (row) => CategorySpending(
            categoryId: row['category_id'] as int,
            categoryName: row['category_name'] as String,
            amount: (row['total'] as num).toDouble(),
          ),
        )
        .toList();
  }

  static double _value(
    List<Map<String, Object?>> rows,
    String type,
    String column,
  ) {
    for (final row in rows) {
      if (row['type'] == type) return ((row[column] as num?) ?? 0).toDouble();
    }
    return 0;
  }
}
