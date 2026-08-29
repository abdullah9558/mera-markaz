import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/expenses/data/expense_repository.dart';
import 'package:pakpocket/features/expenses/data/module_finance_repository.dart';
import 'package:pakpocket/features/expenses/domain/finance_transaction.dart';
import 'package:pakpocket/features/udhaar/data/ledger_repository.dart';
import 'package:pakpocket/features/udhaar/domain/ledger.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late ModuleFinanceRepository modules;
  late ExpenseRepository expenses;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
    await database.startGuestSession('stage-7');
    modules = ModuleFinanceRepository(database);
    expenses = ExpenseRepository(database);
  });

  tearDown(() => database.close());

  test(
    'fuel confirmation is linked and repeated saves update, not duplicate',
    () async {
      final first = await modules.recordFuelExpense(
        liters: 20,
        cost: 6000,
        odometer: 500,
      );
      final second = await modules.recordFuelExpense(
        entryId: first.recordId,
        liters: 21,
        cost: 6300,
        odometer: 520,
      );

      expect(second.transactionId, first.transactionId);
      final rows = await expenses.all();
      expect(rows, hasLength(1));
      expect(rows.single.source, TransactionSource.fuel);
      expect(rows.single.amount, 6300);
    },
  );

  test('electricity and salary post to the correct sides of finance', () async {
    await modules.recordElectricityBill(
      units: 250,
      total: 14500,
      configVersion: 'test-tariff',
    );
    await modules.recordSalary(
      monthlySalary: 180000,
      annualIncome: 2160000,
      annualTax: 120000,
      taxYear: '2025-26',
    );

    final rows = await expenses.all();
    expect(
      rows
          .where((row) => row.source == TransactionSource.electricity)
          .single
          .type,
      TransactionType.expense,
    );
    expect(
      rows.where((row) => row.source == TransactionSource.salary).single.type,
      TransactionType.income,
    );
  });

  test(
    'Udhaar remains in financial overview without inflating income or expense',
    () async {
      await LedgerRepository(database).create(
        name: 'Ahmed',
        direction: LedgerDirection.gave,
        amount: 10000,
        date: DateTime.now(),
        description: 'Short loan',
      );

      final ledger = await LedgerRepository(database).summary();
      final finance = await expenses.summary();
      expect(ledger.toReceive, 10000);
      expect(finance.monthIncome, 0);
      expect(finance.monthExpense, 0);
    },
  );
}
