import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/notification_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Map<NotificationType, bool>? values;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await NotificationPreferences().all();
    if (mounted) setState(() => values = loaded);
  }

  Future<void> changed(NotificationType type, bool enabled) async {
    if (enabled) {
      final granted = await ref
          .read(notificationServiceProvider)
          .requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.phrase('Notification permission was not granted.'),
              ),
            ),
          );
        }
        return;
      }
    }
    await NotificationPreferences().setEnabled(type, enabled);
    if (mounted) setState(() => values![type] = enabled);
  }

  String label(NotificationType type) => switch (type) {
    NotificationType.udhaarDue => 'Udhaar due dates',
    NotificationType.budgetThreshold => 'Budget thresholds',
    NotificationType.monthlySummary => 'Monthly expense summary',
    NotificationType.zakatReminder => 'Yearly Zakat reminder',
    NotificationType.recurringExpense => 'Recurring expenses',
    NotificationType.electricityReminder => 'Electricity usage reminder',
  };
  IconData icon(NotificationType type) => switch (type) {
    NotificationType.udhaarDue => Icons.handshake_outlined,
    NotificationType.budgetThreshold => Icons.savings_outlined,
    NotificationType.monthlySummary => Icons.summarize_outlined,
    NotificationType.zakatReminder => Icons.volunteer_activism_outlined,
    NotificationType.recurringExpense => Icons.repeat,
    NotificationType.electricityReminder => Icons.bolt_outlined,
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Notifications'))),
    body: values == null
        ? Center(child: CircularProgressIndicator())
        : ListView(
            padding: EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    context.l10n.phrase(
                      'Permission is requested only when you enable a reminder. Each reminder type can be disabled independently.',
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Card(
                child: Column(
                  children: NotificationType.values
                      .map(
                        (type) => SwitchListTile(
                          secondary: Icon(icon(type)),
                          title: Text(label(type)),
                          value: values![type]!,
                          onChanged: (value) => changed(type, value),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
  );
}
