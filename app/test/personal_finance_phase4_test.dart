import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/personal_finance/data/personal_finance_repository.dart';
import 'package:pakpocket/features/personal_finance/domain/personal_finance_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late PersonalFinanceRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
    await database.startGuestSession('phase-four');
    repository = PersonalFinanceRepository(database);
  });

  tearDown(() => database.close());

  test('salary breakdown posts and updates one canonical income', () async {
    final date = DateTime(2026, 8, 31);
    final id = await repository.saveSalary(
      SalaryBreakdown(
        basicSalary: 150000,
        houseAllowance: 30000,
        tax: 10000,
        otherDeductions: 5000,
        receivedAt: date,
      ),
    );
    await repository.saveSalary(
      SalaryBreakdown(
        id: id,
        basicSalary: 160000,
        houseAllowance: 30000,
        tax: 12000,
        receivedAt: date,
      ),
    );
    final rows = await database.database.query(
      'transactions',
      where: 'owner_id = ? AND source = ?',
      whereArgs: [database.ownerId, 'salary'],
    );
    expect(rows, hasLength(1));
    expect(rows.single['amount'], 178000);
  });

  test('only received freelancer income affects canonical income', () async {
    final id = await repository.saveFreelancer(
      FreelancerIncomeRecord(
        client: 'Client A',
        grossAmount: 1000,
        currency: 'USD',
        exchangeRate: 280,
        fees: 5000,
        status: FreelancerPaymentStatus.expected,
        expectedAt: DateTime(2026, 9, 10),
      ),
    );
    expect(
      await database.database.query(
        'transactions',
        where: 'owner_id = ? AND source = ?',
        whereArgs: [database.ownerId, 'freelancer'],
      ),
      isEmpty,
    );
    await repository.saveFreelancer(
      FreelancerIncomeRecord(
        id: id,
        client: 'Client A',
        grossAmount: 1000,
        currency: 'USD',
        exchangeRate: 280,
        fees: 5000,
        status: FreelancerPaymentStatus.received,
        expectedAt: DateTime(2026, 9, 10),
        receivedAt: DateTime(2026, 9, 8),
      ),
    );
    final rows = await database.database.query(
      'transactions',
      where: 'owner_id = ? AND source = ?',
      whereArgs: [database.ownerId, 'freelancer'],
    );
    expect(rows, hasLength(1));
    expect(rows.single['amount'], 275000);
  });

  test('bill payment posts once and marks fully paid bill', () async {
    final billId = await repository.saveBill(
      HouseholdBill(
        type: 'Internet',
        provider: 'ISP',
        amount: 5000,
        dueDate: DateTime(2026, 9, 5),
        status: BillStatus.unpaid,
      ),
    );
    await repository.payBill(billId, 2000, DateTime(2026, 9, 1));
    await repository.payBill(billId, 3000, DateTime(2026, 9, 2));
    final bill = (await database.database.query(
      'bills',
      where: 'id = ?',
      whereArgs: [billId],
    )).single;
    expect(bill['status'], BillStatus.paid.name);
    final expenses = await database.database.query(
      'transactions',
      where: 'owner_id = ? AND source = ?',
      whereArgs: [database.ownerId, 'bill'],
    );
    expect(expenses, hasLength(2));
  });

  test('emergency fund status is explainable and capped', () {
    const status = EmergencyFundStatus(
      saved: 300000,
      monthlyEssential: 100000,
      targetMonths: 6,
    );
    expect(status.monthsCovered, 3);
    expect(status.targetAmount, 600000);
    expect(status.progress, .5);
  });

  test('empty emergency fund repository snapshot completes', () async {
    final status = await repository.emergencyFundStatus();
    expect(status.saved, 0);
    expect(status.monthlyEssential, 0);
    expect(status.targetMonths, 3);
  });
}
