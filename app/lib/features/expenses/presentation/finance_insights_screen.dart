import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/budget_repository.dart';
import '../data/expense_repository.dart';
import '../data/finance_export_service.dart';
import '../domain/budget_analytics.dart';
import '../domain/finance_transaction.dart';

class FinanceInsightsScreen extends ConsumerStatefulWidget {
  const FinanceInsightsScreen({super.key});
  @override
  ConsumerState<FinanceInsightsScreen> createState() =>
      _FinanceInsightsScreenState();
}

class _FinanceInsightsScreenState extends ConsumerState<FinanceInsightsScreen> {
  late Future<
    (
      FinanceSummary,
      MonthlyBudget?,
      List<CategoryTotal>,
      List<CategoryBudgetStatus>,
      List<int>,
    )
  >
  data;
  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<
    (
      FinanceSummary,
      MonthlyBudget?,
      List<CategoryTotal>,
      List<CategoryBudgetStatus>,
      List<int>,
    )
  >
  _load() async {
    final now = DateTime.now();
    final budgets = ref.read(budgetRepositoryProvider);
    return (
      await ref.read(expenseRepositoryProvider).summary(),
      await budgets.monthly(now),
      await budgets.categoryTotals(now),
      await budgets.categoryBudgets(now),
      await budgets.warningThresholds(),
    );
  }

  void refresh() => setState(() => data = _load());
  Future<void> setBudget() async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.phrase('Monthly budget')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: 'Rs. ',
            labelText: context.l10n.phrase('Budget amount'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: Text(context.l10n.phrase('Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      await ref
          .read(budgetRepositoryProvider)
          .setMonthly(DateTime.now(), value);
      refresh();
    }
  }

  Future<void> setCategoryBudget([CategoryBudgetStatus? current]) async {
    final repository = ref.read(expenseRepositoryProvider);
    final categories = await repository.categories(TransactionType.expense);
    if (!mounted) return;
    var categoryId = current?.categoryId ?? categories.firstOrNull?.id;
    final amount = TextEditingController(
      text: current == null ? '' : current.budget.toStringAsFixed(0),
    );
    final result = await showDialog<(int, double)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.phrase('Category budget')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: categoryId,
                decoration: InputDecoration(
                  labelText: context.l10n.phrase('Category'),
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(context.l10n.phrase(category.name)),
                      ),
                    )
                    .toList(),
                onChanged: current == null
                    ? (value) => setDialogState(() => categoryId = value)
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixText: 'Rs. ',
                  labelText: context.l10n.phrase('Budget amount'),
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
              onPressed: () {
                final value = double.tryParse(amount.text.trim());
                if (categoryId != null && value != null && value > 0) {
                  Navigator.pop(context, (categoryId!, value));
                }
              },
              child: Text(context.l10n.phrase('Save')),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    if (result == null) return;
    await ref
        .read(budgetRepositoryProvider)
        .setCategory(
          month: DateTime.now(),
          categoryId: result.$1,
          amount: result.$2,
        );
    refresh();
  }

  Future<void> configureThresholds(List<int> current) async {
    final selected = current.toSet();
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.phrase('Budget warnings')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final threshold in const [70, 80, 90, 100])
                CheckboxListTile(
                  value: selected.contains(threshold),
                  title: Text('$threshold%'),
                  onChanged: (enabled) => setDialogState(() {
                    if (enabled == true) {
                      selected.add(threshold);
                    } else {
                      selected.remove(threshold);
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.phrase('Cancel')),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, selected),
              child: Text(context.l10n.phrase('Save')),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await ref.read(budgetRepositoryProvider).setWarningThresholds(result);
    refresh();
  }

  Future<void> export(bool pdf) async {
    try {
      final service = ref.read(financeExportServiceProvider);
      final file = pdf ? await service.pdfReport() : await service.csv();
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(context.l10n.phrase('Export complete')),
            content: SelectableText(file.path),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.phrase('Done')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.phrase('Export failed')}: $e'),
          ),
        );
      }
    }
  }

  String money(num value) =>
      'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.phrase('Budgets & Analytics')),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => export(value == 'pdf'),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'csv',
                child: Text(context.l10n.phrase('Export CSV')),
              ),
              PopupMenuItem(
                value: 'pdf',
                child: Text(context.l10n.phrase('Export PDF')),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: setBudget,
        icon: Icon(Icons.savings_outlined),
        label: Text(context.l10n.phrase('Set budget')),
      ),
      body:
          FutureBuilder<
            (
              FinanceSummary,
              MonthlyBudget?,
              List<CategoryTotal>,
              List<CategoryBudgetStatus>,
              List<int>,
            )
          >(
            future: data,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              final (summary, budget, categories, categoryBudgets, thresholds) =
                  snapshot.data!;
              final rawProgress = budget == null
                  ? 0.0
                  : (summary.monthExpense / budget.amount)
                        .clamp(0.0, double.infinity)
                        .toDouble();
              final progress = rawProgress.clamp(0.0, 1.0).toDouble();
              final maxCategory = categories.isEmpty
                  ? 1.0
                  : categories.first.amount;
              return ListView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.phrase('Monthly budget'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: 8),
                          Text(
                            budget == null
                                ? context.l10n.phrase('Not set')
                                : '${money(summary.monthExpense)} ${context.l10n.phrase('of')} ${money(budget.amount)}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          if (budget != null)
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                rawProgress > 1
                                    ? '${context.l10n.phrase('Budget exceeded by')} ${money(summary.monthExpense - budget.amount)}'
                                    : '${money(budget.amount - summary.monthExpense)} ${context.l10n.phrase('remaining')}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.phrase('Category budgets'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.phrase('Budget warnings'),
                        onPressed: () => configureThresholds(thresholds),
                        icon: const Icon(Icons.notifications_active_outlined),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: setCategoryBudget,
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.phrase('Add')),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  if (categoryBudgets.isEmpty)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Column(
                          children: [
                            Icon(Icons.pie_chart_outline_rounded, size: 38),
                            SizedBox(height: 10),
                            Text(
                              context.l10n.phrase('No category budgets yet'),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 5),
                            Text(
                              context.l10n.phrase(
                                'Set limits for categories such as Food, Fuel or Shopping.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...categoryBudgets.map(
                      (item) => Card(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 8, 14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      context.l10n.phrase(item.category),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (action) async {
                                      if (action == 'edit') {
                                        setCategoryBudget(item);
                                      } else {
                                        await ref
                                            .read(budgetRepositoryProvider)
                                            .deleteCategory(item.budgetId!);
                                        refresh();
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(
                                          context.l10n.phrase('Edit'),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          context.l10n.phrase('Delete'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              LinearProgressIndicator(
                                value: item.progress.clamp(0, 1),
                                minHeight: 9,
                                borderRadius: BorderRadius.circular(99),
                                color: item.exceeded
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                              SizedBox(height: 8),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  item.exceeded
                                      ? '${context.l10n.phrase('Budget exceeded by')} ${money(item.remaining.abs())}'
                                      : '${context.l10n.phrase('Spent')} ${money(item.spent)} • ${context.l10n.phrase('Remaining')} ${money(item.remaining)} • ${(item.progress * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: 24),
                  Text(
                    context.l10n.phrase('Expense by category'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  if (categories.isEmpty)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          context.l10n.phrase(
                            'Add expenses to see category analytics.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...categories.map(
                      (item) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 7),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text(item.category)),
                                Text(
                                  money(item.amount),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: item.amount / maxCategory,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
    );
  }
}
