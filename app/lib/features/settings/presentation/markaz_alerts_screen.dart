import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/notification_inbox_repository.dart';
import '../../personal_finance/data/personal_finance_repository.dart';

final markazInboxProvider = FutureProvider.autoDispose
    .family<List<InboxNotification>, ({String? category, String search})>(
      (ref, filter) => ref
          .watch(notificationInboxRepositoryProvider)
          .list(category: filter.category, search: filter.search),
    );

class MarkazAlertsScreen extends ConsumerStatefulWidget {
  const MarkazAlertsScreen({super.key});

  @override
  ConsumerState<MarkazAlertsScreen> createState() => _MarkazAlertsScreenState();
}

class _MarkazAlertsScreenState extends ConsumerState<MarkazAlertsScreen> {
  String? category;
  String search = '';

  static const filters = <(String, String?)>[
    ('All', null),
    ('Money', 'money'),
    ('Pakistan', 'pakistan'),
    ('Reminders', 'reminders'),
    ('Security', 'security'),
    ('System', 'system'),
  ];

  void refresh() =>
      ref.invalidate(markazInboxProvider((category: category, search: search)));

  @override
  Widget build(BuildContext context) {
    final filter = (category: category, search: search);
    final state = ref.watch(markazInboxProvider(filter));
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.phrase('Markaz Alerts')),
        actions: [
          IconButton(
            tooltip: context.l10n.phrase('Notification settings'),
            onPressed: () => context.push('/notification-settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final repository = ref.read(notificationInboxRepositoryProvider);
              if (value == 'read') await repository.markAllRead();
              if (value == 'clear') await repository.clearRead();
              refresh();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'read',
                child: Text(context.l10n.phrase('Mark all as read')),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Text(context.l10n.phrase('Clear read notifications')),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: SearchBar(
                  hintText: context.l10n.phrase('Search notifications'),
                  leading: const Icon(Icons.search_rounded),
                  onChanged: (value) => setState(() => search = value),
                ),
              ),
              SizedBox(
                height: 54,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final item = filters[index];
                    return ChoiceChip(
                      label: Text(context.l10n.phrase(item.$1)),
                      selected: category == item.$2,
                      onSelected: (_) => setState(() => category = item.$2),
                    );
                  },
                ),
              ),
              Expanded(
                child: state.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => _MessageState(
                    icon: Icons.cloud_off_rounded,
                    title: context.l10n.phrase(
                      'Notifications could not be loaded.',
                    ),
                    action: refresh,
                  ),
                  data: (items) => items.isEmpty
                      ? _MessageState(
                          icon: Icons.notifications_none_rounded,
                          title: context.l10n.phrase('No notifications yet'),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => refresh(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) => _AlertTile(
                              item: items[index],
                              onChanged: refresh,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends ConsumerWidget {
  const _AlertTile({required this.item, required this.onChanged});
  final InboxNotification item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Dismissible(
    key: ValueKey(item.id),
    direction: DismissDirection.endToStart,
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.delete_outline_rounded),
    ),
    onDismissed: (_) async {
      await ref.read(notificationInboxRepositoryProvider).delete(item.id);
      onChanged();
    },
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            minVerticalPadding: 14,
            leading: CircleAvatar(child: Icon(_categoryIcon(item.category))),
            title: Text(
              item.title,
              style: TextStyle(
                fontWeight: item.isUnread ? FontWeight.w800 : null,
              ),
            ),
            subtitle: Text(item.body),
            trailing: item.isUnread
                ? Semantics(
                    label: context.l10n.phrase('Unread notification'),
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : null,
            onTap: () async {
              await ref
                  .read(notificationInboxRepositoryProvider)
                  .markRead(item.id);
              onChanged();
              if (context.mounted && item.route != null) {
                context.push(item.route!);
              }
            },
          ),
          if (_action(item.actionJson) case final action?)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
              child: Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _performAction(context, ref, action),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(context.l10n.phrase('Mark Paid')),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: item.route == null
                        ? null
                        : () => context.push(item.route!),
                    child: Text(context.l10n.phrase('View')),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  Map<String, Object?>? _action(String? value) {
    if (value == null) return null;
    try {
      return (jsonDecode(value) as Map).cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _performAction(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> action,
  ) async {
    if (action['type'] != 'mark_bill_paid') return;
    try {
      await ref
          .read(personalFinanceRepositoryProvider)
          .payBill(
            (action['billId'] as num).toInt(),
            (action['amount'] as num).toDouble(),
            DateTime.now(),
          );
      await ref.read(notificationInboxRepositoryProvider).markRead(item.id);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.phrase('Bill marked as paid.'))),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.phrase('The bill could not be updated.'),
            ),
          ),
        );
      }
    }
  }

  IconData _categoryIcon(String category) => switch (category) {
    'money' => Icons.account_balance_wallet_outlined,
    'pakistan' => Icons.public_rounded,
    'reminders' => Icons.event_available_outlined,
    'security' => Icons.shield_outlined,
    _ => Icons.info_outline_rounded,
  };
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.title, this.action});
  final IconData icon;
  final String title;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: action,
              child: Text(context.l10n.phrase('Try again')),
            ),
          ],
        ],
      ),
    ),
  );
}
