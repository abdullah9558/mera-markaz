import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/user_settings.dart';

final settingsControllerProvider =
    NotifierProvider<SettingsController, UserSettings>(SettingsController.new);

class SettingsController extends Notifier<UserSettings> {
  static const _languageKey = 'language_code';
  static const _themeKey = 'theme_mode';
  @override
  UserSettings build() {
    _load();
    return UserSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    var theme = ThemeMode.system;
    for (final value in ThemeMode.values) {
      if (value.name == savedTheme) theme = value;
    }
    state = state.copyWith(
      languageCode: prefs.getString(_languageKey) ?? 'en',
      themeMode: theme,
    );
  }

  Future<void> setLanguage(String code) async {
    state = state.copyWith(languageCode: code);
    await (await SharedPreferences.getInstance()).setString(_languageKey, code);
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await (await SharedPreferences.getInstance()).setString(
      _themeKey,
      mode.name,
    );
  }
}
