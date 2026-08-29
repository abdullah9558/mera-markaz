import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto_envelope.dart';

class CryptoAuthenticationException implements Exception {
  const CryptoAuthenticationException();

  @override
  String toString() => 'Encrypted data authentication failed.';
}

class MeraMarkazCrypto {
  MeraMarkazCrypto({AesGcm? aesGcm, Hkdf? hkdf})
    : _aesGcm = aesGcm ?? AesGcm.with256bits(),
      _hkdf = hkdf ?? Hkdf(hmac: Hmac.sha256(), outputLength: keyLengthBytes);

  static const keyLengthBytes = 32;
  static const nonceLengthBytes = 12;
  static const tagLengthBytes = 16;
  static const keyVersion = 1;
  static const _appDomain = 'pk.pakpocket.pakpocket';

  final AesGcm _aesGcm;
  final Hkdf _hkdf;

  Future<SecretKeyData> generateUserMasterKey() async =>
      SecretKeyData.random(length: keyLengthBytes);

  Future<SecretKeyData> derivePurposeKey({
    required SecretKey masterKey,
    required String purpose,
    List<int> salt = const [],
  }) {
    if (!_allowedPurposes.contains(purpose)) {
      throw ArgumentError.value(purpose, 'purpose', 'Unsupported key purpose');
    }
    return _hkdf.deriveKey(
      secretKey: masterKey,
      nonce: salt,
      info: utf8.encode('$_appDomain/$purpose/v1'),
    );
  }

  Future<CryptoEnvelope> encrypt({
    required List<int> plaintext,
    required SecretKey key,
    required List<int> aad,
    int keyVersion = keyVersion,
  }) async {
    final nonce = _aesGcm.newNonce();
    if (nonce.length != nonceLengthBytes) {
      throw StateError('The AES-GCM implementation returned an invalid nonce.');
    }
    final box = await _aesGcm.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
      aad: aad,
    );
    if (box.mac.bytes.length != tagLengthBytes) {
      throw StateError('The AES-GCM implementation returned an invalid tag.');
    }
    return CryptoEnvelope(
      algorithm: CryptoEnvelope.currentAlgorithm,
      schemaVersion: CryptoEnvelope.currentSchemaVersion,
      keyVersion: keyVersion,
      nonce: Uint8List.fromList(box.nonce),
      ciphertext: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
    );
  }

  Future<Uint8List> decrypt({
    required CryptoEnvelope envelope,
    required SecretKey key,
    required List<int> aad,
  }) async {
    _validateEnvelope(envelope);
    try {
      final cleartext = await _aesGcm.decrypt(
        SecretBox(
          envelope.ciphertext,
          nonce: envelope.nonce,
          mac: Mac(envelope.mac),
        ),
        secretKey: key,
        aad: aad,
      );
      return Uint8List.fromList(cleartext);
    } on SecretBoxAuthenticationError {
      throw const CryptoAuthenticationException();
    }
  }

  Uint8List randomBytes(int length) =>
      Uint8List.fromList(SecretKeyData.random(length: length).bytes);

  void _validateEnvelope(CryptoEnvelope envelope) {
    if (envelope.algorithm != CryptoEnvelope.currentAlgorithm ||
        envelope.schemaVersion != CryptoEnvelope.currentSchemaVersion ||
        envelope.keyVersion < 1 ||
        envelope.nonce.length != nonceLengthBytes ||
        envelope.mac.length != tagLengthBytes) {
      throw const FormatException('Unsupported or malformed encrypted data.');
    }
  }

  static const _allowedPurposes = {
    'local-db',
    'record',
    'blob',
    'backup',
    'index',
    'recovery-wrap',
  };
}

List<int> canonicalAad({
  required String ownerId,
  required String recordType,
  required String recordId,
  required int revision,
  int schemaVersion = 1,
  int keyVersion = 1,
}) => utf8.encode(
  'pk.pakpocket.pakpocket|$schemaVersion|$keyVersion|$ownerId|'
  '$recordType|$recordId|$revision',
);
