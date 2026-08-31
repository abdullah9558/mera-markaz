import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../data/timeline_repository.dart';
import '../domain/timeline_event.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});
  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _search = TextEditingController();
  final Set<TimelineEventType> _types = {};
  DateTimeRange? _range;
  double? _minimum;
  double? _maximum;
  late Future<List<TimelineEvent>> _events;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _events = ref
        .read(timelineRepositoryProvider)
        .events(
          TimelineFilter(
            types: _types,
            from: _range?.start,
            to: _range?.end.add(const Duration(days: 1)),
            minimumAmount: _minimum,
            maximumAmount: _maximum,
            query: _search.text,
          ),
        );
  }

  void _refresh() => setState(_reload);
  String _money(num value) =>
      'Rs. ${NumberFormat.decimalPattern('en_PK').format(value.abs())}';

  Future<void> _amountFilter() async {
    final minimum = TextEditingController(text: _minimum?.toString());
    final maximum = TextEditingController(text: _maximum?.toString());
    final result = await showDialog<(double?, double?)>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.phrase('Amount range')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minimum,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Minimum amount'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: maximum,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.phrase('Maximum amount'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, (null, null)),
            child: Text(context.l10n.phrase('Clear')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (
              double.tryParse(minimum.text),
              double.tryParse(maximum.text),
            )),
            child: Text(context.l10n.phrase('Apply')),
          ),
        ],
      ),
    );
    minimum.dispose();
    maximum.dispose();
    if (result != null) {
      _minimum = result.$1;
      _maximum = result.$2;
      _refresh();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.phrase('Financial timeline')),
      actions: [
        IconButton(
          tooltip: context.l10n.phrase('Recurring transactions'),
          onPressed: () => context.push('/recurring'),
          icon: const Icon(Icons.autorenew_rounded),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => _refresh(),
            decoration: InputDecoration(
              hintText: context.l10n.phrase('Search timeline'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [
              for (final type in TimelineEventType.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FilterChip(
                    selected: _types.contains(type),
                    label: Text(context.l10n.phrase(type.name)),
                    onSelected: (selected) {
                      selected ? _types.add(type) : _types.remove(type);
                      _refresh();
                    },
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(context.l10n.phrase('Date range')),
                onPressed: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (range != null) {
                    _range = range;
                    _refresh();
                  }
                },
              ),
              const SizedBox(width: 6),
              ActionChip(
                avatar: const Icon(Icons.payments_outlined, size: 18),
                label: Text(context.l10n.phrase('Amount range')),
                onPressed: _amountFilter,
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<TimelineEvent>>(
            future: _events,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final events = snapshot.data!;
              if (events.isEmpty) {
                return Center(
                  child: Text(
                    context.l10n.phrase('No timeline entries found.'),
                  ),
                );
              }
              String? previousDay;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final day = DateFormat.yMMMMd().format(event.date);
                  final showHeader = day != previousDay;
                  previousDay = day;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                          child: Text(
                            day,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      Card(
                        child: ListTile(
                          leading: Icon(_icon(event.type)),
                          title: Text(event.title),
                          subtitle: Text(context.l10n.phrase(event.subtitle)),
                          trailing: Text(
                            '${event.positive ? '+' : '−'} ${_money(event.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: event.positive
                                  ? AppColors.emerald
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );

  IconData _icon(TimelineEventType type) => switch (type) {
    TimelineEventType.income => Icons.payments_outlined,
    TimelineEventType.expense => Icons.receipt_long_outlined,
    TimelineEventType.udhaar => Icons.handshake_outlined,
    TimelineEventType.savings => Icons.savings_outlined,
  };
}
