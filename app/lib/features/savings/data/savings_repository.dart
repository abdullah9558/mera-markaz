import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/savings_goal.dart';

final savingsRepositoryProvider = Provider(
  (ref) => SavingsRepository(ref.watch(appDatabaseProvider)),
);

class SavingsRepository {
  const SavingsRepository(this._database);
  final AppDatabase _database;

  Future<List<SavingsGoal>> goals({bool includeArchived = false}) async {
    final rows = await _database.database.rawQuery(
      '''
      SELECT g.*, COALESCE(SUM(c.amount), 0) saved_amount
      FROM savings_goals g
      LEFT JOIN goal_contributions c ON c.goal_id = g.id AND c.owner_id = g.owner_id
      WHERE g.owner_id = ? ${includeArchived ? '' : "AND g.status != 'archived'"}
      GROUP BY g.id
      ORDER BY CASE g.status WHEN 'active' THEN 0 WHEN 'completed' THEN 1 ELSE 2 END,
        g.updated_at DESC
      ''',
      [_database.ownerId],
    );
    return rows.map(_goalFromRow).toList();
  }

  Future<SavingsGoal> goal(int id) async {
    final rows = await _database.database.rawQuery(
      '''SELECT g.*, COALESCE(SUM(c.amount), 0) saved_amount
         FROM savings_goals g
         LEFT JOIN goal_contributions c ON c.goal_id = g.id AND c.owner_id = g.owner_id
         WHERE g.id = ? AND g.owner_id = ? GROUP BY g.id''',
      [id, _database.ownerId],
    );
    if (rows.isEmpty) throw StateError('Savings goal not found.');
    return _goalFromRow(rows.single);
  }

  Future<int> saveGoal({
    int? id,
    required String name,
    String? icon,
    required double targetAmount,
    DateTime? targetDate,
    String? notes,
  }) async {
    if (name.trim().isEmpty || targetAmount <= 0) {
      throw const FormatException('Enter a goal name and positive target.');
    }
    final now = DateTime.now().toIso8601String();
    final values = {
      'name': name.trim(),
      'icon': icon,
      'target_amount': targetAmount,
      'target_date': targetDate?.toIso8601String(),
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'updated_at': now,
      'owner_id': _database.ownerId,
    };
    if (id == null) {
      return _database.database.insert('savings_goals', {
        ...values,
        'status': SavingsGoalStatus.active.name,
        'created_at': now,
      });
    }
    await _database.database.update(
      'savings_goals',
      values,
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _database.ownerId],
    );
    return id;
  }

  Future<void> addContribution({
    required int goalId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    if (amount == 0) {
      throw const FormatException('Contribution cannot be zero.');
    }
    final current = await goal(goalId);
    if (amount < 0 && amount.abs() > current.savedAmount) {
      throw const FormatException('Withdrawal exceeds the saved amount.');
    }
    if (current.status == SavingsGoalStatus.archived) {
      throw const FormatException('Archived goals cannot be changed.');
    }
    await _database.database.transaction((txn) async {
      await txn.insert('goal_contributions', {
        'goal_id': goalId,
        'amount': amount,
        'contributed_at': date.toIso8601String(),
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'owner_id': _database.ownerId,
      });
      await txn.update(
        'savings_goals',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ? AND owner_id = ?',
        whereArgs: [goalId, _database.ownerId],
      );
    });
  }

  Future<List<GoalContribution>> contributions(int goalId) async {
    final rows = await _database.database.query(
      'goal_contributions',
      where: 'goal_id = ? AND owner_id = ?',
      whereArgs: [goalId, _database.ownerId],
      orderBy: 'contributed_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => GoalContribution(
            id: row['id'] as int,
            goalId: goalId,
            amount: (row['amount'] as num).toDouble(),
            contributedAt: DateTime.parse(row['contributed_at'] as String),
            note: row['note'] as String?,
          ),
        )
        .toList();
  }

  Future<void> deleteContribution(int id) => _database.database.delete(
    'goal_contributions',
    where: 'id = ? AND owner_id = ?',
    whereArgs: [id, _database.ownerId],
  );

  Future<void> setStatus(int id, SavingsGoalStatus status) =>
      _database.database.update(
        'savings_goals',
        {'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ? AND owner_id = ?',
        whereArgs: [id, _database.ownerId],
      );

  SavingsGoal _goalFromRow(Map<String, Object?> row) => SavingsGoal(
    id: row['id'] as int,
    name: row['name'] as String,
    icon: row['icon'] as String?,
    targetAmount: (row['target_amount'] as num).toDouble(),
    savedAmount: (row['saved_amount'] as num).toDouble(),
    targetDate: row['target_date'] == null
        ? null
        : DateTime.parse(row['target_date'] as String),
    notes: row['notes'] as String?,
    status: SavingsGoalStatus.values.byName(row['status'] as String),
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}
