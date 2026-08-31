import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/analytics/data/financial_analytics_repository.dart';
import 'package:pakpocket/features/expenses/data/expense_repository.dart';
import 'package:pakpocket/features/expenses/domain/finance_transaction.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late ExpenseRepository expenses;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
    await database.startGuestSession('foundation');
    expenses = ExpenseRepository(database);
  });

  tearDown(() => database.close());

  Future<ExpenseCategory> category(TransactionType type, String name) async =>
      (await expenses.categories(type)).firstWhere((c) => c.name == name);

  test(
    'linked source saves update one transaction instead of duplicating',
    () async {
      final fuel = await category(TransactionType.expense, 'Fuel');
      FinanceTransaction entry(double amount) => FinanceTransaction(
        type: TransactionType.expense,
        amount: amount,
        categoryId: fuel.id,
        categoryName: fuel.name,
        occurredAt: DateTime(2026, 8, 25),
        description: 'Fuel fill-up',
        source: TransactionSource.fuel,
        sourceRecordId: 'fuel-entry-42',
      );

      final firstId = await expenses.save(entry(5000));
      final secondId = await expenses.save(entry(5500));

      expect(secondId, firstId);
      expect(await expenses.all(), hasLength(1));
      expect((await expenses.all()).single.amount, 5500);
    },
  );

  test(
    'monthly analytics uses period boundaries and real previous totals',
    () async {
      final salary = await category(TransactionType.income, 'Salary');
      final food = await category(TransactionType.expense, 'Food');
      Future<int> add(
        TransactionType type,
        ExpenseCategory selected,
        double amount,
        DateTime date,
      ) => expenses.save(
        FinanceTransaction(
          type: type,
          amount: amount,
          categoryId: selected.id,
          categoryName: selected.name,
          occurredAt: date,
          description: selected.name,
        ),
      );

      await add(TransactionType.expense, food, 1000, DateTime(2026, 7, 31));
      await add(TransactionType.income, salary, 100000, DateTime(2026, 8, 1));
      await add(TransactionType.expense, food, 25000, DateTime(2026, 8, 31));
      await add(TransactionType.expense, food, 999, DateTime(2026, 9, 1));

      final result = await FinancialAnalyticsRepository(
        database,
      ).monthlySummary(DateTime(2026, 8));

      expect(result.income, 100000);
      expect(result.expenses, 25000);
      expect(result.previousExpenses, 1000);
      expect(result.availableBalance, 75000);
      expect(result.savingsRate, .75);
      expect(result.expenseChange, 24);
    },
  );

  test('non-manual records require a stable source record ID', () async {
    final fuel = await category(TransactionType.expense, 'Fuel');
    await expectLater(
      expenses.save(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 100,
          categoryId: fuel.id,
          categoryName: fuel.name,
          occurredAt: DateTime.now(),
          description: 'Fuel',
          source: TransactionSource.fuel,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
