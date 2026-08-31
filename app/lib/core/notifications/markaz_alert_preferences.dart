import 'package:shared_preferences/shared_preferences.dart';

import 'notification_policy.dart';

class MarkazAlertPreferences {
  const MarkazAlertPreferences();

  static String _enabledKey(MarkazAlertCategory category) =>
      'markaz_alert_enabled_${category.name}';
  static const _privacyKey = 'markaz_alert_privacy';
  static const _quietEnabledKey = 'markaz_alert_quiet_enabled';
  static const _quietStartKey = 'markaz_alert_quiet_start';
  static const _quietEndKey = 'markaz_alert_quiet_end';

  Future<bool> enabled(MarkazAlertCategory category) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey(category)) ??
        category == MarkazAlertCategory.security;
  }

  Future<void> setEnabled(MarkazAlertCategory category, bool value) async =>
      (await SharedPreferences.getInstance()).setBool(
        _enabledKey(category),
        value,
      );

  Future<Map<MarkazAlertCategory, bool>> all() async => {
    for (final category in MarkazAlertCategory.values)
      category: await enabled(category),
  };

  Future<NotificationPrivacy> privacy() async {
    final value = (await SharedPreferences.getInstance()).getString(
      _privacyKey,
    );
    return NotificationPrivacy.values.firstWhere(
      (item) => item.name == value,
      orElse: () => NotificationPrivacy.private,
    );
  }

  Future<void> setPrivacy(NotificationPrivacy value) async =>
      (await SharedPreferences.getInstance()).setString(
        _privacyKey,
        value.name,
      );

  Future<QuietHours> quietHours() async {
    final preferences = await SharedPreferences.getInstance();
    return QuietHours(
      enabled: preferences.getBool(_quietEnabledKey) ?? true,
      startMinute: preferences.getInt(_quietStartKey) ?? 22 * 60,
      endMinute: preferences.getInt(_quietEndKey) ?? 8 * 60,
    );
  }

  Future<void> setQuietHours(QuietHours value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_quietEnabledKey, value.enabled);
    await preferences.setInt(_quietStartKey, value.startMinute);
    await preferences.setInt(_quietEndKey, value.endMinute);
  }
}
