import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/notifications/notification_policy.dart';
import 'package:pakpocket/core/notifications/markaz_alert_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const policy = NotificationPolicy();
  const quiet = QuietHours();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'notification privacy defaults private and security defaults enabled',
    () async {
      const preferences = MarkazAlertPreferences();
      expect(await preferences.privacy(), NotificationPrivacy.private);
      expect(await preferences.enabled(MarkazAlertCategory.security), isTrue);
      expect(await preferences.enabled(MarkazAlertCategory.currency), isFalse);
    },
  );

  test('threshold alert fires only when the value crosses the boundary', () {
    final first = policy.thresholdCrossing(
      category: MarkazAlertCategory.budget,
      subjectId: 'fuel',
      previousValue: 79,
      currentValue: 80,
      threshold: 80,
      triggersAbove: true,
      now: DateTime(2026, 8, 31, 12),
      quietHours: quiet,
    );
    final stillAbove = policy.thresholdCrossing(
      category: MarkazAlertCategory.budget,
      subjectId: 'fuel',
      previousValue: 80,
      currentValue: 91,
      threshold: 80,
      triggersAbove: true,
      now: DateTime(2026, 8, 31, 13),
      quietHours: quiet,
    );
    expect(first.shouldNotify, isTrue);
    expect(stillAbove.shouldNotify, isFalse);
  });

  test('ordinary alerts wait until quiet hours end', () {
    final result = policy.thresholdCrossing(
      category: MarkazAlertCategory.currency,
      subjectId: 'usd_pkr',
      previousValue: 279,
      currentValue: 281,
      threshold: 280,
      triggersAbove: true,
      now: DateTime(2026, 8, 31, 23, 30),
      quietHours: quiet,
    );
    expect(result.shouldNotify, isTrue);
    expect(result.deliverAt, DateTime(2026, 9, 1, 8));
  });

  test('security alerts are not delayed by ordinary quiet hours', () {
    final result = policy.thresholdCrossing(
      category: MarkazAlertCategory.security,
      subjectId: 'new-device',
      previousValue: 0,
      currentValue: 1,
      threshold: 1,
      triggersAbove: true,
      now: DateTime(2026, 8, 31, 23, 30),
      quietHours: quiet,
      securityCritical: true,
    );
    expect(result.deliverAt, DateTime(2026, 8, 31, 23, 30));
  });

  test('private mode excludes sensitive notification detail', () {
    expect(
      policy.protectedBody(
        privacy: NotificationPrivacy.private,
        privateBody: 'One of your budgets needs attention.',
        detailedBody: 'You spent Rs. 92,000 from your Fuel budget.',
      ),
      'One of your budgets needs attention.',
    );
  });
}
