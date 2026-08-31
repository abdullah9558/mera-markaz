import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/ledger_repository.dart';
import '../domain/ledger.dart';
import '../../home/presentation/dashboard_provider.dart';

String _ledgerMoney(num value) =>
    'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';

class UdhaarScreen extends ConsumerStatefulWidget {
  const UdhaarScreen({super.key});
  @override
  ConsumerState<UdhaarScreen> createState() => _UdhaarScreenState();
}

class _UdhaarScreenState extends ConsumerState<UdhaarScreen> {
  late Future<(LedgerSummary, List<LedgerPerson>)> data;
  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<(LedgerSummary, List<LedgerPerson>)> _load() async {
    final repo = ref.read(ledgerRepositoryProvider);
    return (await repo.summary(), await repo.people());
  }

  void refresh() {
    ref.invalidate(homeDashboardProvider);
    setState(() => data = _load());
  }

  Future<void> add() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _NewLedgerSheet(repository: ref.read(ledgerRepositoryProvider)),
    );
    if (changed == true) refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Udhaar / Khata'))),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: add,
      icon: Icon(Icons.person_add),
      label: Text(context.l10n.phrase('New ledger')),
    ),
    body: FutureBuilder<(LedgerSummary, List<LedgerPerson>)>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final (summary, people) = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: _LedgerTotal(
                          label: 'You will receive',
                          value: _ledgerMoney(summary.toReceive),
                          color: AppColors.emerald,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _LedgerTotal(
                          label: 'You have to pay',
                          value: _ledgerMoney(summary.toPay),
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (people.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.handshake_outlined, size: 68),
                          SizedBox(height: 14),
                          Text(
                            context.l10n.phrase('No active ledgers'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            context.l10n.phrase(
                              'Track money you gave or took without giving contact access.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: people.length,
                    separatorBuilder: (_, _) => SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final person = people[index];
                      return Card(
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            child: Text(
                              person.name.characters.first.toUpperCase(),
                            ),
                          ),
                          title: Text(
                            person.name,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            [
                              if (person.toReceive > 0)
                                '${context.l10n.phrase('Receive')} ${_ledgerMoney(person.toReceive)}',
                              if (person.toPay > 0)
                                '${context.l10n.phrase('Pay')} ${_ledgerMoney(person.toPay)}',
                            ].join(' • '),
                          ),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    LedgerDetailScreen(person: person),
                              ),
                            );
                            refresh();
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class LedgerDetailScreen extends ConsumerStatefulWidget {
  const LedgerDetailScreen({super.key, required this.person});
  final LedgerPerson person;
  @override
  ConsumerState<LedgerDetailScreen> createState() => _LedgerDetailScreenState();
}

class _LedgerDetailScreenState extends ConsumerState<LedgerDetailScreen> {
  late Future<List<LedgerEntry>> entries;
  @override
  void initState() {
    super.initState();
    entries = _load();
  }

  Future<List<LedgerEntry>> _load() =>
      ref.read(ledgerRepositoryProvider).entries(widget.person.id);
  void refresh() => setState(() => entries = _load());
  Future<void> addEntry() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NewLedgerSheet(
        repository: ref.read(ledgerRepositoryProvider),
        person: widget.person,
      ),
    );
    if (changed == true) refresh();
  }

  Future<void> pay(LedgerEntry entry) async {
    final controller = TextEditingController();
    final payment = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.phrase('Record payment')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.l10n.phrase('Remaining')}: ${_ledgerMoney(entry.remaining)}',
            ),
            SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Payment amount'),
                prefixText: 'Rs. ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: Text(context.l10n.phrase('Record')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (payment == null) return;
    try {
      await ref.read(ledgerRepositoryProvider).recordPayment(entry, payment);
      refresh();
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> createInstallments(LedgerEntry entry) async {
    final count = TextEditingController(text: '3');
    var firstDue = entry.dueAt ?? DateTime.now().add(const Duration(days: 30));
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.phrase('Create installment plan')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: count,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.phrase('Number of installments'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: firstDue,
                  );
                  if (value != null) setDialogState(() => firstDue = value);
                },
                icon: const Icon(Icons.event),
                label: Text(DateFormat.yMMMd().format(firstDue)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.phrase('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.l10n.phrase('Create')),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      await ref
          .read(ledgerRepositoryProvider)
          .createInstallmentPlan(
            entry,
            count: int.tryParse(count.text) ?? 0,
            firstDue: firstDue,
          );
      if (mounted) setState(() {});
    }
    count.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.person.name),
      actions: [
        PopupMenuButton(
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'delete',
              child: Text(context.l10n.phrase('Delete ledger')),
            ),
          ],
          onSelected: (_) async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(context.l10n.phrase('Delete ledger?')),
                content: Text(
                  context.l10n.phrase(
                    'All entries and repayment history for this person will be deleted.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10n.phrase('Cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(context.l10n.phrase('Delete')),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref
                  .read(ledgerRepositoryProvider)
                  .deletePerson(widget.person.id);
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: addEntry,
      icon: Icon(Icons.add),
      label: Text(context.l10n.phrase('Add entry')),
    ),
    body: FutureBuilder<List<LedgerEntry>>(
      future: entries,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final values = snapshot.data!;
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: values.length,
          separatorBuilder: (_, _) => SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = values[index];
            final status = entry.statusAt(DateTime.now());
            return Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.description,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _StatusChip(status: status),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      entry.direction == LedgerDirection.gave
                          ? '${context.l10n.phrase('I gave')} ${_ledgerMoney(entry.amount)}'
                          : '${context.l10n.phrase('I took')} ${_ledgerMoney(entry.amount)}',
                    ),
                    Text(
                      '${context.l10n.phrase('Remaining')} ${_ledgerMoney(entry.remaining)} • ${DateFormat.yMMMd().format(entry.occurredAt)}',
                    ),
                    if (entry.dueAt != null)
                      Text(
                        '${context.l10n.phrase('Due')} ${DateFormat.yMMMd().format(entry.dueAt!)}',
                      ),
                    if (entry.remaining > 0)
                      Wrap(
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => createInstallments(entry),
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(context.l10n.phrase('Installments')),
                          ),
                          TextButton.icon(
                            onPressed: () => pay(entry),
                            icon: const Icon(Icons.payments_outlined),
                            label: Text(context.l10n.phrase('Record payment')),
                          ),
                        ],
                      ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(context.l10n.phrase('Repayment details')),
                      children: [
                        FutureBuilder<List<LedgerInstallment>>(
                          future: ref
                              .read(ledgerRepositoryProvider)
                              .installments(entry.id),
                          builder: (context, plan) => Column(
                            children: (plan.data ?? const [])
                                .map(
                                  (item) => ListTile(
                                    dense: true,
                                    leading: Icon(
                                      item.status == 'paid'
                                          ? Icons.check_circle
                                          : Icons.schedule,
                                    ),
                                    title: Text(
                                      '${context.l10n.phrase('Installment')} ${item.number} • ${_ledgerMoney(item.amount)}',
                                    ),
                                    subtitle: Text(
                                      DateFormat.yMMMd().format(item.dueAt),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        FutureBuilder<List<LedgerPayment>>(
                          future: ref
                              .read(ledgerRepositoryProvider)
                              .paymentHistory(entry.id),
                          builder: (context, history) => Column(
                            children: (history.data ?? const [])
                                .map(
                                  (item) => ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.history),
                                    title: Text(
                                      '${context.l10n.phrase('Payment')} ${_ledgerMoney(item.amount)}',
                                    ),
                                    subtitle: Text(
                                      DateFormat.yMMMd().format(item.paidAt),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _NewLedgerSheet extends StatefulWidget {
  const _NewLedgerSheet({required this.repository, this.person});
  final LedgerRepository repository;
  final LedgerPerson? person;
  @override
  State<_NewLedgerSheet> createState() => _NewLedgerSheetState();
}

class _NewLedgerSheetState extends State<_NewLedgerSheet> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final amount = TextEditingController();
  final description = TextEditingController();
  final notes = TextEditingController();
  LedgerDirection direction = LedgerDirection.gave;
  DateTime date = DateTime.now();
  DateTime? due;
  String? error;
  bool saving = false;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    amount.dispose();
    description.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final value = double.tryParse(amount.text);
    if (value == null ||
        value <= 0 ||
        (widget.person == null && name.text.trim().isEmpty) ||
        description.text.trim().isEmpty) {
      setState(() => error = 'Enter a name, positive amount and description.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      if (widget.person == null) {
        await widget.repository.create(
          name: name.text,
          phone: phone.text,
          direction: direction,
          amount: value,
          date: date,
          dueDate: due,
          description: description.text,
          notes: notes.text,
        );
      } else {
        await widget.repository.addEntry(
          personId: widget.person!.id,
          direction: direction,
          amount: value,
          date: date,
          dueDate: due,
          description: description.text,
          notes: notes.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      top: 12,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.person == null
                    ? context.l10n.phrase('New ledger')
                    : '${context.l10n.phrase('Add entry for')} ${widget.person!.name}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close),
            ),
          ],
        ),
        if (widget.person == null) ...[
          SizedBox(height: 12),
          TextField(
            controller: name,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Person name'),
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Phone (optional)'),
            ),
          ),
        ],
        SizedBox(height: 12),
        SegmentedButton<LedgerDirection>(
          segments: [
            ButtonSegment(
              value: LedgerDirection.gave,
              label: Text(context.l10n.phrase('I gave')),
            ),
            ButtonSegment(
              value: LedgerDirection.took,
              label: Text(context.l10n.phrase('I took')),
            ),
          ],
          selected: {direction},
          onSelectionChanged: (value) =>
              setState(() => direction = value.first),
        ),
        SizedBox(height: 12),
        TextField(
          controller: amount,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Amount'),
            prefixText: 'Rs. ',
          ),
        ),
        SizedBox(height: 12),
        TextField(
          controller: description,
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Description'),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    initialDate: date,
                  );
                  if (value != null) setState(() => date = value);
                },
                icon: Icon(Icons.event),
                label: Text(DateFormat.yMMMd().format(date)),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final value = await showDatePicker(
                    context: context,
                    firstDate: date,
                    lastDate: DateTime(date.year + 10),
                    initialDate: due ?? date,
                  );
                  if (value != null) setState(() => due = value);
                },
                icon: Icon(Icons.alarm),
                label: Text(
                  due == null
                      ? context.l10n.phrase('Due date')
                      : DateFormat.yMMMd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).format(due!),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        TextField(
          controller: notes,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Notes (optional)'),
          ),
        ),
        if (error != null)
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        SizedBox(height: 18),
        FilledButton(
          onPressed: saving ? null : save,
          child: Text(context.l10n.phrase(saving ? 'Saving…' : 'Save ledger')),
        ),
      ],
    ),
  );
}

class _LedgerTotal extends StatelessWidget {
  const _LedgerTotal({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: color),
          SizedBox(height: 14),
          Text(
            context.l10n.phrase(label),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final LedgerStatus status;
  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      LedgerStatus.pending => 'Pending',
      LedgerStatus.partiallyPaid => 'Part paid',
      LedgerStatus.paid => 'Paid',
      LedgerStatus.overdue => 'Overdue',
    };
    final color = switch (status) {
      LedgerStatus.paid => AppColors.emerald,
      LedgerStatus.overdue => Colors.red,
      LedgerStatus.partiallyPaid => Colors.orange,
      LedgerStatus.pending => Colors.blueGrey,
    };
    return Chip(
      label: Text(context.l10n.phrase(label)),
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: .13),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}
