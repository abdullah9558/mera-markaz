import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widget_snapshot_service.dart';

class WidgetSettingsScreen extends StatefulWidget {
  const WidgetSettingsScreen({super.key});
  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  WidgetPrivacy privacy = WidgetPrivacy.hidden;
  WidgetTheme theme = WidgetTheme.system;
  String insight = 'safe_to_spend';
  String market = 'usd_pkr';
  Set<String> quickActions = {'expense', 'udhaar', 'savings'};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await const WidgetSnapshotService().load();
    if (!mounted) return;
    setState(() {
      privacy = value.privacy;
      theme = value.theme;
      insight = value.insight;
      market = value.market;
      quickActions = value.quickActions.toSet();
    });
  }

  Future<void> save() async {
    setState(() => saving = true);
    await const WidgetSnapshotService().configure(
      WidgetPreferences(
        privacy: privacy,
        theme: theme,
        insight: insight,
        market: market,
        quickActions: quickActions.take(3).toList(),
      ),
    );
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.phrase('Widget settings saved.'))),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Home-screen widgets'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.security_outlined),
            title: Text(context.l10n.phrase('Privacy first')),
            subtitle: Text(
              context.l10n.phrase(
                'Amounts are hidden by default. Widgets use a small cached snapshot and never open your encrypted database.',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(context.l10n.phrase('Amount visibility')),
        SegmentedButton<WidgetPrivacy>(
          segments: [
            ButtonSegment(
              value: WidgetPrivacy.hidden,
              label: Text(context.l10n.phrase('Hide amounts')),
            ),
            ButtonSegment(
              value: WidgetPrivacy.visible,
              label: Text(context.l10n.phrase('Show amounts')),
            ),
          ],
          selected: {privacy},
          onSelectionChanged: (value) => setState(() => privacy = value.first),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<WidgetTheme>(
          initialValue: theme,
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Widget theme'),
          ),
          items: WidgetTheme.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(
                    context.l10n.phrase(
                      value.name == 'system'
                          ? 'System'
                          : value.name == 'light'
                          ? 'Light'
                          : 'Dark',
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => theme = value ?? theme),
        ),
        const SizedBox(height: 16),
        Text(context.l10n.phrase('Quick widget actions')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children:
              const {
                    'expense': 'Expense',
                    'income': 'Income',
                    'udhaar': 'Udhaar',
                    'fuel': 'Fuel',
                    'scan': 'Scan Receipt',
                    'savings': 'Savings',
                  }.entries
                  .map(
                    (entry) => FilterChip(
                      label: Text(context.l10n.phrase(entry.value)),
                      selected: quickActions.contains(entry.key),
                      onSelected: (selected) => setState(() {
                        if (selected && quickActions.length < 3) {
                          quickActions.add(entry.key);
                        }
                        if (!selected) quickActions.remove(entry.key);
                      }),
                    ),
                  )
                  .toList(),
        ),
        Text(context.l10n.phrase('Choose up to three actions.')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: insight,
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Financial widget'),
          ),
          items:
              const {
                    'safe_to_spend': 'Safe to Spend',
                    'budget': 'Budget',
                    'udhaar': 'Udhaar',
                    'savings': 'Savings goal',
                    'upcoming': 'Upcoming payments',
                    'fuel': 'Fuel',
                    'net_worth': 'Net worth',
                    'health': 'Financial Health',
                    'solar': 'Solar ROI',
                    'zakat': 'Zakat review',
                  }.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(context.l10n.phrase(entry.value)),
                    ),
                  )
                  .toList(),
          onChanged: (value) => setState(() => insight = value ?? insight),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: market,
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Pakistan Live widget'),
          ),
          items:
              const {
                    'usd_pkr': 'USD/PKR',
                    'aed_pkr': 'AED/PKR',
                    'sar_pkr': 'SAR/PKR',
                    'gold_24k_tola': 'Gold',
                    'petrol': 'Petrol',
                  }.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(context.l10n.phrase(entry.value)),
                    ),
                  )
                  .toList(),
          onChanged: (value) => setState(() => market = value ?? market),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: saving ? null : save,
          icon: const Icon(Icons.save_outlined),
          label: Text(
            context.l10n.phrase(saving ? 'Saving…' : 'Save widget settings'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.phrase(
            'After saving, long-press your Android home screen, choose Widgets, then select a Mera Markaz widget.',
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
