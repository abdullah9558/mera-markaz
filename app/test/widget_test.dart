import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/app.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/analytics/domain/financial_analytics.dart';
import 'package:pakpocket/features/home/presentation/dashboard_provider.dart';
import 'package:pakpocket/features/home/data/dashboard_layout_repository.dart';
import 'package:pakpocket/features/intelligence/data/intelligence_provider.dart';
import 'package:pakpocket/features/intelligence/domain/financial_intelligence.dart';
import 'package:pakpocket/features/udhaar/domain/ledger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'offline_guest_session': true});
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
  });

  tearDown(() => database.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          androidHomeBackgroundSyncProvider.overrideWithValue(false),
          homeDashboardProvider.overrideWith(
            (ref) async => HomeDashboardData(
              finance: FinancialPeriodSummary(
                start: DateTime(2026, 8),
                end: DateTime(2026, 9),
                income: 0,
                expenses: 0,
                previousIncome: 0,
                previousExpenses: 0,
              ),
              ledger: const LedgerSummary(toReceive: 0, toPay: 0),
              budget: null,
              categories: const [],
              recentTransactions: const [],
            ),
          ),
          dashboardLayoutProvider.overrideWith(
            (ref) async => [
              for (
                var index = 0;
                index < DashboardSection.values.length;
                index++
              )
                DashboardSectionPreference(
                  section: DashboardSection.values[index],
                  position: index,
                  visible: true,
                ),
            ],
          ),
          financialInsightsProvider.overrideWith((ref) async => const []),
          markazScoreProvider.overrideWith(
            (ref) async =>
                const MarkazScore(value: 0, factors: [], improvements: []),
          ),
        ],
        child: const PakPocketApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home remains useful with no financial records', (tester) async {
    await pumpApp(tester);
    expect(find.text('Assalam-o-Alaikum'), findsOneWidget);
    expect(find.text('Rs. 0'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Quick actions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quick actions'), findsOneWidget);
  });

  testWidgets('Urdu setting switches direction to RTL', (tester) async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'ur',
      'offline_guest_session': true,
    });
    await pumpApp(tester);
    expect(find.text('السلام علیکم'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('السلام علیکم'))),
      TextDirection.rtl,
    );
  });

  testWidgets('salary tax quick action performs a calculation', (tester) async {
    await pumpApp(tester);
    await tester.scrollUntilVisible(
      find.text('Calculate Tax'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.ancestor(
        of: find.text('Calculate Tax'),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.first, '100000');
    for (var index = 0; index < 4; index++) {
      await tester.drag(find.byType(ListView), const Offset(0, -450));
      await tester.pumpAndSettle();
      if (find
          .widgetWithText(FilledButton, 'Calculate')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    final calculateButton = find.widgetWithText(FilledButton, 'Calculate');
    await tester.ensureVisible(calculateButton);
    await tester.pumpAndSettle();
    await tester.tap(calculateButton);
    await tester.pumpAndSettle();
    expect(find.text('Estimated tax'), findsOneWidget);
    expect(find.text('Rs. 6,000'), findsWidgets);
  });

  testWidgets('global search opens from the dashboard', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Search your local records'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('session gate allows explicit offline session', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    expect(find.text('Continue with Email'), findsOneWidget);
    final offlineButton = find.text('Continue as Guest');
    await tester.ensureVisible(offlineButton);
    await tester.tap(offlineButton);
    await tester.pumpAndSettle();
    expect(find.text('Assalam-o-Alaikum'), findsOneWidget);
  });

  testWidgets('authentication screen is localized in Urdu', (tester) async {
    SharedPreferences.setMockInitialValues({'language_code': 'ur'});
    await pumpApp(tester);
    expect(find.text('ای میل کے ساتھ جاری رکھیں'), findsOneWidget);
    expect(find.text('گوگل کے ساتھ جاری رکھیں'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('ای میل کے ساتھ جاری رکھیں'))),
      TextDirection.rtl,
    );
  });
}
