import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    if (id == null) {
      return _database.database.insert('net_worth_accounts', values);
    }
    await _database.database.update(
      'net_worth_accounts',
      values,
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _database.ownerId],
    );
    return id;
  }

  Future<void> delete(int id) => _database.database.delete(
    'net_worth_accounts',
    where: 'id = ? AND owner_id = ?',
    whereArgs: [id, _database.ownerId],
  );
}
