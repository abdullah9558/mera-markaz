import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('Database was not initialized'),
);

class AppDatabase {
  static const legacyOwner = 'legacy';
  Database? _database;
  String _ownerId = legacyOwner;
  Database get database =>
      _database ?? (throw StateError('Database is not open'));
  String get ownerId => _ownerId;

  Future<void> open({String? databasePath, String? encryptionPassword}) async {
    final path =
        databasePath ?? p.join(await getDatabasesPath(), 'pakpocket.db');
    if (encryptionPassword != null && databasePath == null) {
      await _prepareEncryptedDatabase(path, encryptionPassword);
      _database = await sqlcipher.openDatabase(
        path,
        password: encryptionPassword,
        version: 9,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
        onUpgrade: _upgrade,
      );
      await _verifyHealthy(_database!);
      return;
    }
    _database = await openDatabase(
      path,
      version: 9,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  static Future<void> _create(Database db, int version) async {
    for (final statement in _schema) {
      await db.execute(statement);
    }
    await _seedCategories(db);
  }

  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      for (final table in _version1OwnedTables) {
        await db.execute(
          "ALTER TABLE $table ADD COLUMN owner_id TEXT NOT NULL DEFAULT '$legacyOwner'",
        );
        await db.execute('CREATE INDEX idx_${table}_owner ON $table(owner_id)');
      }
      await db.execute(
        'CREATE TABLE IF NOT EXISTS app_metadata (key TEXT PRIMARY KEY, value TEXT)',
      );
    }
    if (oldVersion < 3) {
      await _upgradeToVersion3(db);
    }
    if (oldVersion < 4) {
      await _upgradeToVersion4(db);
    }
    if (oldVersion < 5) {
      await _upgradeToVersion5(db);
    }
    if (oldVersion < 6) {
      await db.execute('DROP TABLE IF EXISTS subscription_status');
    }
    if (oldVersion < 7) {
      await db.execute(
        'CREATE TABLE IF NOT EXISTS secure_profiles (user_id TEXT PRIMARY KEY, profile_json TEXT NOT NULL, updated_at TEXT NOT NULL)',
      );
    }
    if (oldVersion < 8) {
      for (final statement in _syncSchema) {
        await db.execute(statement);
      }
    }
    if (oldVersion < 9) {
      await db.execute(
        'ALTER TABLE ledger_transactions ADD COLUMN owner_id TEXT',
      );
      await db.execute(
        'UPDATE ledger_transactions SET owner_id = (SELECT owner_id FROM ledger_people WHERE ledger_people.id = ledger_transactions.person_id)',
      );
      await db.execute(
        "UPDATE ledger_transactions SET owner_id = '$legacyOwner' WHERE owner_id IS NULL",
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ledger_transactions_owner ON ledger_transactions(owner_id)',
      );
    }
  }

  static Future<void> _prepareEncryptedDatabase(
    String path,
    String password,
  ) async {
    final file = File(path);
    if (!await file.exists()) return;
    if (!await _hasPlaintextSqliteHeader(file)) {
      // An encrypted file must only be opened with its existing key. Never treat
      // a wrong-key failure as a plaintext migration opportunity.
      return;
    }

    final temporaryPath = '$path.encrypted.tmp';
    final rollbackPath = '$path.plaintext.rollback';
    await _deleteDatabaseArtifacts(temporaryPath);
    await _deleteDatabaseArtifacts(rollbackPath);

    Database? source;
    Database? temporary;
    try {
      source = await sqlcipher.openDatabase(path, singleInstance: false);
      await source.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final expectedCounts = await _tableCounts(source);
      final escapedPassword = password.replaceAll("'", "''");
      final escapedPath = temporaryPath.replaceAll("'", "''");
      await source.execute(
        "ATTACH DATABASE '$escapedPath' AS encrypted KEY '$escapedPassword'",
      );
      try {
        await source.rawQuery("SELECT sqlcipher_export('encrypted')");
        final version = await source.getVersion();
        await source.execute('PRAGMA encrypted.user_version = $version');
      } finally {
        await source.execute('DETACH DATABASE encrypted');
      }
      await source.close();
      source = null;

      temporary = await sqlcipher.openDatabase(
        temporaryPath,
        password: password,
        singleInstance: false,
      );
      await _verifyHealthy(temporary);
      final actualCounts = await _tableCounts(temporary);
      if (!_sameCounts(expectedCounts, actualCounts)) {
        throw StateError('Encrypted database verification failed.');
      }
      await temporary.close();
      temporary = null;

      await file.rename(rollbackPath);
      try {
        await File(temporaryPath).rename(path);
        final verification = await sqlcipher.openDatabase(
          path,
          password: password,
          singleInstance: false,
        );
        await _verifyHealthy(verification);
        await verification.close();
        await _deleteDatabaseArtifacts(rollbackPath);
      } catch (_) {
        if (await File(path).exists()) await _deleteDatabaseArtifacts(path);
        if (await File(rollbackPath).exists()) {
          await File(rollbackPath).rename(path);
        }
        rethrow;
      }
    } finally {
      await source?.close();
      await temporary?.close();
      await _deleteDatabaseArtifacts(temporaryPath);
    }
  }

  static Future<bool> _hasPlaintextSqliteHeader(File file) async {
    final reader = await file.open();
    try {
      final bytes = await reader.read(16);
      return bytes.length == 16 &&
          utf8.decode(bytes, allowMalformed: true) == 'SQLite format 3\u0000';
    } finally {
      await reader.close();
    }
  }

  static Future<Map<String, int>> _tableCounts(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    final counts = <String, int>{};
    for (final row in tables) {
      final table = row['name']! as String;
      final quoted = '"${table.replaceAll('"', '""')}"';
      final result = await db.rawQuery('SELECT COUNT(*) AS count FROM $quoted');
      counts[table] = (result.single['count'] as num).toInt();
    }
    return counts;
  }

  static bool _sameCounts(Map<String, int> first, Map<String, int> second) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      if (second[entry.key] != entry.value) return false;
    }
    return true;
  }

  static Future<void> _verifyHealthy(Database db) async {
    final check = await db.rawQuery('PRAGMA quick_check');
    if (check.isEmpty || check.first.values.first.toString() != 'ok') {
      throw StateError('Database integrity verification failed.');
    }
  }

  static Future<void> _deleteDatabaseArtifacts(String path) async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final artifact = File('$path$suffix');
      if (await artifact.exists()) await artifact.delete();
    }
  }

  Future<void> startGuestSession(String sessionId) async {
    _ownerId = 'guest:$sessionId';
  }

  Future<void> activateAccount(String userId) async {
    final accountOwner = 'account:$userId';
    await database.transaction((txn) async {
      final claimed = await txn.query(
        'app_metadata',
        where: 'key = ?',
        whereArgs: ['legacy_claimed'],
        limit: 1,
      );
      if (claimed.isEmpty) {
        await _moveOwner(txn, legacyOwner, accountOwner);
        await txn.insert('app_metadata', {
          'key': 'legacy_claimed',
          'value': accountOwner,
        });
      }
    });
    _ownerId = accountOwner;
  }

  Future<void> claimGuestSession(String guestOwner, String userId) async {
    final accountOwner = 'account:$userId';
    await database.transaction(
      (txn) => _moveOwner(txn, guestOwner, accountOwner),
    );
    _ownerId = accountOwner;
  }

  Future<void> discardOwner(String owner) async {
    await database.transaction((txn) async {
      await txn.rawDelete(
        'DELETE FROM ledger_transactions WHERE person_id IN (SELECT id FROM ledger_people WHERE owner_id = ?)',
        [owner],
      );
      await txn.rawDelete(
        'DELETE FROM fuel_entries WHERE vehicle_id IN (SELECT id FROM vehicles WHERE owner_id = ?)',
        [owner],
      );
      for (final table in _ownedTables) {
        await txn.delete(table, where: 'owner_id = ?', whereArgs: [owner]);
      }
    });
    if (_ownerId == owner) _ownerId = legacyOwner;
  }

  Future<void> cleanupAbandonedGuestSessions() async {
    final owners = <String>{};
    for (final table in _ownedTables) {
      final rows = await database.query(
        table,
        columns: ['owner_id'],
        distinct: true,
        where: "owner_id LIKE 'guest:%'",
      );
      owners.addAll(rows.map((row) => row['owner_id']! as String));
    }
    for (final owner in owners) {
      await discardOwner(owner);
    }
  }

  static Future<void> _moveOwner(
    DatabaseExecutor executor,
    String from,
    String to,
  ) async {
    for (final table in _ownedTables) {
      await executor.update(
        table,
        {'owner_id': to},
        where: 'owner_id = ?',
        whereArgs: [from],
      );
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  static const _schema = <String>[
    'CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, type TEXT NOT NULL, icon TEXT, color INTEGER, is_system INTEGER NOT NULL DEFAULT 0)',
    "CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, amount REAL NOT NULL CHECK(amount >= 0), category_id INTEGER, occurred_at TEXT NOT NULL, description TEXT NOT NULL, payment_method TEXT, note TEXT, created_at TEXT NOT NULL, updated_at TEXT, source TEXT NOT NULL DEFAULT 'manual', source_record_id TEXT, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(category_id) REFERENCES categories(id))",
    "CREATE TABLE budgets (id INTEGER PRIMARY KEY AUTOINCREMENT, category_id INTEGER, amount REAL NOT NULL CHECK(amount >= 0), period_start TEXT NOT NULL, period_end TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(category_id) REFERENCES categories(id))",
    "CREATE TABLE ledger_people (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE ledger_transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, person_id INTEGER NOT NULL, direction TEXT NOT NULL, amount REAL NOT NULL CHECK(amount >= 0), paid_amount REAL NOT NULL DEFAULT 0 CHECK(paid_amount >= 0), occurred_at TEXT NOT NULL, due_at TEXT, description TEXT, notes TEXT, status TEXT NOT NULL, linked_transaction_id INTEGER, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(person_id) REFERENCES ledger_people(id) ON DELETE CASCADE, FOREIGN KEY(linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL)",
    "CREATE TABLE electricity_calculations (id INTEGER PRIMARY KEY AUTOINCREMENT, provider TEXT NOT NULL, units REAL NOT NULL, estimated_total REAL NOT NULL, config_version TEXT NOT NULL, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE tax_calculations (id INTEGER PRIMARY KEY AUTOINCREMENT, tax_year TEXT NOT NULL, annual_income REAL NOT NULL, annual_tax REAL NOT NULL, config_version TEXT NOT NULL, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE solar_calculations (id INTEGER PRIMARY KEY AUTOINCREMENT, system_kw REAL NOT NULL, annual_generation REAL NOT NULL, config_version TEXT NOT NULL, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE property_calculations (id INTEGER PRIMARY KEY AUTOINCREMENT, square_feet REAL NOT NULL, marla_standard REAL NOT NULL, estimated_price REAL, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE vehicles (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, make_model TEXT, fuel_type TEXT NOT NULL, odometer REAL NOT NULL DEFAULT 0, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE fuel_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, vehicle_id INTEGER NOT NULL, liters REAL NOT NULL, cost REAL NOT NULL, odometer REAL NOT NULL, filled_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', linked_transaction_id INTEGER, FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE, FOREIGN KEY(linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL)",
    "CREATE TABLE vehicle_maintenance (id INTEGER PRIMARY KEY AUTOINCREMENT, vehicle_id INTEGER NOT NULL, kind TEXT NOT NULL, cost REAL NOT NULL DEFAULT 0 CHECK(cost >= 0), odometer REAL, serviced_at TEXT NOT NULL, next_due_at TEXT, next_due_odometer REAL, notes TEXT, linked_transaction_id INTEGER, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE, FOREIGN KEY(linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL)",
    "CREATE TABLE receipt_drafts (id INTEGER PRIMARY KEY AUTOINCREMENT, image_path TEXT NOT NULL, merchant TEXT, total REAL, purchased_at TEXT, raw_text TEXT, status TEXT NOT NULL DEFAULT 'draft', linked_transaction_id INTEGER, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL)",
    "CREATE TABLE net_worth_accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, kind TEXT NOT NULL, balance REAL NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE zakat_calculations (id INTEGER PRIMARY KEY AUTOINCREMENT, eligible_assets REAL NOT NULL, deductions REAL NOT NULL, nisab REAL NOT NULL, zakat REAL NOT NULL, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    'CREATE TABLE app_metadata (key TEXT PRIMARY KEY, value TEXT)',
    'CREATE TABLE secure_profiles (user_id TEXT PRIMARY KEY, profile_json TEXT NOT NULL, updated_at TEXT NOT NULL)',
    ..._syncSchema,
    "CREATE TABLE budget_threshold_events (id INTEGER PRIMARY KEY AUTOINCREMENT, budget_id INTEGER NOT NULL, threshold INTEGER NOT NULL, period_start TEXT NOT NULL, notified_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', UNIQUE(budget_id, threshold, period_start, owner_id), FOREIGN KEY(budget_id) REFERENCES budgets(id) ON DELETE CASCADE)",
    "CREATE TABLE savings_goals (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, icon TEXT, target_amount REAL NOT NULL CHECK(target_amount > 0), target_date TEXT, notes TEXT, status TEXT NOT NULL DEFAULT 'active', created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE goal_contributions (id INTEGER PRIMARY KEY AUTOINCREMENT, goal_id INTEGER NOT NULL, amount REAL NOT NULL CHECK(amount != 0), contributed_at TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(goal_id) REFERENCES savings_goals(id) ON DELETE CASCADE)",
    "CREATE TABLE recurring_transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, amount REAL NOT NULL CHECK(amount > 0), category_id INTEGER, description TEXT NOT NULL, frequency TEXT NOT NULL, interval_count INTEGER NOT NULL DEFAULT 1 CHECK(interval_count > 0), next_due_at TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'active', source TEXT NOT NULL DEFAULT 'recurring', created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(category_id) REFERENCES categories(id))",
    "CREATE TABLE reminders (id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, reference_type TEXT, reference_id TEXT, title TEXT NOT NULL, scheduled_at TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE ai_conversations (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE ai_messages (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id INTEGER NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(conversation_id) REFERENCES ai_conversations(id) ON DELETE CASCADE)",
    "CREATE UNIQUE INDEX idx_transactions_source_link ON transactions(owner_id, source, source_record_id) WHERE source_record_id IS NOT NULL",
    'CREATE INDEX idx_transactions_owner_date ON transactions(owner_id, occurred_at)',
    'CREATE INDEX idx_transactions_owner_type_date ON transactions(owner_id, type, occurred_at)',
    'CREATE INDEX idx_fuel_entries_owner_date ON fuel_entries(owner_id, filled_at)',
    'CREATE INDEX idx_vehicle_maintenance_owner_due ON vehicle_maintenance(owner_id, next_due_at)',
    'CREATE INDEX idx_receipt_drafts_owner_created ON receipt_drafts(owner_id, created_at)',
    'CREATE INDEX idx_goal_contributions_goal_date ON goal_contributions(goal_id, contributed_at)',
    'CREATE INDEX idx_reminders_owner_schedule ON reminders(owner_id, status, scheduled_at)',
  ];

  static const _syncSchema = <String>[
    'CREATE TABLE IF NOT EXISTS sync_identity (table_name TEXT NOT NULL, local_id INTEGER NOT NULL, owner_id TEXT NOT NULL, record_uuid TEXT NOT NULL UNIQUE, content_hash TEXT, revision INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(table_name, local_id, owner_id))',
    'CREATE TABLE IF NOT EXISTS sync_outbox (record_uuid TEXT PRIMARY KEY, record_type TEXT NOT NULL, revision INTEGER NOT NULL, operation TEXT NOT NULL, envelope_json TEXT NOT NULL, content_hash TEXT, created_at TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0)',
    'CREATE TABLE IF NOT EXISTS sync_conflicts (record_uuid TEXT PRIMARY KEY, record_type TEXT NOT NULL, local_revision INTEGER NOT NULL, remote_revision INTEGER NOT NULL, remote_envelope_json TEXT NOT NULL, detected_at TEXT NOT NULL)',
    'CREATE INDEX IF NOT EXISTS idx_sync_identity_owner ON sync_identity(owner_id, table_name)',
    'CREATE INDEX IF NOT EXISTS idx_sync_outbox_created ON sync_outbox(created_at)',
  ];

  static const _ownedTables = <String>[
    'transactions',
    'budgets',
    'ledger_people',
    'electricity_calculations',
    'tax_calculations',
    'solar_calculations',
    'property_calculations',
    'vehicles',
    'fuel_entries',
    'vehicle_maintenance',
    'receipt_drafts',
    'net_worth_accounts',
    'zakat_calculations',
    'budget_threshold_events',
    'savings_goals',
    'goal_contributions',
    'recurring_transactions',
    'reminders',
    'ai_conversations',
    'ai_messages',
  ];

  static const _version1OwnedTables = <String>[
    'transactions',
    'budgets',
    'ledger_people',
    'electricity_calculations',
    'tax_calculations',
    'solar_calculations',
    'property_calculations',
    'vehicles',
    'zakat_calculations',
  ];

  static Future<void> _upgradeToVersion3(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
        "ALTER TABLE transactions ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'",
      );
      await txn.execute(
        'ALTER TABLE transactions ADD COLUMN source_record_id TEXT',
      );
      await txn.execute('ALTER TABLE transactions ADD COLUMN updated_at TEXT');
      await txn.execute(
        'ALTER TABLE ledger_transactions ADD COLUMN linked_transaction_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL',
      );
      await txn.execute(
        "ALTER TABLE fuel_entries ADD COLUMN owner_id TEXT NOT NULL DEFAULT '$legacyOwner'",
      );
      await txn.execute(
        'ALTER TABLE fuel_entries ADD COLUMN linked_transaction_id INTEGER REFERENCES transactions(id) ON DELETE SET NULL',
      );
      await txn.execute('''
        UPDATE fuel_entries
        SET owner_id = COALESCE(
          (SELECT owner_id FROM vehicles WHERE vehicles.id = fuel_entries.vehicle_id),
          '$legacyOwner'
        )
      ''');
      for (final statement in _version3Schema) {
        await txn.execute(statement);
      }
    });
  }

  static Future<void> _upgradeToVersion4(Database db) async {
    await db.execute(
      "CREATE TABLE vehicle_maintenance (id INTEGER PRIMARY KEY AUTOINCREMENT, vehicle_id INTEGER NOT NULL, kind TEXT NOT NULL, cost REAL NOT NULL DEFAULT 0 CHECK(cost >= 0), odometer REAL, serviced_at TEXT NOT NULL, next_due_at TEXT, next_due_odometer REAL, notes TEXT, linked_transaction_id INTEGER, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE, FOREIGN KEY(linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL)",
    );
    await db.execute(
      'CREATE INDEX idx_vehicle_maintenance_owner_due ON vehicle_maintenance(owner_id, next_due_at)',
    );
  }

  static Future<void> _upgradeToVersion5(Database db) async {
    await db.transaction((txn) async {
      await txn.execute(
        "CREATE TABLE receipt_drafts (id INTEGER PRIMARY KEY AUTOINCREMENT, image_path TEXT NOT NULL, merchant TEXT, total REAL, purchased_at TEXT, raw_text TEXT, status TEXT NOT NULL DEFAULT 'draft', linked_transaction_id INTEGER, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL)",
      );
      await txn.execute(
        "CREATE TABLE net_worth_accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, kind TEXT NOT NULL, balance REAL NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
      );
      await txn.execute(
        'CREATE INDEX idx_receipt_drafts_owner_created ON receipt_drafts(owner_id, created_at)',
      );
    });
  }

  static const _version3Schema = <String>[
    "CREATE TABLE budget_threshold_events (id INTEGER PRIMARY KEY AUTOINCREMENT, budget_id INTEGER NOT NULL, threshold INTEGER NOT NULL, period_start TEXT NOT NULL, notified_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', UNIQUE(budget_id, threshold, period_start, owner_id), FOREIGN KEY(budget_id) REFERENCES budgets(id) ON DELETE CASCADE)",
    "CREATE TABLE savings_goals (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, icon TEXT, target_amount REAL NOT NULL CHECK(target_amount > 0), target_date TEXT, notes TEXT, status TEXT NOT NULL DEFAULT 'active', created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE goal_contributions (id INTEGER PRIMARY KEY AUTOINCREMENT, goal_id INTEGER NOT NULL, amount REAL NOT NULL CHECK(amount != 0), contributed_at TEXT NOT NULL, note TEXT, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(goal_id) REFERENCES savings_goals(id) ON DELETE CASCADE)",
    "CREATE TABLE recurring_transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, amount REAL NOT NULL CHECK(amount > 0), category_id INTEGER, description TEXT NOT NULL, frequency TEXT NOT NULL, interval_count INTEGER NOT NULL DEFAULT 1 CHECK(interval_count > 0), next_due_at TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'active', source TEXT NOT NULL DEFAULT 'recurring', created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(category_id) REFERENCES categories(id))",
    "CREATE TABLE reminders (id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL, reference_type TEXT, reference_id TEXT, title TEXT NOT NULL, scheduled_at TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE ai_conversations (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE ai_messages (id INTEGER PRIMARY KEY AUTOINCREMENT, conversation_id INTEGER NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(conversation_id) REFERENCES ai_conversations(id) ON DELETE CASCADE)",
    "CREATE UNIQUE INDEX idx_transactions_source_link ON transactions(owner_id, source, source_record_id) WHERE source_record_id IS NOT NULL",
    'CREATE INDEX idx_transactions_owner_date ON transactions(owner_id, occurred_at)',
    'CREATE INDEX idx_transactions_owner_type_date ON transactions(owner_id, type, occurred_at)',
    'CREATE INDEX idx_fuel_entries_owner_date ON fuel_entries(owner_id, filled_at)',
    'CREATE INDEX idx_goal_contributions_goal_date ON goal_contributions(goal_id, contributed_at)',
    'CREATE INDEX idx_reminders_owner_schedule ON reminders(owner_id, status, scheduled_at)',
  ];

  static Future<void> _seedCategories(Database db) async {
    const expenses = [
      'Food',
      'Grocery',
      'Fuel',
      'Shopping',
      'Rent',
      'Electricity',
      'Gas',
      'Internet',
      'Mobile',
      'Education',
      'Health',
      'Entertainment',
      'Travel',
      'Car',
      'Family',
      'Other',
    ];
    const income = ['Salary', 'Freelance', 'Business', 'Other'];
    for (final name in expenses) {
      await db.insert('categories', {
        'name': name,
        'type': 'expense',
        'is_system': 1,
      });
    }
    for (final name in income) {
      await db.insert('categories', {
        'name': name,
        'type': 'income',
        'is_system': 1,
      });
    }
  }
}
