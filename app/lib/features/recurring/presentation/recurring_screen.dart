import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/finance_transaction.dart';
import '../../home/presentation/dashboard_provider.dart';
import '../data/recurring_repository.dart';
import '../domain/recurring_transaction.dart';

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});
  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  late Future<List<RecurringTransaction>> _items;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _items = ref.read(recurringRepositoryProvider).all();
  void _refresh() => setState(_reload);
  String _money(num value) =>
      'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';

  Future<void> _edit([RecurringTransaction? current]) async {
    final categories = await ref
        .read(expenseRepositoryProvider)
        .categories(current?.type ?? TransactionType.expense);
    if (!mounted) return;
    final amount = TextEditingController(text: current?.amount.toString());
    final description = TextEditingController(text: current?.description);
    var type = current?.type ?? TransactionType.expense;
    var availableCategories = categories;
    var categoryId = current?.categoryId ?? categories.firstOrNull?.id;
    var frequency = current?.frequency ?? RecurringFrequency.monthly;
    var due = current?.nextDueAt ?? DateTime.now();
    final result =
        await showModalBottomSheet<
          (TransactionType, int, double, String, RecurringFrequency, DateTime)
        >(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setSheetState) => Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.phrase('Recurring transaction'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<TransactionType>(
                      segments: [
                        ButtonSegment(
                          value: TransactionType.expense,
                          label: Text(context.l10n.phrase('Expense')),
                        ),
                        ButtonSegment(
                          value: TransactionType.income,
                          label: Text(context.l10n.phrase('Income')),
                        ),
                      ],
                      selected: {type},
                      onSelectionChanged: current == null
                          ? (value) async {
                              type = value.first;
                              final updated = await ref
                                  .read(expenseRepositoryProvider)
                                  .categories(type);
                              setSheetState(() {
                                availableCategories = updated;
                                categoryId = updated.firstOrNull?.id;
                              });
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: description,
                      decoration: InputDecoration(
                        labelText: context.l10n.phrase('Description'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: 'Rs. ',
                        labelText: context.l10n.phrase('Amount'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: categoryId,
                      decoration: InputDecoration(
                        labelText: context.l10n.phrase('Category'),
                      ),
                      items: availableCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(context.l10n.phrase(category.name)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => categoryId = value,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<RecurringFrequency>(
                      initialValue: frequency,
                      decoration: InputDecoration(
                        labelText: context.l10n.phrase('Frequency'),
                      ),
                      items: RecurringFrequency.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(context.l10n.phrase(value.name)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => frequency = value ?? frequency,
                    ),
                    ListTile(
                      title: Text(context.l10n.phrase('Next due date')),
                      subtitle: Text(DateFormat.yMMMd().format(due)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                          initialDate: due,
                        );
                        if (selected != null) {
                          setSheetState(() => due = selected);
                        }
                      },
                    ),
                    FilledButton(
                      onPressed: () {
                        final value = double.tryParse(amount.text);
                        if (value != null &&
                            value > 0 &&
                            categoryId != null &&
                            description.text.trim().isNotEmpty) {
                          Navigator.pop(context, (
                            type,
                            categoryId!,
                            value,
                            description.text,
                            frequency,
                            due,
                          ));
                        }
                      },
                      child: Text(context.l10n.phrase('Save')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    amount.dispose();
    description.dispose();
    if (result == null) return;
    await ref
        .read(recurringRepositoryProvider)
        .save(
          id: current?.id,
          type: result.$1,
          categoryId: result.$2,
          amount: result.$3,
          description: result.$4,
          frequency: result.$5,
          nextDueAt: result.$6,
        );
    _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Recurring transactions'))),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _edit,
      icon: const Icon(Icons.add),
      label: Text(context.l10n.phrase('Add recurring')),
    ),
    body: FutureBuilder<List<RecurringTransaction>>(
      future: _items,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return Center(
            child: Text(context.l10n.phrase('No recurring transactions yet.')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            final due = item.dueAt(DateTime.now());
            return Card(
              child: ListTile(
                onTap: () => _edit(item),
                leading: const Icon(Icons.autorenew_rounded),
                title: Text(item.description),
                subtitle: Text(
                  '${context.l10n.phrase(item.frequency.name)} • ${DateFormat.yMMMd().format(item.nextDueAt)}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    final repository = ref.read(recurringRepositoryProvider);
                    if (action == 'confirm') {
                      await repository.confirmOccurrence(item);
                      ref.invalidate(homeDashboardProvider);
                    } else if (action == 'status') {
                      await repository.setStatus(
                        item.id,
                        item.status == RecurringStatus.active
                            ? RecurringStatus.paused
                            : RecurringStatus.active,
                      );
                    } else if (action == 'delete') {
                      await repository.delete(item.id);
                    } else {
                      await _edit(item);
                    }
                    _refresh();
                  },
                  itemBuilder: (_) => [
                    if (due)
                      PopupMenuItem(
                        value: 'confirm',
                        child: Text(
                          '${context.l10n.phrase('Confirm')} ${_money(item.amount)}',
                        ),
                      ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(context.l10n.phrase('Edit')),
                    ),
                    PopupMenuItem(
                      value: 'status',
                      child: Text(
                        context.l10n.phrase(
                          item.status == RecurringStatus.active
                              ? 'Pause'
                              : 'Resume',
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.l10n.phrase('Delete')),
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
