import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/core/localization/app_localizations.dart';
import 'package:pakpocket/features/advanced_finance/presentation/advanced_finance_screen.dart';
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
    await database.startGuestSession('phase-seven-widget');
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
      home: const AdvancedFinanceScreen(),
    ),
  );

  testWidgets('financing and inflation calculations are interactive', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Financing'), findsOneWidget);
    expect(find.text('Inflation'), findsOneWidget);
    expect(find.text('Financial Health'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Financing amount'),
      '1000000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Down payment'),
      '200000',
    );
    await tester.ensureVisible(find.text('Calculate and save'));
    await tester.pump();
    await tester.runAsync(() async {
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Monthly installment'), findsOneWidget);

    await tester.tap(find.text('Inflation'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.widgetWithText(TextField, 'Current savings'),
      '500000',
    );
    await tester.ensureVisible(find.text('Calculate and save'));
    await tester.pump();
    await tester.runAsync(() async {
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Estimated purchasing power'), findsOneWidget);
  });

  testWidgets('Phase 7 primary navigation is localized in Urdu', (
    tester,
  ) async {
    await tester.pumpWidget(app(locale: const Locale('ur')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('اعلیٰ مالیاتی مرکز'), findsOneWidget);
    expect(find.text('فنانسنگ'), findsOneWidget);
    expect(find.text('مہنگائی'), findsOneWidget);
    expect(find.text('مالی صحت'), findsOneWidget);
  });
}
