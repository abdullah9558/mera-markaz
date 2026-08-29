import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../security/crypto/crypto_envelope.dart';
import '../security/crypto/key_enrollment_service.dart';
import '../security/crypto/mera_markaz_crypto.dart';
import 'device_identity_service.dart';

final encryptedSyncServiceProvider = Provider(
  (ref) => EncryptedSyncService(database: ref.watch(appDatabaseProvider)),
);

class EncryptedSyncService {
  EncryptedSyncService({
    required this.database,
    FirebaseFirestore? firestore,
    KeyEnrollmentService? enrollment,
    DeviceIdentityService? devices,
    MeraMarkazCrypto? crypto,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _enrollment = enrollment ?? KeyEnrollmentService(),
       _devices = devices ?? DeviceIdentityService(),
       _crypto = crypto ?? MeraMarkazCrypto();

  final AppDatabase database;
  final FirebaseFirestore _firestore;
  final KeyEnrollmentService _enrollment;
  final DeviceIdentityService _devices;
  final MeraMarkazCrypto _crypto;

  static const syncedTables = <String>[
    'transactions',
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
    'budget_threshold_events',
    'savings_goals',
    'goal_contributions',
    'recurring_transactions',
    'reminders',
    'ai_conversations',
    'ai_messages',
  ];

  Future<bool> enabled(String uid) => _enrollment.isConfirmed(uid);

  Future<void> synchronize(String uid) async {
    if (!await enabled(uid)) return;
    final master = await _enrollment.unlockWithDevice(uid);
    try {
      final recordKey = await _crypto.derivePurposeKey(
        masterKey: master,
        purpose: 'record',
      );
      final deviceId = await _devices.id();
      await _stageCurrentRows(uid, deviceId, recordKey);
      await _stageDeletedRows(uid, deviceId, recordKey);
      await _uploadOutbox(uid, deviceId);
      await _downloadAndMerge(uid, recordKey);
    } finally {
      master.destroy();
    }
  }

  Future<void> _stageCurrentRows(
    String uid,
    String deviceId,
    SecretKey recordKey,
  ) async {
    final owner = 'account:$uid';
    for (final table in syncedTables) {
      final rows = await database.database.query(
        table,
        where: 'owner_id = ?',
        whereArgs: [owner],
      );
      for (final row in rows) {
        final localId = row['id']! as int;
        final canonical = _canonicalJson(row);
        final hash = encodeBytes(
          (await Sha256().hash(utf8.encode(canonical))).bytes,
        );
        final identity = await _identity(table, localId, owner);
        if (identity != null &&
            identity['content_hash'] == hash &&
            identity['deleted'] == 0) {
          continue;
        }
        final uuid = identity?['record_uuid'] as String? ?? const Uuid().v4();
        final revision = ((identity?['revision'] as int?) ?? 0) + 1;
        final envelope = await _crypto.encrypt(
          plaintext: utf8.encode(canonical),
          key: recordKey,
          aad: canonicalAad(
            ownerId: uid,
            recordType: table,
            recordId: uuid,
            revision: revision,
          ),
        );
        await database.database.transaction((txn) async {
          await txn.insert('sync_identity', {
            'table_name': table,
            'local_id': localId,
            'owner_id': owner,
            'record_uuid': uuid,
            'content_hash': hash,
            'revision': revision,
            'deleted': 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          await _queue(
            txn,
            uuid: uuid,
            table: table,
            revision: revision,
            operation: 'upsert',
            envelope: envelope,
            hash: hash,
          );
        });
      }
    }
  }

  Future<void> _stageDeletedRows(
    String uid,
    String deviceId,
    SecretKey recordKey,
  ) async {
    final owner = 'account:$uid';
    final identities = await database.database.query(
      'sync_identity',
      where: 'owner_id = ? AND deleted = 0',
      whereArgs: [owner],
    );
    for (final identity in identities) {
      final table = identity['table_name']! as String;
      final localId = identity['local_id']! as int;
      final exists = await database.database.query(
        table,
        columns: ['id'],
        where: 'id = ? AND owner_id = ?',
        whereArgs: [localId, owner],
        limit: 1,
      );
      if (exists.isNotEmpty) continue;
      final uuid = identity['record_uuid']! as String;
      final revision = (identity['revision']! as int) + 1;
      final envelope = await _crypto.encrypt(
        plaintext: utf8.encode('{}'),
        key: recordKey,
        aad: canonicalAad(
          ownerId: uid,
          recordType: table,
          recordId: uuid,
          revision: revision,
        ),
      );
      await database.database.transaction((txn) async {
        await txn.update(
          'sync_identity',
          {'revision': revision, 'deleted': 1},
          where: 'record_uuid = ?',
          whereArgs: [uuid],
        );
        await _queue(
          txn,
          uuid: uuid,
          table: table,
          revision: revision,
          operation: 'delete',
          envelope: envelope,
        );
      });
    }
  }

  Future<void> _uploadOutbox(String uid, String deviceId) async {
    final rows = await database.database.query(
      'sync_outbox',
      orderBy: 'created_at ASC',
    );
    for (final row in rows) {
      final uuid = row['record_uuid']! as String;
      final document = _firestore.doc('users/$uid/records/$uuid');
      final remote = await document.get();
      final localRevision = row['revision']! as int;
      final remoteRevision = remote.data()?['revision'] as int? ?? 0;
      if (remoteRevision >= localRevision) {
        await database.database.delete(
          'sync_outbox',
          where: 'record_uuid = ?',
          whereArgs: [uuid],
        );
        continue;
      }
      final envelope = CryptoEnvelope.fromJson(
        Map<String, Object?>.from(
          jsonDecode(row['envelope_json']! as String) as Map,
        ),
      );
      try {
        await document.set({
          'ownerUid': uid,
          'recordUuid': uuid,
          'recordTypeCode': row['record_type'],
          'schemaVersion': 1,
          'keyVersion': envelope.keyVersion,
          'revision': localRevision,
          'updatedAt': FieldValue.serverTimestamp(),
          'deleted': row['operation'] == 'delete',
          'nonce': Blob(envelope.nonce),
          'ciphertext': Blob(envelope.ciphertext),
          'tag': Blob(envelope.mac),
          'deviceId': deviceId,
        });
        await database.database.delete(
          'sync_outbox',
          where: 'record_uuid = ?',
          whereArgs: [uuid],
        );
      } catch (_) {
        await database.database.rawUpdate(
          'UPDATE sync_outbox SET attempts = attempts + 1 WHERE record_uuid = ?',
          [uuid],
        );
        rethrow;
      }
    }
  }

  Future<void> _downloadAndMerge(String uid, SecretKey recordKey) async {
    final remote = await _firestore.collection('users/$uid/records').get();
    for (final document in remote.docs) {
      final data = document.data();
      final type = data['recordTypeCode'];
      if (type is! String || !syncedTables.contains(type)) continue;
      final identity = await database.database.query(
        'sync_identity',
        where: 'record_uuid = ?',
        whereArgs: [document.id],
        limit: 1,
      );
      final localRevision = identity.isEmpty
          ? 0
          : identity.single['revision']! as int;
      final remoteRevision = data['revision'] as int;
      if (remoteRevision <= localRevision) continue;
      final envelope = CryptoEnvelope.fromJson(_firestoreEnvelopeJson(data));
      late final List<int> clear;
      try {
        clear = await _crypto.decrypt(
          envelope: envelope,
          key: recordKey,
          aad: canonicalAad(
            ownerId: uid,
            recordType: type,
            recordId: document.id,
            revision: remoteRevision,
          ),
        );
      } catch (_) {
        continue;
      }
      final decoded = jsonDecode(utf8.decode(clear));
      if (decoded is! Map) continue;
      final row = Map<String, Object?>.from(decoded);
      final localId = identity.isEmpty
          ? row['id']
          : identity.single['local_id'];
      if (localId is! int) continue;
      final owner = 'account:$uid';

      // A queued local edit means both devices changed the record. Preserve the
      // remote envelope for explicit conflict handling instead of overwriting.
      final queued = await database.database.query(
        'sync_outbox',
        where: 'record_uuid = ?',
        whereArgs: [document.id],
        limit: 1,
      );
      if (queued.isNotEmpty) {
        await _recordConflict(
          document.id,
          type,
          localRevision,
          remoteRevision,
          data,
        );
        continue;
      }
      try {
        await database.database.transaction((txn) async {
          if (data['deleted'] == true) {
            await txn.delete(
              type,
              where: 'id = ? AND owner_id = ?',
              whereArgs: [localId, owner],
            );
          } else {
            row['id'] = localId;
            row['owner_id'] = owner;
            if (identity.isEmpty) {
              await txn.insert(
                type,
                row,
                conflictAlgorithm: ConflictAlgorithm.abort,
              );
            } else {
              await txn.update(
                type,
                row,
                where: 'id = ? AND owner_id = ?',
                whereArgs: [localId, owner],
              );
            }
          }
          final canonical = _canonicalJson(row);
          final hash = encodeBytes(
            (await Sha256().hash(utf8.encode(canonical))).bytes,
          );
          await txn.insert('sync_identity', {
            'table_name': type,
            'local_id': localId,
            'owner_id': owner,
            'record_uuid': document.id,
            'content_hash': hash,
            'revision': remoteRevision,
            'deleted': data['deleted'] == true ? 1 : 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        });
      } catch (_) {
        await _recordConflict(
          document.id,
          type,
          localRevision,
          remoteRevision,
          data,
        );
      }
    }
  }

  Future<void> _recordConflict(
    String uuid,
    String type,
    int localRevision,
    int remoteRevision,
    Map<String, dynamic> data,
  ) async {
    await database.database.insert('sync_conflicts', {
      'record_uuid': uuid,
      'record_type': type,
      'local_revision': localRevision,
      'remote_revision': remoteRevision,
      'remote_envelope_json': jsonEncode(_firestoreEnvelopeJson(data)),
      'detected_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> _identity(
    String table,
    int localId,
    String owner,
  ) async {
    final rows = await database.database.query(
      'sync_identity',
      where: 'table_name = ? AND local_id = ? AND owner_id = ?',
      whereArgs: [table, localId, owner],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> _queue(
    DatabaseExecutor executor, {
    required String uuid,
    required String table,
    required int revision,
    required String operation,
    required CryptoEnvelope envelope,
    String? hash,
  }) => executor.insert('sync_outbox', {
    'record_uuid': uuid,
    'record_type': table,
    'revision': revision,
    'operation': operation,
    'envelope_json': jsonEncode(envelope.toJson()),
    'content_hash': hash,
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'attempts': 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  static String _canonicalJson(Map<String, Object?> row) {
    final entries = row.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return jsonEncode(Map.fromEntries(entries));
  }

  static Map<String, Object?> _firestoreEnvelopeJson(
    Map<String, dynamic> data,
  ) => {
    'algorithm': CryptoEnvelope.currentAlgorithm,
    'schemaVersion': data['schemaVersion'] as int,
    'keyVersion': data['keyVersion'] as int,
    'nonce': encodeBytes((data['nonce'] as Blob).bytes),
    'ciphertext': encodeBytes((data['ciphertext'] as Blob).bytes),
    'tag': encodeBytes((data['tag'] as Blob).bytes),
  };
}
