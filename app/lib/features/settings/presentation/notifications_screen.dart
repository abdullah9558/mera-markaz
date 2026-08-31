import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/markaz_alert_preferences.dart';
import '../../../core/notifications/notification_policy.dart';
import '../../../core/notifications/notification_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final preferences = const MarkazAlertPreferences();
  Map<MarkazAlertCategory, bool>? values;
  NotificationPrivacy privacy = NotificationPrivacy.private;
  QuietHours quietHours = const QuietHours();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await preferences.all();
    final loadedPrivacy = await preferences.privacy();
    final loadedQuietHours = await preferences.quietHours();
    if (!mounted) return;
    setState(() {
      values = enabled;
      privacy = loadedPrivacy;
      quietHours = loadedQuietHours;
    });
  }

  Future<void> _changed(MarkazAlertCategory category, bool enabled) async {
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
    await preferences.setEnabled(category, enabled);
    if (mounted) setState(() => values![category] = enabled);
  }

  Future<void> _pickTime({required bool start}) async {
    final minute = start ? quietHours.startMinute : quietHours.endMinute;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (result == null) return;
    final updated = QuietHours(
      enabled: quietHours.enabled,
      startMinute: start
          ? result.hour * 60 + result.minute
          : quietHours.startMinute,
      endMinute: start
          ? quietHours.endMinute
          : result.hour * 60 + result.minute,
    );
    await preferences.setQuietHours(updated);
    if (mounted) setState(() => quietHours = updated);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Notification settings'))),
    body: values == null
        ? Semantics(
            liveRegion: true,
            label: context.l10n.phrase('Loading notification settings'),
            child: const Center(child: CircularProgressIndicator()),
          )
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _SectionCard(
                    title: context.l10n.phrase('Notification privacy'),
                    subtitle: context.l10n.phrase(
                      'Private mode hides amounts, names and sensitive financial details.',
                    ),
                    child: SegmentedButton<NotificationPrivacy>(
                      segments: [
                        ButtonSegment(
                          value: NotificationPrivacy.private,
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: Text(context.l10n.phrase('Private')),
                        ),
                        ButtonSegment(
                          value: NotificationPrivacy.detailed,
                          icon: const Icon(Icons.subject_rounded),
                          label: Text(context.l10n.phrase('Detailed')),
                        ),
                      ],
                      selected: {privacy},
                      onSelectionChanged: (selection) async {
                        await preferences.setPrivacy(selection.single);
                        setState(() => privacy = selection.single);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    title: context.l10n.phrase('Quiet hours'),
                    subtitle: context.l10n.phrase(
                      'Ordinary alerts wait until quiet hours end. Security alerts remain immediate.',
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.l10n.phrase('Use quiet hours')),
                          value: quietHours.enabled,
                          onChanged: (value) async {
                            final updated = QuietHours(
                              enabled: value,
                              startMinute: quietHours.startMinute,
                              endMinute: quietHours.endMinute,
                            );
                            await preferences.setQuietHours(updated);
                            setState(() => quietHours = updated);
                          },
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _TimeButton(
                                label: context.l10n.phrase('Starts'),
                                minute: quietHours.startMinute,
                                onTap: () => _pickTime(start: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TimeButton(
                                label: context.l10n.phrase('Ends'),
                                minute: quietHours.endMinute,
                                onTap: () => _pickTime(start: false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final group in _groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Text(
                        context.l10n.phrase(group.$1),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final category in group.$2)
                            SwitchListTile(
                              secondary: Icon(_icon(category)),
                              title: Text(
                                context.l10n.phrase(_label(category)),
                              ),
                              value: values![category]!,
                              onChanged: (value) => _changed(category, value),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
  );
}

const _groups = <(String, List<MarkazAlertCategory>)>[
  (
    'Money',
    [
      MarkazAlertCategory.budget,
      MarkazAlertCategory.bills,
      MarkazAlertCategory.udhaar,
      MarkazAlertCategory.salary,
      MarkazAlertCategory.savings,
      MarkazAlertCategory.safeToSpend,
      MarkazAlertCategory.financialHealth,
      MarkazAlertCategory.emergencyFund,
    ],
  ),
  (
    'Pakistan',
    [
      MarkazAlertCategory.petrol,
      MarkazAlertCategory.currency,
      MarkazAlertCategory.gold,
      MarkazAlertCategory.policyRate,
      MarkazAlertCategory.kibor,
      MarkazAlertCategory.inflation,
    ],
  ),
  (
    'Reminders',
    [
      MarkazAlertCategory.electricity,
      MarkazAlertCategory.solar,
      MarkazAlertCategory.zakat,
      MarkazAlertCategory.vehicle,
      MarkazAlertCategory.dailyBrief,
      MarkazAlertCategory.eveningSummary,
    ],
  ),
  (
    'Security and backup',
    [
      MarkazAlertCategory.security,
      MarkazAlertCategory.cloudSync,
      MarkazAlertCategory.localBackup,
    ],
  ),
];

String _label(MarkazAlertCategory value) => switch (value) {
  MarkazAlertCategory.budget => 'Budget thresholds',
  MarkazAlertCategory.bills => 'Bills and due dates',
  MarkazAlertCategory.udhaar => 'Udhaar and installments',
  MarkazAlertCategory.salary => 'Salary reminders',
  MarkazAlertCategory.savings => 'Savings milestones',
  MarkazAlertCategory.petrol => 'Petrol price changes',
  MarkazAlertCategory.currency => 'Currency watch alerts',
  MarkazAlertCategory.gold => 'Gold watch alerts',
  MarkazAlertCategory.policyRate => 'SBP policy rate',
  MarkazAlertCategory.kibor => 'KIBOR watch alerts',
  MarkazAlertCategory.inflation => 'Pakistan inflation releases',
  MarkazAlertCategory.electricity => 'Electricity usage and bills',
  MarkazAlertCategory.solar => 'Solar summaries and maintenance',
  MarkazAlertCategory.zakat => 'Annual Zakat review',
  MarkazAlertCategory.vehicle => 'Vehicle maintenance',
  MarkazAlertCategory.safeToSpend => 'Safe-to-Spend changes',
  MarkazAlertCategory.financialHealth => 'Monthly financial health',
  MarkazAlertCategory.emergencyFund => 'Emergency fund milestones',
  MarkazAlertCategory.security => 'Account security',
  MarkazAlertCategory.cloudSync => 'Cloud sync problems',
  MarkazAlertCategory.localBackup => 'Local backup reminder',
  MarkazAlertCategory.dailyBrief => 'Morning Markaz brief',
  MarkazAlertCategory.eveningSummary => 'Evening summary',
};

IconData _icon(MarkazAlertCategory value) => switch (value) {
  MarkazAlertCategory.budget => Icons.donut_large_rounded,
  MarkazAlertCategory.bills => Icons.receipt_long_outlined,
  MarkazAlertCategory.udhaar => Icons.handshake_outlined,
  MarkazAlertCategory.salary => Icons.payments_outlined,
  MarkazAlertCategory.savings => Icons.savings_outlined,
  MarkazAlertCategory.petrol => Icons.local_gas_station_outlined,
  MarkazAlertCategory.currency => Icons.currency_exchange_rounded,
  MarkazAlertCategory.gold => Icons.workspace_premium_outlined,
  MarkazAlertCategory.policyRate => Icons.account_balance_outlined,
  MarkazAlertCategory.kibor => Icons.percent_rounded,
  MarkazAlertCategory.inflation => Icons.trending_up_rounded,
  MarkazAlertCategory.electricity => Icons.bolt_outlined,
  MarkazAlertCategory.solar => Icons.solar_power_outlined,
  MarkazAlertCategory.zakat => Icons.volunteer_activism_outlined,
  MarkazAlertCategory.vehicle => Icons.directions_car_outlined,
  MarkazAlertCategory.safeToSpend => Icons.shield_outlined,
  MarkazAlertCategory.financialHealth => Icons.monitor_heart_outlined,
  MarkazAlertCategory.emergencyFund => Icons.health_and_safety_outlined,
  MarkazAlertCategory.security => Icons.security_outlined,
  MarkazAlertCategory.cloudSync => Icons.cloud_sync_outlined,
  MarkazAlertCategory.localBackup => Icons.backup_outlined,
  MarkazAlertCategory.dailyBrief => Icons.wb_sunny_outlined,
  MarkazAlertCategory.eveningSummary => Icons.nightlight_outlined,
};

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.minute,
    required this.onTap,
  });
  final String label;
  final int minute;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.schedule_rounded),
    label: Text(
      '$label · ${TimeOfDay(hour: minute ~/ 60, minute: minute % 60).format(context)}',
    ),
  );
}
