import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';

Future<void> showNotificationPopup(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierColor: Colors.black54,
  builder: (_) => const _NotificationPopup(),
);

class _NotificationPopup extends ConsumerStatefulWidget {
  const _NotificationPopup();
  @override
  ConsumerState<_NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends ConsumerState<_NotificationPopup> {
  static const _readKey = 'notification_inbox_all_read';
  bool _allRead = false;
  List<Map<String, Object?>> _reminders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final database = ref.read(appDatabaseProvider);
    final value =
        (await SharedPreferences.getInstance()).getBool(_readKey) ?? false;
    final reminders = await database.database.query(
      'reminders',
      where: "owner_id = ? AND status = 'pending'",
      whereArgs: [database.ownerId],
      orderBy: 'scheduled_at',
      limit: 10,
    );
    if (mounted) {
      setState(() {
        _allRead = value;
        _reminders = reminders;
      });
    }
  }

  Future<void> _markAllRead() async {
    await (await SharedPreferences.getInstance()).setBool(_readKey, true);
    if (mounted) setState(() => _allRead = true);
  }

  @override
  Widget build(BuildContext context) {
    final notifications = [
      ..._reminders.map(
        (reminder) => (
          Icons.event_repeat_outlined,
          reminder['title'] as String,
          '${context.l10n.phrase('Upcoming reminder')} • ${DateFormat.yMMMd().format(DateTime.parse(reminder['scheduled_at'] as String))}',
        ),
      ),
      (
        Icons.insights_outlined,
        context.l10n.phrase('Monthly summary'),
        context.l10n.phrase('Your latest financial summary is ready.'),
      ),
      (
        Icons.handshake_outlined,
        context.l10n.phrase('Udhaar reminders'),
        context.l10n.phrase('Upcoming Udhaar due dates will appear here.'),
      ),
      (
        Icons.security_outlined,
        context.l10n.phrase('Account security'),
        context.l10n.phrase('Keep biometric lock enabled for extra security.'),
      ),
    ];
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(18, 70, 18, 24),
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: Colors.white.withValues(alpha: .14)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.phrase('Notifications'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _allRead ? null : _markAllRead,
                    child: Text(context.l10n.phrase('Mark all as read')),
                  ),
                  IconButton(
                    tooltip: context.l10n.phrase('Close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              ...notifications.map(
                (notification) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.emerald.withValues(alpha: .12),
                    child: Icon(notification.$1, color: AppColors.emerald),
                  ),
                  title: Text(notification.$2),
                  subtitle: Text(notification.$3),
                  trailing: _allRead
                      ? const Icon(Icons.done_all, size: 18)
                      : const CircleAvatar(
                          radius: 4,
                          backgroundColor: AppColors.cyan,
                        ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
