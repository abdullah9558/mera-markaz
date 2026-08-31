import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/presentation/dashboard_provider.dart';
import '../data/data_control_service.dart';

class PrivacyDataScreen extends ConsumerStatefulWidget {
  const PrivacyDataScreen({super.key});
  @override
  ConsumerState<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends ConsumerState<PrivacyDataScreen> {
  bool busy = false;
  Future<void> export() async {
    setState(() => busy = true);
    try {
      final file = await ref.read(dataControlServiceProvider).exportJson();
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(context.l10n.phrase('Data exported')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.phrase(
                    'An encrypted Mera Markaz backup was saved locally:',
                  ),
                ),
                SizedBox(height: 10),
                SelectableText(file.path),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.phrase('Done')),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.warning_amber),
        title: Text(context.l10n.phrase('Delete all financial data?')),
        content: Text(
          context.l10n.phrase(
            'This permanently removes expenses, income, budgets, Udhaar ledgers, vehicles and saved calculations from this device. App preferences are retained. Export first if you need a copy.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.phrase('Delete everything')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    await ref.read(dataControlServiceProvider).deleteAllFinancialData();
    ref.invalidate(homeDashboardProvider);
    if (mounted) {
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.phrase('All financial data was deleted.')),
        ),
      );
    }
  }

  Future<void> restore() async {
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mmb'],
    );
    if (selection.isEmpty) return;
    final path = selection.single.path;
    if (path == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.phrase('Restore encrypted backup?')),
        content: Text(
          context.l10n.phrase(
            'Current records for this profile will be replaced only after the backup is authenticated and validated.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.phrase('Restore backup')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await ref.read(dataControlServiceProvider).restoreMmb(File(path));
      ref.invalidate(homeDashboardProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.phrase('Encrypted backup restored.')),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.phrase(
                'Backup could not be restored. No data was changed.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Privacy & Data'))),
    body: ListView(
      padding: EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.phone_android),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.l10n.phrase(
                      'Your financial records stay in local app storage by default. No CNIC, login, contacts, SMS or location is required.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.download_outlined),
                title: Text(context.l10n.phrase('Export all local data')),
                subtitle: Text(
                  context.l10n.phrase(
                    'Create an authenticated encrypted .mmb backup.',
                  ),
                ),
                trailing: Icon(Icons.chevron_right),
                enabled: !busy,
                onTap: export,
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.restore_outlined),
                title: Text(context.l10n.phrase('Restore encrypted backup')),
                subtitle: Text(
                  context.l10n.phrase(
                    'Authenticate and restore a local .mmb file.',
                  ),
                ),
                trailing: Icon(Icons.chevron_right),
                enabled: !busy,
                onTap: restore,
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  context.l10n.phrase('Delete all financial data'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: Text(
                  context.l10n.phrase('Permanent and cannot be undone.'),
                ),
                enabled: !busy,
                onTap: deleteAll,
              ),
            ],
          ),
        ),
        if (busy)
          Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    ),
  );
}
