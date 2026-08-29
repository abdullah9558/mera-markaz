import 'dart:convert';
import 'dart:typed_data';

String encodeBytes(List<int> value) =>
    base64UrlEncode(value).replaceAll('=', '');

Uint8List decodeBytes(String value) {
  final normalized = value.padRight((value.length + 3) ~/ 4 * 4, '=');
  return Uint8List.fromList(base64Url.decode(normalized));
}

class CryptoEnvelope {
  const CryptoEnvelope({
    required this.algorithm,
    required this.schemaVersion,
    required this.keyVersion,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  static const currentAlgorithm = 'AES-256-GCM';
  static const currentSchemaVersion = 1;

  final String algorithm;
  final int schemaVersion;
  final int keyVersion;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List mac;

  Map<String, Object> toJson() => {
    'algorithm': algorithm,
    'schemaVersion': schemaVersion,
    'keyVersion': keyVersion,
    'nonce': encodeBytes(nonce),
    'ciphertext': encodeBytes(ciphertext),
    'tag': encodeBytes(mac),
  };

  factory CryptoEnvelope.fromJson(Map<String, Object?> json) {
    final algorithm = json['algorithm'];
    final schemaVersion = json['schemaVersion'];
    final keyVersion = json['keyVersion'];
    final nonce = json['nonce'];
    final ciphertext = json['ciphertext'];
    final tag = json['tag'];
    if (algorithm is! String ||
        schemaVersion is! int ||
        keyVersion is! int ||
        nonce is! String ||
        ciphertext is! String ||
        tag is! String) {
      throw const FormatException('Invalid cryptographic envelope.');
    }
    return CryptoEnvelope(
      algorithm: algorithm,
      schemaVersion: schemaVersion,
      keyVersion: keyVersion,
      nonce: decodeBytes(nonce),
      ciphertext: decodeBytes(ciphertext),
      mac: decodeBytes(tag),
    );
  }
}

class DeviceWrappedKey {
  const DeviceWrappedKey({required this.alias, required this.envelope});

  final String alias;
  final CryptoEnvelope envelope;

  Map<String, Object> toJson() => {
    'alias': alias,
    'envelope': envelope.toJson(),
  };

  factory DeviceWrappedKey.fromJson(Map<String, Object?> json) {
    final alias = json['alias'];
    final envelope = json['envelope'];
    if (alias is! String || envelope is! Map) {
      throw const FormatException('Invalid device-wrapped key.');
    }
    return DeviceWrappedKey(
      alias: alias,
      envelope: CryptoEnvelope.fromJson(Map<String, Object?>.from(envelope)),
    );
  }
}

class RecoveryWrappedKey {
  const RecoveryWrappedKey({
    required this.kdf,
    required this.salt,
    required this.envelope,
  });

  final String kdf;
  final Uint8List salt;
  final CryptoEnvelope envelope;

  Map<String, Object> toJson() => {
    'kdf': kdf,
    'salt': encodeBytes(salt),
    'envelope': envelope.toJson(),
  };

  factory RecoveryWrappedKey.fromJson(Map<String, Object?> json) {
    final kdf = json['kdf'];
    final salt = json['salt'];
    final envelope = json['envelope'];
    if (kdf is! String || salt is! String || envelope is! Map) {
      throw const FormatException('Invalid recovery-wrapped key.');
    }
    return RecoveryWrappedKey(
      kdf: kdf,
      salt: decodeBytes(salt),
      envelope: CryptoEnvelope.fromJson(Map<String, Object?>.from(envelope)),
    );
  }
}
