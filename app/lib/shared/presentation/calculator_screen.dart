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
import '../../features/settings/presentation/settings_controller.dart';
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

class _GuideItem {
  const _GuideItem({
    required this.title,
    required this.body,
    required this.icon,
  });
  final String title;
  final String body;
  final IconData icon;
}

class _CalculatorGuide extends StatelessWidget {
  const _CalculatorGuide({required this.intro, required this.items});
  final String intro;
  final List<_GuideItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.primary.withValues(alpha: .12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.tips_and_updates_outlined, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.phrase(intro),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: colors.primary, size: 22),
                ),
                title: Text(
                  context.l10n.phrase(item.title),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.phrase(item.body),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalculatorPage extends StatelessWidget {
  const _CalculatorPage({
    required this.title,
    required this.guide,
    required this.children,
    required this.onCalculate,
    this.result,
    this.note,
  });
  final String title;
  final Widget guide;
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
        guide,
        SizedBox(height: 8),
        Text(
          context.l10n.phrase('Enter your details'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          context.l10n.phrase('Fields marked optional may be left empty.'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 4),
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
                  Expanded(child: Text(context.l10n.phrase(entry.key))),
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
  Widget build(BuildContext context) {
    final taxConfig = taxConfigFor(
      ref.watch(settingsControllerProvider).taxYear,
    );
    return _CalculatorPage(
      title: context.l10n.text('tax'),
      guide: const _CalculatorGuide(
        intro:
            'Estimate salary tax and monthly take-home before planning your budget.',
        items: [
          _GuideItem(
            title: 'What you need',
            body:
                'Your gross monthly salary and any other annual taxable income. Use amounts before tax deductions.',
            icon: Icons.fact_check_outlined,
          ),
          _GuideItem(
            title: 'How it is calculated',
            body:
                'Monthly salary is converted to annual taxable income and the progressive salaried-individual slabs for the selected FBR tax year are applied. For taxable income above Rs. 10 million, the calculator adds the applicable 9% surcharge on computed income tax.',
            icon: Icons.calculate_outlined,
          ),
          _GuideItem(
            title: 'Tax Year 2027 / FY 2026-27',
            body:
                'The selected FY 2026-27 configuration is Tax Year 2027 under FBR naming. It uses the Finance Act 2026 salaried slabs and identifies the source/version in every result.',
            icon: Icons.calendar_month_outlined,
          ),
          _GuideItem(
            title: 'Before you rely on it',
            body:
                'Enter taxable salary, not gross reimbursements. Exempt allowances, tax credits, employer adjustments, pension treatment, foreign income and income under other heads require their own legal treatment and may change the final return.',
            icon: Icons.gavel_outlined,
          ),
        ],
      ),
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
        () => result = TaxCalculator(taxConfig).calculate(
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
                    'Tax before surcharge': _money(result!.baseTax),
                    if (result!.surcharge > 0)
                      '9% high-income surcharge': _money(result!.surcharge),
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
  }

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
  final duty = TextEditingController(text: '1.5');
  final adjustments = TextEditingController();
  final tvFee = TextEditingController(text: '35');
  bool protectedConsumer = false;
  ElectricityResult? result;
  int? savedCalculationId;
  bool saving = false;
  @override
  void dispose() {
    units.dispose();
    previous.dispose();
    current.dispose();
    tax.dispose();
    duty.dispose();
    adjustments.dispose();
    tvFee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CalculatorPage(
    title: context.l10n.text('electricity'),
    guide: const _CalculatorGuide(
      intro:
          'Estimate electricity usage and charges before the official bill arrives.',
      items: [
        _GuideItem(
          title: 'Choose an input method',
          body:
              'Enter consumed units directly, or leave that field empty and provide previous and current meter readings.',
          icon: Icons.electric_meter_outlined,
        ),
        _GuideItem(
          title: 'Protected or non-protected status',
          body:
              'Select protected only when your bill identifies you as protected. NEPRA defines this around sustained low residential consumption; the status is determined by your billing history, not only this month’s units.',
          icon: Icons.verified_user_outlined,
        ),
        _GuideItem(
          title: 'What the estimate includes',
          body:
              'The calculator applies configured residential energy slabs, fixed charges and your estimated tax or adjustment percentage.',
          icon: Icons.receipt_long_outlined,
        ),
        _GuideItem(
          title: 'Why the official bill may differ',
          body:
              'Monthly FCA/QTA, subsidies, arrears and provider-specific adjustments are not a stable per-unit tariff. Copy their combined amount from the applicable notification or bill into the adjustment field for a closer estimate.',
          icon: Icons.info_outline,
        ),
      ],
    ),
    children: [
      if (errorBanner() case final banner?) banner,
      SwitchListTile.adaptive(
        value: protectedConsumer,
        onChanged: (value) => setState(() => protectedConsumer = value),
        title: Text(context.l10n.phrase('Protected residential consumer')),
        subtitle: Text(
          context.l10n.phrase(
            'Enable only if “Protected” appears on your electricity bill.',
          ),
        ),
      ),
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
      _NumberField(
        controller: duty,
        label: context.l10n.phrase('Electricity duty'),
        suffix: '%',
      ),
      _NumberField(
        controller: adjustments,
        label: context.l10n.phrase('FCA, QTA and other adjustments'),
        suffix: 'PKR',
      ),
      _NumberField(
        controller: tvFee,
        label: context.l10n.phrase('TV fee'),
        suffix: 'PKR',
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
      final tariff = protectedConsumer
          ? protectedResidentialTariff2026
          : residentialTariff2026;
      result = ElectricityCalculator(tariff).calculate(
        ElectricityInput(
          units: consumed,
          taxRate: _parse(tax) / 100,
          electricityDutyRate: _parse(duty) / 100,
          adjustments: _parse(adjustments),
          tvFee: _parse(tvFee),
        ),
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
                  'Tariff category': result!.config.category,
                  'Energy charges': _money(result!.energyCharges),
                  'Fixed charges': _money(result!.fixedCharges),
                  'Taxes/adjustments': _money(result!.taxes),
                  'Electricity duty': _money(result!.electricityDuty),
                  'FCA/QTA/other adjustments': _money(result!.adjustments),
                  'TV fee': _money(result!.tvFee),
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
  final essentialLoad = TextEditingController();
  final backupHours = TextEditingController();
  SolarResult? result;
  @override
  void dispose() {
    units.dispose();
    roof.dispose();
    essentialLoad.dispose();
    backupHours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _CalculatorPage(
    title: context.l10n.text('solar'),
    guide: const _CalculatorGuide(
      intro:
          'Size a preliminary solar system from your electricity usage and available roof area.',
      items: [
        _GuideItem(
          title: 'What you need',
          body:
              'Use an average monthly kWh value from recent bills and estimate the shade-free roof area available for panels.',
          icon: Icons.fact_check_outlined,
        ),
        _GuideItem(
          title: 'What you will learn',
          body:
              'See a suggested system size, approximate panel count, roof requirement, generation, savings and simple payback period.',
          icon: Icons.solar_power_outlined,
        ),
        _GuideItem(
          title: 'Panel quality checklist',
          body:
              'Prefer verifiable Tier-1 bankable manufacturers, N-type mono modules with documented IEC 61215 and IEC 61730 compliance, a traceable serial number, product warranty and linear performance warranty. Tier-1 describes manufacturer bankability, not an automatic quality guarantee.',
          icon: Icons.solar_power_outlined,
        ),
        _GuideItem(
          title: 'Inverter and protection checklist',
          body:
              'The inverter must support the panel string voltage/current, provide suitable MPPT inputs, anti-islanding and applicable grid protection. Ask for DC isolators, correctly rated breakers, surge protection, earthing and a licensed installer. Confirm the current DISCO and NEPRA prosumer rules before planning export.',
          icon: Icons.electrical_services_outlined,
        ),
        _GuideItem(
          title: 'Battery sizing',
          body:
              'Enter only essential simultaneous load and desired backup hours. The tool estimates usable energy and allows 20% reserve for a lithium battery. Lead-acid systems normally require a larger nominal bank and different depth-of-discharge assumptions.',
          icon: Icons.battery_charging_full_outlined,
        ),
        _GuideItem(
          title: 'Plan before purchasing',
          body:
              'Ask a qualified installer to inspect structure, shade, orientation, inverter limits, batteries and current net-metering rules.',
          icon: Icons.engineering_outlined,
        ),
      ],
    ),
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
      _NumberField(
        controller: essentialLoad,
        label: context.l10n.phrase('Essential backup load'),
        suffix: 'kW',
      ),
      _NumberField(
        controller: backupHours,
        label: context.l10n.phrase('Required backup time'),
        suffix: 'hours',
      ),
    ],
    onCalculate: () => runCalculation(
      () => result = SolarCalculator(defaultSolarAssumptions).calculate(
        SolarInput(
          monthlyUnits: _parse(units),
          roofAreaSquareFeet: _parse(roof),
          essentialLoadKw: _parse(essentialLoad),
          backupHours: _parse(backupHours),
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
              'Suggested inverter':
                  '${result!.inverterKw.toStringAsFixed(1)} kW',
              'Usable battery energy':
                  '${result!.usableBatteryKwh.toStringAsFixed(1)} kWh',
              'Lithium battery bank (80% DoD)':
                  '${result!.nominalBatteryKwh.toStringAsFixed(1)} kWh',
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

class _PropertyForm extends ConsumerStatefulWidget {
  const _PropertyForm();
  @override
  ConsumerState<_PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends ConsumerState<_PropertyForm>
    with _CalculationState<_PropertyForm> {
  final length = TextEditingController();
  final width = TextEditingController();
  late final TextEditingController marla;
  final price = TextEditingController();
  PropertyResult? result;
  @override
  void initState() {
    super.initState();
    final standard = ref.read(settingsControllerProvider).marlaSquareFeet;
    marla = TextEditingController(text: standard.toString());
  }

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
    guide: const _CalculatorGuide(
      intro:
          'Convert plot dimensions into the property units commonly used in Pakistan.',
      items: [
        _GuideItem(
          title: 'Measure the plot',
          body:
              'Enter length and width in feet. This simple calculator assumes a rectangular plot.',
          icon: Icons.straighten_outlined,
        ),
        _GuideItem(
          title: 'Select the local Marla standard',
          body:
              'Marla size is not identical everywhere. Confirm whether your locality uses 225, 250, 272.25 or another square-foot standard.',
          icon: Icons.location_city_outlined,
        ),
        _GuideItem(
          title: 'Optional price estimate',
          body:
              'Enter a price per Marla to estimate total price. Registration, taxes, development charges and agent fees are not included.',
          icon: Icons.price_check_outlined,
        ),
        _GuideItem(
          title: 'Verify before buying',
          body:
              'This converts area only; it does not verify ownership, approved layout, zoning, road width, possession, encumbrances or buildable area. Match the Marla definition and dimensions against the allotment letter, approved map and relevant development authority record.',
          icon: Icons.policy_outlined,
        ),
      ],
    ),
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
      DropdownButtonFormField<double>(
        initialValue: const [225.0, 250.0, 272.25].contains(_parse(marla))
            ? _parse(marla)
            : null,
        decoration: InputDecoration(
          labelText: context.l10n.phrase('Common Marla standard'),
        ),
        items: [
          DropdownMenuItem(
            value: 225,
            child: Text(context.l10n.phrase('225 sq ft — Lahore convention')),
          ),
          DropdownMenuItem(
            value: 250,
            child: Text(context.l10n.phrase('250 sq ft — some societies')),
          ),
          DropdownMenuItem(
            value: 272.25,
            child: Text(context.l10n.phrase('272.25 sq ft — ICT/traditional')),
          ),
        ],
        onChanged: (value) {
          if (value != null) setState(() => marla.text = value.toString());
        },
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
              'Acres': _number(result!.acres, decimals: 4),
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
    guide: const _CalculatorGuide(
      intro:
          'Understand vehicle fuel average, trip cost and cost per kilometre.',
      items: [
        _GuideItem(
          title: 'Use the full-tank method',
          body:
              'For a reliable average, reset the trip meter after filling, drive normally, refill fully, then enter distance and litres added.',
          icon: Icons.local_gas_station_outlined,
        ),
        _GuideItem(
          title: 'How it is calculated',
          body:
              'Fuel average is distance divided by litres. Trip cost is litres multiplied by price, and cost per kilometre is total cost divided by distance.',
          icon: Icons.calculate_outlined,
        ),
        _GuideItem(
          title: 'Compare fairly',
          body:
              'Traffic, idling, tyre pressure, air conditioning, load and driving style affect consumption. Compare several full-tank entries.',
          icon: Icons.speed_outlined,
        ),
      ],
    ),
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
                  'Consumption':
                      '${result!.litersPer100Km.toStringAsFixed(2)} L/100 km',
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
  final cash = TextEditingController();
  final gold = TextEditingController();
  final silver = TextEditingController();
  final investments = TextEditingController();
  final businessAssets = TextEditingController();
  final receivables = TextEditingController();
  final otherAssets = TextEditingController();
  final liabilities = TextEditingController();
  final nisab = TextEditingController();
  bool isMuslim = false;
  bool ownsAboveNisab = false;
  bool lunarYearPassed = false;
  ZakatResult? result;
  @override
  void dispose() {
    cash.dispose();
    gold.dispose();
    silver.dispose();
    investments.dispose();
    businessAssets.dispose();
    receivables.dispose();
    otherAssets.dispose();
    liabilities.dispose();
    nisab.dispose();
    super.dispose();
  }

  Widget _conditionTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        context.l10n.phrase(title),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(context.l10n.phrase(subtitle)),
      controlAffinity: ListTileControlAffinity.leading,
    ),
  );

  @override
  Widget build(BuildContext context) => _CalculatorPage(
    title: context.l10n.text('zakat'),
    guide: const _CalculatorGuide(
      intro:
          'Review the basic conditions, understand Nisab, and calculate 2.5% of eligible net wealth.',
      items: [
        _GuideItem(
          title: 'When is Zakat applicable?',
          body:
              'Zakat generally applies to a Muslim whose eligible net wealth reaches Nisab and remains at or above it for one lunar year. Detailed rulings may differ, so consult a trusted scholar when unsure.',
          icon: Icons.person_outline,
        ),
        _GuideItem(
          title: 'What is Nisab?',
          body:
              'Nisab is the minimum wealth threshold. It is commonly based on the current market value of 87.48 grams of gold or 612.36 grams of silver. Many scholars recommend the silver threshold because it benefits more people in need.',
          icon: Icons.monetization_on_outlined,
        ),
        _GuideItem(
          title: 'What wealth is usually included?',
          body:
              'Cash and bank balances, gold and silver, trade inventory, eligible investments, recoverable receivables and other assets held for growth or sale are commonly included.',
          icon: Icons.account_balance_wallet_outlined,
        ),
        _GuideItem(
          title: 'What is generally excluded?',
          body:
              'A primary residence, normal personal vehicle, clothing, household furniture and ordinary daily-use items are generally not included. Enter only immediately deductible liabilities after confirming the applicable ruling.',
          icon: Icons.remove_circle_outline,
        ),
        _GuideItem(
          title: 'Simple rule',
          body:
              'If eligible assets minus deductible short-term liabilities meet the selected Nisab after one lunar year, estimated Zakat is 2.5% (1/40) of net eligible wealth.',
          icon: Icons.calculate_outlined,
        ),
      ],
    ),
    children: [
      if (errorBanner() case final banner?) banner,
      Text(
        context.l10n.phrase('Confirm the basic conditions'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      Text(
        context.l10n.phrase(
          'These checks help you review applicability; they are not a religious ruling.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      _conditionTile(
        title: 'I am Muslim',
        subtitle: 'Zakat is an obligation for eligible Muslims.',
        value: isMuslim,
        onChanged: (value) => setState(() => isMuslim = value ?? false),
      ),
      _conditionTile(
        title: 'My net eligible wealth reaches Nisab',
        subtitle: 'Use the current value of the Nisab standard you follow.',
        value: ownsAboveNisab,
        onChanged: (value) => setState(() => ownsAboveNisab = value ?? false),
      ),
      _conditionTile(
        title: 'One lunar year has passed',
        subtitle: 'Confirm the Hawl rule that applies to your assets.',
        value: lunarYearPassed,
        onChanged: (value) => setState(() => lunarYearPassed = value ?? false),
      ),
      Text(
        context.l10n.phrase('Your Zakatable assets'),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      _NumberField(
        controller: cash,
        label: context.l10n.phrase('Cash in hand and bank'),
        suffix: 'PKR',
      ),
      _NumberField(
        controller: gold,
        label: context.l10n.phrase('Gold value'),
        suffix: 'PKR',
      ),
      _NumberField(
        controller: silver,
        label: context.l10n.phrase('Silver value'),
        suffix: 'PKR',
      ),
      _NumberField(
        controller: investments,
        label: context.l10n.phrase('Eligible investments and shares'),
        suffix: 'PKR',
      ),
      _NumberField(
        controller: businessAssets,
        label: context.l10n.phrase('Business inventory and trade assets'),
        suffix: 'PKR',
      ),
      _NumberField(
        controller: receivables,
        label: context.l10n.phrase('Recoverable money owed to you'),
        suffix: 'PKR',
      ),
      _NumberField(
        controller: otherAssets,
        label: context.l10n.phrase('Other eligible assets'),
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
    onCalculate: () => runCalculation(() {
      if (!isMuslim || !ownsAboveNisab || !lunarYearPassed) {
        throw CalculationException(
          context.l10n.phrase(
            'Please review and confirm all applicable conditions before calculating.',
          ),
        );
      }
      final totalAssets =
          _parse(cash) +
          _parse(gold) +
          _parse(silver) +
          _parse(investments) +
          _parse(businessAssets) +
          _parse(receivables) +
          _parse(otherAssets);
      result = ZakatCalculator().calculate(
        ZakatInput(
          assets: totalAssets,
          liabilities: _parse(liabilities),
          nisab: _parse(nisab),
        ),
      );
    }),
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
