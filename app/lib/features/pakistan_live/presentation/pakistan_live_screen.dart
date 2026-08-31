import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/pakistan_data/pakistan_data_point.dart';
import '../../../core/pakistan_data/pakistan_data_service.dart';
import '../../../core/pakistan_data/pakistan_data_repository.dart';

final pakistanLiveProvider = FutureProvider((ref) async {
  final service = ref.watch(pakistanDataServiceProvider);
  try {
    await service.refresh();
  } catch (_) {
    // Saved verified values remain available while the source is unreachable.
  }
  return service.dashboard();
});

final pakistanHistoryProvider =
    FutureProvider.family<List<PakistanDataPoint>, String>(
      (ref, seriesKey) =>
          ref.watch(pakistanDataRepositoryProvider).history(seriesKey),
    );

class PakistanLiveScreen extends ConsumerStatefulWidget {
  const PakistanLiveScreen({super.key});
  @override
  ConsumerState<PakistanLiveScreen> createState() => _PakistanLiveScreenState();
}

class _PakistanLiveScreenState extends ConsumerState<PakistanLiveScreen> {
  String filter = 'All';
  bool refreshing = false;

  Future<void> refresh() async {
    setState(() => refreshing = true);
    try {
      final count = await ref.read(pakistanDataServiceProvider).refresh();
      ref.invalidate(pakistanLiveProvider);
      if (mounted && count == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.phrase(
                'No verified update is available. Cached data is unchanged.',
              ),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.phrase(
                'Could not refresh Pakistan data. Showing saved values.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pakistanLiveProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.phrase('Pakistan Live')),
        actions: [
          IconButton(
            tooltip: context.l10n.phrase('PKR Exchange Center'),
            onPressed: () => context.push('/exchange'),
            icon: const Icon(Icons.currency_exchange_rounded),
          ),
          IconButton(
            tooltip: context.l10n.phrase('Financial watchlists'),
            onPressed: () => context.push('/watchlists'),
            icon: const Icon(Icons.add_alert_outlined),
          ),
          IconButton(
            tooltip: context.l10n.phrase('Refresh'),
            onPressed: refreshing ? null : refresh,
            icon: refreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: state.when(
          loading: () => const _LoadingView(),
          error: (_, _) => _EmptyView(onRefresh: refresh),
          data: (items) {
            if (items.isEmpty) return _EmptyView(onRefresh: refresh);
            final visible = items
                .where(
                  (item) => filter == 'All' || _group(item.seriesKey) == filter,
                )
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
              children: [
                Text(
                  context.l10n.phrase('Pakistan economic information'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.phrase(
                    'Every value includes its source and update time. Saved or stale values are never presented as live.',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: const [
                      'All',
                      'Currency',
                      'Metals',
                      'Fuel',
                      'Economy',
                    ].length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final value = const [
                        'All',
                        'Currency',
                        'Metals',
                        'Fuel',
                        'Economy',
                      ][index];
                      return ChoiceChip(
                        label: Text(context.l10n.phrase(value)),
                        selected: filter == value,
                        onSelected: (_) => setState(() => filter = value),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                ...visible.map((item) => _IndicatorCard(item: item)),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _group(String key) {
  if (key.endsWith('_pkr')) return 'Currency';
  if (key.startsWith('gold') || key.startsWith('silver')) return 'Metals';
  if (key == 'petrol' || key == 'diesel') return 'Fuel';
  return 'Economy';
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({required this.item});
  final PakistanDataPoint item;
  @override
  Widget build(BuildContext context) {
    final change = item.change;
    final positive = (change ?? 0) >= 0;
    final freshnessColor = switch (item.freshness) {
      DataFreshness.current => Colors.green,
      DataFreshness.recentlyUpdated => Colors.blue,
      DataFreshness.cached => Colors.orange,
      DataFreshness.stale ||
      DataFreshness.unavailable => Theme.of(context).colorScheme.error,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => _Details(item: item),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(child: Icon(_icon(item.seriesKey))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.phrase(_label(item.seriesKey)),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: freshnessColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.phrase(_freshness(item.freshness)),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${NumberFormat.decimalPattern('en_PK').format(item.value)} ${item.unit}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  if (change != null)
                    Text(
                      '${positive ? '+' : ''}${change.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: positive
                            ? Colors.green
                            : Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.item});
  final PakistanDataPoint item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(pakistanHistoryProvider(item.seriesKey));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.phrase(_label(item.seriesKey)),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            _row(context, 'Source', item.sourceName),
            _row(
              context,
              'Effective date',
              DateFormat.yMMMd().add_jm().format(item.effectiveAt.toLocal()),
            ),
            _row(
              context,
              'Last updated',
              DateFormat.yMMMd().add_jm().format(item.retrievedAt.toLocal()),
            ),
            _row(
              context,
              'Status',
              context.l10n.phrase(_freshness(item.freshness)),
            ),
            _row(context, 'Data version', item.configVersion),
            const SizedBox(height: 10),
            Text(
              context.l10n.phrase('Historical movement'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            history.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) =>
                  Text(context.l10n.phrase('History is unavailable.')),
              data: (points) => points.length < 2
                  ? Text(
                      context.l10n.phrase(
                        'More history is needed for a chart.',
                      ),
                    )
                  : _HistoryChart(points: points),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            context.l10n.phrase(label),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.points});
  final List<PakistanDataPoint> points;

  @override
  Widget build(BuildContext context) {
    final first = points.first.value;
    final last = points.last.value;
    return Semantics(
      label: context.l10n
          .phrase('Historical chart from {first} to {last}')
          .replaceAll('{first}', first.toStringAsFixed(2))
          .replaceAll('{last}', last.toStringAsFixed(2)),
      child: SizedBox(
        height: 120,
        width: double.infinity,
        child: CustomPaint(
          painter: _HistoryPainter(
            values: points.map((point) => point.value).toList(),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    final range = maximum - minimum;
    final path = Path();
    for (var index = 0; index < values.length; index++) {
      final x = size.width * index / (values.length - 1);
      final normalized = range == 0 ? .5 : (values[index] - minimum) / range;
      final y = size.height - (normalized * (size.height - 16)) - 8;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRefresh});
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 90),
      const Icon(Icons.cloud_off_outlined, size: 68),
      const SizedBox(height: 18),
      Text(
        context.l10n.phrase('No verified Pakistan data yet'),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Text(
        context.l10n.phrase(
          'Connect to the internet and refresh. Mera Markaz will never invent a live value.',
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.phrase('Refresh')),
      ),
    ],
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(18),
    itemCount: 6,
    itemBuilder: (_, _) => const Card(child: SizedBox(height: 90)),
  );
}

String _label(String key) =>
    const {
      'usd_pkr': 'USD / PKR',
      'gbp_pkr': 'GBP / PKR',
      'eur_pkr': 'EUR / PKR',
      'aed_pkr': 'AED / PKR',
      'sar_pkr': 'SAR / PKR',
      'cad_pkr': 'CAD / PKR',
      'aud_pkr': 'AUD / PKR',
      'qar_pkr': 'QAR / PKR',
      'kwd_pkr': 'KWD / PKR',
      'omr_pkr': 'OMR / PKR',
      'gold_24k_tola': 'Gold 24K / Tola',
      'silver_tola': 'Silver / Tola',
      'petrol': 'Petrol',
      'diesel': 'Diesel',
      'sbp_policy_rate': 'SBP Policy Rate',
      'kibor_3m': 'KIBOR 3M',
      'inflation_cpi': 'Inflation (CPI)',
      'forex_reserves': 'Forex Reserves',
    }[key] ??
    key;
String _freshness(DataFreshness value) => switch (value) {
  DataFreshness.current => 'Current',
  DataFreshness.recentlyUpdated => 'Recently updated',
  DataFreshness.cached => 'Cached',
  DataFreshness.stale => 'Stale',
  DataFreshness.unavailable => 'Unavailable',
};
IconData _icon(String key) => switch (_group(key)) {
  'Currency' => Icons.currency_exchange,
  'Metals' => Icons.diamond_outlined,
  'Fuel' => Icons.local_gas_station_outlined,
  _ => Icons.monitor_heart_outlined,
};
