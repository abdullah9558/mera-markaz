import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../data/savings_repository.dart';
import '../domain/savings_goal.dart';

class SavingsScreen extends ConsumerStatefulWidget {
  const SavingsScreen({super.key});
  @override
  ConsumerState<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends ConsumerState<SavingsScreen> {
  late Future<List<SavingsGoal>> _goals;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _goals = ref
      .read(savingsRepositoryProvider)
      .goals(includeArchived: _showArchived);
  String _money(num value) =>
      'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';

  Future<void> _edit([SavingsGoal? goal]) async {
    final changed = await showGoalEditor(
      context,
      ref.read(savingsRepositoryProvider),
      goal: goal,
    );
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.phrase('Savings goals')),
      actions: [
        IconButton(
          tooltip: context.l10n.phrase(
            _showArchived ? 'Hide archived goals' : 'Show archived goals',
          ),
          onPressed: () => setState(() {
            _showArchived = !_showArchived;
            _reload();
          }),
          icon: Icon(
            _showArchived ? Icons.inventory : Icons.inventory_2_outlined,
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _edit,
      icon: const Icon(Icons.add),
      label: Text(context.l10n.phrase('Create goal')),
    ),
    body: FutureBuilder<List<SavingsGoal>>(
      future: _goals,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.phrase('Retry')),
            ),
          );
        }
        final goals = snapshot.data!;
        if (goals.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.savings_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.phrase('No savings goals yet'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.phrase(
                      "Create a goal for something you're working toward.",
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _edit,
                    child: Text(context.l10n.phrase('Create goal')),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_reload),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
            itemCount: goals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final goal = goals[index];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SavingsGoalDetailScreen(goalId: goal.id),
                      ),
                    );
                    if (mounted) setState(_reload);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              goal.icon ?? '🎯',
                              style: const TextStyle(fontSize: 30),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                goal.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (goal.status == SavingsGoalStatus.completed)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        LinearProgressIndicator(
                          value: goal.progress.clamp(0, 1),
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${_money(goal.savedAmount)} / ${_money(goal.targetAmount)} • ${(goal.progress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.l10n.phrase('Remaining')}: ${_money(goal.remaining)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class SavingsGoalDetailScreen extends ConsumerStatefulWidget {
  const SavingsGoalDetailScreen({super.key, required this.goalId});
  final int goalId;
  @override
  ConsumerState<SavingsGoalDetailScreen> createState() =>
      _SavingsGoalDetailScreenState();
}

class _SavingsGoalDetailScreenState
    extends ConsumerState<SavingsGoalDetailScreen> {
  late Future<(SavingsGoal, List<GoalContribution>)> _data;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repository = ref.read(savingsRepositoryProvider);
    _data =
        Future.wait<Object>([
          repository.goal(widget.goalId),
          repository.contributions(widget.goalId),
        ]).then(
          (values) =>
              (values[0] as SavingsGoal, values[1] as List<GoalContribution>),
        );
  }

  String _money(num value) =>
      'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';

  Future<void> _contribute(SavingsGoal goal, {required bool withdrawal}) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final result = await showModalBottomSheet<(double, String?)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          20,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.phrase(
                withdrawal ? 'Withdraw savings' : 'Add contribution',
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: 'Rs. ',
                labelText: context.l10n.phrase('Amount'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Note (optional)'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(amount.text.trim());
                if (parsed != null && parsed > 0) {
                  Navigator.pop(context, (
                    withdrawal ? -parsed : parsed,
                    note.text.trim(),
                  ));
                }
              },
              child: Text(context.l10n.phrase('Confirm')),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    note.dispose();
    if (result == null) return;
    try {
      await ref
          .read(savingsRepositoryProvider)
          .addContribution(
            goalId: goal.id,
            amount: result.$1,
            date: DateTime.now(),
            note: result.$2,
          );
      if (mounted) setState(_reload);
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.phrase(error.message))),
        );
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<(SavingsGoal, List<GoalContribution>)>(
    future: _data,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final (goal, contributions) = snapshot.data!;
      final forecast = GoalForecast.calculate(
        goal: goal,
        contributions: contributions,
      );
      return Scaffold(
        appBar: AppBar(
          title: Text(goal.name),
          actions: [
            PopupMenuButton<String>(
              onSelected: (action) async {
                final repository = ref.read(savingsRepositoryProvider);
                if (action == 'edit') {
                  await showGoalEditor(context, repository, goal: goal);
                } else if (action == 'restore') {
                  await repository.setStatus(goal.id, SavingsGoalStatus.active);
                } else if (action == 'complete') {
                  await repository.setStatus(
                    goal.id,
                    SavingsGoalStatus.completed,
                  );
                } else if (action == 'archive') {
                  await repository.setStatus(
                    goal.id,
                    SavingsGoalStatus.archived,
                  );
                  if (context.mounted) Navigator.pop(context);
                  return;
                }
                if (mounted) setState(_reload);
              },
              itemBuilder: (_) => [
                if (goal.status == SavingsGoalStatus.archived)
                  PopupMenuItem(
                    value: 'restore',
                    child: Text(context.l10n.phrase('Restore goal')),
                  ),
                PopupMenuItem(
                  value: 'edit',
                  child: Text(context.l10n.phrase('Edit goal')),
                ),
                PopupMenuItem(
                  value: 'complete',
                  child: Text(context.l10n.phrase('Complete goal')),
                ),
                if (goal.status != SavingsGoalStatus.archived)
                  PopupMenuItem(
                    value: 'archive',
                    child: Text(context.l10n.phrase('Archive goal')),
                  ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Text(
                      goal.icon ?? '🎯',
                      style: const TextStyle(fontSize: 46),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_money(goal.savedAmount)} / ${_money(goal.targetAmount)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: goal.progress.clamp(0, 1),
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${(goal.progress * 100).toStringAsFixed(0)}% ${context.l10n.phrase('complete')}',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: goal.status == SavingsGoalStatus.archived
                                ? null
                                : () => _contribute(goal, withdrawal: false),
                            icon: const Icon(Icons.add),
                            label: Text(context.l10n.phrase('Contribute')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                goal.savedAmount <= 0 ||
                                    goal.status == SavingsGoalStatus.archived
                                ? null
                                : () => _contribute(goal, withdrawal: true),
                            icon: const Icon(Icons.remove),
                            label: Text(context.l10n.phrase('Withdraw')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.phrase('Savings forecast'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      forecast.estimatedMonths == null
                          ? context.l10n.phrase(
                              'Add more contribution history to estimate completion.',
                            )
                          : '${context.l10n.phrase('Estimated time at your current rate')}: ${forecast.estimatedMonths} ${context.l10n.phrase('months')}.',
                    ),
                    if (forecast.requiredMonthlySavings != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${context.l10n.phrase('Required monthly saving')}: ${_money(forecast.requiredMonthlySavings!)}',
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.phrase(
                        'Forecasts are estimates based on recorded contributions.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.phrase('Contribution history'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (contributions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    context.l10n.phrase('No contributions recorded yet.'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...contributions.map(
                (entry) => Card(
                  child: ListTile(
                    leading: Icon(
                      entry.isWithdrawal
                          ? Icons.remove_circle_outline
                          : Icons.add_circle_outline,
                    ),
                    title: Text(
                      '${entry.isWithdrawal ? '−' : '+'} ${_money(entry.amount.abs())}',
                    ),
                    subtitle: Text(
                      '${DateFormat.yMMMd().format(entry.contributedAt)}${entry.note == null ? '' : ' • ${entry.note}'}',
                    ),
                    trailing: IconButton(
                      tooltip: context.l10n.phrase('Delete'),
                      onPressed: () async {
                        await ref
                            .read(savingsRepositoryProvider)
                            .deleteContribution(entry.id);
                        if (mounted) setState(_reload);
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Future<bool?> showGoalEditor(
  BuildContext context,
  SavingsRepository repository, {
  SavingsGoal? goal,
}) {
  final name = TextEditingController(text: goal?.name);
  final target = TextEditingController(
    text: goal == null ? '' : goal.targetAmount.toStringAsFixed(0),
  );
  final notes = TextEditingController(text: goal?.notes);
  var targetDate = goal?.targetDate;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          20,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.phrase(goal == null ? 'Create goal' : 'Edit goal'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: context.l10n.phrase('Goal name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: target,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixText: 'Rs. ',
                  labelText: context.l10n.phrase('Target amount'),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(context.l10n.phrase('Target date')),
                subtitle: Text(
                  targetDate == null
                      ? context.l10n.phrase('Optional')
                      : DateFormat.yMMMd().format(targetDate!),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: targetDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (selected != null) {
                    setSheetState(() => targetDate = selected);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.l10n.phrase('Notes (optional)'),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(target.text.trim());
                  if (amount == null ||
                      amount <= 0 ||
                      name.text.trim().isEmpty) {
                    return;
                  }
                  await repository.saveGoal(
                    id: goal?.id,
                    name: name.text,
                    icon: goal?.icon ?? '🎯',
                    targetAmount: amount,
                    targetDate: targetDate,
                    notes: notes.text,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: Text(context.l10n.phrase('Save goal')),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    name.dispose();
    target.dispose();
    notes.dispose();
  });
}
