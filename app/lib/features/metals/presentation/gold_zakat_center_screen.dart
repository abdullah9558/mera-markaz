import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/pakistan_data/pakistan_data_point.dart';
import '../../../core/pakistan_data/pakistan_data_repository.dart';
import '../data/metal_zakat_repository.dart';
import '../domain/metal_models.dart';

class GoldZakatCenterScreen extends ConsumerStatefulWidget {
  const GoldZakatCenterScreen({super.key});
  @override
  ConsumerState<GoldZakatCenterScreen> createState() => _GoldZakatCenterState();
}

class _GoldZakatCenterState extends ConsumerState<GoldZakatCenterScreen> {
  int section = 0;
  late Future<
    (
      PakistanDataPoint?,
      PakistanDataPoint?,
      List<MetalHolding>,
      List<ZakatRecord>,
    )
  >
  data;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final metals = ref.read(metalZakatRepositoryProvider);
    final rates = ref.read(pakistanDataRepositoryProvider);
    data = _load(rates, metals);
  }

  Future<
    (
      PakistanDataPoint?,
      PakistanDataPoint?,
      List<MetalHolding>,
      List<ZakatRecord>,
    )
  >
  _load(PakistanDataRepository rates, MetalZakatRepository metals) async {
    final gold = await rates.latest('gold_24k_tola');
    final silver = await rates.latest('silver_tola');
    final holdings = await metals.holdings();
    final zakat = await metals.zakatHistory();
    return (gold, silver, holdings, zakat);
  }

  void _refresh() => setState(_reload);
  String money(num value) =>
      'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.phrase('Gold & Zakat Center'))),
    floatingActionButton: section == 0
        ? null
        : FloatingActionButton.extended(
            key: ValueKey('gold-zakat-fab-$section'),
            onPressed: section == 1 ? _holdingDialog : _zakatDialog,
            icon: const Icon(Icons.add),
            label: Text(
              context.l10n.phrase(
                section == 1 ? 'Add holding' : 'New Zakat calculation',
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
                'Market',
                'My holdings',
                'Zakat history',
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
                return Center(
                  child: Text(context.l10n.phrase('Could not load metal data')),
                );
              }
              final value = snapshot.data!;
              return switch (section) {
                0 => _Market(gold: value.$1, silver: value.$2, money: money),
                1 => _Holdings(
                  items: value.$3,
                  goldRate: value.$1?.value,
                  silverRate: value.$2?.value,
                  money: money,
                ),
                _ => _ZakatHistory(items: value.$4, money: money),
              };
            },
          ),
        ),
      ],
    ),
  );

  Future<void> _holdingDialog() async {
    final quantity = TextEditingController();
    final purchase = TextEditingController();
    var metal = MetalType.gold;
    var unit = MetalUnit.tola;
    var purity = 1.0;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(context.l10n.phrase('Add metal holding')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField(
                  initialValue: metal,
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Metal'),
                  ),
                  items: MetalType.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            context.l10n.phrase(
                              v == MetalType.gold ? 'Gold' : 'Silver',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => metal = v!),
                ),
                DropdownButtonFormField(
                  initialValue: unit,
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Unit'),
                  ),
                  items: MetalUnit.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            context.l10n.phrase(switch (v) {
                              MetalUnit.gram => 'Gram',
                              MetalUnit.tola => 'Tola',
                              MetalUnit.tenGrams => '10 grams',
                            }),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => unit = v!),
                ),
                TextField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Quantity'),
                  ),
                ),
                TextField(
                  controller: purchase,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('Purchase price (optional)'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text(context.l10n.phrase('Purity'))),
                    Text('${(purity * 100).round()}%'),
                  ],
                ),
                Slider(
                  value: purity,
                  min: .5,
                  max: 1,
                  divisions: 50,
                  onChanged: (v) => setDialog(() => purity = v),
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
                final amount = double.tryParse(quantity.text);
                if (amount == null || amount <= 0) return;
                final holding = MetalHolding(
                  metal: metal,
                  quantity: amount,
                  unit: unit,
                  purity: purity,
                  purchasePrice: double.tryParse(purchase.text),
                );
                final value = await data;
                final rate = metal == MetalType.gold
                    ? value.$1?.value
                    : value.$2?.value;
                await ref
                    .read(metalZakatRepositoryProvider)
                    .saveHolding(
                      holding,
                      currentValue: rate == null
                          ? null
                          : holding.valueFromTolaRate(rate),
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

  Future<void> _zakatDialog() async {
    final value = await data;
    final repo = ref.read(metalZakatRepositoryProvider);
    final fields = List.generate(6, (_) => TextEditingController());
    final goldValue = await repo.holdingsValue(MetalType.gold);
    final silverValue = await repo.holdingsValue(MetalType.silver);
    var method = 'silver';
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          final goldNisab = (value.$1?.value ?? 0) * 87.48 / 11.6638038;
          final silverNisab = (value.$2?.value ?? 0) * 612.36 / 11.6638038;
          return AlertDialog(
            title: Text(context.l10n.phrase('Annual Zakat calculation')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField(
                    initialValue: method,
                    decoration: InputDecoration(
                      labelText: context.l10n.phrase('Nisab method'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'silver',
                        child: Text(context.l10n.phrase('Silver')),
                      ),
                      DropdownMenuItem(
                        value: 'gold',
                        child: Text(context.l10n.phrase('Gold')),
                      ),
                    ],
                    onChanged: (v) => setDialog(() => method = v!),
                  ),
                  for (final item in const [
                    'Cash',
                    'Bank savings',
                    'Business assets',
                    'Receivables',
                    'Other eligible assets',
                    'Eligible liabilities',
                  ].indexed)
                    TextField(
                      controller: fields[item.$1],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.phrase(item.$2),
                      ),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.phrase('Linked gold holdings')),
                    trailing: Text(money(goldValue)),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.phrase('Linked silver holdings')),
                    trailing: Text(money(silverValue)),
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
                  double number(int i) => double.tryParse(fields[i].text) ?? 0;
                  final record = ZakatRecord(
                    cash: number(0),
                    bank: number(1),
                    gold: goldValue,
                    silver: silverValue,
                    businessAssets: number(2),
                    receivables: number(3),
                    otherAssets: number(4),
                    liabilities: number(5),
                    nisabMethod: method,
                    nisabValue: method == 'gold' ? goldNisab : silverNisab,
                    calculatedAt: DateTime.now(),
                    reminderAt: DateTime.now().add(const Duration(days: 354)),
                    sourceReference: method == 'gold'
                        ? value.$1?.sourceReference
                        : value.$2?.sourceReference,
                  );
                  await repo.saveZakat(record);
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: Text(context.l10n.phrase('Save calculation')),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true) _refresh();
  }
}

class _Market extends StatelessWidget {
  const _Market({
    required this.gold,
    required this.silver,
    required this.money,
  });
  final PakistanDataPoint? gold, silver;
  final String Function(num) money;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      for (final item in [
        ('Gold 24K / Tola', gold, Icons.workspace_premium),
        ('Silver / Tola', silver, Icons.circle_outlined),
      ])
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(18),
            leading: CircleAvatar(child: Icon(item.$3)),
            title: Text(context.l10n.phrase(item.$1)),
            subtitle: Text(
              item.$2 == null
                  ? context.l10n.phrase('Unavailable — refresh Pakistan Live')
                  : '${item.$2!.sourceName} • ${DateFormat.yMMMd().add_jm().format(item.$2!.retrievedAt.toLocal())}',
            ),
            trailing: Text(
              item.$2 == null ? '—' : money(item.$2!.value),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
    ],
  );
}

class _Holdings extends StatelessWidget {
  const _Holdings({
    required this.items,
    required this.goldRate,
    required this.silverRate,
    required this.money,
  });
  final List<MetalHolding> items;
  final double? goldRate, silverRate;
  final String Function(num) money;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? Center(child: Text(context.l10n.phrase('No metal holdings yet')))
      : ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            for (final item in items)
              Card(
                child: ListTile(
                  title: Text(
                    '${context.l10n.phrase(item.metal == MetalType.gold ? 'Gold' : 'Silver')} • ${item.quantity} ${context.l10n.phrase(item.unit == MetalUnit.tola
                        ? 'Tola'
                        : item.unit == MetalUnit.gram
                        ? 'Gram'
                        : '10 grams')}',
                  ),
                  subtitle: Text(
                    '${(item.purity * 100).round()}% ${context.l10n.phrase('purity')}',
                  ),
                  trailing: Text(
                    (item.metal == MetalType.gold ? goldRate : silverRate) ==
                            null
                        ? '—'
                        : money(
                            item.valueFromTolaRate(
                              (item.metal == MetalType.gold
                                  ? goldRate
                                  : silverRate)!,
                            ),
                          ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        );
}

class _ZakatHistory extends StatelessWidget {
  const _ZakatHistory({required this.items, required this.money});
  final List<ZakatRecord> items;
  final String Function(num) money;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? Center(child: Text(context.l10n.phrase('No saved Zakat calculations')))
      : ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            for (final item in items)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.volunteer_activism_outlined),
                  ),
                  title: Text(money(item.zakatDue)),
                  subtitle: Text(
                    '${DateFormat.yMMMMd().format(item.calculatedAt)} • ${context.l10n.phrase('Eligible wealth')}: ${money(item.eligibleTotal)}',
                  ),
                  trailing: item.reminderAt == null
                      ? null
                      : const Icon(Icons.notifications_active_outlined),
                ),
              ),
          ],
        );
}
