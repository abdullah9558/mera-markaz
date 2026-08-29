import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/expenses/data/expense_repository.dart';
import 'package:pakpocket/features/expenses/data/budget_repository.dart';
import 'package:pakpocket/features/expenses/domain/finance_transaction.dart';
import 'package:pakpocket/features/udhaar/data/ledger_repository.dart';
import 'package:pakpocket/features/udhaar/domain/ledger.dart';
import 'package:pakpocket/features/search/data/search_repository.dart';
import 'package:pakpocket/features/settings/data/data_control_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
  });
  tearDown(() => database.close());

  test('expense creation, editing, summaries and deletion persist', () async {
    final repository = ExpenseRepository(database);
    final expenseCategory = (await repository.categories(
      TransactionType.expense,
    )).first;
    final incomeCategory = (await repository.categories(
      TransactionType.income,
    )).first;
    final now = DateTime.now();
    final expenseId = await repository.save(
      FinanceTransaction(
        type: TransactionType.expense,
        amount: 1200.50,
        categoryId: expenseCategory.id,
        categoryName: expenseCategory.name,
        occurredAt: now,
        description: 'Groceries',
      ),
    );
    await repository.save(
      FinanceTransaction(
        type: TransactionType.income,
        amount: 5000,
        categoryId: incomeCategory.id,
        categoryName: incomeCategory.name,
        occurredAt: now,
        description: 'Payment',
      ),
    );
    var summary = await repository.summary(now);
    expect(summary.monthExpense, 1200.50);
    expect(summary.monthIncome, 5000);
    await repository.save(
      FinanceTransaction(
        id: expenseId,
        type: TransactionType.expense,
        amount: 1000,
        categoryId: expenseCategory.id,
        categoryName: expenseCategory.name,
        occurredAt: now,
        description: 'Edited groceries',
      ),
    );
    expect(
      (await repository.all()).firstWhere((e) => e.id == expenseId).amount,
      1000,
    );
    await repository.delete(expenseId);
    summary = await repository.summary(now);
    expect(summary.monthExpense, 0);
  });

  test('Udhaar partial and full repayments update balances', () async {
    final repository = LedgerRepository(database);
    final personId = await repository.create(
      name: 'Ali',
      direction: LedgerDirection.gave,
      amount: 10000,
      date: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 7)),
      description: 'Emergency loan',
    );
    var entry = (await repository.entries(personId)).single;
    await repository.recordPayment(entry, 2500);
    entry = (await repository.entries(personId)).single;
    expect(entry.remaining, 7500);
    expect(entry.statusAt(DateTime.now()), LedgerStatus.partiallyPaid);
    expect((await repository.summary()).toReceive, 7500);
    await repository.recordPayment(entry, 7500);
    entry = (await repository.entries(personId)).single;
    expect(entry.statusAt(DateTime.now()), LedgerStatus.paid);
    expect((await repository.summary()).toReceive, 0);
  });

  test('Udhaar rejects overpayment and overdue status is derived', () async {
    final repository = LedgerRepository(database);
    final personId = await repository.create(
      name: 'Sara',
      direction: LedgerDirection.took,
      amount: 500,
      date: DateTime(2026),
      dueDate: DateTime(2026, 1, 2),
      description: 'Borrowed cash',
    );
    final entry = (await repository.entries(personId)).single;
    expect(entry.statusAt(DateTime(2026, 1, 3)), LedgerStatus.overdue);
    await expectLater(
      repository.recordPayment(entry, 501),
      throwsA(isA<FormatException>()),
    );
  });

  test('monthly budget upserts and category analytics use expenses', () async {
    final expenses = ExpenseRepository(database);
    final budgets = BudgetRepository(database);
    final category = (await expenses.categories(TransactionType.expense)).first;
    final now = DateTime.now();
    await expenses.save(
      FinanceTransaction(
        type: TransactionType.expense,
        amount: 750,
        categoryId: category.id,
        categoryName: category.name,
        occurredAt: now,
        description: 'Category expense',
      ),
    );
    await budgets.setMonthly(now, 5000);
    await budgets.setMonthly(now, 6000);
    expect((await budgets.monthly(now))!.amount, 6000);
    final totals = await budgets.categoryTotals(now);
    expect(totals.single.category, category.name);
    expect(totals.single.amount, 750);
  });

  test(
    'global search finds transactions, people and ledger descriptions',
    () async {
      final expenses = ExpenseRepository(database);
      final category = (await expenses.categories(
        TransactionType.expense,
      )).first;
      await expenses.save(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 300,
          categoryId: category.id,
          categoryName: category.name,
          occurredAt: DateTime.now(),
          description: 'School books',
        ),
      );
      await LedgerRepository(database).create(
        name: 'Hamza',
        direction: LedgerDirection.gave,
        amount: 2000,
        date: DateTime.now(),
        description: 'School fee help',
      );
      final results = await SearchRepository(database).search('school');
      expect(
        results.map((value) => value.title),
        containsAll(['School books', 'School fee help']),
      );
      expect((await SearchRepository(database).search('hamza')).length, 2);
    },
  );

  test('delete all financial data preserves categories', () async {
    final expenses = ExpenseRepository(database);
    final category = (await expenses.categories(TransactionType.expense)).first;
    await expenses.save(
      FinanceTransaction(
        type: TransactionType.expense,
        amount: 100,
        categoryId: category.id,
        categoryName: category.name,
        occurredAt: DateTime.now(),
        description: 'Temporary',
      ),
    );
    await DataControlService(database).deleteAllFinancialData();
    expect(await expenses.all(), isEmpty);
    expect(await expenses.categories(TransactionType.expense), isNotEmpty);
  });
}
