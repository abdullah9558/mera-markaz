import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/savings/data/savings_repository.dart';
import 'package:pakpocket/features/savings/domain/savings_goal.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late SavingsRepository savings;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
    await database.startGuestSession('savings-stage-4');
    savings = SavingsRepository(database);
  });

  tearDown(() => database.close());

  test('contributions and withdrawals maintain an auditable balance', () async {
    final id = await savings.saveGoal(
      name: 'New Car',
      targetAmount: 1000000,
      targetDate: DateTime(2028, 6),
    );
    await savings.addContribution(
      goalId: id,
      amount: 25000,
      date: DateTime(2026, 8, 1),
    );
    await savings.addContribution(
      goalId: id,
      amount: 15000,
      date: DateTime(2026, 8, 10),
    );
    await savings.addContribution(
      goalId: id,
      amount: -5000,
      date: DateTime(2026, 8, 20),
    );

    final goal = await savings.goal(id);
    final history = await savings.contributions(id);
    expect(goal.savedAmount, 35000);
    expect(goal.remaining, 965000);
    expect(history, hasLength(3));
    expect(history.first.isWithdrawal, isTrue);
  });

  test('withdrawal cannot exceed the saved amount', () async {
    final id = await savings.saveGoal(name: 'Laptop', targetAmount: 200000);
    await savings.addContribution(
      goalId: id,
      amount: 10000,
      date: DateTime(2026, 8, 1),
    );
    await expectLater(
      savings.addContribution(
        goalId: id,
        amount: -10001,
        date: DateTime(2026, 8, 2),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('forecast is deterministic and clearly derived from history', () {
    final goal = SavingsGoal(
      id: 1,
      name: 'Emergency Fund',
      targetAmount: 500000,
      savedAmount: 100000,
      targetDate: DateTime(2027, 5),
      status: SavingsGoalStatus.active,
      createdAt: DateTime(2026, 6),
      updatedAt: DateTime(2026, 8),
    );
    final history = [
      GoalContribution(
        id: 1,
        goalId: 1,
        amount: 20000,
        contributedAt: DateTime(2026, 6, 1),
      ),
      GoalContribution(
        id: 2,
        goalId: 1,
        amount: 30000,
        contributedAt: DateTime(2026, 7, 1),
      ),
      GoalContribution(
        id: 3,
        goalId: 1,
        amount: 50000,
        contributedAt: DateTime(2026, 8, 1),
      ),
    ];

    final result = GoalForecast.calculate(
      goal: goal,
      contributions: history,
      now: DateTime(2026, 8, 25),
    );
    expect(result.averageMonthlySavings, closeTo(33333.33, .01));
    expect(result.estimatedMonths, 12);
    expect(result.requiredMonthlySavings, closeTo(40000, .01));
  });

  test('archived goals reject new contributions', () async {
    final id = await savings.saveGoal(name: 'Phone', targetAmount: 100000);
    await savings.setStatus(id, SavingsGoalStatus.archived);
    await expectLater(
      savings.addContribution(goalId: id, amount: 1000, date: DateTime.now()),
      throwsA(isA<FormatException>()),
    );
  });
}
