import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
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
    expenses = ExpenseRepository(database);
  });

  tearDown(() => database.close());

  Future<void> addExpense(String description) async {
    final category = (await expenses.categories(TransactionType.expense)).first;
    await expenses.save(
      FinanceTransaction(
        type: TransactionType.expense,
        amount: 500,
        categoryId: category.id,
        categoryName: category.name,
        occurredAt: DateTime.now(),
        description: description,
      ),
    );
  }

  test('new account claims the current guest activity', () async {
    await database.startGuestSession('temporary-one');
    await addExpense('Guest purchase');

    await database.claimGuestSession('guest:temporary-one', 'new-user-id');

    expect((await expenses.all()).single.description, 'Guest purchase');
    expect(database.ownerId, 'account:new-user-id');
  });

  test('existing account login discards guest activity', () async {
    await database.activateAccount('existing-user');
    await addExpense('Saved account purchase');

    await database.startGuestSession('temporary-two');
    await addExpense('Discard me');
    await database.discardOwner('guest:temporary-two');
    await database.activateAccount('existing-user');

    final restored = await expenses.all();
    expect(restored.map((item) => item.description), [
      'Saved account purchase',
    ]);
  });

  test('the same guest session survives an app restart', () async {
    await database.startGuestSession('retained');
    await addExpense('Retained purchase');

    // Re-selecting the persisted owner simulates restoring it on next launch.
    await database.startGuestSession('retained');

    expect((await expenses.all()).single.description, 'Retained purchase');
    expect(database.ownerId, 'guest:retained');
  });
}
