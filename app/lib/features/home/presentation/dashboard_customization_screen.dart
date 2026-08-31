import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../data/dashboard_layout_repository.dart';

class DashboardCustomizationScreen extends ConsumerStatefulWidget {
  const DashboardCustomizationScreen({super.key});
  @override
  ConsumerState<DashboardCustomizationScreen> createState() =>
      _DashboardCustomizationScreenState();
}

class _DashboardCustomizationScreenState
    extends ConsumerState<DashboardCustomizationScreen> {
  List<DashboardSectionPreference>? items;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    ref.read(dashboardLayoutRepositoryProvider).load().then((value) {
      if (mounted) setState(() => items = value);
    });
  }

  Future<void> save() async {
    setState(() => saving = true);
    await ref.read(dashboardLayoutRepositoryProvider).save(items!);
    ref.invalidate(dashboardLayoutProvider);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.phrase('Customize Home')),
      actions: [
        TextButton(
          onPressed: saving || items == null ? null : save,
          child: Text(context.l10n.phrase('Save')),
        ),
      ],
    ),
    body: items == null
        ? const Center(child: CircularProgressIndicator())
        : ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            header: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                context.l10n.phrase(
                  'Choose what appears on Home and drag sections into your preferred order.',
                ),
              ),
            ),
            itemCount: items!.length,
            onReorderItem: (oldIndex, newIndex) => setState(() {
              final item = items!.removeAt(oldIndex);
              items!.insert(newIndex, item);
            }),
            itemBuilder: (context, index) {
              final item = items![index];
              return Card(
                key: ValueKey(item.section),
                child: SwitchListTile(
                  secondary: const Icon(Icons.drag_handle_rounded),
                  value: item.visible,
                  title: Text(context.l10n.phrase(_label(item.section))),
                  onChanged: (value) => setState(
                    () => items![index] = DashboardSectionPreference(
                      section: item.section,
                      position: index,
                      visible: value,
                    ),
                  ),
                ),
              );
            },
          ),
  );
}

String _label(DashboardSection section) => switch (section) {
  DashboardSection.balance => 'Balance summary',
  DashboardSection.safeToSpend => 'Safe to Spend',
  DashboardSection.budget => 'Budget progress',
  DashboardSection.udhaar => 'Udhaar summary',
  DashboardSection.quickActions => 'Quick actions',
  DashboardSection.insight => 'Markaz Insight',
  DashboardSection.pakistanToday => 'Pakistan Today',
  DashboardSection.upcoming => 'Upcoming payments',
  DashboardSection.savings => 'Savings goals',
  DashboardSection.recentActivity => 'Recent transactions',
  DashboardSection.tools => 'Popular tools',
};
