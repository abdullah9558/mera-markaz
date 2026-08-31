import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/advanced/data/net_worth_repository.dart';
import 'package:pakpocket/features/advanced/data/receipt_repository.dart';
import 'package:pakpocket/features/advanced/domain/voice_transaction_parser.dart';
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
    await database.startGuestSession('stage-9');
    expenses = ExpenseRepository(database);
  });

  tearDown(() => database.close());

  test('receipt text parser prefers a labelled total', () {
    final result = ReceiptTextParser.parse(
      'MERA STORE\nMilk 450.00\nSubtotal 450.00\nTOTAL PKR 531.00',
      now: DateTime(2026, 8, 25),
    );
    expect(result.merchant, 'MERA STORE');
    expect(result.total, 531);
  });

  test('confirming a receipt twice updates its linked expense', () async {
    final other = (await expenses.categories(
      TransactionType.expense,
    )).firstWhere((item) => item.name == 'Other');
    final draftId = await database.database.insert('receipt_drafts', {
      'image_path': 'test.jpg',
      'status': 'draft',
      'created_at': DateTime.now().toIso8601String(),
      'owner_id': database.ownerId,
    });
    final receipts = ReceiptRepository(database, expenses);
    final first = await receipts.confirm(
      id: draftId,
      merchant: 'Corner shop',
      total: 500,
      purchasedAt: DateTime.now(),
      categoryId: other.id,
    );
    final second = await receipts.confirm(
      id: draftId,
      merchant: 'Corner shop',
      total: 550,
      purchasedAt: DateTime.now(),
      categoryId: other.id,
    );
    expect(second, first);
    final rows = await expenses.all();
    expect(rows, hasLength(1));
    expect(rows.single.source, TransactionSource.receipt);
    expect(rows.single.amount, 550);
  });

  test('voice parser supports expense and income phrases', () {
    final expense = VoiceTransactionParser.parse('groceries 2500');
    final income = VoiceTransactionParser.parse('salary received 180000');
    expect(expense?.isIncome, isFalse);
    expect(expense?.amount, 2500);
    expect(income?.isIncome, isTrue);
    expect(income?.amount, 180000);
  });

  test('voice parser understands Roman Urdu Udhaar intent', () {
    final receive = VoiceTransactionParser.parse('Ahmed se 25000 lene hain');
    final pay = VoiceTransactionParser.parse('Ali ko 12000 dene hain');
    final salary = VoiceTransactionParser.parse('Tankhwa 180000 receive hui');
    expect(receive?.kind, VoiceEntryKind.udhaarReceivable);
    expect(pay?.kind, VoiceEntryKind.udhaarPayable);
    expect(salary?.kind, VoiceEntryKind.income);
  });

  test('bill parser detects electricity fields for review', () {
    final result = ReceiptTextParser.parse(
      'LESCO\nConsumer No 123456789\nUnits 420 kWh\nDue Date 18/09/2026\nTotal 18500',
    );
    expect(result.documentType, ReceiptDocumentType.electricityBill);
    expect(result.units, 420);
    expect(result.referenceNumber, '123456789');
    expect(result.dueDate, DateTime(2026, 9, 18));
  });

  test('net worth accounts keep assets and liabilities separate', () async {
    final repository = NetWorthRepository(database);
    await repository.save(name: 'Bank', kind: 'asset', balance: 100000);
    await repository.save(name: 'Loan', kind: 'liability', balance: 25000);
    final accounts = await repository.accounts();
    expect(accounts.where((item) => item.isLiability), hasLength(1));
    expect(accounts.where((item) => !item.isLiability), hasLength(1));
    final history = await repository.history();
    expect(history, hasLength(2));
    expect(history.last.netWorth, 75000);
  });
}
