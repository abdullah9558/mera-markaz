import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'android_keystore.dart';
import 'crypto_envelope.dart';
import 'mera_markaz_crypto.dart';

class KeyEnrollmentResult {
  const KeyEnrollmentResult({
    required this.recoveryKey,
    required this.deviceWrappedKey,
    required this.recoveryWrappedKey,
  });

  /// Display once, require confirmation, then discard. Never persist this value.
  final String recoveryKey;
  final DeviceWrappedKey deviceWrappedKey;
  final RecoveryWrappedKey recoveryWrappedKey;
}

class KeyEnrollmentService {
  KeyEnrollmentService({
    MeraMarkazCrypto? crypto,
    DeviceKeyStore? deviceKeyStore,
    Future<SharedPreferences> Function()? preferences,
  }) : _crypto = crypto ?? MeraMarkazCrypto(),
       _deviceKeyStore = deviceKeyStore ?? const AndroidDeviceKeyStore(),
       _preferences = preferences ?? SharedPreferences.getInstance;

  static const _metadataPrefix = 'crypto_enrollment_v1_';
  static const _recoveryKdf = 'HKDF-HMAC-SHA-256/v1';
  final MeraMarkazCrypto _crypto;
  final DeviceKeyStore _deviceKeyStore;
  final Future<SharedPreferences> Function() _preferences;

  Future<KeyEnrollmentResult> enroll(String firebaseUid) async {
    _validateUid(firebaseUid);
    if (await hasEnrollment(firebaseUid)) {
      throw StateError(
        'Encryption keys are already enrolled for this account.',
      );
    }

    final masterKey = await _crypto.generateUserMasterKey();
    final masterBytes = Uint8List.fromList(await masterKey.extractBytes());
    final alias = 'mm_${encodeBytes(_crypto.randomBytes(18))}';
    final deviceAad = _deviceAad(firebaseUid, alias);

    DeviceWrappedKey? deviceWrapped;
    try {
      deviceWrapped = await _deviceKeyStore.wrap(
        alias: alias,
        plaintext: masterBytes,
        aad: deviceAad,
      );

      final recoverySecret = _crypto.randomBytes(32);
      final checksum = await Sha256().hash(recoverySecret);
      final recoveryKey = encodeBytes([
        ...recoverySecret,
        ...checksum.bytes.take(4),
      ]);
      final salt = _crypto.randomBytes(32);
      final recoveryKek = await _crypto.derivePurposeKey(
        masterKey: SecretKey(recoverySecret),
        purpose: 'recovery-wrap',
        salt: salt,
      );
      final recoveryEnvelope = await _crypto.encrypt(
        plaintext: masterBytes,
        key: recoveryKek,
        aad: _recoveryAad(firebaseUid),
      );
      final recoveryWrapped = RecoveryWrappedKey(
        kdf: _recoveryKdf,
        salt: salt,
        envelope: recoveryEnvelope,
      );

      await _persist(firebaseUid, deviceWrapped, recoveryWrapped);
      _wipe(masterBytes);
      _wipe(recoverySecret);
      return KeyEnrollmentResult(
        recoveryKey: recoveryKey,
        deviceWrappedKey: deviceWrapped,
        recoveryWrappedKey: recoveryWrapped,
      );
    } catch (_) {
      _wipe(masterBytes);
      if (deviceWrapped != null) await _deviceKeyStore.delete(alias);
      rethrow;
    }
  }

  Future<SecretKeyData> unlockWithDevice(String firebaseUid) async {
    if (!await isConfirmed(firebaseUid)) {
      throw StateError('Encryption enrollment has not been confirmed.');
    }
    final metadata = await _read(firebaseUid);
    final clear = await _deviceKeyStore.unwrap(
      wrappedKey: metadata.$1,
      aad: _deviceAad(firebaseUid, metadata.$1.alias),
    );
    if (clear.length != MeraMarkazCrypto.keyLengthBytes) {
      _wipe(clear);
      throw const FormatException('Invalid user master key length.');
    }
    return SecretKeyData(clear, overwriteWhenDestroyed: true);
  }

  Future<SecretKeyData> recover(String firebaseUid, String recoveryKey) async {
    if (!await isConfirmed(firebaseUid)) {
      throw StateError('Encryption enrollment has not been confirmed.');
    }
    final metadata = await _read(firebaseUid);
    final decoded = decodeBytes(recoveryKey.trim());
    if (decoded.length != 36) {
      throw const FormatException('Invalid recovery key.');
    }
    final secret = Uint8List.fromList(decoded.take(32).toList());
    final suppliedChecksum = decoded.skip(32).toList();
    final digest = await Sha256().hash(secret);
    if (!_constantTimeEquals(suppliedChecksum, digest.bytes.take(4).toList())) {
      _wipe(secret);
      throw const FormatException('Invalid recovery key checksum.');
    }
    try {
      final kek = await _crypto.derivePurposeKey(
        masterKey: SecretKey(secret),
        purpose: 'recovery-wrap',
        salt: metadata.$2.salt,
      );
      final clear = await _crypto.decrypt(
        envelope: metadata.$2.envelope,
        key: kek,
        aad: _recoveryAad(firebaseUid),
      );
      return SecretKeyData(clear, overwriteWhenDestroyed: true);
    } finally {
      _wipe(secret);
    }
  }

  Future<void> recoverAndEnrollDevice(
    String firebaseUid,
    String recoveryKey,
    RecoveryWrappedKey recoveryWrappedKey,
  ) async {
    _validateUid(firebaseUid);
    if (await hasEnrollment(firebaseUid)) {
      throw StateError('Encryption keys already exist on this device.');
    }
    final decoded = decodeBytes(recoveryKey.trim());
    if (decoded.length != 36) {
      throw const FormatException('Invalid recovery key.');
    }
    final secret = Uint8List.fromList(decoded.take(32).toList());
    final digest = await Sha256().hash(secret);
    if (!_constantTimeEquals(
      decoded.skip(32).toList(),
      digest.bytes.take(4).toList(),
    )) {
      _wipe(secret);
      throw const FormatException('Invalid recovery key checksum.');
    }
    Uint8List? clear;
    DeviceWrappedKey? deviceWrapped;
    try {
      final kek = await _crypto.derivePurposeKey(
        masterKey: SecretKey(secret),
        purpose: 'recovery-wrap',
        salt: recoveryWrappedKey.salt,
      );
      clear = await _crypto.decrypt(
        envelope: recoveryWrappedKey.envelope,
        key: kek,
        aad: _recoveryAad(firebaseUid),
      );
      if (clear.length != MeraMarkazCrypto.keyLengthBytes) {
        throw const FormatException('Invalid recovered encryption key.');
      }
      final alias = 'mm_${encodeBytes(_crypto.randomBytes(18))}';
      deviceWrapped = await _deviceKeyStore.wrap(
        alias: alias,
        plaintext: clear,
        aad: _deviceAad(firebaseUid, alias),
      );
      await _persist(firebaseUid, deviceWrapped, recoveryWrappedKey);
      await confirmEnrollment(firebaseUid);
    } catch (_) {
      if (deviceWrapped != null) {
        await _deviceKeyStore.delete(deviceWrapped.alias);
      }
      rethrow;
    } finally {
      if (clear != null) _wipe(clear);
      _wipe(secret);
    }
  }

  Future<bool> hasEnrollment(String firebaseUid) async {
    final stored = (await _preferences()).getString(
      await _storageKey(firebaseUid),
    );
    return stored != null;
  }

  Future<RecoveryWrappedKey> recoveryWrappedKey(String firebaseUid) async {
    if (!await isConfirmed(firebaseUid)) {
      throw StateError('Encryption enrollment has not been confirmed.');
    }
    return (await _read(firebaseUid)).$2;
  }

  Future<bool> isConfirmed(String firebaseUid) async {
    _validateUid(firebaseUid);
    final value = (await _preferences()).getString(
      await _storageKey(firebaseUid),
    );
    if (value == null) return false;
    final document = jsonDecode(value);
    return document is Map && document['confirmed'] == true;
  }

  Future<void> confirmEnrollment(String firebaseUid) async {
    _validateUid(firebaseUid);
    final preferences = await _preferences();
    final key = await _storageKey(firebaseUid);
    final value = preferences.getString(key);
    if (value == null) throw StateError('No encryption enrollment exists.');
    final document = jsonDecode(value);
    if (document is! Map || document['version'] != 1) {
      throw const FormatException('Unsupported encryption enrollment.');
    }
    final updated = Map<String, Object?>.from(document)..['confirmed'] = true;
    await preferences.setString(key, jsonEncode(updated));
  }

  Future<void> removeLocalEnrollment(String firebaseUid) async {
    final metadata = await _read(firebaseUid);
    await _deviceKeyStore.delete(metadata.$1.alias);
    await (await _preferences()).remove(await _storageKey(firebaseUid));
  }

  Future<void> _persist(
    String uid,
    DeviceWrappedKey device,
    RecoveryWrappedKey recovery,
  ) async {
    final value = jsonEncode({
      'version': 1,
      'confirmed': false,
      'device': device.toJson(),
      'recovery': recovery.toJson(),
    });
    await (await _preferences()).setString(await _storageKey(uid), value);
  }

  Future<(DeviceWrappedKey, RecoveryWrappedKey)> _read(String uid) async {
    _validateUid(uid);
    final value = (await _preferences()).getString(await _storageKey(uid));
    if (value == null) throw StateError('No encryption enrollment exists.');
    final json = jsonDecode(value);
    if (json is! Map || json['version'] != 1) {
      throw const FormatException('Unsupported encryption enrollment.');
    }
    return (
      DeviceWrappedKey.fromJson(
        Map<String, Object?>.from(json['device'] as Map),
      ),
      RecoveryWrappedKey.fromJson(
        Map<String, Object?>.from(json['recovery'] as Map),
      ),
    );
  }

  Future<String> _storageKey(String uid) async {
    final digest = await Sha256().hash(utf8.encode(uid));
    return '$_metadataPrefix${encodeBytes(digest.bytes)}';
  }

  Uint8List _deviceAad(String uid, String alias) =>
      Uint8List.fromList(utf8.encode('device-wrap|v1|$uid|$alias'));

  Uint8List _recoveryAad(String uid) =>
      Uint8List.fromList(utf8.encode('recovery-wrap|v1|$uid'));

  void _validateUid(String uid) {
    if (uid.isEmpty || uid.startsWith('guest:')) {
      throw ArgumentError('Encryption enrollment requires a Firebase user.');
    }
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  static void _wipe(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);
}
