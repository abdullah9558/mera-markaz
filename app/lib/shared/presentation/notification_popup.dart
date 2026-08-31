import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/notifications/notification_inbox_repository.dart';
import '../../core/theme/app_theme.dart';

final notificationInboxUnreadProvider = FutureProvider<bool>((ref) async {
  return await ref.watch(notificationInboxRepositoryProvider).unreadCount() > 0;
});

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
  List<InboxNotification>? _notifications;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notifications = await ref
        .read(notificationInboxRepositoryProvider)
        .list(limit: 6);
    if (mounted) {
      setState(() => _notifications = notifications);
    }
  }

  Future<void> _markAllRead() async {
    await ref.read(notificationInboxRepositoryProvider).markAllRead();
    ref.invalidate(notificationInboxUnreadProvider);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notifications ?? const <InboxNotification>[];
    final allRead = notifications.every((item) => !item.isUnread);
    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(18, 70, 18, 24),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
                    onPressed: allRead ? null : _markAllRead,
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
              if (_notifications == null)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(),
                )
              else if (notifications.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(context.l10n.phrase('No notifications yet')),
                )
              else
                ...notifications.map(
                  (notification) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.emerald.withValues(alpha: .12),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: AppColors.emerald,
                      ),
                    ),
                    title: Text(notification.title),
                    subtitle: Text(notification.body),
                    trailing: notification.isUnread
                        ? const CircleAvatar(
                            radius: 4,
                            backgroundColor: AppColors.cyan,
                          )
                        : const Icon(Icons.done_all, size: 18),
                    onTap: () async {
                      await ref
                          .read(notificationInboxRepositoryProvider)
                          .markRead(notification.id);
                      ref.invalidate(notificationInboxUnreadProvider);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      if (notification.route != null) {
                        context.push(notification.route!);
                      }
                    },
                  ),
                ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/notifications');
                },
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(context.l10n.phrase('Open notification center')),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
