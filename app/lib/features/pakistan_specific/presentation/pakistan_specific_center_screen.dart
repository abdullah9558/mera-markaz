import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../data/pakistan_specific_repository.dart';
import '../domain/pakistan_specific_models.dart';

final committeesProvider = FutureProvider(
  (ref) => ref.watch(pakistanSpecificRepositoryProvider).committees(),
);
final householdsProvider = FutureProvider(
  (ref) => ref.watch(pakistanSpecificRepositoryProvider).households(),
);

class PakistanSpecificCenterScreen extends ConsumerWidget {
  const PakistanSpecificCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.phrase('Pakistan Money Center')),
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: context.l10n.phrase('Committee')),
            Tab(text: context.l10n.phrase('Advanced Udhaar')),
            Tab(text: context.l10n.phrase('Household')),
          ],
        ),
      ),
      body: const TabBarView(
        children: [_CommitteeTab(), _UdhaarTab(), _HouseholdTab()],
      ),
    ),
  );
}

class _CommitteeTab extends ConsumerWidget {
  const _CommitteeTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(committeesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createCommittee(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.phrase('New committee')),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => items.isEmpty
            ? _EmptyState(
                icon: Icons.groups_2_outlined,
                title: 'No committees yet',
                message:
                    'Create a committee to track every monthly contribution, payout turn and due date.',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(
                        child: Icon(Icons.groups_2_outlined),
                      ),
                      title: Text(item.name),
                      subtitle: Text(
                        '${_money(item.totalPot)} • ${item.monthCount} ${context.l10n.phrase('months')}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _CommitteeDetail(committee: item),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _CommitteeDetail extends ConsumerStatefulWidget {
  const _CommitteeDetail({required this.committee});
  final Committee committee;
  @override
  ConsumerState<_CommitteeDetail> createState() => _CommitteeDetailState();
}

class _CommitteeDetailState extends ConsumerState<_CommitteeDetail> {
  late Future<List<CommitteePayment>> payments;
  @override
  void initState() {
    super.initState();
    payments = _load();
  }

  Future<List<CommitteePayment>> _load() => ref
      .read(pakistanSpecificRepositoryProvider)
      .committeePayments(widget.committee.id!);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.committee.name)),
    body: FutureBuilder<List<CommitteePayment>>(
      future: payments,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final values = snapshot.data!;
        final paid = values.where((item) => item.status != 'due').length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.phrase('Committee pot')),
                    Text(
                      _money(widget.committee.totalPot),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: values.isEmpty ? 0 : paid / values.length,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$paid / ${values.length} ${context.l10n.phrase('cycles completed')}',
                    ),
                  ],
                ),
              ),
            ),
            ...values.map(
              (payment) => CheckboxListTile(
                value: payment.status != 'due',
                title: Text('${context.l10n.phrase('Cycle')} ${payment.cycle}'),
                subtitle: Text(
                  '${DateFormat.yMMMd().format(payment.dueDate)} • ${_money(payment.amount)}',
                ),
                secondary: Icon(
                  payment.status == 'received'
                      ? Icons.savings_outlined
                      : Icons.payments_outlined,
                ),
                onChanged: (value) async {
                  await ref
                      .read(pakistanSpecificRepositoryProvider)
                      .markCommitteePayment(payment.id, paid: value ?? false);
                  setState(() => payments = _load());
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _UdhaarTab extends StatelessWidget {
  const _UdhaarTab();
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Icon(Icons.handshake_outlined, size: 64),
      const SizedBox(height: 16),
      Text(
        context.l10n.phrase('Advanced Udhaar'),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Text(
        context.l10n.phrase(
          'Keep a complete repayment history, track partial payments and create installment schedules for every ledger entry.',
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      for (final feature in const [
        ('Partial payment history', Icons.history),
        ('Monthly installment plans', Icons.calendar_month_outlined),
        (
          'Due-date and overdue tracking',
          Icons.notification_important_outlined,
        ),
        ('Private by default', Icons.lock_outline),
      ])
        Card(
          child: ListTile(
            leading: Icon(feature.$2),
            title: Text(context.l10n.phrase(feature.$1)),
          ),
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => context.go('/udhaar'),
        icon: const Icon(Icons.open_in_new),
        label: Text(context.l10n.phrase('Open Udhaar ledger')),
      ),
    ],
  );
}

class _HouseholdTab extends ConsumerWidget {
  const _HouseholdTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createHousehold(context, ref),
        icon: const Icon(Icons.add_home_outlined),
        label: Text(context.l10n.phrase('New household')),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(context.l10n.phrase('Private by default')),
                subtitle: Text(
                  context.l10n.phrase(
                    'Nothing is shared automatically. Choose a household explicitly for each supported record.',
                  ),
                ),
              ),
            ),
            if (items.isEmpty)
              const _EmptyState(
                icon: Icons.home_outlined,
                title: 'No household yet',
                message: 'Create a household before sharing selected records.',
              ),
            ...items.map(
              (item) => Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.home_outlined),
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.members.length} ${context.l10n.phrase('members')}',
                  ),
                  children: [
                    ...item.members.map(
                      (member) => ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(member.name),
                        subtitle: Text(
                          member.email ?? context.l10n.phrase('Local member'),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_add_alt),
                      title: Text(context.l10n.phrase('Add member')),
                      onTap: () => _addMember(context, ref, item.id),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
    child: Column(
      children: [
        Icon(icon, size: 58),
        const SizedBox(height: 14),
        Text(
          context.l10n.phrase(title),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(context.l10n.phrase(message), textAlign: TextAlign.center),
      ],
    ),
  );
}

Future<void> _createCommittee(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final monthly = TextEditingController();
  final members = TextEditingController(text: '5');
  final months = TextEditingController(text: '5');
  final turn = TextEditingController();
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.phrase('New committee')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Committee name'),
              ),
            ),
            TextField(
              controller: monthly,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Monthly contribution'),
              ),
            ),
            TextField(
              controller: members,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Members'),
              ),
            ),
            TextField(
              controller: months,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Months'),
              ),
            ),
            TextField(
              controller: turn,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Your payout turn (optional)'),
              ),
            ),
          ],
        ),
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
  );
  if (accepted == true && context.mounted) {
    try {
      await ref
          .read(pakistanSpecificRepositoryProvider)
          .createCommittee(
            Committee(
              name: name.text,
              monthlyContribution: double.tryParse(monthly.text) ?? 0,
              memberCount: int.tryParse(members.text) ?? 0,
              monthCount: int.tryParse(months.text) ?? 0,
              startDate: DateTime.now(),
              userTurn: int.tryParse(turn.text),
            ),
          );
      ref.invalidate(committeesProvider);
    } on FormatException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
  name.dispose();
  monthly.dispose();
  members.dispose();
  months.dispose();
  turn.dispose();
}

Future<void> _createHousehold(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.phrase('New household')),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: context.l10n.phrase('Household name'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.l10n.phrase('Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text),
          child: Text(context.l10n.phrase('Create')),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value != null && value.trim().isNotEmpty) {
    await ref.read(pakistanSpecificRepositoryProvider).createHousehold(value);
    ref.invalidate(householdsProvider);
  }
}

Future<void> _addMember(
  BuildContext context,
  WidgetRef ref,
  int householdId,
) async {
  final name = TextEditingController();
  final email = TextEditingController();
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.phrase('Add member')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: InputDecoration(labelText: context.l10n.phrase('Name')),
          ),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Email (optional)'),
            ),
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
          child: Text(context.l10n.phrase('Add')),
        ),
      ],
    ),
  );
  if (accepted == true && name.text.trim().isNotEmpty) {
    await ref
        .read(pakistanSpecificRepositoryProvider)
        .addMember(householdId, name: name.text, email: email.text);
    ref.invalidate(householdsProvider);
  }
  name.dispose();
  email.dispose();
}

String _money(double value) =>
    NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 0).format(value);
