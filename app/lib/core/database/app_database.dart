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
        version: 16,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _create,
        onUpgrade: _upgrade,
      );
      await _verifyHealthy(_database!);
      return;
    }
    _database = await openDatabase(
      path,
      version: 16,
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
    if (oldVersion < 10) {
      for (final statement in _version10Schema) {
        await db.execute(statement);
      }
    }
    if (oldVersion < 11) {
      for (final statement in _version11Schema) {
        await db.execute(statement);
      }
    }
    if (oldVersion < 12) {
      for (final statement in _version12Schema) {
        await db.execute(statement);
      }
    }
    if (oldVersion < 13) {
      for (final statement in _version13Schema) {
        await db.execute(statement);
      }
    }
    if (oldVersion < 14) {
      for (final statement in _version14Schema) {
        await db.execute(statement);
      }
    }
    if (oldVersion < 15) {
      for (final statement in _version15Schema) {
        await db.execute(statement);
      }
    }
    if (oldVersion < 16) {
      for (final statement in _version16Migration) {
        await db.execute(statement);
      }
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
    "CREATE TABLE receipt_drafts (id INTEGER PRIMARY KEY AUTOINCREMENT, image_path TEXT NOT NULL, merchant TEXT, total REAL, purchased_at TEXT, raw_text TEXT, document_type TEXT NOT NULL DEFAULT 'receipt', due_at TEXT, reference_number TEXT, units REAL, status TEXT NOT NULL DEFAULT 'draft', linked_transaction_id INTEGER, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL)",
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
    ..._version10Schema,
    ..._version11Schema,
    ..._version12Schema,
    ..._version13Schema,
    ..._version14Schema,
    ..._version15Schema,
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
    'watch_conditions',
    'notification_inbox',
    'dashboard_sections',
    'widget_configs',
    'salary_records',
    'freelancer_income',
    'bills',
    'bill_payments',
    'net_worth_snapshots',
    'financial_preferences',
    'electricity_readings',
    'appliance_scenarios',
    'solar_systems',
    'solar_performance',
    'metal_holdings',
    'zakat_records',
    'financing_scenarios',
    'inflation_scenarios',
    'financial_health_snapshots',
    'households',
    'household_members',
    'household_record_scopes',
    'committees',
    'committee_members',
    'committee_payments',
    'ledger_payment_history',
    'ledger_installments',
    'ledger_attachments',
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

  static const _version10Schema = <String>[
    "CREATE TABLE IF NOT EXISTS pakistan_data_points (id INTEGER PRIMARY KEY AUTOINCREMENT, series_key TEXT NOT NULL, value REAL NOT NULL, unit TEXT NOT NULL, source_name TEXT NOT NULL, source_reference TEXT NOT NULL, effective_at TEXT NOT NULL, retrieved_at TEXT NOT NULL, previous_value REAL, freshness TEXT NOT NULL, config_version TEXT NOT NULL, UNIQUE(series_key, effective_at, source_name))",
    "CREATE TABLE IF NOT EXISTS watch_conditions (id INTEGER PRIMARY KEY AUTOINCREMENT, series_key TEXT NOT NULL, comparison TEXT NOT NULL, target_value REAL NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, cooldown_minutes INTEGER NOT NULL DEFAULT 1440, last_triggered_at TEXT, was_matching INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE IF NOT EXISTS notification_inbox (id INTEGER PRIMARY KEY AUTOINCREMENT, category TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, route TEXT, action_json TEXT, deduplication_key TEXT, occurred_at TEXT NOT NULL, read_at TEXT, deleted_at TEXT, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', UNIQUE(owner_id, deduplication_key))",
    "CREATE TABLE IF NOT EXISTS dashboard_sections (id INTEGER PRIMARY KEY AUTOINCREMENT, section_key TEXT NOT NULL, position INTEGER NOT NULL, visible INTEGER NOT NULL DEFAULT 1, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', UNIQUE(owner_id, section_key))",
    "CREATE TABLE IF NOT EXISTS widget_configs (id INTEGER PRIMARY KEY AUTOINCREMENT, widget_id INTEGER NOT NULL, family TEXT NOT NULL, theme_mode TEXT NOT NULL DEFAULT 'system', privacy_mode TEXT NOT NULL DEFAULT 'masked', config_json TEXT NOT NULL DEFAULT '{}', updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', UNIQUE(owner_id, widget_id))",
    'CREATE INDEX IF NOT EXISTS idx_pakistan_data_series_date ON pakistan_data_points(series_key, effective_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_watch_owner_enabled ON watch_conditions(owner_id, enabled, series_key)',
    'CREATE INDEX IF NOT EXISTS idx_notification_owner_date ON notification_inbox(owner_id, deleted_at, occurred_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_dashboard_owner_position ON dashboard_sections(owner_id, position)',
    'CREATE INDEX IF NOT EXISTS idx_widget_owner_family ON widget_configs(owner_id, family)',
  ];

  static const _version11Schema = <String>[
    "CREATE TABLE IF NOT EXISTS salary_records (id INTEGER PRIMARY KEY AUTOINCREMENT, basic_salary REAL NOT NULL CHECK(basic_salary >= 0), house_allowance REAL NOT NULL DEFAULT 0, medical_allowance REAL NOT NULL DEFAULT 0, transport_allowance REAL NOT NULL DEFAULT 0, bonus REAL NOT NULL DEFAULT 0, commission REAL NOT NULL DEFAULT 0, other_allowances REAL NOT NULL DEFAULT 0, tax REAL NOT NULL DEFAULT 0, other_deductions REAL NOT NULL DEFAULT 0, received_at TEXT NOT NULL, notes TEXT, linked_transaction_id INTEGER, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL)",
    "CREATE TABLE IF NOT EXISTS freelancer_income (id INTEGER PRIMARY KEY AUTOINCREMENT, client TEXT NOT NULL, gross_amount REAL NOT NULL CHECK(gross_amount > 0), currency TEXT NOT NULL, exchange_rate REAL NOT NULL CHECK(exchange_rate > 0), fees REAL NOT NULL DEFAULT 0 CHECK(fees >= 0), pkr_net REAL NOT NULL CHECK(pkr_net >= 0), payment_method TEXT, status TEXT NOT NULL, expected_at TEXT NOT NULL, received_at TEXT, notes TEXT, linked_transaction_id INTEGER, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL)",
    "CREATE TABLE IF NOT EXISTS bills (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, provider TEXT NOT NULL, account_reference TEXT, amount REAL NOT NULL CHECK(amount >= 0), issue_date TEXT, due_date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'unpaid', recurring_frequency TEXT, notes TEXT, attachment_path TEXT, linked_recurring_id INTEGER, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(linked_recurring_id) REFERENCES recurring_transactions(id) ON DELETE SET NULL)",
    "CREATE TABLE IF NOT EXISTS bill_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, bill_id INTEGER NOT NULL, amount REAL NOT NULL CHECK(amount > 0), paid_at TEXT NOT NULL, linked_transaction_id INTEGER, notes TEXT, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(bill_id) REFERENCES bills(id) ON DELETE CASCADE, FOREIGN KEY(linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL)",
    "CREATE TABLE IF NOT EXISTS net_worth_snapshots (id INTEGER PRIMARY KEY AUTOINCREMENT, total_assets REAL NOT NULL, total_liabilities REAL NOT NULL, net_worth REAL NOT NULL, captured_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE IF NOT EXISTS financial_preferences (id INTEGER PRIMARY KEY AUTOINCREMENT, emergency_fund_target_months REAL NOT NULL DEFAULT 3 CHECK(emergency_fund_target_months > 0), essential_monthly_expenses REAL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', UNIQUE(owner_id))",
    'CREATE INDEX IF NOT EXISTS idx_salary_owner_date ON salary_records(owner_id, received_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_freelancer_owner_status_date ON freelancer_income(owner_id, status, expected_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_bills_owner_due_status ON bills(owner_id, due_date, status)',
    'CREATE INDEX IF NOT EXISTS idx_bill_payments_bill_date ON bill_payments(bill_id, paid_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_net_worth_snapshots_owner_date ON net_worth_snapshots(owner_id, captured_at DESC)',
  ];

  static const _version12Schema = <String>[
    "CREATE TABLE IF NOT EXISTS electricity_readings (id INTEGER PRIMARY KEY AUTOINCREMENT, provider TEXT NOT NULL, billing_month TEXT NOT NULL, previous_reading REAL, current_reading REAL, units REAL NOT NULL CHECK(units >= 0), actual_bill REAL, estimated_bill REAL, record_type TEXT NOT NULL, notes TEXT, linked_bill_id INTEGER, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(linked_bill_id) REFERENCES bills(id) ON DELETE SET NULL)",
    "CREATE TABLE IF NOT EXISTS appliance_scenarios (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, quantity INTEGER NOT NULL CHECK(quantity > 0), wattage REAL NOT NULL CHECK(wattage > 0), hours_per_day REAL NOT NULL CHECK(hours_per_day >= 0 AND hours_per_day <= 24), days_per_month INTEGER NOT NULL CHECK(days_per_month > 0 AND days_per_month <= 31), tariff_per_kwh REAL NOT NULL CHECK(tariff_per_kwh >= 0), created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE IF NOT EXISTS solar_systems (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, installation_date TEXT NOT NULL, system_kw REAL NOT NULL CHECK(system_kw > 0), panel_count INTEGER NOT NULL CHECK(panel_count > 0), panel_wattage REAL NOT NULL CHECK(panel_wattage > 0), inverter TEXT, battery TEXT, installation_cost REAL NOT NULL CHECK(installation_cost >= 0), maintenance_cost REAL NOT NULL DEFAULT 0 CHECK(maintenance_cost >= 0), created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE IF NOT EXISTS solar_performance (id INTEGER PRIMARY KEY AUTOINCREMENT, solar_system_id INTEGER NOT NULL, month TEXT NOT NULL, generation_kwh REAL NOT NULL CHECK(generation_kwh >= 0), grid_import_kwh REAL NOT NULL DEFAULT 0 CHECK(grid_import_kwh >= 0), grid_export_kwh REAL NOT NULL DEFAULT 0 CHECK(grid_export_kwh >= 0), electricity_bill REAL NOT NULL DEFAULT 0 CHECK(electricity_bill >= 0), estimated_savings REAL NOT NULL DEFAULT 0 CHECK(estimated_savings >= 0), created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', UNIQUE(owner_id, solar_system_id, month), FOREIGN KEY(solar_system_id) REFERENCES solar_systems(id) ON DELETE CASCADE)",
    'CREATE INDEX IF NOT EXISTS idx_electricity_readings_owner_month ON electricity_readings(owner_id, billing_month DESC)',
    'CREATE INDEX IF NOT EXISTS idx_appliance_scenarios_owner ON appliance_scenarios(owner_id, name)',
    'CREATE INDEX IF NOT EXISTS idx_solar_systems_owner ON solar_systems(owner_id, installation_date DESC)',
    'CREATE INDEX IF NOT EXISTS idx_solar_performance_system_month ON solar_performance(solar_system_id, month DESC)',
  ];

  static const _version13Schema = <String>[
    "CREATE TABLE IF NOT EXISTS metal_holdings (id INTEGER PRIMARY KEY AUTOINCREMENT, metal TEXT NOT NULL, quantity REAL NOT NULL CHECK(quantity > 0), unit TEXT NOT NULL, purity REAL NOT NULL CHECK(purity > 0 AND purity <= 1), purchase_price REAL, purchase_date TEXT, notes TEXT, linked_net_worth_account_id INTEGER, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(linked_net_worth_account_id) REFERENCES net_worth_accounts(id) ON DELETE SET NULL)",
    "CREATE TABLE IF NOT EXISTS zakat_records (id INTEGER PRIMARY KEY AUTOINCREMENT, cash_amount REAL NOT NULL DEFAULT 0, bank_amount REAL NOT NULL DEFAULT 0, gold_amount REAL NOT NULL DEFAULT 0, silver_amount REAL NOT NULL DEFAULT 0, business_assets REAL NOT NULL DEFAULT 0, receivables REAL NOT NULL DEFAULT 0, other_assets REAL NOT NULL DEFAULT 0, liabilities REAL NOT NULL DEFAULT 0, nisab_method TEXT NOT NULL, nisab_value REAL NOT NULL, eligible_total REAL NOT NULL, zakat_due REAL NOT NULL, calculated_at TEXT NOT NULL, reminder_at TEXT, source_reference TEXT, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    'CREATE INDEX IF NOT EXISTS idx_metal_holdings_owner_metal ON metal_holdings(owner_id, metal)',
    'CREATE INDEX IF NOT EXISTS idx_zakat_records_owner_date ON zakat_records(owner_id, calculated_at DESC)',
  ];

  static const _version14Schema = <String>[
    "CREATE TABLE IF NOT EXISTS financing_scenarios (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, financing_type TEXT NOT NULL, amount REAL NOT NULL, down_payment REAL NOT NULL DEFAULT 0, rate_type TEXT NOT NULL, annual_rate REAL NOT NULL, kibor_rate REAL, spread REAL NOT NULL DEFAULT 0, tenure_months INTEGER NOT NULL, monthly_payment REAL NOT NULL, total_repayment REAL NOT NULL, financing_cost REAL NOT NULL, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE IF NOT EXISTS inflation_scenarios (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, calculation_type TEXT NOT NULL, nominal_amount REAL NOT NULL, adjusted_amount REAL NOT NULL, cumulative_inflation REAL NOT NULL, rates_json TEXT NOT NULL, start_year INTEGER, end_year INTEGER, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE IF NOT EXISTS financial_health_snapshots (id INTEGER PRIMARY KEY AUTOINCREMENT, score INTEGER NOT NULL, status TEXT NOT NULL, components_json TEXT NOT NULL, explanations_json TEXT NOT NULL, captured_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    'CREATE INDEX IF NOT EXISTS idx_financing_owner_created ON financing_scenarios(owner_id, created_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_inflation_owner_created ON inflation_scenarios(owner_id, created_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_health_owner_date ON financial_health_snapshots(owner_id, captured_at DESC)',
  ];

  static const _version15Schema = <String>[
    "CREATE TABLE IF NOT EXISTS households (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE IF NOT EXISTS household_members (id INTEGER PRIMARY KEY AUTOINCREMENT, household_id INTEGER NOT NULL, display_name TEXT NOT NULL, email TEXT, role TEXT NOT NULL DEFAULT 'member', status TEXT NOT NULL DEFAULT 'local', created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(household_id) REFERENCES households(id) ON DELETE CASCADE)",
    "CREATE TABLE IF NOT EXISTS household_record_scopes (id INTEGER PRIMARY KEY AUTOINCREMENT, record_type TEXT NOT NULL, record_id INTEGER NOT NULL, privacy_scope TEXT NOT NULL DEFAULT 'onlyMe', household_id INTEGER, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', UNIQUE(owner_id, record_type, record_id), FOREIGN KEY(household_id) REFERENCES households(id) ON DELETE CASCADE)",
    "CREATE TABLE IF NOT EXISTS committees (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, monthly_contribution REAL NOT NULL CHECK(monthly_contribution > 0), member_count INTEGER NOT NULL CHECK(member_count > 1), month_count INTEGER NOT NULL CHECK(month_count > 1), start_date TEXT NOT NULL, user_turn INTEGER CHECK(user_turn > 0), reminder_day INTEGER CHECK(reminder_day >= 1 AND reminder_day <= 28), notes TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner')",
    "CREATE TABLE IF NOT EXISTS committee_members (id INTEGER PRIMARY KEY AUTOINCREMENT, committee_id INTEGER NOT NULL, name TEXT NOT NULL, turn_number INTEGER, is_user INTEGER NOT NULL DEFAULT 0, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(committee_id) REFERENCES committees(id) ON DELETE CASCADE)",
    "CREATE TABLE IF NOT EXISTS committee_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, committee_id INTEGER NOT NULL, cycle_number INTEGER NOT NULL, due_date TEXT NOT NULL, amount REAL NOT NULL, paid_at TEXT, received_at TEXT, status TEXT NOT NULL DEFAULT 'due', notes TEXT, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', UNIQUE(owner_id, committee_id, cycle_number), FOREIGN KEY(committee_id) REFERENCES committees(id) ON DELETE CASCADE)",
    "CREATE TABLE IF NOT EXISTS ledger_payment_history (id INTEGER PRIMARY KEY AUTOINCREMENT, ledger_transaction_id INTEGER NOT NULL, amount REAL NOT NULL CHECK(amount > 0), paid_at TEXT NOT NULL, notes TEXT, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(ledger_transaction_id) REFERENCES ledger_transactions(id) ON DELETE CASCADE)",
    "CREATE TABLE IF NOT EXISTS ledger_installments (id INTEGER PRIMARY KEY AUTOINCREMENT, ledger_transaction_id INTEGER NOT NULL, installment_number INTEGER NOT NULL, amount REAL NOT NULL CHECK(amount > 0), due_at TEXT NOT NULL, paid_at TEXT, status TEXT NOT NULL DEFAULT 'pending', owner_id TEXT NOT NULL DEFAULT '$legacyOwner', UNIQUE(owner_id, ledger_transaction_id, installment_number), FOREIGN KEY(ledger_transaction_id) REFERENCES ledger_transactions(id) ON DELETE CASCADE)",
    "CREATE TABLE IF NOT EXISTS ledger_attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, ledger_transaction_id INTEGER NOT NULL, file_path TEXT NOT NULL, display_name TEXT NOT NULL, created_at TEXT NOT NULL, owner_id TEXT NOT NULL DEFAULT '$legacyOwner', FOREIGN KEY(ledger_transaction_id) REFERENCES ledger_transactions(id) ON DELETE CASCADE)",
    'CREATE INDEX IF NOT EXISTS idx_households_owner ON households(owner_id, updated_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_household_members_household ON household_members(household_id)',
    'CREATE INDEX IF NOT EXISTS idx_record_scopes_owner_type ON household_record_scopes(owner_id, record_type, privacy_scope)',
    'CREATE INDEX IF NOT EXISTS idx_committees_owner ON committees(owner_id, start_date DESC)',
    'CREATE INDEX IF NOT EXISTS idx_committee_payments_due ON committee_payments(owner_id, due_date, status)',
    'CREATE INDEX IF NOT EXISTS idx_ledger_payments_entry ON ledger_payment_history(ledger_transaction_id, paid_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_ledger_installments_due ON ledger_installments(owner_id, due_at, status)',
  ];

  static const _version16Migration = <String>[
    "ALTER TABLE receipt_drafts ADD COLUMN document_type TEXT NOT NULL DEFAULT 'receipt'",
    'ALTER TABLE receipt_drafts ADD COLUMN due_at TEXT',
    'ALTER TABLE receipt_drafts ADD COLUMN reference_number TEXT',
    'ALTER TABLE receipt_drafts ADD COLUMN units REAL',
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
