import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../home/presentation/dashboard_provider.dart';
import '../../personal_finance/data/personal_finance_repository.dart';
import '../data/advanced_finance_repository.dart';
import '../domain/advanced_finance_models.dart';

class AdvancedFinanceScreen extends ConsumerStatefulWidget {
  const AdvancedFinanceScreen({super.key});
  @override
  ConsumerState<AdvancedFinanceScreen> createState() => _AdvancedFinanceState();
}

class _AdvancedFinanceState extends ConsumerState<AdvancedFinanceScreen> {
  int section = 0;
  String money(num value) =>
      'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Advanced Finance Center'))),
    body: Column(
      children: [
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final item in const [
                'Financing',
                'Inflation',
                'Financial Health',
              ].indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(context.l10n.phrase(item.$2)),
                    selected: section == item.$1,
                    onSelected: (_) => setState(() => section = item.$1),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (section) {
            0 => _FinancingView(money: money),
            1 => _InflationView(money: money),
            _ => _HealthView(money: money),
          },
        ),
      ],
    ),
  );
}

class _FinancingView extends ConsumerStatefulWidget {
  const _FinancingView({required this.money});
  final String Function(num) money;
  @override
  ConsumerState<_FinancingView> createState() => _FinancingViewState();
}

class _FinancingViewState extends ConsumerState<_FinancingView> {
  final amount = TextEditingController(),
      down = TextEditingController(),
      rate = TextEditingController(text: '14'),
      kibor = TextEditingController(text: '11'),
      spread = TextEditingController(text: '3'),
      months = TextEditingController(text: '36');
  FinancingRateType type = FinancingRateType.fixed;
  FinancingResult? result;
  Future<void> calculate() async {
    try {
      final input = FinancingInput(
        amount: double.parse(amount.text),
        downPayment: double.tryParse(down.text) ?? 0,
        annualRate: double.parse(rate.text),
        months: int.parse(months.text),
        rateType: type,
        kiborRate: type == FinancingRateType.variable
            ? double.parse(kibor.text)
            : null,
        spread: type == FinancingRateType.variable
            ? double.parse(spread.text)
            : 0,
      );
      final calculated = FinancingCalculator.calculate(input);
      setState(() => result = calculated);
      await ref
          .read(advancedFinanceRepositoryProvider)
          .saveFinancing(
            name:
                '${context.l10n.phrase('Financing scenario')} ${DateFormat.Hm().format(DateTime.now())}',
            financingType: 'custom',
            input: input,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.phrase('Enter valid financing values')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
    children: [
      _Intro(
        icon: Icons.account_balance_outlined,
        title: 'Compare financing clearly',
        body:
            'Model fixed rates or KIBOR plus spread. Results are estimates, not a lender offer.',
      ),
      SegmentedButton<FinancingRateType>(
        segments: [
          ButtonSegment(
            value: FinancingRateType.fixed,
            label: Text(context.l10n.phrase('Fixed rate')),
          ),
          ButtonSegment(
            value: FinancingRateType.variable,
            label: Text(context.l10n.phrase('KIBOR + spread')),
          ),
        ],
        selected: {type},
        onSelectionChanged: (v) => setState(() => type = v.first),
      ),
      _Number(controller: amount, label: 'Financing amount'),
      _Number(controller: down, label: 'Down payment'),
      if (type == FinancingRateType.fixed)
        _Number(controller: rate, label: 'Annual rate (%)')
      else ...[
        _Number(controller: kibor, label: 'KIBOR (%)'),
        _Number(controller: spread, label: 'Bank spread (%)'),
      ],
      _Number(controller: months, label: 'Tenure (months)'),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: calculate,
        icon: const Icon(Icons.calculate_outlined),
        label: Text(context.l10n.phrase('Calculate and save')),
      ),
      if (result != null) ...[
        const SizedBox(height: 12),
        _Metric(
          title: 'Monthly installment',
          value: widget.money(result!.monthlyPayment),
          icon: Icons.calendar_month_outlined,
        ),
        _Metric(
          title: 'Total repayment',
          value: widget.money(result!.totalRepayment),
          icon: Icons.payments_outlined,
        ),
        _Metric(
          title: 'Estimated financing cost',
          value: widget.money(result!.financingCost),
          icon: Icons.trending_up,
        ),
        ExpansionTile(
          title: Text(context.l10n.phrase('Amortization schedule')),
          children: [
            for (final row in result!.schedule.take(12))
              ListTile(
                dense: true,
                title: Text('${context.l10n.phrase('Month')} ${row.month}'),
                subtitle: Text(
                  '${context.l10n.phrase('Principal')}: ${widget.money(row.principal)} • ${context.l10n.phrase('Interest')}: ${widget.money(row.interest)}',
                ),
                trailing: Text(widget.money(row.balance)),
              ),
          ],
        ),
      ],
    ],
  );
}

class _InflationView extends ConsumerStatefulWidget {
  const _InflationView({required this.money});
  final String Function(num) money;
  @override
  ConsumerState<_InflationView> createState() => _InflationViewState();
}

class _InflationViewState extends ConsumerState<_InflationView> {
  final amount = TextEditingController(),
      rate = TextEditingController(text: '8'),
      years = TextEditingController(text: '5');
  InflationCalculationType type = InflationCalculationType.futureScenario;
  PurchasingPowerResult? result;
  Future<void> calculate() async {
    try {
      final count = int.parse(years.text);
      final rates = List.filled(count, double.parse(rate.text));
      final calculated = type == InflationCalculationType.historical
          ? InflationCalculator.historical(
              amount: double.parse(amount.text),
              annualRates: rates,
            )
          : InflationCalculator.futureScenario(
              savings: double.parse(amount.text),
              assumedRates: rates,
            );
      setState(() => result = calculated);
      await ref
          .read(advancedFinanceRepositoryProvider)
          .saveInflation(
            name: context.l10n.phrase(
              type == InflationCalculationType.historical
                  ? 'Historical inflation'
                  : 'Purchasing power scenario',
            ),
            result: calculated,
            rates: rates,
            startYear: DateTime.now().year,
            endYear: DateTime.now().year + count,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.phrase('Enter valid inflation assumptions'),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
    children: [
      _Intro(
        icon: Icons.currency_exchange,
        title: 'Understand purchasing power',
        body:
            'Historical calculations and future assumptions are labelled separately. Future inflation is never presented as known.',
      ),
      SegmentedButton<InflationCalculationType>(
        segments: [
          ButtonSegment(
            value: InflationCalculationType.historical,
            label: Text(context.l10n.phrase('Historical')),
          ),
          ButtonSegment(
            value: InflationCalculationType.futureScenario,
            label: Text(context.l10n.phrase('Future scenario')),
          ),
        ],
        selected: {type},
        onSelectionChanged: (v) => setState(() => type = v.first),
      ),
      _Number(
        controller: amount,
        label: type == InflationCalculationType.historical
            ? 'Past amount'
            : 'Current savings',
      ),
      _Number(
        controller: rate,
        label: type == InflationCalculationType.historical
            ? 'Average annual inflation (%)'
            : 'Assumed annual inflation (%)',
      ),
      _Number(controller: years, label: 'Number of years'),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: calculate,
        icon: const Icon(Icons.show_chart),
        label: Text(context.l10n.phrase('Calculate and save')),
      ),
      if (result != null) ...[
        const SizedBox(height: 12),
        _Metric(
          title: type == InflationCalculationType.historical
              ? 'Approximate value today'
              : 'Estimated purchasing power',
          value: widget.money(result!.adjustedAmount),
          icon: Icons.insights,
        ),
        _Metric(
          title: 'Cumulative inflation',
          value: '${result!.cumulativeInflation.toStringAsFixed(1)}%',
          icon: Icons.percent,
        ),
        SizedBox(height: 160, child: _Bars(values: result!.yearlyValues)),
      ],
    ],
  );
}

class _HealthView extends ConsumerWidget {
  const _HealthView({required this.money});
  final String Function(num) money;
  Future<FinancialHealthResult> load(WidgetRef ref) async {
    final dashboard = await ref.read(homeDashboardProvider.future);
    final emergency = await ref
        .read(personalFinanceRepositoryProvider)
        .emergencyFundStatus();
    final bills = await ref.read(personalFinanceRepositoryProvider).bills();
    final due = bills.where((b) => !b.dueDate.isAfter(DateTime.now())).toList();
    final paid = due.where((b) => b.status.name == 'paid').length;
    final result = FinancialHealthCalculator.calculate(
      FinancialHealthInput(
        monthlyIncome: dashboard.finance.income,
        monthlyExpenses: dashboard.finance.expenses,
        budgetAdherence: dashboard.budget == null
            ? 1
            : (1 - dashboard.budgetProgress.clamp(0, 1)).toDouble(),
        savingsRate: dashboard.finance.savingsRate,
        emergencyMonths: emergency.monthsCovered,
        debtPaymentRate: dashboard.finance.income <= 0
            ? 0
            : dashboard.ledger.toPay / dashboard.finance.income,
        billPaymentRate: due.isEmpty ? 1 : paid / due.length,
      ),
    );
    await ref.read(advancedFinanceRepositoryProvider).saveHealth(result);
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder(
    future: load(ref),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Text(
            context.l10n.phrase(
              'Add income, expenses and preferences to calculate your health score.',
            ),
          ),
        );
      }
      final value = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _Intro(
            icon: Icons.health_and_safety_outlined,
            title: 'Explainable Financial Health',
            body:
                'This score uses only your local finance data and shows every component. It is not an AI credit score.',
          ),
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: value.score / 100,
                    strokeWidth: 16,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${value.score}',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(context.l10n.phrase(value.status)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          for (final item in value.components.entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.phrase(item.key),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(item.value.toStringAsFixed(1)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (item.value / 25).clamp(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          for (final text in value.explanations)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(
                text.startsWith('Your score')
                    ? context.l10n.phrase(text)
                    : '${context.l10n.phrase('Largest improvement opportunity')}: ${context.l10n.phrase(text.split(' is currently').first)}',
              ),
            ),
        ],
      );
    },
  );
}

class _Number extends StatelessWidget {
  const _Number({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: context.l10n.phrase(label)),
    ),
  );
}

class _Intro extends StatelessWidget {
  const _Intro({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(child: Icon(icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.phrase(title),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(context.l10n.phrase(body)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.icon});
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(context.l10n.phrase(title)),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
  );
}

class _Bars extends StatelessWidget {
  const _Bars({required this.values});
  final List<double> values;
  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(1, (m, v) => v > m ? v : m);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final value in values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FractionallySizedBox(
                heightFactor: (value / max).clamp(.05, 1),
                alignment: Alignment.bottomCenter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
