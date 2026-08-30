import 'package:flutter/material.dart';

class UserSettings {
  const UserSettings({
    this.languageCode = 'en',
    this.themeMode = ThemeMode.system,
    this.currencyCode = 'PKR',
    this.defaultProvider = 'IESCO',
    this.marlaSquareFeet = 272.25,
    this.taxYear = '2026-27',
    this.notificationsEnabled = true,
  });
  final String languageCode;
  final ThemeMode themeMode;
  final String currencyCode;
  final String defaultProvider;
  final double marlaSquareFeet;
  final String taxYear;
  final bool notificationsEnabled;

  UserSettings copyWith({
    String? languageCode,
    ThemeMode? themeMode,
    double? marlaSquareFeet,
    String? taxYear,
  }) => UserSettings(
    languageCode: languageCode ?? this.languageCode,
    themeMode: themeMode ?? this.themeMode,
    currencyCode: currencyCode,
    defaultProvider: defaultProvider,
    marlaSquareFeet: marlaSquareFeet ?? this.marlaSquareFeet,
    taxYear: taxYear ?? this.taxYear,
    notificationsEnabled: notificationsEnabled,
  );
}
