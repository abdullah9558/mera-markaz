import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/core/localization/app_localizations.dart';
import 'package:pakpocket/features/electricity/presentation/energy_intelligence_screen.dart';
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
    await database.startGuestSession('phase-five-widget');
  });
  tearDown(() => database.close());

  Widget app({Locale locale = const Locale('en')}) => ProviderScope(
    overrides: [appDatabaseProvider.overrideWithValue(database)],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const EnergyIntelligenceScreen(),
    ),
  );

  testWidgets('all Phase 5 sections and entry forms are reachable', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Usage history'), findsOneWidget);
    expect(find.text('Appliances'), findsOneWidget);
    expect(find.text('Solar planner'), findsOneWidget);
    expect(find.text('Solar ROI'), findsOneWidget);

    await tester.tap(find.text('Add reading'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Add electricity reading'), findsOneWidget);
    expect(find.text('Actual bill'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Appliances'));
    await tester.pump();
    await tester.tap(find.text('Add appliance'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Add appliance scenario'), findsOneWidget);
    expect(find.text('Wattage'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Solar ROI'));
    await tester.pump();
    await tester.tap(find.text('Add solar system'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('System size (kW)'), findsOneWidget);
    expect(find.text('Installation cost'), findsOneWidget);
  });

  testWidgets('Phase 5 navigation labels are localized in Urdu', (
    tester,
  ) async {
    await tester.pumpWidget(app(locale: const Locale('ur')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('توانائی کی ذہانت'), findsOneWidget);
    expect(find.text('استعمال کی تاریخ'), findsOneWidget);
    expect(find.text('برقی آلات'), findsOneWidget);
    expect(find.text('سولر منصوبہ ساز'), findsOneWidget);
    expect(find.text('سولر سرمایہ واپسی'), findsOneWidget);
  });
}
