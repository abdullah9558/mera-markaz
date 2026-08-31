import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/pakistan_data/pakistan_data_repository.dart';
import '../../advanced/data/net_worth_repository.dart';
import '../domain/metal_models.dart';

final metalZakatRepositoryProvider = Provider(
  (ref) => MetalZakatRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(pakistanDataRepositoryProvider),
    ref.watch(netWorthRepositoryProvider),
  ),
);

class MetalZakatRepository {
  const MetalZakatRepository(this.database, this.rates, this.netWorth);
  final AppDatabase database;
  final PakistanDataRepository rates;
  final NetWorthRepository netWorth;

  Future<List<MetalHolding>> holdings() async {
    final rows = await database.database.query(
      'metal_holdings',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_holdingFromRow).toList();
  }

  Future<int> saveHolding(MetalHolding holding, {double? currentValue}) async {
    if (holding.quantity <= 0 || holding.purity <= 0 || holding.purity > 1) {
      throw const FormatException('Enter a valid holding.');
    }
    final now = DateTime.now().toIso8601String();
    final data = <String, Object?>{
      'metal': holding.metal.name,
      'quantity': holding.quantity,
      'unit': holding.unit.name,
      'purity': holding.purity,
      'purchase_price': holding.purchasePrice,
      'purchase_date': holding.purchaseDate?.toIso8601String(),
      'notes': holding.notes,
      'linked_net_worth_account_id': holding.linkedNetWorthAccountId,
      'updated_at': now,
      'owner_id': database.ownerId,
    };
    int id;
    if (holding.id == null) {
      data['created_at'] = now;
      id = await database.database.insert('metal_holdings', data);
    } else {
      id = holding.id!;
      await database.database.update(
        'metal_holdings',
        data,
        where: 'id = ? AND owner_id = ?',
        whereArgs: [id, database.ownerId],
      );
    }
    if (currentValue != null) {
      final accountId = await netWorth.save(
        id: holding.linkedNetWorthAccountId,
        name:
            '${holding.metal == MetalType.gold ? 'Gold' : 'Silver'} holding #$id',
        kind: 'asset',
        balance: currentValue,
      );
      await database.database.update(
        'metal_holdings',
        {'linked_net_worth_account_id': accountId},
        where: 'id = ? AND owner_id = ?',
        whereArgs: [id, database.ownerId],
      );
    }
    return id;
  }

  Future<void> deleteHolding(MetalHolding holding) async {
    await database.database.delete(
      'metal_holdings',
      where: 'id = ? AND owner_id = ?',
      whereArgs: [holding.id, database.ownerId],
    );
    if (holding.linkedNetWorthAccountId != null) {
      await netWorth.delete(holding.linkedNetWorthAccountId!);
    }
  }

  Future<double?> currentRate(MetalType metal) async => (await rates.latest(
    metal == MetalType.gold ? 'gold_24k_tola' : 'silver_tola',
  ))?.value;

  Future<double> holdingsValue(MetalType metal) async {
    final rate = await currentRate(metal);
    if (rate == null) return 0;
    return (await holdings())
        .where((item) => item.metal == metal)
        .fold<double>(0, (sum, item) => sum + item.valueFromTolaRate(rate));
  }

  Future<int> saveZakat(ZakatRecord record) {
    final values = [
      record.cash,
      record.bank,
      record.gold,
      record.silver,
      record.businessAssets,
      record.receivables,
      record.otherAssets,
      record.liabilities,
      record.nisabValue,
    ];
    if (values.any((value) => value < 0)) {
      throw const FormatException('Zakat values cannot be negative.');
    }
    return database.database.insert('zakat_records', {
      'cash_amount': record.cash,
      'bank_amount': record.bank,
      'gold_amount': record.gold,
      'silver_amount': record.silver,
      'business_assets': record.businessAssets,
      'receivables': record.receivables,
      'other_assets': record.otherAssets,
      'liabilities': record.liabilities,
      'nisab_method': record.nisabMethod,
      'nisab_value': record.nisabValue,
      'eligible_total': record.eligibleTotal,
      'zakat_due': record.zakatDue,
      'calculated_at': record.calculatedAt.toIso8601String(),
      'reminder_at': record.reminderAt?.toIso8601String(),
      'source_reference': record.sourceReference,
      'created_at': DateTime.now().toIso8601String(),
      'owner_id': database.ownerId,
    });
  }

  Future<List<ZakatRecord>> zakatHistory() async {
    final rows = await database.database.query(
      'zakat_records',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      orderBy: 'calculated_at DESC',
    );
    return rows
        .map(
          (row) => ZakatRecord(
            id: row['id'] as int,
            cash: (row['cash_amount'] as num).toDouble(),
            bank: (row['bank_amount'] as num).toDouble(),
            gold: (row['gold_amount'] as num).toDouble(),
            silver: (row['silver_amount'] as num).toDouble(),
            businessAssets: (row['business_assets'] as num).toDouble(),
            receivables: (row['receivables'] as num).toDouble(),
            otherAssets: (row['other_assets'] as num).toDouble(),
            liabilities: (row['liabilities'] as num).toDouble(),
            nisabMethod: row['nisab_method'] as String,
            nisabValue: (row['nisab_value'] as num).toDouble(),
            calculatedAt: DateTime.parse(row['calculated_at'] as String),
            reminderAt: row['reminder_at'] == null
                ? null
                : DateTime.parse(row['reminder_at'] as String),
            sourceReference: row['source_reference'] as String?,
          ),
        )
        .toList();
  }

  MetalHolding _holdingFromRow(Map<String, Object?> row) => MetalHolding(
    id: row['id'] as int,
    metal: MetalType.values.byName(row['metal'] as String),
    quantity: (row['quantity'] as num).toDouble(),
    unit: MetalUnit.values.byName(row['unit'] as String),
    purity: (row['purity'] as num).toDouble(),
    purchasePrice: (row['purchase_price'] as num?)?.toDouble(),
    purchaseDate: row['purchase_date'] == null
        ? null
        : DateTime.parse(row['purchase_date'] as String),
    notes: row['notes'] as String?,
    linkedNetWorthAccountId: row['linked_net_worth_account_id'] as int?,
  );
}
