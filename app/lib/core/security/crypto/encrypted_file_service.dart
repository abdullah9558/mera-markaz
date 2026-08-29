import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'automatic_local_key_service.dart';
import 'crypto_envelope.dart';
import 'mera_markaz_crypto.dart';

class EncryptedFileService {
  EncryptedFileService({
    AutomaticLocalKeyService? localKeys,
    MeraMarkazCrypto? crypto,
  }) : _localKeys = localKeys ?? AutomaticLocalKeyService(),
       _crypto = crypto ?? MeraMarkazCrypto();

  final AutomaticLocalKeyService _localKeys;
  final MeraMarkazCrypto _crypto;

  Future<void> encryptBytesToFile({
    required List<int> bytes,
    required File destination,
    required String purpose,
  }) async {
    final key = await _purposeKey(purpose);
    await _encrypt(bytes, destination, purpose, key);
  }

  Future<void> encryptBytesWithMasterKey({
    required List<int> bytes,
    required File destination,
    required String purpose,
    required SecretKey masterKey,
  }) async {
    final key = await _crypto.derivePurposeKey(
      masterKey: masterKey,
      purpose: purpose,
    );
    await _encrypt(bytes, destination, purpose, key);
  }

  Future<void> _encrypt(
    List<int> bytes,
    File destination,
    String purpose,
    SecretKey key,
  ) async {
    final aad = utf8.encode('encrypted-file|v1|$purpose');
    final envelope = await _crypto.encrypt(
      plaintext: bytes,
      key: key,
      aad: aad,
    );
    await destination.parent.create(recursive: true);
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(jsonEncode(envelope.toJson()), flush: true);
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destination.path);
  }

  Future<Uint8List> decryptFile(File file, {required String purpose}) async {
    return _decrypt(file, purpose, await _purposeKey(purpose));
  }

  Future<Uint8List> decryptFileWithMasterKey(
    File file, {
    required String purpose,
    required SecretKey masterKey,
  }) async {
    final key = await _crypto.derivePurposeKey(
      masterKey: masterKey,
      purpose: purpose,
    );
    return _decrypt(file, purpose, key);
  }

  Future<Uint8List> _decrypt(File file, String purpose, SecretKey key) async {
    final document = jsonDecode(await file.readAsString());
    if (document is! Map) {
      throw const FormatException('Invalid encrypted file.');
    }
    final envelope = CryptoEnvelope.fromJson(
      Map<String, Object?>.from(document),
    );
    return _crypto.decrypt(
      envelope: envelope,
      key: key,
      aad: utf8.encode('encrypted-file|v1|$purpose'),
    );
  }

  Future<SecretKeyData> _purposeKey(String purpose) async {
    final password = await _localKeys.databasePassword();
    final master = Uint8List.fromList(decodeBytes(password));
    try {
      return await _crypto.derivePurposeKey(
        masterKey: SecretKey(master),
        purpose: purpose,
      );
    } finally {
      master.fillRange(0, master.length, 0);
    }
  }
}
