import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/localization/app_localizations.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/data/finance_export_service.dart';
import '../../expenses/domain/finance_transaction.dart';
import '../../home/presentation/dashboard_provider.dart';
import '../data/net_worth_repository.dart';
import '../data/receipt_repository.dart';
import '../domain/voice_transaction_parser.dart';

class AdvancedFeaturesScreen extends StatelessWidget {
  const AdvancedFeaturesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Smart finance tools'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FeatureTile(
          icon: Icons.document_scanner_outlined,
          title: 'Receipt scanner',
          subtitle: 'Scan, review and confirm receipt expenses',
          onTap: () => _open(context, const ReceiptScannerScreen()),
        ),
        _FeatureTile(
          icon: Icons.mic_none_outlined,
          title: 'Voice entry',
          subtitle: 'Speak a short income or expense entry',
          onTap: () => _open(context, const VoiceEntryScreen()),
        ),
        _FeatureTile(
          icon: Icons.description_outlined,
          title: 'Reports',
          subtitle: 'Generate local PDF and CSV reports',
          onTap: () => _open(context, const ReportsScreen()),
        ),
        _FeatureTile(
          icon: Icons.account_balance_outlined,
          title: 'Net worth',
          subtitle: 'Track assets and liabilities',
          onTap: () => _open(context, const NetWorthScreen()),
        ),
      ],
    ),
  );
  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(
        context.l10n.phrase(title),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(context.l10n.phrase(subtitle)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class ReceiptScannerScreen extends ConsumerStatefulWidget {
  const ReceiptScannerScreen({super.key});
  @override
  ConsumerState<ReceiptScannerScreen> createState() =>
      _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends ConsumerState<ReceiptScannerScreen> {
  bool working = false;
  Future<void> _pick(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 2200,
    );
    if (image == null) return;
    setState(() => working = true);
    try {
      final draft = await ref.read(receiptRepositoryProvider).scan(image.path);
      if (mounted) {
        await _review(draft);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.l10n.phrase('Could not scan receipt')}: $error',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _review(ReceiptDraft draft) async {
    final merchant = TextEditingController(text: draft.merchant);
    final total = TextEditingController(
      text: draft.total == 0 ? '' : draft.total.toStringAsFixed(2),
    );
    final categories = await ref
        .read(expenseRepositoryProvider)
        .categories(TransactionType.expense);
    var category = categories.firstWhere(
      (item) => item.name == 'Other',
      orElse: () => categories.first,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.phrase('Review receipt')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FutureBuilder(
                    future: ref
                        .read(receiptRepositoryProvider)
                        .imageBytes(draft),
                    builder: (context, snapshot) => snapshot.hasData
                        ? Image.memory(
                            snapshot.data!,
                            height: 150,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(
                            height: 150,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                  ),
                ),
                TextField(
                  controller: merchant,
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Merchant'),
                  ),
                ),
                TextField(
                  controller: total,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Total'),
                  ),
                ),
                DropdownButtonFormField(
                  initialValue: category.id,
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Category'),
                  ),
                  items: categories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(context.l10n.phrase(item.name)),
                        ),
                      )
                      .toList(),
                  onChanged: (id) => setDialogState(
                    () => category = categories.firstWhere(
                      (item) => item.id == id,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.phrase(
                    'Please verify scanned details before saving.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.phrase('Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(receiptRepositoryProvider)
                    .confirm(
                      id: draft.id,
                      merchant: merchant.text,
                      total: double.tryParse(total.text) ?? 0,
                      purchasedAt: draft.purchasedAt,
                      categoryId: category.id,
                    );
                ref.invalidate(homeDashboardProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(context.l10n.phrase('Confirm expense')),
            ),
          ],
        ),
      ),
    );
    merchant.dispose();
    total.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Receipt scanner'))),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: working
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.document_scanner_outlined, size: 72),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.phrase(
                      'Receipt data stays on this device. Always review OCR results.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(context.l10n.phrase('Take photo')),
                  ),
                  TextButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(context.l10n.phrase('Choose from gallery')),
                  ),
                ],
              ),
      ),
    ),
  );
}

class VoiceEntryScreen extends ConsumerStatefulWidget {
  const VoiceEntryScreen({super.key});
  @override
  ConsumerState<VoiceEntryScreen> createState() => _VoiceEntryScreenState();
}

class _VoiceEntryScreenState extends ConsumerState<VoiceEntryScreen> {
  final speech = SpeechToText();
  String words = '';
  bool listening = false;
  Future<void> listen() async {
    if (listening) {
      await speech.stop();
      setState(() => listening = false);
      return;
    }
    final ready = await speech.initialize();
    if (!ready) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.phrase('Speech recognition is unavailable.'),
            ),
          ),
        );
      }
      return;
    }
    setState(() => listening = true);
    await speech.listen(
      onResult: (result) => setState(() {
        words = result.recognizedWords;
        if (result.finalResult) listening = false;
      }),
    );
  }

  Future<void> save() async {
    final draft = VoiceTransactionParser.parse(words);
    if (draft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.phrase(
              'Say a description and amount, for example: groceries 2500.',
            ),
          ),
        ),
      );
      return;
    }
    final type = draft.isIncome
        ? TransactionType.income
        : TransactionType.expense;
    final categories = await ref
        .read(expenseRepositoryProvider)
        .categories(type);
    final category = categories.firstWhere(
      (item) => item.name == 'Other',
      orElse: () => categories.first,
    );
    await ref
        .read(expenseRepositoryProvider)
        .save(
          FinanceTransaction(
            type: type,
            amount: draft.amount,
            categoryId: category.id,
            categoryName: category.name,
            occurredAt: DateTime.now(),
            description: draft.description,
            note: 'Created from reviewed voice entry',
          ),
        );
    ref.invalidate(homeDashboardProvider);
    if (mounted) {
      setState(() => words = '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.phrase('Transaction saved.'))),
      );
    }
  }

  @override
  void dispose() {
    speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Voice entry'))),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                words.isEmpty
                    ? context.l10n.phrase(
                        'Tap the microphone and speak a short transaction.',
                      )
                    : words,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          FloatingActionButton.large(
            onPressed: listen,
            child: Icon(listening ? Icons.stop : Icons.mic),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: words.isEmpty ? null : save,
              child: Text(context.l10n.phrase('Review and save')),
            ),
          ),
        ],
      ),
    ),
  );
}

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});
  Future<void> _generate(BuildContext context, WidgetRef ref, bool pdf) async {
    final file = pdf
        ? await ref.read(financeExportServiceProvider).pdfReport()
        : await ref.read(financeExportServiceProvider).csv();
    if (context.mounted) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(context.l10n.phrase('Report created')),
          content: SelectableText(file.path),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.phrase('Close')),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Reports'))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _FeatureTile(
          icon: Icons.picture_as_pdf_outlined,
          title: 'PDF financial report',
          subtitle: 'Monthly summary and transaction history',
          onTap: () => _generate(context, ref, true),
        ),
        _FeatureTile(
          icon: Icons.table_chart_outlined,
          title: 'CSV transaction export',
          subtitle: 'Spreadsheet-ready transaction data',
          onTap: () => _generate(context, ref, false),
        ),
      ],
    ),
  );
}

final netWorthAccountsProvider = FutureProvider(
  (ref) => ref.watch(netWorthRepositoryProvider).accounts(),
);

class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(netWorthAccountsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.phrase('Net worth'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _accountDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.phrase('Add account')),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) {
          final assets = items
              .where((item) => !item.isLiability)
              .fold<double>(0, (sum, item) => sum + item.balance);
          final liabilities = items
              .where((item) => item.isLiability)
              .fold<double>(0, (sum, item) => sum + item.balance);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(context.l10n.phrase('Estimated net worth')),
                      Text(
                        _money(assets - liabilities),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${context.l10n.phrase('Assets')}: ${_money(assets)}',
                          ),
                          Text(
                            '${context.l10n.phrase('Liabilities')}: ${_money(liabilities)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              ...items.map(
                (item) => ListTile(
                  leading: Icon(
                    item.isLiability ? Icons.trending_down : Icons.trending_up,
                  ),
                  title: Text(item.name),
                  subtitle: Text(context.l10n.phrase(item.kind)),
                  trailing: Text(_money(item.balance)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _accountDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final balance = TextEditingController();
  var kind = 'asset';
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(context.l10n.phrase('Add account')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Account name'),
              ),
            ),
            TextField(
              controller: balance,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Current balance'),
              ),
            ),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'asset',
                  label: Text(context.l10n.phrase('Asset')),
                ),
                ButtonSegment(
                  value: 'liability',
                  label: Text(context.l10n.phrase('Liability')),
                ),
              ],
              selected: {kind},
              onSelectionChanged: (value) => setState(() => kind = value.first),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(netWorthRepositoryProvider)
                  .save(
                    name: name.text,
                    kind: kind,
                    balance: double.tryParse(balance.text) ?? -1,
                  );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: Text(context.l10n.phrase('Save')),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  balance.dispose();
  if (saved == true) ref.invalidate(netWorthAccountsProvider);
}

String _money(num value) =>
    'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';
