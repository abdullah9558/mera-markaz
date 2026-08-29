import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../domain/finance_transaction.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(appDatabaseProvider)),
);

class ExpenseRepository {
  const ExpenseRepository(this._appDatabase);
  final AppDatabase _appDatabase;

  Future<List<ExpenseCategory>> categories(TransactionType type) async {
    final rows = await _appDatabase.database.query(
      'categories',
      where: 'type = ?',
      whereArgs: [type.name],
      orderBy: 'name',
    );
    return rows
        .map(
          (row) => ExpenseCategory(
            id: row['id'] as int,
            name: row['name'] as String,
            type: type,
          ),
        )
        .toList();
  }

  Future<List<FinanceTransaction>> all() async {
    final rows = await _appDatabase.database.rawQuery(
      'SELECT t.*, c.name category_name FROM transactions t JOIN categories c ON c.id = t.category_id WHERE t.owner_id = ? ORDER BY occurred_at DESC, t.id DESC',
      [_appDatabase.ownerId],
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> save(FinanceTransaction value) async {
    if (value.amount <= 0) {
      throw const FormatException('Amount must be greater than zero.');
    }
    if (value.description.trim().isEmpty) {
      throw const FormatException('Description is required.');
    }
    if (value.source != TransactionSource.manual &&
        (value.sourceRecordId == null ||
            value.sourceRecordId!.trim().isEmpty)) {
      throw const FormatException(
        'Linked transactions require a source record ID.',
      );
    }
    final now = DateTime.now().toIso8601String();
    final data = {
      'type': value.type.name,
      'amount': value.amount,
      'category_id': value.categoryId,
      'occurred_at': value.occurredAt.toIso8601String(),
      'description': value.description.trim(),
      'payment_method': value.paymentMethod,
      'note': value.note,
      'created_at': now,
      'updated_at': now,
      'source': value.source.name,
      'source_record_id': value.sourceRecordId,
      'owner_id': _appDatabase.ownerId,
    };
    var id = value.id;
    if (id == null && value.sourceRecordId != null) {
      final existing = await _appDatabase.database.query(
        'transactions',
        columns: ['id', 'created_at'],
        where: 'owner_id = ? AND source = ? AND source_record_id = ?',
        whereArgs: [
          _appDatabase.ownerId,
          value.source.name,
          value.sourceRecordId,
        ],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        id = existing.first['id'] as int;
        data['created_at'] = existing.first['created_at'];
      }
    }
    if (id == null) {
      return _appDatabase.database.insert('transactions', data);
    }
    await _appDatabase.database.update(
      'transactions',
      data,
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _appDatabase.ownerId],
    );
    return id;
  }

  Future<void> delete(int id) => _appDatabase.database.delete(
    'transactions',
    where: 'id = ? AND owner_id = ?',
    whereArgs: [id, _appDatabase.ownerId],
  );

  Future<FinanceSummary> summary([DateTime? now]) async {
    final date = now ?? DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final week = day.subtract(Duration(days: day.weekday - 1));
    final month = DateTime(date.year, date.month);
    Future<double> total(TransactionType type, DateTime from) async {
      final rows = await _appDatabase.database.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) total FROM transactions WHERE owner_id = ? AND type = ? AND occurred_at >= ?',
        [_appDatabase.ownerId, type.name, from.toIso8601String()],
      );
      return (rows.first['total'] as num).toDouble();
    }

    return FinanceSummary(
      todayExpense: await total(TransactionType.expense, day),
      weekExpense: await total(TransactionType.expense, week),
      monthExpense: await total(TransactionType.expense, month),
      monthIncome: await total(TransactionType.income, month),
    );
  }

  FinanceTransaction _fromRow(Map<String, Object?> row) => FinanceTransaction(
    id: row['id'] as int,
    type: TransactionType.values.byName(row['type'] as String),
    amount: (row['amount'] as num).toDouble(),
    categoryId: row['category_id'] as int,
    categoryName: row['category_name'] as String,
    occurredAt: DateTime.parse(row['occurred_at'] as String),
    description: row['description'] as String,
    paymentMethod: row['payment_method'] as String?,
    note: row['note'] as String?,
    source: TransactionSource.values.byName(
      (row['source'] as String?) ?? TransactionSource.manual.name,
    ),
    sourceRecordId: row['source_record_id'] as String?,
  );
}
