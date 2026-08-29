import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/security/crypto/automatic_local_key_service.dart';
import 'package:pakpocket/core/security/crypto/crypto_envelope.dart';
import 'package:pakpocket/core/security/crypto/encrypted_file_service.dart';
import 'package:pakpocket/core/security/crypto/mera_markaz_crypto.dart';

void main() {
  test('encrypted files contain no recognizable plaintext', () async {
    final directory = await Directory.systemTemp.createTemp('mm-encrypted-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/receipt.mmr');
    final service = EncryptedFileService(
      localKeys: FixedLocalKeyService(encodeBytes(List<int>.filled(32, 1))),
    );
    const sensitive = 'Merchant ABC amount 987654 phone 03001234567';
    await service.encryptBytesToFile(
      bytes: sensitive.codeUnits,
      destination: file,
      purpose: 'blob',
    );
    expect(await file.readAsString(), isNot(contains('Merchant ABC')));
    expect(
      String.fromCharCodes(await service.decryptFile(file, purpose: 'blob')),
      sensitive,
    );
  });

  test('tampered encrypted file and wrong installation key fail', () async {
    final directory = await Directory.systemTemp.createTemp('mm-tamper-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/backup.mmb');
    final correct = EncryptedFileService(
      localKeys: FixedLocalKeyService(encodeBytes(List<int>.filled(32, 1))),
    );
    await correct.encryptBytesToFile(
      bytes: [1, 2, 3, 4],
      destination: file,
      purpose: 'backup',
    );
    final wrong = EncryptedFileService(
      localKeys: FixedLocalKeyService(encodeBytes(List<int>.filled(32, 2))),
    );
    await expectLater(
      wrong.decryptFile(file, purpose: 'backup'),
      throwsA(isA<CryptoAuthenticationException>()),
    );
    final text = await file.readAsString();
    await file.writeAsString(
      text.replaceFirst('ciphertext":"', 'ciphertext":"A'),
    );
    await expectLater(
      correct.decryptFile(file, purpose: 'backup'),
      throwsA(
        anyOf(isA<CryptoAuthenticationException>(), isA<FormatException>()),
      ),
    );
  });
}

class FixedLocalKeyService extends AutomaticLocalKeyService {
  FixedLocalKeyService(this.value);
  final String value;

  @override
  Future<String> databasePassword() async => value;
}
