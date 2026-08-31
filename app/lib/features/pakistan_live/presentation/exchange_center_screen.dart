import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/currency_converter.dart';
import 'pakistan_live_screen.dart';

class ExchangeCenterScreen extends ConsumerStatefulWidget {
  const ExchangeCenterScreen({super.key});
  @override
  ConsumerState<ExchangeCenterScreen> createState() =>
      _ExchangeCenterScreenState();
}

class _ExchangeCenterScreenState extends ConsumerState<ExchangeCenterScreen> {
  String from = 'USD';
  String to = 'PKR';
  double amount = 1;
  @override
  Widget build(BuildContext context) {
    final points = ref.watch(pakistanLiveProvider).asData?.value ?? const [];
    final rates = <String, double>{
      for (final point in points.where(
        (item) => item.seriesKey.endsWith('_pkr'),
      ))
        point.seriesKey.split('_').first.toUpperCase(): point.value,
    };
    final currencies = ['PKR', ...rates.keys];
    double? result;
    Object? error;
    try {
      result = const CurrencyConverter().convert(
        amount: amount,
        from: from,
        to: to,
        pkrPerUnit: rates,
      );
    } catch (value) {
      error = value;
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.phrase('PKR Exchange Center'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.l10n.phrase(
              'Convert using the latest verified rates saved by Pakistan Live.',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 18),
          TextFormField(
            initialValue: amount.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.l10n.phrase('Amount'),
            ),
            onChanged: (value) =>
                setState(() => amount = double.tryParse(value) ?? 0),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: currencies.contains(from) ? from : 'PKR',
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('From'),
                  ),
                  items: currencies
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => from = value!),
                ),
              ),
              IconButton(
                tooltip: context.l10n.phrase('Swap'),
                onPressed: () => setState(() {
                  final old = from;
                  from = to;
                  to = old;
                }),
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: currencies.contains(to) ? to : 'PKR',
                  decoration: InputDecoration(
                    labelText: context.l10n.phrase('To'),
                  ),
                  items: currencies
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => to = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Text(context.l10n.phrase('Converted amount')),
                  const SizedBox(height: 8),
                  Text(
                    result == null
                        ? '—'
                        : '${NumberFormat.decimalPattern('en_PK').format(result)} $to',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        context.l10n.phrase(
                          'A verified rate is unavailable. Refresh Pakistan Live first.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.phrase('Quick amounts'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [1, 100, 500, 1000]
                .map(
                  (value) => ActionChip(
                    label: Text(NumberFormat.decimalPattern().format(value)),
                    onPressed: () => setState(() => amount = value.toDouble()),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.phrase(
              'Rates may differ from bank, card, remittance or open-market settlement rates. Check the source and update time before relying on a conversion.',
            ),
          ),
        ],
      ),
    );
  }
}
