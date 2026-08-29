import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum NotificationType {
  udhaarDue,
  budgetThreshold,
  monthlySummary,
  zakatReminder,
  recurringExpense,
  electricityReminder,
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

class NotificationPreferences {
  static String key(NotificationType type) => 'notification_${type.name}';
  Future<bool> enabled(NotificationType type) async =>
      (await SharedPreferences.getInstance()).getBool(key(type)) ?? false;
  Future<void> setEnabled(NotificationType type, bool value) async =>
      (await SharedPreferences.getInstance()).setBool(key(type), value);
  Future<Map<NotificationType, bool>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final type in NotificationType.values)
        type: prefs.getBool(key(type)) ?? false,
    };
  }
}

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  bool initialized = false;
  Future<void> initialize() async {
    if (initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        true;
  }

  Future<void> scheduleUdhaarReminder({
    required int id,
    required String personName,
    required double amount,
    required DateTime dueDate,
  }) async {
    if (!await NotificationPreferences().enabled(NotificationType.udhaarDue)) {
      return;
    }
    await initialize();
    var scheduled = DateTime(dueDate.year, dueDate.month, dueDate.day, 9);
    if (!scheduled.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id,
      'Udhaar due today',
      'Open Mera Markaz to review this private reminder.',
      tz.TZDateTime.from(scheduled, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'udhaar_due',
          'Udhaar due dates',
          channelDescription: 'Reminders for money to receive or pay',
          importance: Importance.high,
          priority: Priority.high,
          visibility: NotificationVisibility.private,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id);
  }
}
