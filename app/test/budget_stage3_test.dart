import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/expenses/data/budget_repository.dart';
import 'package:pakpocket/features/expenses/data/expense_repository.dart';
import 'package:pakpocket/features/expenses/domain/finance_transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late BudgetRepository budgets;
  late ExpenseRepository expenses;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
    await database.startGuestSession('budget-stage-3');
    budgets = BudgetRepository(database);
    expenses = ExpenseRepository(database);
  });

  tearDown(() => database.close());

  test('category budget reports remaining and exceeded amounts', () async {
    final food = (await expenses.categories(
      TransactionType.expense,
    )).firstWhere((category) => category.name == 'Food');
    await budgets.setCategory(
      month: DateTime(2026, 8),
      categoryId: food.id,
      amount: 20000,
    );
    await expenses.save(
      FinanceTransaction(
        type: TransactionType.expense,
        amount: 22500,
        categoryId: food.id,
        categoryName: food.name,
        occurredAt: DateTime(2026, 8, 25),
        description: 'Food expense',
      ),
    );

    final status = (await budgets.categoryBudgets(DateTime(2026, 8))).single;
    expect(status.spent, 22500);
    expect(status.remaining, -2500);
    expect(status.progress, 1.125);
    expect(status.exceeded, isTrue);
  });

  test('each configured threshold produces only one persisted event', () async {
    final shopping = (await expenses.categories(
      TransactionType.expense,
    )).firstWhere((category) => category.name == 'Shopping');
    await budgets.setWarningThresholds([80, 100]);
    await budgets.setCategory(
      month: DateTime(2026, 8),
      categoryId: shopping.id,
      amount: 10000,
    );
    await expenses.save(
      FinanceTransaction(
        type: TransactionType.expense,
        amount: 8500,
        categoryId: shopping.id,
        categoryName: shopping.name,
        occurredAt: DateTime(2026, 8, 10),
        description: 'Shopping',
      ),
    );

    final first = await budgets.evaluateThresholds(DateTime(2026, 8));
    final repeated = await budgets.evaluateThresholds(DateTime(2026, 8));

    expect(first.map((alert) => alert.threshold), [80]);
    expect(repeated, isEmpty);

    await expenses.save(
      FinanceTransaction(
        type: TransactionType.expense,
        amount: 2000,
        categoryId: shopping.id,
        categoryName: shopping.name,
        occurredAt: DateTime(2026, 8, 20),
        description: 'More shopping',
      ),
    );
    final exceeded = await budgets.evaluateThresholds(DateTime(2026, 8));
    expect(exceeded.map((alert) => alert.threshold), [100]);
    expect(exceeded.single.exceeded, isTrue);
  });

  test('warning threshold configuration is normalized and persisted', () async {
    await budgets.setWarningThresholds([100, 80, 80, -1, 150]);
    expect(await budgets.warningThresholds(), [80, 100]);
  });
}
