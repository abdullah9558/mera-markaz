import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../domain/budget_analytics.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(appDatabaseProvider)),
);

class BudgetRepository {
  const BudgetRepository(this.database);
  final AppDatabase database;
  static const _thresholdsKey = 'budget_warning_thresholds_v1';
  DateTime _start(DateTime value) => DateTime(value.year, value.month);
  DateTime _end(DateTime value) => DateTime(
    value.year,
    value.month + 1,
  ).subtract(const Duration(microseconds: 1));
  Future<MonthlyBudget?> monthly(DateTime month) async {
    final start = _start(month);
    final rows = await database.database.query(
      'budgets',
      where: 'owner_id = ? AND category_id IS NULL AND period_start = ?',
      whereArgs: [database.ownerId, start.toIso8601String()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MonthlyBudget(
      id: rows.first['id'] as int,
      amount: (rows.first['amount'] as num).toDouble(),
      month: start,
    );
  }

  Future<void> setMonthly(DateTime month, double amount) async {
    if (amount <= 0) {
      throw const FormatException('Budget must be greater than zero.');
    }
    final start = _start(month);
    final end = _end(month).toIso8601String();
    final existing = await database.database.query(
      'budgets',
      columns: ['id'],
      where: 'owner_id = ? AND category_id IS NULL AND period_start = ?',
      whereArgs: [database.ownerId, start.toIso8601String()],
      limit: 1,
    );
    if (existing.isEmpty) {
      await database.database.insert('budgets', {
        'category_id': null,
        'amount': amount,
        'period_start': start.toIso8601String(),
        'period_end': end,
        'owner_id': database.ownerId,
      });
    } else {
      await database.database.update(
        'budgets',
        {'amount': amount, 'period_end': end},
        where: 'owner_id = ? AND category_id IS NULL AND period_start = ?',
        whereArgs: [database.ownerId, start.toIso8601String()],
      );
    }
  }

  Future<List<CategoryTotal>> categoryTotals(DateTime month) async {
    final rows = await database.database.rawQuery(
      '''SELECT c.name category, COALESCE(SUM(t.amount), 0) amount FROM transactions t JOIN categories c ON c.id = t.category_id WHERE t.owner_id = ? AND t.type = 'expense' AND t.occurred_at >= ? AND t.occurred_at < ? GROUP BY c.id ORDER BY amount DESC''',
      [
        database.ownerId,
        _start(month).toIso8601String(),
        DateTime(month.year, month.month + 1).toIso8601String(),
      ],
    );
    return rows
        .map(
          (row) => CategoryTotal(
            category: row['category'] as String,
            amount: (row['amount'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<List<CategoryBudgetStatus>> categoryBudgets(DateTime month) async {
    final start = _start(month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await database.database.rawQuery(
      '''
      SELECT b.id budget_id, c.id category_id, c.name category,
        b.amount budget,
        COALESCE(SUM(t.amount), 0) spent
      FROM budgets b
      JOIN categories c ON c.id = b.category_id
      LEFT JOIN transactions t ON t.category_id = c.id
        AND t.owner_id = b.owner_id AND t.type = 'expense'
        AND t.occurred_at >= ? AND t.occurred_at < ?
      WHERE b.owner_id = ? AND b.period_start = ? AND b.category_id IS NOT NULL
      GROUP BY b.id, c.id, c.name, b.amount
      ORDER BY c.name
      ''',
      [
        start.toIso8601String(),
        end.toIso8601String(),
        database.ownerId,
        start.toIso8601String(),
      ],
    );
    return rows
        .map(
          (row) => CategoryBudgetStatus(
            budgetId: row['budget_id'] as int,
            categoryId: row['category_id'] as int,
            category: row['category'] as String,
            budget: (row['budget'] as num).toDouble(),
            spent: (row['spent'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<void> setCategory({
    required DateTime month,
    required int categoryId,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw const FormatException('Budget must be greater than zero.');
    }
    final start = _start(month);
    final existing = await database.database.query(
      'budgets',
      columns: ['id'],
      where: 'owner_id = ? AND category_id = ? AND period_start = ?',
      whereArgs: [database.ownerId, categoryId, start.toIso8601String()],
      limit: 1,
    );
    if (existing.isEmpty) {
      await database.database.insert('budgets', {
        'category_id': categoryId,
        'amount': amount,
        'period_start': start.toIso8601String(),
        'period_end': _end(month).toIso8601String(),
        'owner_id': database.ownerId,
      });
    } else {
      await database.database.update(
        'budgets',
        {'amount': amount, 'period_end': _end(month).toIso8601String()},
        where: 'id = ? AND owner_id = ?',
        whereArgs: [existing.first['id'], database.ownerId],
      );
    }
  }

  Future<void> deleteCategory(int budgetId) => database.database.delete(
    'budgets',
    where: 'id = ? AND owner_id = ? AND category_id IS NOT NULL',
    whereArgs: [budgetId, database.ownerId],
  );

  Future<List<int>> warningThresholds() async {
    final stored = (await SharedPreferences.getInstance()).getString(
      _thresholdsKey,
    );
    if (stored == null) return const [70, 80, 90, 100];
    final values =
        stored
            .split(',')
            .map(int.tryParse)
            .whereType<int>()
            .where((value) => value > 0 && value <= 100)
            .toSet()
            .toList()
          ..sort();
    return values.isEmpty ? const [70, 80, 90, 100] : values;
  }

  Future<void> setWarningThresholds(Iterable<int> values) async {
    final normalized =
        values.where((value) => value > 0 && value <= 100).toSet().toList()
          ..sort();
    if (normalized.isEmpty) {
      throw const FormatException('Select at least one warning threshold.');
    }
    await (await SharedPreferences.getInstance()).setString(
      _thresholdsKey,
      normalized.join(','),
    );
  }

  Future<List<BudgetThresholdAlert>> evaluateThresholds(DateTime month) async {
    final thresholds = await warningThresholds();
    final start = _start(month);
    final overall = await monthly(month);
    final categories = await categoryBudgets(month);
    final alerts = <BudgetThresholdAlert>[];
    final candidates = <BudgetThresholdAlert>[];
    if (overall?.id != null) {
      final rows = await database.database.rawQuery(
        '''SELECT COALESCE(SUM(amount), 0) total FROM transactions
           WHERE owner_id = ? AND type = 'expense' AND occurred_at >= ? AND occurred_at < ?''',
        [
          database.ownerId,
          start.toIso8601String(),
          DateTime(month.year, month.month + 1).toIso8601String(),
        ],
      );
      final spent = (rows.first['total'] as num).toDouble();
      for (final threshold in thresholds) {
        if (spent / overall!.amount * 100 >= threshold) {
          candidates.add(
            BudgetThresholdAlert(
              budgetId: overall.id!,
              threshold: threshold,
              spent: spent,
              budget: overall.amount,
            ),
          );
        }
      }
    }
    for (final category in categories) {
      for (final threshold in thresholds) {
        if (category.progress * 100 >= threshold) {
          candidates.add(
            BudgetThresholdAlert(
              budgetId: category.budgetId!,
              category: category.category,
              threshold: threshold,
              spent: category.spent,
              budget: category.budget,
            ),
          );
        }
      }
    }
    for (final candidate in candidates) {
      final id = await database.database.insert('budget_threshold_events', {
        'budget_id': candidate.budgetId,
        'threshold': candidate.threshold,
        'period_start': start.toIso8601String(),
        'notified_at': DateTime.now().toIso8601String(),
        'owner_id': database.ownerId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (id != 0) alerts.add(candidate);
    }
    return alerts;
  }
}
