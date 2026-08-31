import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/expenses/data/expense_repository.dart';
import 'package:pakpocket/features/expenses/domain/finance_transaction.dart';
import 'package:pakpocket/features/recurring/data/recurring_repository.dart';
import 'package:pakpocket/features/recurring/domain/recurring_transaction.dart';
import 'package:pakpocket/features/savings/data/savings_repository.dart';
import 'package:pakpocket/features/search/data/search_repository.dart';
import 'package:pakpocket/features/search/domain/search_result.dart';
import 'package:pakpocket/features/timeline/data/timeline_repository.dart';
import 'package:pakpocket/features/timeline/domain/timeline_event.dart';
import 'package:pakpocket/features/personal_finance/data/personal_finance_repository.dart';
import 'package:pakpocket/features/personal_finance/domain/personal_finance_models.dart';
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
    await database.startGuestSession('unified-stage-6');
    expenses = ExpenseRepository(database);
  });
  tearDown(() => database.close());

  test('recurring confirmation posts once and advances its reminder', () async {
    final salary = (await expenses.categories(
      TransactionType.income,
    )).firstWhere((item) => item.name == 'Salary');
    final repository = RecurringRepository(database, expenses);
    final id = await repository.save(
      type: TransactionType.income,
      amount: 150000,
      categoryId: salary.id,
      description: 'Monthly salary',
      frequency: RecurringFrequency.monthly,
      nextDueAt: DateTime(2026, 8, 31),
    );
    final recurring = (await repository.all()).single;
    await repository.confirmOccurrence(recurring);
    await repository.confirmOccurrence(recurring);

    final transactions = await expenses.all();
    final reminder = await database.database.query(
      'reminders',
      where: "reference_type = 'recurring' AND reference_id = ?",
      whereArgs: ['$id'],
    );
    expect(transactions, hasLength(1));
    expect(transactions.single.source, TransactionSource.recurring);
    expect((await repository.all()).single.nextDueAt, DateTime(2026, 9, 30));
    expect(
      DateTime.parse(reminder.single['scheduled_at'] as String),
      DateTime(2026, 9, 30),
    );
  });

  test(
    'timeline combines and filters transaction and savings activity',
    () async {
      final food = (await expenses.categories(
        TransactionType.expense,
      )).firstWhere((item) => item.name == 'Food');
      await expenses.save(
        FinanceTransaction(
          type: TransactionType.expense,
          amount: 4200,
          categoryId: food.id,
          categoryName: food.name,
          occurredAt: DateTime(2026, 8, 25),
          description: 'Grocery',
        ),
      );
      final savings = SavingsRepository(database);
      final goal = await savings.saveGoal(name: 'Laptop', targetAmount: 200000);
      await savings.addContribution(
        goalId: goal,
        amount: 10000,
        date: DateTime(2026, 8, 24),
      );

      final repository = TimelineRepository(database);
      expect(await repository.events(const TimelineFilter()), hasLength(2));
      final filtered = await repository.events(
        const TimelineFilter(types: {TimelineEventType.savings}),
      );
      expect(filtered.single.title, 'Laptop');
      expect(filtered.single.amount, -10000);
    },
  );

  test('global search includes savings goals and vehicles', () async {
    await SavingsRepository(
      database,
    ).saveGoal(name: 'Family Car', targetAmount: 3000000);
    await database.database.insert('vehicles', {
      'name': 'City Car',
      'make_model': 'Honda City',
      'fuel_type': 'Petrol',
      'odometer': 0,
      'owner_id': database.ownerId,
    });
    final results = await SearchRepository(database).search('car');
    expect(
      results.map((item) => item.type).toSet(),
      containsAll({SearchResultType.savingsGoal, SearchResultType.vehicle}),
    );
  });

  test(
    'unpaid bills appear in the financial calendar without posting expense',
    () async {
      await PersonalFinanceRepository(database).saveBill(
        HouseholdBill(
          type: 'Internet',
          provider: 'Home ISP',
          amount: 4500,
          dueDate: DateTime(2026, 9, 10),
          status: BillStatus.unpaid,
        ),
      );
      final events = await TimelineRepository(
        database,
      ).events(const TimelineFilter());
      expect(events.single.title, 'Home ISP');
      expect(events.single.subtitle, 'Upcoming bill');
      expect(await expenses.all(), isEmpty);
    },
  );
}
