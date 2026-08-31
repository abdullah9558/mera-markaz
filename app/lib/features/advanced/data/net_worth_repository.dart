import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';

final netWorthRepositoryProvider = Provider<NetWorthRepository>(
  (ref) => NetWorthRepository(ref.watch(appDatabaseProvider)),
);

class NetWorthAccount {
  const NetWorthAccount({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
  });
  final int id;
  final String name;
  final String kind;
  final double balance;
  bool get isLiability => kind == 'liability';
}

class NetWorthSnapshot {
  const NetWorthSnapshot({
    required this.assets,
    required this.liabilities,
    required this.capturedAt,
  });
  final double assets, liabilities;
  final DateTime capturedAt;
  double get netWorth => assets - liabilities;
}

class NetWorthRepository {
  const NetWorthRepository(this._database);
  final AppDatabase _database;
  Future<List<NetWorthAccount>> accounts() async {
    final rows = await _database.database.query(
      'net_worth_accounts',
      where: 'owner_id = ?',
      whereArgs: [_database.ownerId],
      orderBy: 'kind, name',
    );
    return rows
        .map(
          (row) => NetWorthAccount(
            id: row['id'] as int,
            name: row['name'] as String,
            kind: row['kind'] as String,
            balance: (row['balance'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<int> save({
    int? id,
    required String name,
    required String kind,
    required double balance,
  }) async {
    if (name.trim().isEmpty ||
        balance < 0 ||
        !{'asset', 'liability'}.contains(kind)) {
      throw const FormatException('Enter a valid account and balance.');
    }
    final values = {
      'name': name.trim(),
      'kind': kind,
      'balance': balance,
      'updated_at': DateTime.now().toIso8601String(),
      'owner_id': _database.ownerId,
    };
    return _database.database.transaction((txn) async {
      final savedId = id ?? await txn.insert('net_worth_accounts', values);
      if (id != null) {
        await txn.update(
          'net_worth_accounts',
          values,
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, _database.ownerId],
        );
      }
      await _capture(txn);
      return savedId;
    });
  }

  Future<void> delete(int id) => _database.database.transaction((txn) async {
    await txn.delete(
      'net_worth_accounts',
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _database.ownerId],
    );
    await _capture(txn);
  });

  Future<List<NetWorthSnapshot>> history() async {
    final rows = await _database.database.query(
      'net_worth_snapshots',
      where: 'owner_id = ?',
      whereArgs: [_database.ownerId],
      orderBy: 'captured_at ASC',
    );
    return rows
        .map(
          (row) => NetWorthSnapshot(
            assets: (row['total_assets'] as num).toDouble(),
            liabilities: (row['total_liabilities'] as num).toDouble(),
            capturedAt: DateTime.parse(row['captured_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> _capture(DatabaseExecutor txn) async {
    final totals = await txn.rawQuery(
      "SELECT COALESCE(SUM(CASE WHEN kind = 'asset' THEN balance ELSE 0 END), 0) assets, COALESCE(SUM(CASE WHEN kind = 'liability' THEN balance ELSE 0 END), 0) liabilities FROM net_worth_accounts WHERE owner_id = ?",
      [_database.ownerId],
    );
    final assets = (totals.single['assets'] as num).toDouble();
    final liabilities = (totals.single['liabilities'] as num).toDouble();
    await txn.insert('net_worth_snapshots', {
      'total_assets': assets,
      'total_liabilities': liabilities,
      'net_worth': assets - liabilities,
      'captured_at': DateTime.now().toIso8601String(),
      'owner_id': _database.ownerId,
    });
  }
}
