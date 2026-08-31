import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../home/presentation/dashboard_provider.dart';
import '../data/personal_finance_repository.dart';
import '../domain/personal_finance_models.dart';

class PersonalFinanceCenterScreen extends ConsumerStatefulWidget {
  const PersonalFinanceCenterScreen({super.key});
  @override
  ConsumerState<PersonalFinanceCenterScreen> createState() =>
      _PersonalFinanceCenterScreenState();
}

class _PersonalFinanceCenterScreenState
    extends ConsumerState<PersonalFinanceCenterScreen> {
  int section = 0;
  late Future<
    (
      List<SalaryBreakdown>,
      List<FreelancerIncomeRecord>,
      List<HouseholdBill>,
      EmergencyFundStatus,
    )
  >
  data;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    final repository = ref.read(personalFinanceRepositoryProvider);
    data = _load(repository);
  }

  Future<
    (
      List<SalaryBreakdown>,
      List<FreelancerIncomeRecord>,
      List<HouseholdBill>,
      EmergencyFundStatus,
    )
  >
  _load(PersonalFinanceRepository repository) async {
    final salaries = await repository.salaries();
    final freelancer = await repository.freelancerIncome();
    final bills = await repository.bills();
    final emergency = await repository.emergencyFundStatus();
    return (salaries, freelancer, bills, emergency);
  }

  void refresh() {
    setState(reload);
    ref.invalidate(homeDashboardProvider);
  }

  String money(num value) =>
      'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.phrase('Personal Finance Center')),
      actions: [
        IconButton(
          tooltip: context.l10n.phrase('Financial calendar'),
          onPressed: () => context.push('/history'),
          icon: const Icon(Icons.calendar_month_outlined),
        ),
        IconButton(
          tooltip: context.l10n.phrase('Net worth'),
          onPressed: () => context.push('/advanced'),
          icon: const Icon(Icons.account_balance_wallet_outlined),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        if (section == 0) await _salaryDialog();
        if (section == 1) await _freelancerDialog();
        if (section == 2) await _billDialog();
        if (section == 3) await _emergencyDialog();
      },
      icon: Icon(section == 3 ? Icons.tune : Icons.add),
      label: Text(context.l10n.phrase(section == 3 ? 'Configure' : 'Add')),
    ),
    body: Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [
              for (final entry in const [
                'Salary',
                'Freelancer',
                'Bills',
                'Emergency Fund',
              ].indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(context.l10n.phrase(entry.$2)),
                    selected: section == entry.$1,
                    onSelected: (_) => setState(() => section = entry.$1),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return _ErrorState(onRetry: refresh);
              final value = snapshot.data!;
              return switch (section) {
                0 => _SalaryList(items: value.$1, money: money),
                1 => _FreelancerList(items: value.$2, money: money),
                2 => _BillList(
                  items: value.$3,
                  money: money,
                  onPay: (bill) => _payBill(bill),
                ),
                _ => _EmergencyView(
                  status: value.$4,
                  money: money,
                  onOpenNetWorth: () => context.push('/advanced'),
                ),
              };
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _salaryDialog() async {
    final values = List.generate(9, (_) => TextEditingController());
    final result = await showDialog<List<double>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.phrase('Record salary')),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (final entry in const [
                  'Basic Salary',
                  'House Allowance',
                  'Medical',
                  'Transport',
                  'Bonus',
                  'Commission',
                  'Other Allowances',
                  'Tax',
                  'Other deductions',
                ].indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: values[entry.$1],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.l10n.phrase(entry.$2),
                        prefixText: 'Rs. ',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final parsed = values
                  .map(
                    (item) =>
                        double.tryParse(item.text.replaceAll(',', '')) ?? 0,
                  )
                  .toList();
              if (parsed.first > 0) Navigator.pop(context, parsed);
            },
            child: Text(context.l10n.phrase('Save')),
          ),
        ],
      ),
    );
    for (final controller in values) {
      controller.dispose();
    }
    if (result == null) return;
    await ref
        .read(personalFinanceRepositoryProvider)
        .saveSalary(
          SalaryBreakdown(
            basicSalary: result[0],
            houseAllowance: result[1],
            medicalAllowance: result[2],
            transportAllowance: result[3],
            bonus: result[4],
            commission: result[5],
            otherAllowances: result[6],
            tax: result[7],
            otherDeductions: result[8],
            receivedAt: DateTime.now(),
          ),
        );
    refresh();
  }

  Future<void> _freelancerDialog() async {
    final client = TextEditingController();
    final amount = TextEditingController();
    final rate = TextEditingController();
    final fees = TextEditingController();
    var currency = 'USD';
    var status = FreelancerPaymentStatus.expected;
    final result = await showDialog<FreelancerIncomeRecord>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.phrase('Freelancer income')),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: client,
                    decoration: InputDecoration(
                      labelText: context.l10n.phrase('Client'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: amount,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.l10n.phrase('Amount'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField(
                          initialValue: currency,
                          items:
                              const ['USD', 'GBP', 'EUR', 'AED', 'SAR', 'PKR']
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (value) => currency = value!,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rate,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.phrase('PKR exchange rate'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fees,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.phrase('Fees'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    initialValue: status,
                    decoration: InputDecoration(
                      labelText: context.l10n.phrase('Payment status'),
                    ),
                    items: FreelancerPaymentStatus.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(context.l10n.phrase(value.name)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setDialogState(() => status = value!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.phrase('Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final gross = double.tryParse(amount.text);
                final exchange = double.tryParse(rate.text);
                if (client.text.trim().isNotEmpty &&
                    gross != null &&
                    gross > 0 &&
                    exchange != null &&
                    exchange > 0) {
                  Navigator.pop(
                    context,
                    FreelancerIncomeRecord(
                      client: client.text,
                      grossAmount: gross,
                      currency: currency,
                      exchangeRate: exchange,
                      fees: double.tryParse(fees.text) ?? 0,
                      status: status,
                      expectedAt: DateTime.now(),
                      receivedAt: status == FreelancerPaymentStatus.received
                          ? DateTime.now()
                          : null,
                    ),
                  );
                }
              },
              child: Text(context.l10n.phrase('Save')),
            ),
          ],
        ),
      ),
    );
    client.dispose();
    amount.dispose();
    rate.dispose();
    fees.dispose();
    if (result != null) {
      await ref.read(personalFinanceRepositoryProvider).saveFreelancer(result);
      refresh();
    }
  }

  Future<void> _billDialog() async {
    final provider = TextEditingController();
    final amount = TextEditingController();
    var type = 'Electricity';
    var due = DateTime.now().add(const Duration(days: 7));
    final result = await showDialog<HouseholdBill>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.phrase('Add bill')),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField(
                  initialValue: type,
                  items:
                      const [
                            'Electricity',
                            'Gas',
                            'Internet',
                            'Mobile',
                            'Water',
                            'Rent',
                            'School Fees',
                            'Loan Installment',
                            'Subscription',
                            'Custom',
                          ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(context.l10n.phrase(value)),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => type = value!,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: provider,
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Provider'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Amount'),
                    prefixText: 'Rs. ',
                  ),
                ),
                ListTile(
                  title: Text(context.l10n.phrase('Due date')),
                  subtitle: Text(DateFormat.yMMMd().format(due)),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: due,
                    );
                    if (selected != null) setDialogState(() => due = selected);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.phrase('Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(amount.text);
                if (provider.text.trim().isNotEmpty &&
                    parsed != null &&
                    parsed >= 0) {
                  Navigator.pop(
                    context,
                    HouseholdBill(
                      type: type,
                      provider: provider.text,
                      amount: parsed,
                      dueDate: due,
                      status: BillStatus.unpaid,
                    ),
                  );
                }
              },
              child: Text(context.l10n.phrase('Save')),
            ),
          ],
        ),
      ),
    );
    provider.dispose();
    amount.dispose();
    if (result != null) {
      await ref.read(personalFinanceRepositoryProvider).saveBill(result);
      refresh();
    }
  }

  Future<void> _payBill(HouseholdBill bill) async {
    final amount = TextEditingController(text: bill.amount.toStringAsFixed(0));
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.phrase('Record bill payment')),
        content: TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: 'Rs. ',
            labelText: context.l10n.phrase('Amount'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(amount.text);
              if (parsed != null && parsed > 0) Navigator.pop(context, parsed);
            },
            child: Text(context.l10n.phrase('Confirm')),
          ),
        ],
      ),
    );
    amount.dispose();
    if (value != null) {
      await ref
          .read(personalFinanceRepositoryProvider)
          .payBill(bill.id!, value, DateTime.now());
      refresh();
    }
  }

  Future<void> _emergencyDialog() async {
    final months = TextEditingController(text: '3');
    final essential = TextEditingController();
    final value = await showDialog<(double, double?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.phrase('Emergency fund target')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: months,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Target months'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: essential,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.phrase(
                  'Essential monthly expenses (optional)',
                ),
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
            onPressed: () {
              final parsed = double.tryParse(months.text);
              if (parsed != null && parsed > 0) {
                Navigator.pop(context, (
                  parsed,
                  double.tryParse(essential.text),
                ));
              }
            },
            child: Text(context.l10n.phrase('Save')),
          ),
        ],
      ),
    );
    months.dispose();
    essential.dispose();
    if (value != null) {
      await ref
          .read(personalFinanceRepositoryProvider)
          .setEmergencyFundTarget(
            targetMonths: value.$1,
            monthlyEssential: value.$2,
          );
      refresh();
    }
  }
}

class _SalaryList extends StatelessWidget {
  const _SalaryList({required this.items, required this.money});
  final List<SalaryBreakdown> items;
  final String Function(num) money;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? _EmptyState(
          icon: Icons.payments_outlined,
          title: 'No salary records yet',
        )
      : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ExpansionTile(
                title: Text(money(item.net)),
                subtitle: Text(DateFormat.yMMMd().format(item.receivedAt)),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  LinearProgressIndicator(
                    value: item.effectiveTaxRate.clamp(0, 1),
                  ),
                  const SizedBox(height: 8),
                  Text('${context.l10n.phrase('Gross')}: ${money(item.gross)}'),
                  Text(
                    '${context.l10n.phrase('Deductions')}: ${money(item.deductions)}',
                  ),
                ],
              ),
            );
          },
        );
}

class _FreelancerList extends StatelessWidget {
  const _FreelancerList({required this.items, required this.money});
  final List<FreelancerIncomeRecord> items;
  final String Function(num) money;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? _EmptyState(icon: Icons.language, title: 'No freelancer income yet')
      : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.public),
                title: Text(item.client),
                subtitle: Text(
                  '${item.grossAmount} ${item.currency} • ${context.l10n.phrase(item.status.name)}',
                ),
                trailing: Text(
                  money(item.pkrNet),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
}

class _BillList extends StatelessWidget {
  const _BillList({
    required this.items,
    required this.money,
    required this.onPay,
  });
  final List<HouseholdBill> items;
  final String Function(num) money;
  final ValueChanged<HouseholdBill> onPay;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? _EmptyState(icon: Icons.receipt_long_outlined, title: 'No bills yet')
      : ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final status = item.statusAt(DateTime.now());
            return Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(item.provider),
                subtitle: Text(
                  '${context.l10n.phrase(item.type)} • ${DateFormat.yMMMd().format(item.dueDate)}',
                ),
                trailing: status == BillStatus.paid
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : FilledButton.tonal(
                        onPressed: () => onPay(item),
                        child: Text(money(item.amount)),
                      ),
              ),
            );
          },
        );
}

class _EmergencyView extends StatelessWidget {
  const _EmergencyView({
    required this.status,
    required this.money,
    required this.onOpenNetWorth,
  });
  final EmergencyFundStatus status;
  final String Function(num) money;
  final VoidCallback onOpenNetWorth;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Text(
                context.l10n.phrase('Emergency fund coverage'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              Text(
                '${status.monthsCovered.toStringAsFixed(1)} ${context.l10n.phrase('months')}',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: status.progress),
              const SizedBox(height: 12),
              Text('${money(status.saved)} / ${money(status.targetAmount)}'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: ListTile(
          onTap: onOpenNetWorth,
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: Text(
            context.l10n.phrase('Add cash or bank savings in Net Worth'),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64),
        const SizedBox(height: 12),
        Text(
          context.l10n.phrase(title),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: Text(context.l10n.phrase('Try again')),
    ),
  );
}
