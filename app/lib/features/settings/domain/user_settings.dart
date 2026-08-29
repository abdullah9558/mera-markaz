import 'package:flutter/material.dart';

class UserSettings {
  const UserSettings({
    this.languageCode = 'en',
    this.themeMode = ThemeMode.system,
    this.currencyCode = 'PKR',
    this.defaultProvider = 'IESCO',
    this.marlaSquareFeet = 272.25,
    this.taxYear = '2025-26',
    this.notificationsEnabled = true,
  });
  final String languageCode;
  final ThemeMode themeMode;
  final String currencyCode;
  final String defaultProvider;
  final double marlaSquareFeet;
  final String taxYear;
  final bool notificationsEnabled;

  UserSettings copyWith({String? languageCode, ThemeMode? themeMode}) =>
      UserSettings(
        languageCode: languageCode ?? this.languageCode,
        themeMode: themeMode ?? this.themeMode,
        currencyCode: currencyCode,
        defaultProvider: defaultProvider,
        marlaSquareFeet: marlaSquareFeet,
        taxYear: taxYear,
        notificationsEnabled: notificationsEnabled,
      );
}
