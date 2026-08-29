import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/security/crypto/crypto_envelope.dart';
import 'package:pakpocket/core/security/crypto/mera_markaz_crypto.dart';

void main() {
  final crypto = MeraMarkazCrypto();
  final aad = canonicalAad(
    ownerId: 'uid-1',
    recordType: 'transaction',
    recordId: '98ce4109-65d1-42d1-a61a-548f62251f64',
    revision: 7,
  );

  test('AES-256-GCM round trips and creates unique nonces', () async {
    final key = await crypto.generateUserMasterKey();
    final first = await crypto.encrypt(
      plaintext: utf8.encode('sensitive amount 1234'),
      key: key,
      aad: aad,
    );
    final second = await crypto.encrypt(
      plaintext: utf8.encode('sensitive amount 1234'),
      key: key,
      aad: aad,
    );
    expect(first.nonce, isNot(equals(second.nonce)));
    expect(
      utf8.decode(await crypto.decrypt(envelope: first, key: key, aad: aad)),
      'sensitive amount 1234',
    );
  });

  test('tampered ciphertext fails closed', () async {
    final key = await crypto.generateUserMasterKey();
    final envelope = await crypto.encrypt(
      plaintext: [1, 2, 3],
      key: key,
      aad: aad,
    );
    final changed = Uint8List.fromList(envelope.ciphertext)..[0] ^= 1;
    final tampered = CryptoEnvelope(
      algorithm: envelope.algorithm,
      schemaVersion: envelope.schemaVersion,
      keyVersion: envelope.keyVersion,
      nonce: envelope.nonce,
      ciphertext: changed,
      mac: envelope.mac,
    );
    expect(
      () => crypto.decrypt(envelope: tampered, key: key, aad: aad),
      throwsA(isA<CryptoAuthenticationException>()),
    );
  });

  test('wrong key and wrong AAD fail closed', () async {
    final key = await crypto.generateUserMasterKey();
    final wrongKey = await crypto.generateUserMasterKey();
    final envelope = await crypto.encrypt(
      plaintext: [1, 2, 3],
      key: key,
      aad: aad,
    );
    await expectLater(
      crypto.decrypt(envelope: envelope, key: wrongKey, aad: aad),
      throwsA(isA<CryptoAuthenticationException>()),
    );
    await expectLater(
      crypto.decrypt(
        envelope: envelope,
        key: key,
        aad: Uint8List.fromList([...aad, 0]),
      ),
      throwsA(isA<CryptoAuthenticationException>()),
    );
  });

  test('HKDF produces distinct purpose keys', () async {
    final master = await crypto.generateUserMasterKey();
    final record = await crypto.derivePurposeKey(
      masterKey: master,
      purpose: 'record',
    );
    final backup = await crypto.derivePurposeKey(
      masterKey: master,
      purpose: 'backup',
    );
    expect(
      await record.extractBytes(),
      isNot(equals(await backup.extractBytes())),
    );
  });

  test('malformed nonce is rejected before decryption', () async {
    final key = SecretKeyData.random(length: 32);
    final malformed = CryptoEnvelope(
      algorithm: CryptoEnvelope.currentAlgorithm,
      schemaVersion: 1,
      keyVersion: 1,
      nonce: Uint8List(11),
      ciphertext: Uint8List(1),
      mac: Uint8List(16),
    );
    expect(
      () => crypto.decrypt(envelope: malformed, key: key, aad: aad),
      throwsFormatException,
    );
  });
}
