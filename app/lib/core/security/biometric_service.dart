import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

final biometricServiceProvider = Provider((ref) => BiometricService());

class BiometricService {
  BiometricService({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  static const _keyPrefix = 'biometric_lock_v1_';
  final LocalAuthentication _authentication;

  Future<bool> isEnabled(String userId) async =>
      (await SharedPreferences.getInstance()).getBool('$_keyPrefix$userId') ??
      false;

  Future<void> setEnabled(String userId, bool enabled) async {
    await (await SharedPreferences.getInstance()).setBool(
      '$_keyPrefix$userId',
      enabled,
    );
  }

  Future<bool> isAvailable() async {
    try {
      final supported = await _authentication.isDeviceSupported();
      final enrolled = await _authentication.getAvailableBiometrics();
      return supported && enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _authentication.authenticate(
        localizedReason: 'Unlock Mera Markaz with your fingerprint',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
