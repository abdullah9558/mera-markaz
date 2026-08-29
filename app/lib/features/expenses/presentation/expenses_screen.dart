import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/expense_repository.dart';
import '../domain/finance_transaction.dart';
import '../../home/presentation/dashboard_provider.dart';
import 'finance_insights_screen.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});
  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  late Future<(FinanceSummary, List<FinanceTransaction>)> data;
  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<(FinanceSummary, List<FinanceTransaction>)> _load() async {
    final repo = ref.read(expenseRepositoryProvider);
    return (await repo.summary(), await repo.all());
  }

  void _refresh() {
    ref.invalidate(homeDashboardProvider);
    setState(() => data = _load());
  }

  Future<void> _open([FinanceTransaction? value]) async {
    final changed = await showFinanceTransactionSheet(
      context,
      ref.read(expenseRepositoryProvider),
      initial: value,
    );
    if (changed == true) _refresh();
  }

  String money(num value) =>
      'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.phrase('Expenses & Income')),
      actions: [
        IconButton(
          tooltip: context.l10n.phrase('Budgets & Analytics'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FinanceInsightsScreen()),
          ),
          icon: Icon(Icons.insights_outlined),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _open,
      icon: Icon(Icons.add),
      label: Text(context.l10n.phrase('Add transaction')),
    ),
    body: FutureBuilder<(FinanceSummary, List<FinanceTransaction>)>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(message: '${snapshot.error}', onRetry: _refresh);
        }
        final (summary, items) = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _Summary(
                                  label: 'Monthly income',
                                  value: money(summary.monthIncome),
                                ),
                              ),
                              Expanded(
                                child: _Summary(
                                  label: 'Monthly expenses',
                                  value: money(summary.monthExpense),
                                ),
                              ),
                            ],
                          ),
                          Divider(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: _Summary(
                                  label: 'Today',
                                  value: money(summary.todayExpense),
                                ),
                              ),
                              Expanded(
                                child: _Summary(
                                  label: 'This week',
                                  value: money(summary.weekExpense),
                                ),
                              ),
                              Expanded(
                                child: _Summary(
                                  label: 'Balance',
                                  value: money(summary.balance),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyTransactions(),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final income = item.type == TransactionType.income;
                      return Card(
                        child: ListTile(
                          onTap: () => _open(item),
                          leading: CircleAvatar(
                            backgroundColor: income
                                ? Colors.green.withValues(alpha: .14)
                                : Theme.of(context).colorScheme.errorContainer,
                            child: Icon(
                              income ? Icons.south_west : Icons.north_east,
                              color: income
                                  ? Colors.green.shade700
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                          title: Text(
                            item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${context.l10n.phrase(item.categoryName)} • ${DateFormat.yMMMd().format(item.occurredAt)}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${income ? '+' : '-'}${money(item.amount)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: income
                                      ? Colors.green.shade700
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    _open(item);
                                  } else {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text(
                                          context.l10n.phrase(
                                            'Delete transaction?',
                                          ),
                                        ),
                                        content: Text(
                                          '${context.l10n.phrase('Delete')} “${item.description}”?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text(
                                              context.l10n.phrase('Cancel'),
                                            ),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text(
                                              context.l10n.phrase('Delete'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await ref
                                          .read(expenseRepositoryProvider)
                                          .delete(item.id!);
                                      _refresh();
                                    }
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(context.l10n.phrase('Edit')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(context.l10n.phrase('Delete')),
                                  ),
                                ],
                              ),
                            ],
                          ),
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

Future<bool?> showFinanceTransactionSheet(
  BuildContext context,
  ExpenseRepository repository, {
  FinanceTransaction? initial,
  TransactionType initialType = TransactionType.expense,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => TransactionSheet(
    repository: repository,
    initial: initial,
    initialType: initialType,
  ),
);

class TransactionSheet extends StatefulWidget {
  const TransactionSheet({
    super.key,
    required this.repository,
    this.initial,
    this.initialType = TransactionType.expense,
  });
  final ExpenseRepository repository;
  final FinanceTransaction? initial;
  final TransactionType initialType;
  @override
  State<TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<TransactionSheet> {
  late TransactionType type;
  late DateTime date;
  late TextEditingController amount;
  late TextEditingController description;
  late TextEditingController note;
  List<ExpenseCategory> categories = [];
  int? categoryId;
  String payment = 'Cash';
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final value = widget.initial;
    type = value?.type ?? widget.initialType;
    date = value?.occurredAt ?? DateTime.now();
    amount = TextEditingController(
      text: value == null ? '' : value.amount.toString(),
    );
    description = TextEditingController(text: value?.description);
    note = TextEditingController(text: value?.note);
    payment = value?.paymentMethod ?? 'Cash';
    _loadCategories(value?.categoryId);
  }

  Future<void> _loadCategories([int? selected]) async {
    final values = await widget.repository.categories(type);
    if (!mounted) return;
    setState(() {
      categories = values;
      categoryId = selected != null && values.any((c) => c.id == selected)
          ? selected
          : values.firstOrNull?.id;
    });
  }

  @override
  void dispose() {
    amount.dispose();
    description.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = double.tryParse(amount.text.trim());
    if (parsed == null ||
        parsed <= 0 ||
        description.text.trim().isEmpty ||
        categoryId == null) {
      setState(
        () => error = 'Enter a positive amount, description and category.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final category = categories.firstWhere((c) => c.id == categoryId);
      await widget.repository.save(
        FinanceTransaction(
          id: widget.initial?.id,
          type: type,
          amount: parsed,
          categoryId: category.id,
          categoryName: category.name,
          occurredAt: date,
          description: description.text,
          paymentMethod: payment,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
        ),
      );
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
                widget.initial == null ? 'Add transaction' : 'Edit transaction',
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
        SizedBox(height: 12),
        SegmentedButton<TransactionType>(
          segments: [
            ButtonSegment(
              value: TransactionType.expense,
              label: Text(context.l10n.phrase('Expense')),
              icon: Icon(Icons.north_east),
            ),
            ButtonSegment(
              value: TransactionType.income,
              label: Text(context.l10n.phrase('Income')),
              icon: Icon(Icons.south_west),
            ),
          ],
          selected: {type},
          onSelectionChanged: (value) {
            setState(() => type = value.first);
            _loadCategories();
          },
        ),
        SizedBox(height: 14),
        TextField(
          controller: amount,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Amount'),
            prefixText: 'Rs. ',
          ),
        ),
        SizedBox(height: 14),
        TextField(
          controller: description,
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Description'),
          ),
        ),
        SizedBox(height: 14),
        DropdownButtonFormField<int>(
          key: ValueKey('category-${type.name}-$categoryId'),
          initialValue: categoryId,
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Category'),
          ),
          items: categories
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(context.l10n.phrase(c.name)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => categoryId = value),
        ),
        SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: payment,
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Payment method'),
          ),
          items: ['Cash', 'Bank', 'Card', 'Easypaisa', 'JazzCash', 'Other']
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(context.l10n.phrase(value)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => payment = value ?? payment),
        ),
        SizedBox(height: 14),
        ListTile(
          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Icon(Icons.calendar_today),
          title: Text(context.l10n.phrase('Date')),
          subtitle: Text(DateFormat.yMMMd().format(date)),
          onTap: () async {
            final selected = await showDatePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(Duration(days: 1)),
              initialDate: date,
            );
            if (selected != null) setState(() => date = selected);
          },
        ),
        SizedBox(height: 14),
        TextField(
          controller: note,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: context.l10n.phrase('Note (optional)'),
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
          onPressed: saving ? null : _save,
          child: Text(context.l10n.phrase(saving ? 'Saving…' : 'Save')),
        ),
      ],
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.phrase(label),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      SizedBox(height: 4),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ],
  );
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64),
          SizedBox(height: 14),
          Text(
            context.l10n.phrase('No transactions yet'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            context.l10n.phrase(
              'Add income or an expense to begin your monthly overview.',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        TextButton(
          onPressed: onRetry,
          child: Text(context.l10n.phrase('Try again')),
        ),
      ],
    ),
  );
}
