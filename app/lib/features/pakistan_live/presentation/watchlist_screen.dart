import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../data/watchlist_repository.dart';
import '../domain/watch_condition.dart';

final watchlistProvider = FutureProvider(
  (ref) => ref.watch(watchlistRepositoryProvider).all(),
);

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(watchlistProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.phrase('Financial watchlists'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add_alert_outlined),
        label: Text(context.l10n.phrase('Add alert')),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(watchlistProvider),
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.phrase('Try again')),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none_rounded, size: 64),
                      const SizedBox(height: 14),
                      Text(
                        context.l10n.phrase('No price alerts yet'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.phrase(
                          'Create an alert for a meaningful currency, gold, fuel or economic threshold.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(context.l10n.phrase('Delete alert?')),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: Text(context.l10n.phrase('Cancel')),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: Text(context.l10n.phrase('Delete')),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (_) async {
                      await ref
                          .read(watchlistRepositoryProvider)
                          .delete(item.id);
                      ref.invalidate(watchlistProvider);
                    },
                    background: Container(
                      alignment: AlignmentDirectional.centerEnd,
                      padding: const EdgeInsets.all(24),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const Icon(Icons.delete_outline),
                    ),
                    child: Card(
                      child: ListTile(
                        onTap: () => _edit(context, ref, item),
                        leading: Icon(
                          item.comparison == WatchComparison.above
                              ? Icons.trending_up
                              : Icons.trending_down,
                        ),
                        title: Text(
                          _label(item.seriesKey),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${context.l10n.phrase(item.comparison == WatchComparison.above ? 'Above' : 'Below')} ${item.targetValue.toStringAsFixed(2)}',
                        ),
                        trailing: Switch(
                          value: item.enabled,
                          onChanged: (value) async {
                            await ref
                                .read(watchlistRepositoryProvider)
                                .setEnabled(item.id, value);
                            ref.invalidate(watchlistProvider);
                          },
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

Future<void> _edit(
  BuildContext context,
  WidgetRef ref, [
  WatchCondition? current,
]) async {
  const series = [
    'usd_pkr',
    'gbp_pkr',
    'eur_pkr',
    'aed_pkr',
    'sar_pkr',
    'gold_24k_tola',
    'silver_tola',
    'petrol',
    'diesel',
    'sbp_policy_rate',
    'inflation_cpi',
  ];
  var selected = current?.seriesKey ?? series.first;
  var comparison = current?.comparison ?? WatchComparison.above;
  var input = current?.targetValue.toString() ?? '';
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.phrase(
                current == null ? 'Create price alert' : 'Edit price alert',
              ),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Indicator'),
              ),
              items: series
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_label(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setSheetState(() => selected = value!),
            ),
            const SizedBox(height: 12),
            SegmentedButton<WatchComparison>(
              segments: [
                ButtonSegment(
                  value: WatchComparison.above,
                  label: Text(context.l10n.phrase('Above')),
                ),
                ButtonSegment(
                  value: WatchComparison.below,
                  label: Text(context.l10n.phrase('Below')),
                ),
              ],
              selected: {comparison},
              onSelectionChanged: (value) =>
                  setSheetState(() => comparison = value.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: input,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) => input = value,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Target value'),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  final target = double.tryParse(
                    input.replaceAll(',', '').trim(),
                  );
                  if (target != null && target > 0) {
                    Navigator.pop(sheetContext, true);
                  }
                },
                child: Text(context.l10n.phrase('Save alert')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (saved != true) return;
  await ref
      .read(watchlistRepositoryProvider)
      .save(
        id: current?.id,
        seriesKey: selected,
        comparison: comparison,
        targetValue: double.parse(input.replaceAll(',', '').trim()),
        enabled: current?.enabled ?? true,
        cooldownMinutes: current?.cooldownMinutes ?? 1440,
      );
  ref.invalidate(watchlistProvider);
}

String _label(String key) =>
    const {
      'usd_pkr': 'USD / PKR',
      'gbp_pkr': 'GBP / PKR',
      'eur_pkr': 'EUR / PKR',
      'aed_pkr': 'AED / PKR',
      'sar_pkr': 'SAR / PKR',
      'gold_24k_tola': 'Gold 24K / Tola',
      'silver_tola': 'Silver / Tola',
      'petrol': 'Petrol',
      'diesel': 'Diesel',
      'sbp_policy_rate': 'SBP Policy Rate',
      'inflation_cpi': 'Inflation (CPI)',
    }[key] ??
    key;
