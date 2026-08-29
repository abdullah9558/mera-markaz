import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

final moduleFinanceRepositoryProvider = Provider<ModuleFinanceRepository>(
  (ref) => ModuleFinanceRepository(ref.watch(appDatabaseProvider)),
);

class LinkedRecordResult {
  const LinkedRecordResult({
    required this.recordId,
    required this.transactionId,
  });
  final int recordId;
  final int transactionId;
}

/// Owns the boundary between calculator records and the shared money timeline.
/// Each source record has at most one linked transaction.
class ModuleFinanceRepository {
  const ModuleFinanceRepository(this._database);
  final AppDatabase _database;

  Future<LinkedRecordResult> recordElectricityBill({
    int? calculationId,
    required double units,
    required double total,
    required String configVersion,
    DateTime? occurredAt,
  }) => _database.database.transaction((txn) async {
    final now = DateTime.now();
    final values = {
      'provider': 'Residential estimate',
      'units': units,
      'estimated_total': total,
      'config_version': configVersion,
      'created_at': now.toIso8601String(),
      'owner_id': _database.ownerId,
    };
    final recordId = await _saveSourceRecord(
      txn,
      table: 'electricity_calculations',
      id: calculationId,
      values: values,
    );
    final transactionId = await _upsertTransaction(
      txn,
      source: 'electricity',
      sourceRecordId: '$recordId',
      type: 'expense',
      category: 'Electricity',
      amount: total,
      description: 'Electricity bill',
      occurredAt: occurredAt ?? now,
    );
    return LinkedRecordResult(recordId: recordId, transactionId: transactionId);
  });

  Future<LinkedRecordResult> recordSalary({
    int? calculationId,
    required double monthlySalary,
    required double annualIncome,
    required double annualTax,
    required String taxYear,
    DateTime? occurredAt,
  }) => _database.database.transaction((txn) async {
    final now = DateTime.now();
    final recordId = await _saveSourceRecord(
      txn,
      table: 'tax_calculations',
      id: calculationId,
      values: {
        'tax_year': taxYear,
        'annual_income': annualIncome,
        'annual_tax': annualTax,
        'config_version': taxYear,
        'created_at': now.toIso8601String(),
        'owner_id': _database.ownerId,
      },
    );
    final transactionId = await _upsertTransaction(
      txn,
      source: 'salary',
      sourceRecordId: '$recordId',
      type: 'income',
      category: 'Salary',
      amount: monthlySalary,
      description: 'Monthly salary',
      occurredAt: occurredAt ?? now,
    );
    return LinkedRecordResult(recordId: recordId, transactionId: transactionId);
  });

  Future<LinkedRecordResult> recordFuelExpense({
    int? entryId,
    int? vehicleId,
    required double liters,
    required double cost,
    required double odometer,
    DateTime? occurredAt,
  }) => _database.database.transaction((txn) async {
    final now = occurredAt ?? DateTime.now();
    final resolvedVehicleId = vehicleId ?? await _defaultVehicle(txn);
    final values = {
      'vehicle_id': resolvedVehicleId,
      'liters': liters,
      'cost': cost,
      'odometer': odometer,
      'filled_at': now.toIso8601String(),
      'owner_id': _database.ownerId,
    };
    final recordId = await _saveSourceRecord(
      txn,
      table: 'fuel_entries',
      id: entryId,
      values: values,
    );
    final transactionId = await _upsertTransaction(
      txn,
      source: 'fuel',
      sourceRecordId: '$recordId',
      type: 'expense',
      category: 'Fuel',
      amount: cost,
      description: 'Fuel purchase',
      occurredAt: now,
    );
    await txn.update(
      'fuel_entries',
      {'linked_transaction_id': transactionId},
      where: 'id = ? AND owner_id = ?',
      whereArgs: [recordId, _database.ownerId],
    );
    return LinkedRecordResult(recordId: recordId, transactionId: transactionId);
  });

  Future<int> _saveSourceRecord(
    DatabaseExecutor txn, {
    required String table,
    required int? id,
    required Map<String, Object?> values,
  }) async {
    if (id == null) return txn.insert(table, values);
    await txn.update(
      table,
      values,
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _database.ownerId],
    );
    return id;
  }

  Future<int> _defaultVehicle(DatabaseExecutor txn) async {
    final rows = await txn.query(
      'vehicles',
      columns: ['id'],
      where: 'owner_id = ?',
      whereArgs: [_database.ownerId],
      orderBy: 'id',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int;
    return txn.insert('vehicles', {
      'name': 'My vehicle',
      'fuel_type': 'petrol',
      'odometer': 0,
      'owner_id': _database.ownerId,
    });
  }

  Future<int> _upsertTransaction(
    DatabaseExecutor txn, {
    required String source,
    required String sourceRecordId,
    required String type,
    required String category,
    required double amount,
    required String description,
    required DateTime occurredAt,
  }) async {
    if (amount <= 0) throw const FormatException('Amount must be positive.');
    final categories = await txn.query(
      'categories',
      columns: ['id'],
      where: 'type = ? AND name = ?',
      whereArgs: [type, category],
      limit: 1,
    );
    if (categories.isEmpty) {
      throw FormatException('$category category is not available.');
    }
    final now = DateTime.now().toIso8601String();
    final existing = await txn.query(
      'transactions',
      columns: ['id', 'created_at'],
      where: 'owner_id = ? AND source = ? AND source_record_id = ?',
      whereArgs: [_database.ownerId, source, sourceRecordId],
      limit: 1,
    );
    final values = <String, Object?>{
      'type': type,
      'amount': amount,
      'category_id': categories.first['id'],
      'occurred_at': occurredAt.toIso8601String(),
      'description': description,
      'created_at': existing.isEmpty ? now : existing.first['created_at'],
      'updated_at': now,
      'source': source,
      'source_record_id': sourceRecordId,
      'owner_id': _database.ownerId,
    };
    if (existing.isEmpty) return txn.insert('transactions', values);
    final id = existing.first['id'] as int;
    await txn.update(
      'transactions',
      values,
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _database.ownerId],
    );
    return id;
  }
}
