import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/localization/app_localizations.dart';
import 'package:pakpocket/features/settings/presentation/notifications_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const NotificationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('alert settings expose private defaults and quiet hours', (
    tester,
  ) async {
    await pump(tester, const Locale('en'));
    expect(find.text('Notification privacy'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
    expect(find.text('Quiet hours'), findsOneWidget);
    expect(find.text('Budget thresholds'), findsOneWidget);
  });

  testWidgets('alert settings render in Urdu RTL', (tester) async {
    await pump(tester, const Locale('ur'));
    final title = find.text('اطلاعات کی رازداری');
    expect(title, findsOneWidget);
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
  });
}
