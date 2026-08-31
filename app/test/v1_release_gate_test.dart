import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/config/release_config.dart';

void main() {
  test('V1 exposes only the approved calculator set', () {
    expect(ReleaseConfig.isPlayStoreV1, isTrue);
    expect(
      ReleaseConfig.enabledTools,
      equals({'tax', 'electricity', 'fuel', 'zakat'}),
    );
  });

  test('V1 Android manifest requests only essential permissions', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.USE_BIOMETRIC'));
    for (final excluded in [
      'POST_NOTIFICATIONS',
      'RECEIVE_BOOT_COMPLETED',
      'CAMERA',
      'RECORD_AUDIO',
      'APPWIDGET_UPDATE',
    ]) {
      expect(manifest, isNot(contains(excluded)));
    }
  });

  test('V1 router has no future-feature destinations', () {
    final router = File('lib/core/router/app_router.dart').readAsStringSync();
    for (final route in [
      '/markaz-ai',
      '/pakistan-live',
      '/watchlists',
      '/advanced',
      '/recurring',
      '/widget-settings',
      '/notifications',
    ]) {
      expect(router, isNot(contains(route)));
    }
  });
}
