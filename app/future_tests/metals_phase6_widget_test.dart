import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/core/localization/app_localizations.dart';
import 'package:pakpocket/features/metals/presentation/gold_zakat_center_screen.dart';
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
    await database.startGuestSession('phase-six-widget');
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
      home: const GoldZakatCenterScreen(),
    ),
  );

  testWidgets('Phase 6 tabs and holding form are reachable', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('My holdings'), findsOneWidget);
    expect(find.text('Zakat history'), findsOneWidget);

    await tester.tap(find.text('My holdings'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Add metal holding'), findsOneWidget);
    expect(find.text('Purchase price (optional)'), findsOneWidget);
    expect(find.text('Purity'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Zakat history'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(() async {
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Annual Zakat calculation'), findsOneWidget);
    expect(find.text('Linked gold holdings'), findsOneWidget);
    expect(find.text('Eligible liabilities'), findsOneWidget);
  });

  testWidgets('Phase 6 primary navigation is localized in Urdu', (
    tester,
  ) async {
    await tester.pumpWidget(app(locale: const Locale('ur')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('سونا، چاندی اور زکوٰۃ مرکز'), findsOneWidget);
    expect(find.text('مارکیٹ'), findsOneWidget);
    expect(find.text('میرے ذخائر'), findsOneWidget);
    expect(find.text('زکوٰۃ کی تاریخ'), findsOneWidget);
  });
}
