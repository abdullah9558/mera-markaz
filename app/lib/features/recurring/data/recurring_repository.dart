import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/finance_transaction.dart';
import '../domain/recurring_transaction.dart';

final recurringRepositoryProvider = Provider(
  (ref) => RecurringRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(expenseRepositoryProvider),
  ),
);

class RecurringRepository {
  const RecurringRepository(this._database, this._expenses);
  final AppDatabase _database;
  final ExpenseRepository _expenses;

  Future<List<RecurringTransaction>> all() async {
    final rows = await _database.database.rawQuery(
      '''SELECT r.*, c.name category_name FROM recurring_transactions r
         JOIN categories c ON c.id = r.category_id
         WHERE r.owner_id = ? ORDER BY r.next_due_at''',
      [_database.ownerId],
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> save({
    int? id,
    required TransactionType type,
    required double amount,
    required int categoryId,
    required String description,
    required RecurringFrequency frequency,
    int intervalCount = 1,
    required DateTime nextDueAt,
  }) async {
    if (amount <= 0 || description.trim().isEmpty || intervalCount <= 0) {
      throw const FormatException('Enter valid recurring transaction details.');
    }
    final now = DateTime.now().toIso8601String();
    final values = {
      'type': type.name,
      'amount': amount,
      'category_id': categoryId,
      'description': description.trim(),
      'frequency': frequency.name,
      'interval_count': intervalCount,
      'next_due_at': nextDueAt.toIso8601String(),
      'source': 'recurring',
      'updated_at': now,
      'owner_id': _database.ownerId,
    };
    final recurringId =
        id ??
        await _database.database.insert('recurring_transactions', {
          ...values,
          'status': RecurringStatus.active.name,
          'created_at': now,
        });
    if (id != null) {
      await _database.database.update(
        'recurring_transactions',
        values,
        where: 'id = ? AND owner_id = ?',
        whereArgs: [id, _database.ownerId],
      );
    }
    await _upsertReminder(recurringId, description, nextDueAt);
    return recurringId;
  }

  Future<void> setStatus(int id, RecurringStatus status) async {
    await _database.database.update(
      'recurring_transactions',
      {'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _database.ownerId],
    );
    await _database.database.update(
      'reminders',
      {'status': status == RecurringStatus.active ? 'pending' : 'paused'},
      where:
          "owner_id = ? AND reference_type = 'recurring' AND reference_id = ?",
      whereArgs: [_database.ownerId, '$id'],
    );
  }

  Future<void> delete(int id) async {
    await _database.database.transaction((txn) async {
      await txn.delete(
        'reminders',
        where:
            "owner_id = ? AND reference_type = 'recurring' AND reference_id = ?",
        whereArgs: [_database.ownerId, '$id'],
      );
      await txn.delete(
        'recurring_transactions',
        where: 'id = ? AND owner_id = ?',
        whereArgs: [id, _database.ownerId],
      );
    });
  }

  Future<int> confirmOccurrence(RecurringTransaction recurring) async {
    if (recurring.status != RecurringStatus.active) {
      throw const FormatException(
        'Paused recurring transactions cannot be posted.',
      );
    }
    final transactionId = await _expenses.save(
      FinanceTransaction(
        type: recurring.type,
        amount: recurring.amount,
        categoryId: recurring.categoryId,
        categoryName: recurring.categoryName,
        occurredAt: recurring.nextDueAt,
        description: recurring.description,
        source: TransactionSource.recurring,
        sourceRecordId:
            '${recurring.id}:${recurring.nextDueAt.toIso8601String()}',
      ),
    );
    final next = recurring.followingDate();
    await _database.database.update(
      'recurring_transactions',
      {
        'next_due_at': next.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND owner_id = ?',
      whereArgs: [recurring.id, _database.ownerId],
    );
    await _upsertReminder(recurring.id, recurring.description, next);
    return transactionId;
  }

  Future<void> _upsertReminder(int id, String title, DateTime date) async {
    await _database.database.delete(
      'reminders',
      where:
          "owner_id = ? AND reference_type = 'recurring' AND reference_id = ?",
      whereArgs: [_database.ownerId, '$id'],
    );
    await _database.database.insert('reminders', {
      'kind': 'recurringTransaction',
      'reference_type': 'recurring',
      'reference_id': '$id',
      'title': title,
      'scheduled_at': date.toIso8601String(),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
      'owner_id': _database.ownerId,
    });
  }

  RecurringTransaction _fromRow(Map<String, Object?> row) =>
      RecurringTransaction(
        id: row['id'] as int,
        type: TransactionType.values.byName(row['type'] as String),
        amount: (row['amount'] as num).toDouble(),
        categoryId: row['category_id'] as int,
        categoryName: row['category_name'] as String,
        description: row['description'] as String,
        frequency: RecurringFrequency.values.byName(row['frequency'] as String),
        intervalCount: row['interval_count'] as int,
        nextDueAt: DateTime.parse(row['next_due_at'] as String),
        status: RecurringStatus.values.byName(row['status'] as String),
      );
}
