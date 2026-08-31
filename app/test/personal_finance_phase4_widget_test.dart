import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/core/localization/app_localizations.dart';
import 'package:pakpocket/features/personal_finance/presentation/personal_finance_center_screen.dart';
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
    await database.startGuestSession('phase-four-widget');
  });
  tearDown(() => database.close());

  Widget app() => ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
    child: const MaterialApp(
      locale: Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: PersonalFinanceCenterScreen(),
    ),
  );

  testWidgets('all Phase 4 sections and bill form are reachable', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Freelancer'), findsOneWidget);
    expect(find.text('Bills'), findsOneWidget);
    expect(find.text('Emergency Fund'), findsOneWidget);

    await tester.tap(find.text('Bills'));
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Add bill'), findsOneWidget);
    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('Due date'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
