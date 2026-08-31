import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/personal_finance_models.dart';

final personalFinanceRepositoryProvider = Provider(
  (ref) => PersonalFinanceRepository(ref.watch(appDatabaseProvider)),
);

class PersonalFinanceRepository {
  const PersonalFinanceRepository(this.database);
  final AppDatabase database;

  Future<List<SalaryBreakdown>> salaries() async {
    final rows = await database.database.query(
      'salary_records',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      orderBy: 'received_at DESC',
    );
    return rows
        .map(
          (row) => SalaryBreakdown(
            id: row['id'] as int,
            basicSalary: (row['basic_salary'] as num).toDouble(),
            houseAllowance: (row['house_allowance'] as num).toDouble(),
            medicalAllowance: (row['medical_allowance'] as num).toDouble(),
            transportAllowance: (row['transport_allowance'] as num).toDouble(),
            bonus: (row['bonus'] as num).toDouble(),
            commission: (row['commission'] as num).toDouble(),
            otherAllowances: (row['other_allowances'] as num).toDouble(),
            tax: (row['tax'] as num).toDouble(),
            otherDeductions: (row['other_deductions'] as num).toDouble(),
            receivedAt: DateTime.parse(row['received_at'] as String),
            notes: row['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<List<FreelancerIncomeRecord>> freelancerIncome() async {
    final rows = await database.database.query(
      'freelancer_income',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      orderBy: 'expected_at DESC',
    );
    return rows
        .map(
          (row) => FreelancerIncomeRecord(
            id: row['id'] as int,
            client: row['client'] as String,
            grossAmount: (row['gross_amount'] as num).toDouble(),
            currency: row['currency'] as String,
            exchangeRate: (row['exchange_rate'] as num).toDouble(),
            fees: (row['fees'] as num).toDouble(),
            paymentMethod: row['payment_method'] as String?,
            status: FreelancerPaymentStatus.values.byName(
              row['status'] as String,
            ),
            expectedAt: DateTime.parse(row['expected_at'] as String),
            receivedAt: row['received_at'] == null
                ? null
                : DateTime.parse(row['received_at'] as String),
            notes: row['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<List<HouseholdBill>> bills() async {
    final rows = await database.database.query(
      'bills',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      orderBy: 'due_date ASC',
    );
    return rows
        .map(
          (row) => HouseholdBill(
            id: row['id'] as int,
            type: row['type'] as String,
            provider: row['provider'] as String,
            accountReference: row['account_reference'] as String?,
            amount: (row['amount'] as num).toDouble(),
            issueDate: row['issue_date'] == null
                ? null
                : DateTime.parse(row['issue_date'] as String),
            dueDate: DateTime.parse(row['due_date'] as String),
            status: BillStatus.values.byName(row['status'] as String),
            recurringFrequency: row['recurring_frequency'] as String?,
            notes: row['notes'] as String?,
            attachmentPath: row['attachment_path'] as String?,
          ),
        )
        .toList();
  }

  Future<EmergencyFundStatus> emergencyFundStatus() async {
    final preference = await database.database.query(
      'financial_preferences',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      limit: 1,
    );
    final savings = await database.database.rawQuery(
      "SELECT COALESCE(SUM(balance), 0) saved FROM net_worth_accounts WHERE owner_id = ? AND kind = 'asset' AND (LOWER(name) LIKE '%cash%' OR LOWER(name) LIKE '%saving%' OR LOWER(name) LIKE '%bank%')",
      [database.ownerId],
    );
    final expense = await database.database.rawQuery(
      "SELECT COALESCE(AVG(month_total), 0) average FROM (SELECT SUM(amount) month_total FROM transactions WHERE owner_id = ? AND type = 'expense' AND occurred_at >= ? GROUP BY substr(occurred_at, 1, 7))",
      [
        database.ownerId,
        DateTime.now().subtract(const Duration(days: 183)).toIso8601String(),
      ],
    );
    final configured =
        preference.firstOrNull?['essential_monthly_expenses'] as num?;
    return EmergencyFundStatus(
      saved: (savings.single['saved'] as num).toDouble(),
      monthlyEssential:
          configured?.toDouble() ??
          (expense.single['average'] as num).toDouble(),
      targetMonths:
          ((preference.firstOrNull?['emergency_fund_target_months'] as num?) ??
                  3)
              .toDouble(),
    );
  }

  Future<void> setEmergencyFundTarget({
    required double targetMonths,
    double? monthlyEssential,
  }) async {
    if (targetMonths <= 0 ||
        (monthlyEssential != null && monthlyEssential < 0)) {
      throw const FormatException('Emergency fund target is invalid.');
    }
    await database.database.insert('financial_preferences', {
      'emergency_fund_target_months': targetMonths,
      'essential_monthly_expenses': monthlyEssential,
      'updated_at': DateTime.now().toIso8601String(),
      'owner_id': database.ownerId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> saveSalary(SalaryBreakdown value) async {
    if (value.basicSalary < 0 || value.net <= 0) {
      throw const FormatException('Net salary must be greater than zero.');
    }
    return database.database.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final data = <String, Object?>{
        'basic_salary': value.basicSalary,
        'house_allowance': value.houseAllowance,
        'medical_allowance': value.medicalAllowance,
        'transport_allowance': value.transportAllowance,
        'bonus': value.bonus,
        'commission': value.commission,
        'other_allowances': value.otherAllowances,
        'tax': value.tax,
        'other_deductions': value.otherDeductions,
        'received_at': value.receivedAt.toIso8601String(),
        'notes': value.notes,
        'created_at': now,
        'updated_at': now,
        'owner_id': database.ownerId,
      };
      final id = value.id ?? await txn.insert('salary_records', data);
      if (value.id != null) {
        data.remove('created_at');
        await txn.update(
          'salary_records',
          data,
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, database.ownerId],
        );
      }
      final transactionId = await _upsertTransaction(
        txn,
        type: 'income',
        amount: value.net,
        categoryName: 'Salary',
        occurredAt: value.receivedAt,
        description: 'Salary received',
        source: 'salary',
        sourceRecordId: '$id',
      );
      await txn.update(
        'salary_records',
        {'linked_transaction_id': transactionId},
        where: 'id = ? AND owner_id = ?',
        whereArgs: [id, database.ownerId],
      );
      return id;
    });
  }

  Future<int> saveFreelancer(FreelancerIncomeRecord value) async {
    if (value.client.trim().isEmpty ||
        value.grossAmount <= 0 ||
        value.exchangeRate <= 0 ||
        value.fees < 0 ||
        value.fees > value.pkrGross) {
      throw const FormatException('Freelancer income values are invalid.');
    }
    return database.database.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final data = <String, Object?>{
        'client': value.client.trim(),
        'gross_amount': value.grossAmount,
        'currency': value.currency,
        'exchange_rate': value.exchangeRate,
        'fees': value.fees,
        'pkr_net': value.pkrNet,
        'payment_method': value.paymentMethod,
        'status': value.status.name,
        'expected_at': value.expectedAt.toIso8601String(),
        'received_at': value.receivedAt?.toIso8601String(),
        'notes': value.notes,
        'created_at': now,
        'updated_at': now,
        'owner_id': database.ownerId,
      };
      final id = value.id ?? await txn.insert('freelancer_income', data);
      if (value.id != null) {
        data.remove('created_at');
        await txn.update(
          'freelancer_income',
          data,
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, database.ownerId],
        );
      }
      if (value.status == FreelancerPaymentStatus.received) {
        final transactionId = await _upsertTransaction(
          txn,
          type: 'income',
          amount: value.pkrNet,
          categoryName: 'Freelance',
          occurredAt: value.receivedAt ?? value.expectedAt,
          description: 'Freelance income - ${value.client}',
          source: 'freelancer',
          sourceRecordId: '$id',
        );
        await txn.update(
          'freelancer_income',
          {'linked_transaction_id': transactionId},
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, database.ownerId],
        );
      } else {
        await txn.delete(
          'transactions',
          where: 'owner_id = ? AND source = ? AND source_record_id = ?',
          whereArgs: [database.ownerId, 'freelancer', '$id'],
        );
        await txn.update(
          'freelancer_income',
          {'linked_transaction_id': null},
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, database.ownerId],
        );
      }
      return id;
    });
  }

  Future<int> saveBill(HouseholdBill value) async {
    if (value.provider.trim().isEmpty || value.amount < 0) {
      throw const FormatException('Bill values are invalid.');
    }
    final now = DateTime.now().toIso8601String();
    final data = <String, Object?>{
      'type': value.type,
      'provider': value.provider.trim(),
      'account_reference': value.accountReference,
      'amount': value.amount,
      'issue_date': value.issueDate?.toIso8601String(),
      'due_date': value.dueDate.toIso8601String(),
      'status': value.status.name,
      'recurring_frequency': value.recurringFrequency,
      'notes': value.notes,
      'attachment_path': value.attachmentPath,
      'created_at': now,
      'updated_at': now,
      'owner_id': database.ownerId,
    };
    if (value.id == null) return database.database.insert('bills', data);
    data.remove('created_at');
    await database.database.update(
      'bills',
      data,
      where: 'id = ? AND owner_id = ?',
      whereArgs: [value.id, database.ownerId],
    );
    return value.id!;
  }

  Future<int> payBill(int billId, double amount, DateTime paidAt) async {
    if (amount <= 0) throw const FormatException('Payment must be positive.');
    return database.database.transaction((txn) async {
      final rows = await txn.query(
        'bills',
        where: 'id = ? AND owner_id = ?',
        whereArgs: [billId, database.ownerId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Bill not found.');
      final bill = rows.single;
      final paymentId = await txn.insert('bill_payments', {
        'bill_id': billId,
        'amount': amount,
        'paid_at': paidAt.toIso8601String(),
        'owner_id': database.ownerId,
      });
      final transactionId = await _upsertTransaction(
        txn,
        type: 'expense',
        amount: amount,
        categoryName: 'Bills',
        occurredAt: paidAt,
        description: '${bill['provider']} bill payment',
        source: 'bill',
        sourceRecordId: '$paymentId',
      );
      await txn.update(
        'bill_payments',
        {'linked_transaction_id': transactionId},
        where: 'id = ? AND owner_id = ?',
        whereArgs: [paymentId, database.ownerId],
      );
      final paid = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) total FROM bill_payments WHERE bill_id = ? AND owner_id = ?',
        [billId, database.ownerId],
      );
      if ((paid.single['total'] as num).toDouble() >=
          (bill['amount'] as num).toDouble()) {
        await txn.update(
          'bills',
          {
            'status': BillStatus.paid.name,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND owner_id = ?',
          whereArgs: [billId, database.ownerId],
        );
      }
      return paymentId;
    });
  }

  Future<int> _upsertTransaction(
    DatabaseExecutor txn, {
    required String type,
    required double amount,
    required String categoryName,
    required DateTime occurredAt,
    required String description,
    required String source,
    required String sourceRecordId,
  }) async {
    final categories = await txn.query(
      'categories',
      columns: ['id'],
      where: 'name = ? AND type = ?',
      whereArgs: [categoryName, type],
      limit: 1,
    );
    final categoryId = categories.isNotEmpty
        ? categories.single['id'] as int
        : await txn.insert('categories', {
            'name': categoryName,
            'type': type,
            'is_system': 1,
          });
    final existing = await txn.query(
      'transactions',
      columns: ['id'],
      where: 'owner_id = ? AND source = ? AND source_record_id = ?',
      whereArgs: [database.ownerId, source, sourceRecordId],
      limit: 1,
    );
    final now = DateTime.now().toIso8601String();
    final data = <String, Object?>{
      'type': type,
      'amount': amount,
      'category_id': categoryId,
      'occurred_at': occurredAt.toIso8601String(),
      'description': description,
      'created_at': now,
      'updated_at': now,
      'source': source,
      'source_record_id': sourceRecordId,
      'owner_id': database.ownerId,
    };
    if (existing.isEmpty) return txn.insert('transactions', data);
    final id = existing.single['id'] as int;
    data.remove('created_at');
    await txn.update(
      'transactions',
      data,
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, database.ownerId],
    );
    return id;
  }
}
