import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'android_keystore.dart';
import 'crypto_envelope.dart';
import 'mera_markaz_crypto.dart';

class AutomaticLocalKeyService {
  AutomaticLocalKeyService({
    DeviceKeyStore? deviceKeyStore,
    MeraMarkazCrypto? crypto,
    Future<SharedPreferences> Function()? preferences,
  }) : _deviceKeyStore = deviceKeyStore ?? const AndroidDeviceKeyStore(),
       _crypto = crypto ?? MeraMarkazCrypto(),
       _preferences = preferences ?? SharedPreferences.getInstance;

  static const _metadataKey = 'automatic_local_database_key_v1';
  static final _aad = Uint8List.fromList(
    utf8.encode('pk.pakpocket.pakpocket|local-database-key|v1'),
  );

  final DeviceKeyStore _deviceKeyStore;
  final MeraMarkazCrypto _crypto;
  final Future<SharedPreferences> Function() _preferences;

  Future<String> databasePassword() async {
    final preferences = await _preferences();
    final stored = preferences.getString(_metadataKey);
    if (stored != null) {
      final document = jsonDecode(stored);
      if (document is! Map || document['version'] != 1) {
        throw const FormatException('Unsupported local encryption metadata.');
      }
      final wrapped = DeviceWrappedKey.fromJson(
        Map<String, Object?>.from(document['wrappedKey'] as Map),
      );
      final key = Uint8List.fromList(
        await _deviceKeyStore.unwrap(wrappedKey: wrapped, aad: _aad),
      );
      if (key.length != MeraMarkazCrypto.keyLengthBytes) {
        _wipe(key);
        throw const FormatException('Invalid local database key.');
      }
      try {
        return encodeBytes(key);
      } finally {
        _wipe(key);
      }
    }

    final key = Uint8List.fromList(
      SecretKeyData.random(length: MeraMarkazCrypto.keyLengthBytes).bytes,
    );
    final alias = 'mm_${encodeBytes(_crypto.randomBytes(18))}';
    DeviceWrappedKey? wrapped;
    try {
      wrapped = await _deviceKeyStore.wrap(
        alias: alias,
        plaintext: key,
        aad: _aad,
      );
      await preferences.setString(
        _metadataKey,
        jsonEncode({'version': 1, 'wrappedKey': wrapped.toJson()}),
      );
      return encodeBytes(key);
    } catch (_) {
      if (wrapped != null) await _deviceKeyStore.delete(alias);
      rethrow;
    } finally {
      _wipe(key);
    }
  }

  static void _wipe(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);
}
