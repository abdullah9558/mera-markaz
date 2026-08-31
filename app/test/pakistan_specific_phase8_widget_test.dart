import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/core/localization/app_localizations.dart';
import 'package:pakpocket/features/pakistan_specific/presentation/pakistan_specific_center_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
    await database.startGuestSession('phase-eight-widget');
  });
  tearDown(() => database.close());

  testWidgets('Phase 8 center exposes all three feature areas', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: PakistanSpecificCenterScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Pakistan Money Center'), findsOneWidget);
    expect(find.text('Committee'), findsOneWidget);
    expect(find.text('Advanced Udhaar'), findsOneWidget);
    expect(find.text('Household'), findsOneWidget);
    expect(find.text('Committee'), findsOneWidget);
  });
}
