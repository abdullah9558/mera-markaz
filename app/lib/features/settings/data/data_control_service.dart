import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/security/crypto/encrypted_file_service.dart';
import '../../../core/security/crypto/key_enrollment_service.dart';

final dataControlServiceProvider = Provider<DataControlService>(
  (ref) => DataControlService(ref.watch(appDatabaseProvider)),
);

class DataControlService {
  DataControlService(
    this.database, {
    EncryptedFileService? encryptedFiles,
    KeyEnrollmentService? enrollment,
  }) : _encryptedFiles = encryptedFiles ?? EncryptedFileService(),
       _enrollment = enrollment ?? KeyEnrollmentService();
  final AppDatabase database;
  final EncryptedFileService _encryptedFiles;
  final KeyEnrollmentService _enrollment;
  static const exportTables = [
    'transactions',
    'categories',
    'budgets',
    'ledger_people',
    'ledger_transactions',
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
    'budget_threshold_events',
    'savings_goals',
    'goal_contributions',
    'recurring_transactions',
    'reminders',
    'ai_conversations',
    'ai_messages',
  ];
  Future<File> exportJson() async {
    final content = <String, Object?>{
      'format': 'MeraMarkaz local data export',
      'version': 1,
      'owner_id': database.ownerId,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
    };
    for (final table in exportTables) {
      content[table] = switch (table) {
        'categories' => await database.database.query(table),
        'ledger_transactions' => await database.database.rawQuery(
          'SELECT t.* FROM ledger_transactions t JOIN ledger_people p ON p.id = t.person_id WHERE p.owner_id = ?',
          [database.ownerId],
        ),
        'fuel_entries' => await database.database.rawQuery(
          'SELECT f.* FROM fuel_entries f JOIN vehicles v ON v.id = f.vehicle_id WHERE v.owner_id = ?',
          [database.ownerId],
        ),
        _ => await database.database.query(
          table,
          where: 'owner_id = ?',
          whereArgs: [database.ownerId],
        ),
      };
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(
        directory.path,
        'mera-markaz-backup-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.mmb',
      ),
    );
    final uid = _accountUid;
    if (uid != null && await _enrollment.isConfirmed(uid)) {
      final master = await _enrollment.unlockWithDevice(uid);
      try {
        await _encryptedFiles.encryptBytesWithMasterKey(
          bytes: utf8.encode(jsonEncode(content)),
          destination: file,
          purpose: 'backup',
          masterKey: master,
        );
      } finally {
        master.destroy();
      }
    } else {
      await _encryptedFiles.encryptBytesToFile(
        bytes: utf8.encode(jsonEncode(content)),
        destination: file,
        purpose: 'backup',
      );
    }
    return file;
  }

  Future<void> restoreMmb(File file) async {
    if (p.extension(file.path).toLowerCase() != '.mmb') {
      throw const FormatException('Select a Mera Markaz .mmb backup.');
    }
    final uid = _accountUid;
    late final Uint8List clear;
    if (uid != null && await _enrollment.isConfirmed(uid)) {
      final master = await _enrollment.unlockWithDevice(uid);
      try {
        clear = await _encryptedFiles.decryptFileWithMasterKey(
          file,
          purpose: 'backup',
          masterKey: master,
        );
      } finally {
        master.destroy();
      }
    } else {
      clear = await _encryptedFiles.decryptFile(file, purpose: 'backup');
    }
    final decoded = jsonDecode(utf8.decode(clear));
    clear.fillRange(0, clear.length, 0);
    if (decoded is! Map ||
        decoded['format'] != 'MeraMarkaz local data export' ||
        decoded['version'] != 1 ||
        decoded['owner_id'] != database.ownerId) {
      throw const FormatException(
        'This backup is invalid or belongs to a different local profile.',
      );
    }
    for (final table in exportTables) {
      if (decoded[table] is! List) {
        throw const FormatException('The backup manifest is incomplete.');
      }
    }
    final owner = database.ownerId;
    await database.database.transaction((txn) async {
      await txn.rawDelete(
        'DELETE FROM ledger_transactions WHERE person_id IN (SELECT id FROM ledger_people WHERE owner_id = ?)',
        [owner],
      );
      await txn.rawDelete(
        'DELETE FROM fuel_entries WHERE vehicle_id IN (SELECT id FROM vehicles WHERE owner_id = ?)',
        [owner],
      );
      for (final table in exportTables.reversed) {
        if (table == 'categories' ||
            table == 'ledger_transactions' ||
            table == 'fuel_entries') {
          continue;
        }
        await txn.delete(table, where: 'owner_id = ?', whereArgs: [owner]);
      }
      for (final table in exportTables) {
        if (table == 'categories') continue;
        for (final value in decoded[table]! as List) {
          if (value is! Map) {
            throw const FormatException('The backup contains an invalid row.');
          }
          await txn.insert(
            table,
            Map<String, Object?>.from(value),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  String? get _accountUid {
    const prefix = 'account:';
    return database.ownerId.startsWith(prefix)
        ? database.ownerId.substring(prefix.length)
        : null;
  }

  Future<void> deleteAllFinancialData() async {
    final owner = database.ownerId;
    final receiptImages = await database.database.query(
      'receipt_drafts',
      columns: ['image_path'],
      where: 'owner_id = ?',
      whereArgs: [owner],
    );
    await database.database.transaction((txn) async {
      await txn.rawDelete(
        'DELETE FROM ledger_transactions WHERE person_id IN (SELECT id FROM ledger_people WHERE owner_id = ?)',
        [owner],
      );
      await txn.rawDelete(
        'DELETE FROM fuel_entries WHERE vehicle_id IN (SELECT id FROM vehicles WHERE owner_id = ?)',
        [owner],
      );
      for (final table in const [
        'budget_threshold_events',
        'goal_contributions',
        'ai_messages',
        'household_members',
        'household_record_scopes',
        'committee_members',
        'committee_payments',
        'ledger_payment_history',
        'ledger_installments',
        'ledger_attachments',
      ]) {
        await txn.delete(table, where: 'owner_id = ?', whereArgs: [owner]);
      }
      for (final table in const [
        'transactions',
        'budgets',
        'electricity_calculations',
        'tax_calculations',
        'solar_calculations',
        'property_calculations',
        'zakat_calculations',
        'zakat_records',
        'metal_holdings',
        'financing_scenarios',
        'inflation_scenarios',
        'financial_health_snapshots',
        'committees',
        'households',
        'receipt_drafts',
        'net_worth_accounts',
        'vehicles',
        'ledger_people',
        'savings_goals',
        'recurring_transactions',
        'reminders',
        'ai_conversations',
      ]) {
        await txn.delete(table, where: 'owner_id = ?', whereArgs: [owner]);
      }
    });
    for (final row in receiptImages) {
      final file = File(row['image_path'] as String);
      if (await file.exists()) await file.delete();
    }
  }
}
