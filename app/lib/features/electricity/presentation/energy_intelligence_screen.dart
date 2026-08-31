import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../data/energy_intelligence_repository.dart';
import '../domain/energy_intelligence.dart';

class EnergyIntelligenceScreen extends ConsumerStatefulWidget {
  const EnergyIntelligenceScreen({super.key});
  @override
  ConsumerState<EnergyIntelligenceScreen> createState() =>
      _EnergyIntelligenceScreenState();
}

class _EnergyIntelligenceScreenState
    extends ConsumerState<EnergyIntelligenceScreen> {
  int section = 0;
  late Future<
    (List<ElectricityReading>, List<ApplianceUsage>, List<SolarSystemProfile>)
  >
  data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    data = _load(ref.read(energyIntelligenceRepositoryProvider));
  }

  Future<
    (List<ElectricityReading>, List<ApplianceUsage>, List<SolarSystemProfile>)
  >
  _load(EnergyIntelligenceRepository repository) async {
    final readings = await repository.readings();
    final appliances = await repository.appliances();
    final systems = await repository.solarSystems();
    return (readings, appliances, systems);
  }

  void _refresh() => setState(_reload);
  String money(num value) =>
      'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Energy Intelligence'))),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        if (section == 0) await _readingDialog();
        if (section == 1) await _applianceDialog();
        if (section == 2) await _readingDialog();
        if (section == 3) await _solarSystemDialog();
      },
      icon: const Icon(Icons.add),
      label: Text(
        context.l10n.phrase(
          section == 0 || section == 2
              ? 'Add reading'
              : section == 1
              ? 'Add appliance'
              : 'Add solar system',
        ),
      ),
    ),
    body: Column(
      children: [
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final item in const [
                'Usage history',
                'Appliances',
                'Solar planner',
                'Solar ROI',
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
          child: FutureBuilder(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _Empty(
                  icon: Icons.error_outline,
                  title: 'Could not load energy data',
                  action: 'Try again',
                  onAction: _refresh,
                );
              }
              final value = snapshot.data!;
              return switch (section) {
                0 => _History(readings: value.$1, money: money),
                1 => _Appliances(items: value.$2, money: money),
                2 => _SolarPlanner(readings: value.$1),
                _ => _SolarRoi(
                  systems: value.$3,
                  repository: ref.read(energyIntelligenceRepositoryProvider),
                  money: money,
                  onSaved: _refresh,
                ),
              };
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _readingDialog() async {
    final provider = TextEditingController(text: 'LESCO');
    final units = TextEditingController();
    final previous = TextEditingController();
    final current = TextEditingController();
    final bill = TextEditingController();
    var actual = true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.phrase('Add electricity reading')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: provider,
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Provider'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.phrase('Actual bill')),
                  subtitle: Text(
                    context.l10n.phrase('Turn off for an estimate'),
                  ),
                  value: actual,
                  onChanged: (value) => setDialogState(() => actual = value),
                ),
                _NumberField(controller: units, label: 'Units consumed'),
                _NumberField(
                  controller: previous,
                  label: 'Previous reading (optional)',
                ),
                _NumberField(
                  controller: current,
                  label: 'Current reading (optional)',
                ),
                _NumberField(
                  controller: bill,
                  label: actual ? 'Bill amount' : 'Estimated amount',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.phrase('Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final previousValue = double.tryParse(previous.text);
                final currentValue = double.tryParse(current.text);
                final calculated = previousValue != null && currentValue != null
                    ? currentValue - previousValue
                    : null;
                final unitValue = double.tryParse(units.text) ?? calculated;
                if (provider.text.trim().isEmpty ||
                    unitValue == null ||
                    unitValue < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.phrase('Enter valid electricity details'),
                      ),
                    ),
                  );
                  return;
                }
                await ref
                    .read(energyIntelligenceRepositoryProvider)
                    .saveReading(
                      ElectricityReading(
                        provider: provider.text,
                        billingMonth: DateTime.now(),
                        previousReading: previousValue,
                        currentReading: currentValue,
                        units: unitValue,
                        actualBill: actual ? double.tryParse(bill.text) : null,
                        estimatedBill: actual
                            ? null
                            : double.tryParse(bill.text),
                        isActual: actual,
                      ),
                    );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: Text(context.l10n.phrase('Save')),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _applianceDialog() async {
    final fields = List.generate(6, (_) => TextEditingController());
    fields[1].text = '1';
    fields[3].text = '4';
    fields[4].text = '30';
    fields[5].text = '50';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.phrase('Add appliance scenario')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fields[0],
                decoration: InputDecoration(
                  labelText: context.l10n.phrase('Appliance name'),
                ),
              ),
              for (final item in const [
                'Quantity',
                'Wattage',
                'Hours per day',
                'Days per month',
                'Tariff per unit',
              ].indexed)
                _NumberField(controller: fields[item.$1 + 1], label: item.$2),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(energyIntelligenceRepositoryProvider)
                    .saveAppliance(
                      ApplianceUsage(
                        name: fields[0].text,
                        quantity: int.parse(fields[1].text),
                        wattage: double.parse(fields[2].text),
                        hoursPerDay: double.parse(fields[3].text),
                        daysPerMonth: int.parse(fields[4].text),
                        tariffPerKwh: double.parse(fields[5].text),
                      ),
                    );
                if (context.mounted) Navigator.pop(context, true);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.l10n.phrase('Enter valid appliance details'),
                    ),
                  ),
                );
              }
            },
            child: Text(context.l10n.phrase('Save')),
          ),
        ],
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _solarSystemDialog() async {
    final fields = List.generate(8, (_) => TextEditingController());
    fields[0].text = 'Home solar';
    fields[2].text = '585';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.phrase('Add solar system')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fields[0],
                decoration: InputDecoration(
                  labelText: context.l10n.phrase('System name'),
                ),
              ),
              for (final item in const [
                'System size (kW)',
                'Panel wattage',
                'Panel count',
              ].indexed)
                _NumberField(controller: fields[item.$1 + 1], label: item.$2),
              TextField(
                controller: fields[4],
                decoration: InputDecoration(
                  labelText: context.l10n.phrase('Inverter (optional)'),
                ),
              ),
              TextField(
                controller: fields[5],
                decoration: InputDecoration(
                  labelText: context.l10n.phrase('Battery (optional)'),
                ),
              ),
              _NumberField(controller: fields[6], label: 'Installation cost'),
              _NumberField(controller: fields[7], label: 'Maintenance cost'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(energyIntelligenceRepositoryProvider)
                    .saveSolarSystem(
                      name: fields[0].text,
                      installed: DateTime.now(),
                      systemKw: double.parse(fields[1].text),
                      panelWattage: double.parse(fields[2].text),
                      panelCount: int.parse(fields[3].text),
                      inverter: fields[4].text,
                      battery: fields[5].text,
                      installationCost: double.parse(fields[6].text),
                      maintenanceCost: double.tryParse(fields[7].text) ?? 0,
                    );
                if (context.mounted) Navigator.pop(context, true);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.l10n.phrase('Enter valid solar system details'),
                    ),
                  ),
                );
              }
            },
            child: Text(context.l10n.phrase('Save')),
          ),
        ],
      ),
    );
    if (saved == true) _refresh();
  }
}

class _History extends StatelessWidget {
  const _History({required this.readings, required this.money});
  final List<ElectricityReading> readings;
  final String Function(num) money;
  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const _Empty(
        icon: Icons.bolt_outlined,
        title: 'Add bills or estimates to see usage trends',
      );
    }
    final average =
        readings.fold<double>(0, (sum, item) => sum + item.units) /
        readings.length;
    final maxUnits = readings.fold<double>(
      1,
      (max, item) => item.units > max ? item.units : max,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _InsightCard(
          title: 'Monthly average',
          value: '${average.toStringAsFixed(0)} kWh',
          detail: '${readings.length} recorded months',
          icon: Icons.insights_outlined,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.phrase('Usage trend'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final item
                          in readings.length > 8
                              ? readings.sublist(readings.length - 8)
                              : readings)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: (item.units / maxUnits)
                                          .clamp(.06, 1),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: item.isActual
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.tertiary,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat.MMM().format(item.billingMonth),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final item in readings.reversed)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  item.isActual
                      ? Icons.receipt_long_outlined
                      : Icons.calculate_outlined,
                ),
              ),
              title: Text(
                '${item.provider} • ${item.units.toStringAsFixed(0)} kWh',
              ),
              subtitle: Text(
                '${DateFormat.yMMMM().format(item.billingMonth)} • ${context.l10n.phrase(item.isActual ? 'Actual' : 'Estimate')}',
              ),
              trailing: Text(
                money(item.actualBill ?? item.estimatedBill ?? 0),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}

class _Appliances extends StatelessWidget {
  const _Appliances({required this.items, required this.money});
  final List<ApplianceUsage> items;
  final String Function(num) money;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _Empty(
        icon: Icons.devices_other_outlined,
        title: 'Add appliances to compare usage and cost',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        for (final item in items) _ApplianceCard(item: item, money: money),
      ],
    );
  }
}

class _ApplianceCard extends StatefulWidget {
  const _ApplianceCard({required this.item, required this.money});
  final ApplianceUsage item;
  final String Function(num) money;
  @override
  State<_ApplianceCard> createState() => _ApplianceCardState();
}

class _ApplianceCardState extends State<_ApplianceCard> {
  late double hours = widget.item.hoursPerDay;
  @override
  Widget build(BuildContext context) {
    final scenario = widget.item.withHours(hours);
    final saved = widget.item.estimatedCost - scenario.estimatedCost;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              '${scenario.monthlyKwh.toStringAsFixed(1)} kWh • ${widget.money(scenario.estimatedCost)}/month',
            ),
            Slider(
              value: hours,
              min: 0,
              max: 24,
              divisions: 48,
              label: '${hours.toStringAsFixed(1)} h',
              onChanged: (value) => setState(() => hours = value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l10n.phrase('What if used per day?')),
                Text(
                  '${hours.toStringAsFixed(1)} h',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            if (saved > 0)
              Text(
                '${context.l10n.phrase('Potential monthly saving')}: ${widget.money(saved)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SolarPlanner extends StatelessWidget {
  const _SolarPlanner({required this.readings});
  final List<ElectricityReading> readings;
  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const _Empty(
        icon: Icons.solar_power_outlined,
        title:
            'Add electricity history for a personalized solar recommendation',
      );
    }
    final result = SolarRecommendation.fromHistory(readings);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        _InsightCard(
          title: 'Recommended system',
          value: '${result.systemKw.toStringAsFixed(1)} kW',
          detail: '${result.panelCount} × 585W panels',
          icon: Icons.solar_power,
        ),
        _InsightCard(
          title: 'Estimated annual generation',
          value: '${result.estimatedAnnualGeneration.toStringAsFixed(0)} kWh',
          detail: 'Based on Pakistan planning assumptions',
          icon: Icons.wb_sunny_outlined,
        ),
        _InsightCard(
          title: 'Estimated grid reduction',
          value: '${result.gridReductionPercent.toStringAsFixed(0)}%',
          detail: 'Actual output varies with shade, orientation and weather',
          icon: Icons.energy_savings_leaf_outlined,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.l10n.phrase(
                'Ask a certified installer to verify roof structure, shade, earthing, protection, inverter sizing and battery requirements before purchase.',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SolarRoi extends StatelessWidget {
  const _SolarRoi({
    required this.systems,
    required this.repository,
    required this.money,
    required this.onSaved,
  });
  final List<SolarSystemProfile> systems;
  final EnergyIntelligenceRepository repository;
  final String Function(num) money;
  final VoidCallback onSaved;
  @override
  Widget build(BuildContext context) {
    if (systems.isEmpty) {
      return const _Empty(
        icon: Icons.roofing_outlined,
        title: 'Add your installed solar system to track return on investment',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        for (final system in systems)
          FutureBuilder<SolarRoiSummary?>(
            future: repository.solarRoi(system.id),
            builder: (context, snapshot) {
              final roi = snapshot.data;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              system.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            tooltip: context.l10n.phrase(
                              'Record monthly performance',
                            ),
                            onPressed: () =>
                                _performanceDialog(context, system),
                            icon: const Icon(Icons.add_chart),
                          ),
                        ],
                      ),
                      Text(
                        '${system.systemKw.toStringAsFixed(1)} kW • ${system.panelCount} panels',
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: roi?.progress ?? 0,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${context.l10n.phrase('Recovered')}: ${money(roi?.accumulatedSavings ?? 0)} / ${money(roi?.investment ?? system.installationCost)}',
                      ),
                      if (roi?.remainingMonths != null)
                        Text(
                          '${context.l10n.phrase('Estimated months remaining')}: ${roi!.remainingMonths!.ceil()}',
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _performanceDialog(
    BuildContext outerContext,
    SolarSystemProfile system,
  ) async {
    final generation = TextEditingController();
    final savings = TextEditingController();
    final saved = await showDialog<bool>(
      context: outerContext,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.phrase('Record monthly performance')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NumberField(
              controller: generation,
              label: 'Generated electricity (kWh)',
            ),
            _NumberField(controller: savings, label: 'Estimated bill saving'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final generated = double.tryParse(generation.text);
              final savedAmount = double.tryParse(savings.text);
              if (generated == null || savedAmount == null) return;
              await repository.saveSolarPerformance(
                systemId: system.id,
                month: DateTime.now(),
                generation: generated,
                estimatedSavings: savedAmount,
              );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: Text(context.l10n.phrase('Save')),
          ),
        ],
      ),
    );
    if (saved == true) onSaved();
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});
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

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
  });
  final String title, value, detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(radius: 26, child: Icon(icon)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.phrase(title)),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(context.l10n.phrase(detail)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            context.l10n.phrase(title),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(context.l10n.phrase(action!)),
            ),
        ],
      ),
    ),
  );
}
