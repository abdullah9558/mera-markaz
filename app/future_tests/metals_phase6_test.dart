import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/core/pakistan_data/pakistan_data_point.dart';
import 'package:pakpocket/core/pakistan_data/pakistan_data_repository.dart';
import 'package:pakpocket/features/advanced/data/net_worth_repository.dart';
import 'package:pakpocket/features/metals/data/metal_zakat_repository.dart';
import 'package:pakpocket/features/metals/domain/metal_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late PakistanDataRepository rates;
  late MetalZakatRepository repository;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
    await database.startGuestSession('phase-six');
    rates = PakistanDataRepository(database);
    repository = MetalZakatRepository(
      database,
      rates,
      NetWorthRepository(database),
    );
    final now = DateTime.now();
    await rates.cache(
      PakistanDataPoint(
        seriesKey: 'gold_24k_tola',
        value: 400000,
        unit: 'PKR/tola',
        sourceName: 'Test source',
        sourceReference: 'test://gold',
        effectiveAt: now,
        retrievedAt: now,
        freshness: DataFreshness.current,
        configVersion: 'test-1',
      ),
    );
  });
  tearDown(() => database.close());

  test('gold holdings use sourced rates and link once to Net Worth', () async {
    final holding = MetalHolding(
      metal: MetalType.gold,
      quantity: 1,
      unit: MetalUnit.tola,
      purity: 1,
      purchasePrice: 350000,
    );
    await repository.saveHolding(holding, currentValue: 400000);
    expect(await repository.holdingsValue(MetalType.gold), 400000);
    final accounts = await NetWorthRepository(database).accounts();
    expect(accounts, hasLength(1));
    expect(accounts.single.balance, 400000);
  });

  test('itemized Zakat record persists annual result and reminder', () async {
    final record = ZakatRecord(
      cash: 100000,
      bank: 500000,
      gold: 400000,
      silver: 0,
      businessAssets: 200000,
      receivables: 100000,
      otherAssets: 0,
      liabilities: 100000,
      nisabMethod: 'silver',
      nisabValue: 200000,
      calculatedAt: DateTime(2026, 8, 31),
      reminderAt: DateTime(2027, 8, 20),
      sourceReference: 'test://silver',
    );
    expect(record.eligibleTotal, 1200000);
    expect(record.zakatDue, 30000);
    await repository.saveZakat(record);
    final history = await repository.zakatHistory();
    expect(history, hasLength(1));
    expect(history.single.zakatDue, 30000);
    expect(history.single.reminderAt, DateTime(2027, 8, 20));
  });
}
