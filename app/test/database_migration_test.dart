import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('schema 2 upgrades additively and preserves transactions', () async {
    final path = p.join(
      await getDatabasesPath(),
      'mera_markaz_v2_migration.db',
    );
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, amount REAL NOT NULL, category_id INTEGER, occurred_at TEXT NOT NULL, description TEXT NOT NULL, payment_method TEXT, note TEXT, created_at TEXT NOT NULL, owner_id TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE budgets (id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER, amount REAL NOT NULL, period_start TEXT NOT NULL, period_end TEXT NOT NULL, owner_id TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE ledger_people (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, owner_id TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE ledger_transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, person_id INTEGER NOT NULL, direction TEXT NOT NULL, amount REAL NOT NULL, paid_amount REAL NOT NULL, occurred_at TEXT NOT NULL, status TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE vehicles (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, owner_id TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE fuel_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, vehicle_id INTEGER NOT NULL, liters REAL NOT NULL, cost REAL NOT NULL, odometer REAL NOT NULL, filled_at TEXT NOT NULL)',
        );
        await db.insert('categories', {
          'id': 1,
          'name': 'Food',
          'type': 'expense',
        });
        await db.insert('transactions', {
          'type': 'expense',
          'amount': 4200,
          'category_id': 1,
          'occurred_at': DateTime(2026, 8, 20).toIso8601String(),
          'description': 'Existing grocery',
          'created_at': DateTime(2026, 8, 20).toIso8601String(),
          'owner_id': 'account:user-1',
        });
      },
    );
    await old.close();

    final upgraded = AppDatabase();
    await upgraded.open(databasePath: path);
    final rows = await upgraded.database.query('transactions');
    final tables = await upgraded.database.query(
      'sqlite_master',
      columns: ['name'],
      where: "type = 'table' AND name IN (?, ?, ?, ?, ?, ?)",
      whereArgs: [
        'savings_goals',
        'recurring_transactions',
        'reminders',
        'pakistan_data_points',
        'notification_inbox',
        'watch_conditions',
      ],
    );

    expect(rows, hasLength(1));
    expect(rows.single['description'], 'Existing grocery');
    expect(rows.single['source'], 'manual');
    expect(tables, hasLength(6));

    await upgraded.close();
    await deleteDatabase(path);
  });
}
