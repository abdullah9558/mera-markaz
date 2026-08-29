import 'package:flutter/services.dart';

import 'crypto_envelope.dart';

abstract interface class DeviceKeyStore {
  Future<DeviceWrappedKey> wrap({
    required String alias,
    required Uint8List plaintext,
    required Uint8List aad,
  });

  Future<Uint8List> unwrap({
    required DeviceWrappedKey wrappedKey,
    required Uint8List aad,
  });

  Future<bool> contains(String alias);
  Future<void> delete(String alias);
}

class AndroidDeviceKeyStore implements DeviceKeyStore {
  const AndroidDeviceKeyStore({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'pk.pakpocket.pakpocket/security_key';
  final MethodChannel _channel;

  /// Debug/device validation only. Uses a temporary key alias and persists no data.
  Future<bool> runSelfTest() async =>
      await _channel.invokeMethod<bool>('runSelfTest') ?? false;

  @override
  Future<DeviceWrappedKey> wrap({
    required String alias,
    required Uint8List plaintext,
    required Uint8List aad,
  }) async {
    final result = await _channel.invokeMapMethod<String, Object?>('wrapKey', {
      'alias': alias,
      'plaintext': plaintext,
      'aad': aad,
    });
    if (result == null) throw StateError('Android Keystore returned no data.');
    return DeviceWrappedKey(
      alias: alias,
      envelope: CryptoEnvelope(
        algorithm: CryptoEnvelope.currentAlgorithm,
        schemaVersion: CryptoEnvelope.currentSchemaVersion,
        keyVersion: 1,
        nonce: _bytes(result['nonce']),
        ciphertext: _bytes(result['ciphertext']),
        mac: _bytes(result['tag']),
      ),
    );
  }

  @override
  Future<Uint8List> unwrap({
    required DeviceWrappedKey wrappedKey,
    required Uint8List aad,
  }) async {
    final envelope = wrappedKey.envelope;
    final result = await _channel.invokeMethod<Uint8List>('unwrapKey', {
      'alias': wrappedKey.alias,
      'nonce': envelope.nonce,
      'ciphertext': envelope.ciphertext,
      'tag': envelope.mac,
      'aad': aad,
    });
    if (result == null) throw StateError('Android Keystore returned no key.');
    return result;
  }

  @override
  Future<bool> contains(String alias) async =>
      await _channel.invokeMethod<bool>('containsKey', {'alias': alias}) ??
      false;

  @override
  Future<void> delete(String alias) =>
      _channel.invokeMethod<void>('deleteKey', {'alias': alias});

  static Uint8List _bytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List<int>) return Uint8List.fromList(value);
    throw const FormatException('Android Keystore returned malformed data.');
  }
}
