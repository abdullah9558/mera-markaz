import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/security/crypto/android_keystore.dart';
import 'package:pakpocket/core/security/crypto/crypto_envelope.dart';
import 'package:pakpocket/core/security/crypto/key_enrollment_service.dart';
import 'package:pakpocket/core/security/crypto/mera_markaz_crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('enrollment supports device unlock and recovery', () async {
    final service = KeyEnrollmentService(
      deviceKeyStore: MemoryDeviceKeyStore(),
    );
    final result = await service.enroll('firebase-user-1');
    expect(await service.isConfirmed('firebase-user-1'), isFalse);
    await service.confirmEnrollment('firebase-user-1');
    expect(await service.isConfirmed('firebase-user-1'), isTrue);

    final deviceKey = await service.unlockWithDevice('firebase-user-1');
    final recoveredKey = await service.recover(
      'firebase-user-1',
      result.recoveryKey,
    );
    expect(
      await deviceKey.extractBytes(),
      equals(await recoveredKey.extractBytes()),
    );

    final stored = (await SharedPreferences.getInstance()).getKeys().map(
      (key) => (SharedPreferences.getInstance()).then((p) => p.getString(key)),
    );
    final values = await Future.wait(stored);
    expect(
      values.whereType<String>().join(),
      isNot(contains(result.recoveryKey)),
    );
  });

  test('wrong recovery key fails without changing enrollment', () async {
    final service = KeyEnrollmentService(
      deviceKeyStore: MemoryDeviceKeyStore(),
    );
    final result = await service.enroll('firebase-user-2');
    await service.confirmEnrollment('firebase-user-2');
    final decoded = decodeBytes(result.recoveryKey)..[0] ^= 1;

    await expectLater(
      service.recover('firebase-user-2', encodeBytes(decoded)),
      throwsFormatException,
    );
    expect(await service.hasEnrollment('firebase-user-2'), isTrue);
  });

  test('recovery envelope enrolls a replacement device', () async {
    final firstStore = MemoryDeviceKeyStore();
    final first = KeyEnrollmentService(deviceKeyStore: firstStore);
    final result = await first.enroll('firebase-user-recovery');
    await first.confirmEnrollment('firebase-user-recovery');
    final original = await first.unlockWithDevice('firebase-user-recovery');
    final originalBytes = await original.extractBytes();
    await first.removeLocalEnrollment('firebase-user-recovery');

    final replacement = KeyEnrollmentService(
      deviceKeyStore: MemoryDeviceKeyStore(),
    );
    await replacement.recoverAndEnrollDevice(
      'firebase-user-recovery',
      result.recoveryKey,
      result.recoveryWrappedKey,
    );
    expect(await replacement.isConfirmed('firebase-user-recovery'), isTrue);
    final restored = await replacement.unlockWithDevice(
      'firebase-user-recovery',
    );
    expect(await restored.extractBytes(), originalBytes);
  });

  test(
    'enrollment rejects guest identities and duplicate enrollment',
    () async {
      final service = KeyEnrollmentService(
        deviceKeyStore: MemoryDeviceKeyStore(),
      );
      await expectLater(service.enroll('guest:temporary'), throwsArgumentError);
      await service.enroll('firebase-user-3');
      await expectLater(service.enroll('firebase-user-3'), throwsStateError);
    },
  );
}

class MemoryDeviceKeyStore implements DeviceKeyStore {
  final _crypto = MeraMarkazCrypto();
  final Map<String, SecretKeyData> _keys = {};

  @override
  Future<DeviceWrappedKey> wrap({
    required String alias,
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    final key = await _crypto.generateUserMasterKey();
    _keys[alias] = key;
    return DeviceWrappedKey(
      alias: alias,
      envelope: await _crypto.encrypt(plaintext: plaintext, key: key, aad: aad),
    );
  }

  @override
  Future<Uint8List> unwrap({
    required DeviceWrappedKey wrappedKey,
    required Uint8List aad,
  }) async {
    final key = _keys[wrappedKey.alias];
    if (key == null) throw StateError('Key unavailable');
    return _crypto.decrypt(envelope: wrappedKey.envelope, key: key, aad: aad);
  }

  @override
  Future<bool> contains(String alias) async => _keys.containsKey(alias);

  @override
  Future<void> delete(String alias) async {
    _keys.remove(alias)?.destroy();
  }
}
