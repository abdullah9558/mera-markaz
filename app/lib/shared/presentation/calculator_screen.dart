// ignore_for_file: sort_child_properties_last, use_null_aware_elements, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/calculators/calculator.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/electricity/domain/electricity_calculator.dart';
import '../../features/expenses/data/module_finance_repository.dart';
import '../../features/home/presentation/dashboard_provider.dart';
import '../../features/fuel/domain/fuel_calculator.dart';
import '../../features/property/domain/property_calculator.dart';
import '../../features/solar/domain/solar_calculator.dart';
import '../../features/tax/domain/tax_calculator.dart';
import '../../features/zakat/domain/zakat_calculator.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) => switch (name) {
    'tax' => _TaxForm(),
    'electricity' => _ElectricityForm(),
    'solar' => _SolarForm(),
    'property' => _PropertyForm(),
    'fuel' => _FuelForm(),
    'zakat' => _ZakatForm(),
    _ => Scaffold(
      appBar: AppBar(title: Text(context.l10n.text('tools'))),
      body: Center(child: Text(context.l10n.phrase('Unknown calculator'))),
    ),
  };
}

String _number(num value, {int decimals = 0}) =>
    NumberFormat.decimalPatternDigits(
      locale: 'en_PK',
      decimalDigits: decimals,
    ).format(value);
String _money(num value) => 'Rs. ${_number(value)}';
double _parse(TextEditingController controller) =>
    double.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.suffix,
  });
  final TextEditingController controller;
  final String label;
  final String? suffix;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
  );
}

class _CalculatorPage extends StatelessWidget {
  const _CalculatorPage({
    required this.title,
    required this.children,
    required this.onCalculate,
    this.result,
    this.note,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback onCalculate;
  final Widget? result;
  final String? note;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: EdgeInsets.all(20),
      children: [
        ...children.expand((widget) => [widget, SizedBox(height: 14)]),
        FilledButton.icon(
          onPressed: onCalculate,
          icon: Icon(Icons.calculate),
          label: Text(context.l10n.text('calculate')),
        ),
        if (result != null) ...[SizedBox(height: 20), result!],
        if (note != null) ...[
          SizedBox(height: 16),
          Text(
            note!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.title, required this.rows, this.metadata});
  final String title;
  final Map<String, String> rows;
  final String? metadata;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          ...rows.entries.map(
            (entry) => Padding(
              padding: EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text(entry.key)),
                  Text(
                    entry.value,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          if (metadata != null) ...[
            Divider(height: 24),
            Text(metadata!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    ),
  );
}

mixin _CalculationState<T extends StatefulWidget> on State<T> {
  String? error;
  void runCalculation(VoidCallback operation) {
    setState(() {
      error = null;
      try {
        operation();
      } on CalculationException catch (e) {
        error = e.message;
      }
    });
  }

  Widget? errorBanner() => error == null
      ? null
      : MaterialBanner(
          content: Text(error!),
          actions: [
            TextButton(
              onPressed: () => setState(() => error = null),
              child: Text(context.l10n.phrase('OK')),
            ),
          ],
        );
}

class _TaxForm extends ConsumerStatefulWidget {
  const _TaxForm();
  @override
  ConsumerState<_TaxForm> createState() => _TaxFormState();
}

class _TaxFormState extends ConsumerState<_TaxForm>
    with _CalculationState<_TaxForm> {
  final salary = TextEditingController();
  final other = TextEditingController();
  TaxResult? result;
  int? savedCalculationId;
  bool saving = false;
  @override
  void dispose() {
    salary.dispose();
    other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CalculatorPage(
    title: context.l10n.text('tax'),
    children: [
      if (errorBanner() case final banner?) banner,
      _NumberField(
        controller: salary,
        label: context.l10n.text('monthlySalary'),
        suffix: 'PKR',
      ),
      _NumberField(
        controller: other,
        label: context.l10n.text('otherAnnualIncome'),
        suffix: 'PKR',
      ),
    ],
    onCalculate: () => runCalculation(
      () => result = TaxCalculator(taxYear2025_26).calculate(
        TaxInput(
          monthlySalary: _parse(salary),
          otherAnnualIncome: _parse(other),
        ),
      ),
    ),
    result: result == null
        ? null
        : Column(
            children: [
              _ResultCard(
                title: context.l10n.text('estimatedTax'),
                rows: {
                  'Annual income': _money(result!.annualIncome),
                  'Annual tax': _money(result!.annualTax),
                  'Monthly tax': _money(result!.monthlyTax),
                  'Monthly take-home': _money(result!.monthlyTakeHome),
                  'Effective rate':
                      '${(result!.effectiveRate * 100).toStringAsFixed(2)}%',
                },
                metadata:
                    'Tax Year ${result!.config.year} • ${result!.config.metadata.sourceLabel}',
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: saving ? null : _recordSalary,
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  label: Text(saving ? 'Saving…' : 'Add salary to income'),
                ),
              ),
            ],
          ),
    note: context.l10n.text('taxDisclaimer'),
  );

  Future<void> _recordSalary() async {
    final value = result;
    if (value == null) return;
    setState(() => saving = true);
    try {
      final linked = await ref
          .read(moduleFinanceRepositoryProvider)
          .recordSalary(
            calculationId: savedCalculationId,
            monthlySalary: _parse(salary),
            annualIncome: value.annualIncome,
            annualTax: value.annualTax,
            taxYear: value.config.year,
          );
      savedCalculationId = linked.recordId;
      ref.invalidate(homeDashboardProvider);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.phrase(
                'Salary added to income. Saving again will update this entry.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _ElectricityForm extends ConsumerStatefulWidget {
  const _ElectricityForm();
  @override
  ConsumerState<_ElectricityForm> createState() => _ElectricityFormState();
}

class _ElectricityFormState extends ConsumerState<_ElectricityForm>
    with _CalculationState<_ElectricityForm> {
  final units = TextEditingController();
  final previous = TextEditingController();
  final current = TextEditingController();
  final tax = TextEditingController(text: '18');
  ElectricityResult? result;
  int? savedCalculationId;
  bool saving = false;
  @override
  void dispose() {
    units.dispose();
    previous.dispose();
    current.dispose();
    tax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CalculatorPage(
    title: context.l10n.text('electricity'),
    children: [
      if (errorBanner() case final banner?) banner,
      _NumberField(
        controller: units,
        label: context.l10n.text('unitsOptional'),
        suffix: 'kWh',
      ),
      _NumberField(
        controller: previous,
        label: context.l10n.text('previousReading'),
      ),
      _NumberField(
        controller: current,
        label: context.l10n.text('currentReading'),
      ),
      _NumberField(
        controller: tax,
        label: context.l10n.text('taxAdjustments'),
        suffix: '%',
      ),
    ],
    onCalculate: () => runCalculation(() {
      var consumed = _parse(units);
      if (units.text.trim().isEmpty) {
        final oldValue = _parse(previous);
        final newValue = _parse(current);
        if (newValue < oldValue)
          throw CalculationException(
            'Current meter reading cannot be lower than previous reading.',
          );
        consumed = newValue - oldValue;
      }
      result = ElectricityCalculator(residentialTariff2026).calculate(
        ElectricityInput(units: consumed, taxRate: _parse(tax) / 100),
      );
    }),
    result: result == null
        ? null
        : Column(
            children: [
              _ResultCard(
                title: context.l10n.text('estimatedBill'),
                rows: {
                  'Units': _number(result!.units, decimals: 1),
                  'Energy charges': _money(result!.energyCharges),
                  'Fixed charges': _money(result!.fixedCharges),
                  'Taxes/adjustments': _money(result!.taxes),
                  'Estimated total': _money(result!.total),
                },
                metadata: result!.config.metadata.sourceLabel,
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: saving ? null : _recordBill,
                  icon: Icon(Icons.receipt_long_outlined),
                  label: Text(saving ? 'Saving…' : 'Add bill to expenses'),
                ),
              ),
            ],
          ),
    note: context.l10n.text('billDisclaimer'),
  );

  Future<void> _recordBill() async {
    final value = result;
    if (value == null) return;
    setState(() => saving = true);
    try {
      final linked = await ref
          .read(moduleFinanceRepositoryProvider)
          .recordElectricityBill(
            calculationId: savedCalculationId,
            units: value.units,
            total: value.total,
            configVersion: value.config.metadata.sourceLabel,
          );
      savedCalculationId = linked.recordId;
      ref.invalidate(homeDashboardProvider);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.phrase('Electricity bill added to expenses.'),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _SolarForm extends StatefulWidget {
  const _SolarForm();
  @override
  State<_SolarForm> createState() => _SolarFormState();
}

class _SolarFormState extends State<_SolarForm>
    with _CalculationState<_SolarForm> {
  final units = TextEditingController();
  final roof = TextEditingController();
  SolarResult? result;
  @override
  void dispose() {
    units.dispose();
    roof.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CalculatorPage(
    title: context.l10n.text('solar'),
    children: [
      if (errorBanner() case final banner?) banner,
      _NumberField(
        controller: units,
        label: context.l10n.text('monthlyUnits'),
        suffix: 'kWh',
      ),
      _NumberField(
        controller: roof,
        label: context.l10n.text('roofArea'),
        suffix: 'sq ft',
      ),
    ],
    onCalculate: () => runCalculation(
      () => result = SolarCalculator(defaultSolarAssumptions).calculate(
        SolarInput(
          monthlyUnits: _parse(units),
          roofAreaSquareFeet: _parse(roof),
        ),
      ),
    ),
    result: result == null
        ? null
        : _ResultCard(
            title: context.l10n.text('solarEstimate'),
            rows: {
              'Recommended size': '${result!.systemKw.toStringAsFixed(2)} kW',
              'Panels (585 W)': '${result!.panelCount}',
              'Monthly generation': '${_number(result!.monthlyGeneration)} kWh',
              'Roof required': '${_number(result!.roofAreaRequired)} sq ft',
              'Monthly savings': _money(result!.monthlySavings),
              'Payback estimate':
                  '${result!.paybackYears.toStringAsFixed(1)} years',
            },
            metadata: result!.config.metadata.sourceLabel,
          ),
    note: context.l10n.text('solarDisclaimer'),
  );
}

class _PropertyForm extends StatefulWidget {
  const _PropertyForm();
  @override
  State<_PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends State<_PropertyForm>
    with _CalculationState<_PropertyForm> {
  final length = TextEditingController();
  final width = TextEditingController();
  final marla = TextEditingController(text: '272.25');
  final price = TextEditingController();
  PropertyResult? result;
  @override
  void dispose() {
    length.dispose();
    width.dispose();
    marla.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CalculatorPage(
    title: context.l10n.text('property'),
    children: [
      if (errorBanner() case final banner?) banner,
      _NumberField(
        controller: length,
        label: context.l10n.text('length'),
        suffix: 'ft',
      ),
      _NumberField(
        controller: width,
        label: context.l10n.text('width'),
        suffix: 'ft',
      ),
      _NumberField(
        controller: marla,
        label: context.l10n.text('marlaStandard'),
        suffix: 'sq ft',
      ),
      _NumberField(
        controller: price,
        label: context.l10n.text('pricePerMarla'),
        suffix: 'PKR',
      ),
    ],
    onCalculate: () => runCalculation(
      () => result = PropertyCalculator().calculate(
        PropertyInput(
          length: _parse(length),
          width: _parse(width),
          marlaSquareFeet: _parse(marla),
          pricePerMarla: _parse(price),
        ),
      ),
    ),
    result: result == null
        ? null
        : _ResultCard(
            title: context.l10n.text('plotResult'),
            rows: {
              'Square feet': _number(result!.squareFeet, decimals: 2),
              'Square yards': _number(result!.squareYards, decimals: 2),
              'Marla': _number(result!.marla, decimals: 2),
              'Kanal': _number(result!.kanal, decimals: 3),
              'Square meters': _number(result!.squareMeters, decimals: 2),
              'Estimated price': _money(result!.price),
            },
          ),
    note: context.l10n.text('marlaDisclaimer'),
  );
}

class _FuelForm extends ConsumerStatefulWidget {
  const _FuelForm();
  @override
  ConsumerState<_FuelForm> createState() => _FuelFormState();
}

class _FuelFormState extends ConsumerState<_FuelForm>
    with _CalculationState<_FuelForm> {
  final distance = TextEditingController();
  final liters = TextEditingController();
  final price = TextEditingController();
  FuelResult? result;
  int? savedEntryId;
  bool saving = false;
  @override
  void dispose() {
    distance.dispose();
    liters.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CalculatorPage(
    title: context.l10n.text('fuel'),
    children: [
      if (errorBanner() case final banner?) banner,
      _NumberField(
        controller: distance,
        label: context.l10n.text('distance'),
        suffix: 'km',
      ),
      _NumberField(
        controller: liters,
        label: context.l10n.text('fuelConsumed'),
        suffix: 'L',
      ),
      _NumberField(
        controller: price,
        label: context.l10n.text('fuelPrice'),
        suffix: 'PKR/L',
      ),
    ],
    onCalculate: () => runCalculation(
      () => result = FuelCalculator().calculate(
        FuelInput(
          distanceKm: _parse(distance),
          liters: _parse(liters),
          fuelPrice: _parse(price),
        ),
      ),
    ),
    result: result == null
        ? null
        : Column(
            children: [
              _ResultCard(
                title: context.l10n.text('fuelResult'),
                rows: {
                  'Fuel average':
                      '${result!.averageKmPerLiter.toStringAsFixed(2)} km/L',
                  'Fuel cost': _money(result!.tripCost),
                  'Cost per km': _money(result!.costPerKm),
                },
              ),
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: saving ? null : _recordFuel,
                  icon: Icon(Icons.local_gas_station_outlined),
                  label: Text(saving ? 'Saving…' : 'Add fuel to expenses'),
                ),
              ),
            ],
          ),
  );

  Future<void> _recordFuel() async {
    final value = result;
    if (value == null) return;
    setState(() => saving = true);
    try {
      final linked = await ref
          .read(moduleFinanceRepositoryProvider)
          .recordFuelExpense(
            entryId: savedEntryId,
            liters: _parse(liters),
            cost: value.tripCost,
            odometer: _parse(distance),
          );
      savedEntryId = linked.recordId;
      ref.invalidate(homeDashboardProvider);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.phrase('Fuel purchase added to expenses.'),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _ZakatForm extends StatefulWidget {
  const _ZakatForm();
  @override
  State<_ZakatForm> createState() => _ZakatFormState();
}

class _ZakatFormState extends State<_ZakatForm>
    with _CalculationState<_ZakatForm> {
  final assets = TextEditingController();
  final liabilities = TextEditingController();
  final nisab = TextEditingController();
  ZakatResult? result;
  @override
  void dispose() {
    assets.dispose();
    liabilities.dispose();
    nisab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CalculatorPage(
    title: context.l10n.text('zakat'),
    children: [
      if (errorBanner() case final banner?) banner,
      _NumberField(
        controller: assets,
        label: context.l10n.text('eligibleAssets'),
        suffix: 'PKR',
      ),
      _NumberField(
        controller: liabilities,
        label: context.l10n.text('liabilities'),
        suffix: 'PKR',
      ),
      _NumberField(
        controller: nisab,
        label: context.l10n.text('nisab'),
        suffix: 'PKR',
      ),
    ],
    onCalculate: () => runCalculation(
      () => result = ZakatCalculator().calculate(
        ZakatInput(
          assets: _parse(assets),
          liabilities: _parse(liabilities),
          nisab: _parse(nisab),
        ),
      ),
    ),
    result: result == null
        ? null
        : _ResultCard(
            title: context.l10n.text('zakatResult'),
            rows: {
              'Net Zakatable': _money(result!.netZakatable),
              'Nisab threshold': _money(result!.nisab),
              'Zakat due?': result!.isDue ? 'Yes' : 'No',
              'Estimated Zakat': _money(result!.zakatDue),
            },
          ),
    note: context.l10n.text('zakatDisclaimer'),
  );
}
