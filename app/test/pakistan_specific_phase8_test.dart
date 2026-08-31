import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/pakistan_specific/data/pakistan_specific_repository.dart';
import 'package:pakpocket/features/pakistan_specific/domain/pakistan_specific_models.dart';
import 'package:pakpocket/features/udhaar/data/ledger_repository.dart';
import 'package:pakpocket/features/udhaar/domain/ledger.dart';
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
    await database.startGuestSession('phase-eight');
  });

  tearDown(() => database.close());

  test('committee creates a complete monthly payment schedule', () async {
    final repository = PakistanSpecificRepository(database);
    final id = await repository.createCommittee(
      Committee(
        name: 'Family committee',
        monthlyContribution: 10000,
        memberCount: 5,
        monthCount: 5,
        startDate: DateTime(2026, 1, 10),
        userTurn: 3,
      ),
      members: const ['A', 'B', 'Me', 'C', 'D'],
    );

    final committees = await repository.committees();
    final payments = await repository.committeePayments(id);
    expect(committees.single.totalPot, 50000);
    expect(payments, hasLength(5));
    expect(payments.first.dueDate, DateTime(2026, 1, 10));

    await repository.markCommitteePayment(payments.first.id, paid: true);
    expect((await repository.committeePayments(id)).first.status, 'paid');
  });

  test('household records remain private until explicitly shared', () async {
    final repository = PakistanSpecificRepository(database);
    final household = await repository.createHousehold('My home');
    await repository.addMember(
      household,
      name: 'Parent',
      email: 'parent@example.com',
    );

    expect(await repository.privacyFor('expense', 17), RecordPrivacy.onlyMe);
    expect(
      () => repository.setPrivacy(
        recordType: 'expense',
        recordId: 17,
        privacy: RecordPrivacy.sharedHousehold,
      ),
      throwsFormatException,
    );
    await repository.setPrivacy(
      recordType: 'expense',
      recordId: 17,
      privacy: RecordPrivacy.sharedHousehold,
      householdId: household,
    );
    expect(
      await repository.privacyFor('expense', 17),
      RecordPrivacy.sharedHousehold,
    );
    expect(
      (await repository.households()).single.members.single.name,
      'Parent',
    );
  });

  test('Udhaar stores payment history and installment progress', () async {
    final repository = LedgerRepository(database);
    final personId = await repository.create(
      name: 'Ali',
      direction: LedgerDirection.gave,
      amount: 12000,
      date: DateTime(2026, 1, 1),
      description: 'Emergency loan',
    );
    final entry = (await repository.entries(personId)).single;
    await repository.createInstallmentPlan(
      entry,
      count: 3,
      firstDue: DateTime(2026, 2, 1),
    );
    await repository.recordPayment(entry, 4000);

    final history = await repository.paymentHistory(entry.id);
    final installments = await repository.installments(entry.id);
    expect(history.single.amount, 4000);
    expect(installments, hasLength(3));
    expect(installments.first.status, 'paid');
    expect(
      installments.skip(1).every((item) => item.status == 'pending'),
      isTrue,
    );
  });
}
