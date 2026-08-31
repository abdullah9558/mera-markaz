import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/widget_snapshot_service.dart';
import '../../../core/notifications/markaz_alert_orchestrator.dart';
import '../../advanced/data/net_worth_repository.dart';
import '../../electricity/data/energy_intelligence_repository.dart';
import '../../intelligence/domain/financial_intelligence.dart';
import '../../metals/data/metal_zakat_repository.dart';
import '../../../core/pakistan_data/pakistan_data_point.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/presentation/brand_widgets.dart';
import '../../../shared/presentation/notification_popup.dart';
import '../../profile/presentation/profile_controller.dart';
import '../../savings/domain/savings_goal.dart';
import '../../intelligence/data/intelligence_provider.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/budget_analytics.dart';
import '../../expenses/domain/finance_transaction.dart';
import '../../expenses/presentation/expenses_screen.dart';
import '../../recurring/domain/recurring_transaction.dart';
import 'dashboard_provider.dart';
import '../data/dashboard_layout_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _quickActions = [
    ('Add Expense', Icons.add_card_rounded, 'expense'),
    ('Add Income', Icons.payments_outlined, 'income'),
    ('Add Udhaar', Icons.handshake_outlined, '/udhaar'),
    ('Calculate Bill', Icons.bolt_outlined, '/tool/electricity'),
    ('Ask Markaz AI', Icons.auto_awesome_outlined, 'ai'),
    ('Savings', Icons.savings_outlined, '/savings'),
    ('Calculate Tax', Icons.account_balance_outlined, '/tool/tax'),
    ('Pakistan Live', Icons.public_rounded, '/pakistan-live'),
  ];

  static const _tools = [
    ('Salary tax', 'FBR-ready estimate', Icons.account_balance, 'tax'),
    ('Electricity Bill', 'Estimate your bill', Icons.bolt, 'electricity'),
    ('Solar Calculator', 'Plan your system', Icons.solar_power, 'solar'),
    ('Plot / Marla', 'Convert property area', Icons.square_foot, 'property'),
  ];

  String _money(num value, {bool hidden = false}) => hidden
      ? 'Rs. ••••••'
      : 'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';

  Future<void> _openTransaction(
    BuildContext context,
    WidgetRef ref,
    TransactionType type,
  ) async {
    final changed = await showFinanceTransactionSheet(
      context,
      ref.read(expenseRepositoryProvider),
      initialType: type,
    );
    if (changed == true) ref.invalidate(homeDashboardProvider);
  }

  Future<void> _setReserve(BuildContext context, WidgetRef ref) async {
    var input = ref.read(safeToSpendReserveProvider).toStringAsFixed(0);
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.phrase('Safety reserve')),
        content: TextFormField(
          initialValue: input,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) => input = value,
          decoration: InputDecoration(
            prefixText: 'Rs. ',
            labelText: context.l10n.phrase('Amount to keep untouched'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(input.replaceAll(',', '').trim());
              if (parsed != null && parsed >= 0) {
                Navigator.pop(dialogContext, parsed);
              }
            },
            child: Text(context.l10n.phrase('Save')),
          ),
        ],
      ),
    );
    if (value != null) {
      await ref.read(safeToSpendReserveProvider.notifier).set(value);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(homeDashboardProvider);
    ref.listen(homeDashboardProvider, (_, next) {
      next.whenData((value) async {
        if (!ref.read(androidHomeBackgroundSyncProvider)) return;
        try {
          await ref.read(markazAlertOrchestratorProvider).refresh();
          final accounts = await ref
              .read(netWorthRepositoryProvider)
              .accounts();
          final netWorth = accounts.fold<double>(
            0,
            (sum, item) =>
                sum + (item.isLiability ? -item.balance : item.balance),
          );
          final score = const FinancialIntelligenceEngine().score(
            IntelligenceSnapshot(
              period: value.finance,
              categories: value.categories,
              categoryBudgets: value.categoryBudgets,
              ledger: value.ledger,
              goals: value.savingsGoals,
            ),
          );
          final energy = ref.read(energyIntelligenceRepositoryProvider);
          final systems = await energy.solarSystems();
          final roi = systems.isEmpty
              ? null
              : await energy.solarRoi(systems.first.id);
          final zakat = await ref
              .read(metalZakatRepositoryProvider)
              .zakatHistory();
          await const WidgetSnapshotService().publish(
            value,
            netWorth: netWorth,
            healthScore: score.value,
            solarProgress: roi?.progress,
            zakatReview: zakat.firstOrNull?.reminderAt?.toIso8601String(),
          );
        } catch (_) {
          await const WidgetSnapshotService().publish(value);
        }
      });
    });
    final dashboard = dashboardState.asData?.value;
    final finance = dashboard?.finance;
    final ledger = dashboard?.ledger;
    final privacy = ref.watch(privacyModeProvider);
    final score = ref.watch(markazScoreProvider).asData?.value;
    final insights = ref.watch(financialInsightsProvider).asData?.value;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final layout = ref.watch(dashboardLayoutProvider).asData?.value;
    final visibleSections = (layout ?? const <DashboardSectionPreference>[])
        .where((item) => item.visible)
        .map((item) => item.section)
        .toSet();
    bool visible(DashboardSection section) =>
        layout == null || visibleSections.contains(section);
    final userName = profile?.fullName.trim() ?? '';
    final salutation = context.l10n.phrase('Assalam-o-Alaikum');
    final hasUnreadNotifications =
        ref.watch(notificationInboxUnreadProvider).asData?.value ?? false;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: .94),
                titleSpacing: 20,
                title: Row(
                  children: [
                    InkWell(
                      onTap: () => context.go('/profile'),
                      borderRadius: BorderRadius.circular(99),
                      child: _UserAvatar(
                        name: profile?.fullName ?? '',
                        photoUrl: profile?.photoUrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            salutation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          if (userName.isNotEmpty)
                            Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: context.l10n.phrase(
                      privacy ? 'Show amounts' : 'Hide amounts',
                    ),
                    onPressed: () =>
                        ref.read(privacyModeProvider.notifier).toggle(),
                    icon: Icon(
                      privacy
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.phrase('Search'),
                    onPressed: () => context.push('/search'),
                    icon: const Icon(Icons.search_rounded),
                  ),
                  IconButton(
                    tooltip: context.l10n.phrase('Customize Home'),
                    onPressed: () async {
                      final changed = await context.push<bool>(
                        '/customize-home',
                      );
                      if (changed == true) {
                        ref.invalidate(dashboardLayoutProvider);
                      }
                    },
                    icon: const Icon(Icons.dashboard_customize_outlined),
                  ),
                  IconButton(
                    tooltip: context.l10n.phrase('Notifications'),
                    onPressed: () => showNotificationPopup(context),
                    icon: Badge(
                      isLabelVisible: hasUnreadNotifications,
                      smallSize: 7,
                      backgroundColor: Colors.orange,
                      child: const Icon(Icons.notifications_outlined),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
                sliver: SliverList.list(
                  children: [
                    if (dashboardState.isLoading) ...[
                      const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 14),
                    ],
                    if (dashboardState.hasError) ...[
                      _DashboardError(
                        onRetry: () => ref.invalidate(homeDashboardProvider),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (visible(DashboardSection.balance))
                      _BalanceCard(
                        balance: _money(
                          finance?.availableBalance ?? 0,
                          hidden: privacy,
                        ),
                        income: _money(finance?.income ?? 0, hidden: privacy),
                        expense: _money(
                          finance?.expenses ?? 0,
                          hidden: privacy,
                        ),
                        change: finance?.expenseChange,
                      ),
                    if (visible(DashboardSection.safeToSpend)) ...[
                      const SizedBox(height: 14),
                      _SafeToSpendCard(
                        value: _money(
                          dashboard?.safeToSpend ?? 0,
                          hidden: privacy,
                        ),
                        commitments: _money(
                          dashboard?.upcomingTotal ?? 0,
                          hidden: privacy,
                        ),
                        reserve: _money(
                          dashboard?.reserve ?? 0,
                          hidden: privacy,
                        ),
                        isNegative: (dashboard?.safeToSpend ?? 0) < 0,
                        onConfigure: () => _setReserve(context, ref),
                      ),
                    ],
                    if (visible(DashboardSection.budget) &&
                        dashboard?.budget != null) ...[
                      const SizedBox(height: 14),
                      _BudgetCard(
                        amount: _money(
                          dashboard!.budget!.amount,
                          hidden: privacy,
                        ),
                        spent: _money(finance?.expenses ?? 0, hidden: privacy),
                        remaining: _money(
                          (dashboard.budgetRemaining ?? 0).abs(),
                          hidden: privacy,
                        ),
                        progress: dashboard.budgetProgress,
                      ),
                    ],
                    if (dashboard?.newBudgetAlerts.isNotEmpty == true) ...[
                      const SizedBox(height: 14),
                      _BudgetAlertCard(alert: dashboard!.newBudgetAlerts.last),
                    ],
                    if (visible(DashboardSection.udhaar)) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _UdhaarCard(
                              icon: Icons.south_west_rounded,
                              label: context.l10n.text('toReceive'),
                              value: _money(
                                ledger?.toReceive ?? 0,
                                hidden: privacy,
                              ),
                              color: AppColors.emerald,
                              onTap: () => context.go('/udhaar'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _UdhaarCard(
                              icon: Icons.north_east_rounded,
                              label: context.l10n.text('toPay'),
                              value: _money(
                                ledger?.toPay ?? 0,
                                hidden: privacy,
                              ),
                              color: const Color(0xFFFFB4AB),
                              onTap: () => context.go('/udhaar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (visible(DashboardSection.quickActions)) ...[
                      const SizedBox(height: 30),
                      _SectionHeading(context.l10n.text('quickActions')),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 108,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _quickActions.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 18),
                          itemBuilder: (context, index) {
                            final action = _quickActions[index];
                            return _QuickAction(
                              label: context.l10n.phrase(action.$1),
                              icon: action.$2,
                              onTap: () {
                                if (action.$3 == 'expense') {
                                  _openTransaction(
                                    context,
                                    ref,
                                    TransactionType.expense,
                                  );
                                } else if (action.$3 == 'income') {
                                  _openTransaction(
                                    context,
                                    ref,
                                    TransactionType.income,
                                  );
                                } else if (action.$3 == 'ai') {
                                  context.push('/markaz-ai');
                                } else if (action.$3.startsWith('/tool/')) {
                                  context.push(action.$3);
                                } else {
                                  context.go(action.$3);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    if (visible(DashboardSection.insight)) ...[
                      const SizedBox(height: 26),
                      Card(
                        child: ListTile(
                          onTap: () => context.push('/markaz-ai'),
                          leading: CircleAvatar(
                            child: Text(score == null ? '—' : '${score.value}'),
                          ),
                          title: Text(context.l10n.phrase('Markaz Insight')),
                          subtitle: Text(
                            insights?.firstOrNull == null
                                ? context.l10n.phrase(
                                    "Keep using Mera Markaz and we'll show insights as your financial history grows.",
                                  )
                                : (Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'ur'
                                      ? insights!.first.urduMessage
                                      : insights!.first.message),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ],
                    if (visible(DashboardSection.pakistanToday)) ...[
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: _SectionHeading(
                              context.l10n.phrase('Pakistan Today'),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/pakistan-live'),
                            child: Text(context.l10n.phrase('View all')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PakistanTodayCard(
                        loading: dashboardState.isLoading,
                        error: dashboardState.hasError,
                        items: dashboard?.pakistanToday ?? const [],
                        onTap: () => context.push('/pakistan-live'),
                        onRetry: () => ref.invalidate(homeDashboardProvider),
                      ),
                    ],
                    if (visible(DashboardSection.upcoming)) ...[
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: _SectionHeading(
                              context.l10n.phrase('Upcoming payments'),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/recurring'),
                            child: Text(context.l10n.phrase('View all')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _UpcomingPreview(
                        items: dashboard?.upcomingCommitments ?? const [],
                        hidden: privacy,
                        money: _money,
                        onTap: () => context.push('/recurring'),
                      ),
                    ],
                    if (visible(DashboardSection.savings)) ...[
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: _SectionHeading(
                              context.l10n.phrase('Savings goals'),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/savings'),
                            child: Text(context.l10n.phrase('View all')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _GoalsPreview(
                        goals: dashboard?.savingsGoals ?? const [],
                        hidden: privacy,
                        money: _money,
                        onTap: () => context.push('/savings'),
                      ),
                    ],
                    if (visible(DashboardSection.recentActivity)) ...[
                      const SizedBox(height: 26),
                      _SectionHeading(
                        context.l10n.phrase('Recent transactions'),
                      ),
                      const SizedBox(height: 12),
                      _RecentTransactions(
                        items: dashboard?.recentTransactions ?? const [],
                        hidden: privacy,
                        money: _money,
                        onViewAll: () => context.push('/history'),
                      ),
                    ],
                    if (visible(DashboardSection.tools)) ...[
                      const SizedBox(height: 26),
                      _SectionHeading(context.l10n.text('popularTools')),
                      const SizedBox(height: 14),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tools.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 1.16,
                            ),
                        itemBuilder: (context, index) {
                          final tool = _tools[index];
                          return _ToolCard(
                            title: context.l10n.phrase(tool.$1),
                            subtitle: context.l10n.phrase(tool.$2),
                            icon: tool.$3,
                            onTap: () => context.push('/tool/${tool.$4}'),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PakistanTodayCard extends StatelessWidget {
  const _PakistanTodayCard({
    required this.loading,
    required this.error,
    required this.items,
    required this.onTap,
    required this.onRetry,
  });

  final bool loading;
  final bool error;
  final List<PakistanDataPoint> items;
  final VoidCallback onTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: loading
            ? const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              )
            : error
            ? Row(
                children: [
                  const Icon(Icons.cloud_off_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.phrase(
                        'Could not refresh Pakistan data. Showing saved values.',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.phrase('Refresh'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              )
            : Builder(
                builder: (context) {
                  final highlights = items
                      .where(
                        (item) => const {
                          'usd_pkr',
                          'gold_24k_tola',
                          'petrol',
                        }.contains(item.seriesKey),
                      )
                      .take(3)
                      .toList();
                  if (highlights.isEmpty) {
                    return Row(
                      children: [
                        const Icon(Icons.public_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.l10n.phrase(
                              'Open Pakistan Live for verified rates and economic updates.',
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      for (
                        var index = 0;
                        index < highlights.length;
                        index++
                      ) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(
                          child: _PakistanHighlight(item: highlights[index]),
                        ),
                      ],
                    ],
                  );
                },
              ),
      ),
    ),
  );
}

class _PakistanHighlight extends StatelessWidget {
  const _PakistanHighlight({required this.item});
  final PakistanDataPoint item;

  @override
  Widget build(BuildContext context) {
    final label = switch (item.seriesKey) {
      'usd_pkr' => 'USD / PKR',
      'gold_24k_tola' => 'Gold 24K / Tola',
      'petrol' => 'Petrol',
      _ => item.seriesKey,
    };
    final stale =
        item.freshness == DataFreshness.stale ||
        item.freshness == DataFreshness.unavailable;
    return Semantics(
      label: '${context.l10n.phrase(label)} ${item.value} ${item.unit}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.phrase(label),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            NumberFormat.decimalPattern('en_PK').format(item.value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            context.l10n.phrase(
              stale ? 'Stale' : _freshnessLabel(item.freshness),
            ),
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: stale
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

String _freshnessLabel(DataFreshness freshness) => switch (freshness) {
  DataFreshness.current => 'Current',
  DataFreshness.recentlyUpdated => 'Recently updated',
  DataFreshness.cached => 'Cached',
  DataFreshness.stale => 'Stale',
  DataFreshness.unavailable => 'Unavailable',
};

class _SafeToSpendCard extends StatelessWidget {
  const _SafeToSpendCard({
    required this.value,
    required this.commitments,
    required this.reserve,
    required this.isNegative,
    required this.onConfigure,
  });
  final String value;
  final String commitments;
  final String reserve;
  final bool isNegative;
  final VoidCallback onConfigure;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.phrase('How Safe to Spend works'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Text(
                  context.l10n.phrase(
                    'Available balance minus upcoming essential payments and your safety reserve. This is guidance, not a guarantee.',
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(context.l10n.phrase('Upcoming commitments')),
                  trailing: Text(commitments),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shield_outlined),
                  title: Text(context.l10n.phrase('Safety reserve')),
                  trailing: Text(reserve),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onConfigure();
                    },
                    icon: const Icon(Icons.tune),
                    label: Text(context.l10n.phrase('Configure reserve')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  (isNegative
                          ? Theme.of(context).colorScheme.error
                          : AppColors.emerald)
                      .withValues(alpha: .15),
              child: Icon(
                Icons.shield_outlined,
                color: isNegative
                    ? Theme.of(context).colorScheme.error
                    : AppColors.emerald,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.phrase('Safe to Spend'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.phrase('After upcoming payments and reserve'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: isNegative ? Theme.of(context).colorScheme.error : null,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}

class _UpcomingPreview extends StatelessWidget {
  const _UpcomingPreview({
    required this.items,
    required this.hidden,
    required this.money,
    required this.onTap,
  });
  final List<RecurringTransaction> items;
  final bool hidden;
  final String Function(num, {bool hidden}) money;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.event_available_outlined),
          title: Text(context.l10n.phrase('No upcoming payments this month')),
          subtitle: Text(
            context.l10n.phrase(
              'Add recurring bills or commitments to improve Safe to Spend.',
            ),
          ),
          trailing: const Icon(Icons.add),
        ),
      );
    }
    return Card(
      child: Column(
        children: items
            .take(3)
            .map(
              (item) => ListTile(
                onTap: onTap,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(DateFormat.yMMMd().format(item.nextDueAt)),
                trailing: Text(
                  money(item.amount, hidden: hidden),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
    required this.change,
  });
  final String balance;
  final String income;
  final String expense;
  final double? change;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF153B78), Color(0xFF12151D)],
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
      boxShadow: [
        BoxShadow(
          color: AppColors.emerald.withValues(alpha: .12),
          blurRadius: 30,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.phrase('AVAILABLE BALANCE'),
          style: const TextStyle(
            color: Color(0xFFC7CBD6),
            letterSpacing: 1.4,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          balance,
          style: const TextStyle(
            color: AppColors.mist,
            fontSize: 38,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.4,
          ),
        ),
        const SizedBox(height: 24),
        if (change != null) ...[
          Text(
            change == 0
                ? context.l10n.phrase('Expenses are unchanged from last month')
                : '${change! > 0 ? '↑' : '↓'} ${(change!.abs() * 100).toStringAsFixed(0)}% ${context.l10n.phrase('expenses vs last month')}',
            style: const TextStyle(color: Color(0xFFC7CBD6), fontSize: 12),
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            Expanded(
              child: _SummaryAmount(
                label: context.l10n.phrase('Income'),
                value: income,
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SummaryAmount(
                label: context.l10n.phrase('Expenses'),
                value: expense,
                color: const Color(0xFFFFB4AB),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.sync_problem_outlined),
      title: Text(context.l10n.phrase('Financial summary unavailable')),
      subtitle: Text(
        context.l10n.phrase(
          'Your records are safe. Try loading the summary again.',
        ),
      ),
      trailing: IconButton(
        tooltip: context.l10n.phrase('Retry'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ),
  );
}

class _SummaryAmount extends StatelessWidget {
  const _SummaryAmount({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Color(0xFFC7CBD6))),
      const SizedBox(height: 4),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.amount,
    required this.spent,
    required this.remaining,
    required this.progress,
  });
  final String amount;
  final String spent;
  final String remaining;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final exceeded = progress > 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.phrase('Monthly budget'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(amount),
              ],
            ),
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0, 1)),
              duration: const Duration(milliseconds: 550),
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 9,
                borderRadius: BorderRadius.circular(99),
                color: exceeded ? const Color(0xFFFFB4AB) : AppColors.emerald,
                backgroundColor: const Color(0xFF232C3E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              exceeded
                  ? '${context.l10n.phrase('Budget exceeded')}: $remaining'
                  : '${context.l10n.phrase('Spent')} $spent • ${context.l10n.phrase('Remaining')} $remaining • ${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Color(0xFFC7CBD6), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetAlertCard extends StatelessWidget {
  const _BudgetAlertCard({required this.alert});
  final BudgetThresholdAlert alert;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.notifications_active_outlined),
      title: Text(
        alert.exceeded
            ? context.l10n.phrase('Budget exceeded')
            : '${alert.threshold}% ${context.l10n.phrase('budget warning')}',
      ),
      subtitle: Text(
        alert.category == null
            ? '${context.l10n.phrase("You've used")} ${alert.threshold}% ${context.l10n.phrase('of your monthly budget.')}'
            : '${context.l10n.phrase("You've used")} ${alert.threshold}% ${context.l10n.phrase('of your')} ${context.l10n.phrase(alert.category!)} ${context.l10n.phrase('budget.')}',
      ),
    ),
  );
}

class _UdhaarCard extends StatelessWidget {
  const _UdhaarCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: .86),
      borderRadius: BorderRadius.circular(24),
    ),
    child: InteractiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 14),
            Text(label, style: const TextStyle(color: Color(0xFFC7CBD6))),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GoalsPreview extends StatelessWidget {
  const _GoalsPreview({
    required this.goals,
    required this.hidden,
    required this.money,
    required this.onTap,
  });
  final List<SavingsGoal> goals;
  final bool hidden;
  final String Function(num value, {bool hidden}) money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return Card(
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.savings_outlined),
          title: Text(context.l10n.phrase('No savings goals yet')),
          subtitle: Text(
            context.l10n.phrase('Create a goal and start tracking progress.'),
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
    }
    return Column(
      children: goals
          .map(
            (goal) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  onTap: onTap,
                  leading: Text(
                    goal.icon ?? '🎯',
                    style: const TextStyle(fontSize: 26),
                  ),
                  title: Text(goal.name),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: LinearProgressIndicator(
                      value: goal.progress.clamp(0, 1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  trailing: Text(
                    money(goal.savedAmount, hidden: hidden),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({
    required this.items,
    required this.hidden,
    required this.money,
    required this.onViewAll,
  });
  final List<FinanceTransaction> items;
  final bool hidden;
  final String Function(num value, {bool hidden}) money;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 36),
              const SizedBox(height: 10),
              Text(
                context.l10n.text('noTransactions'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                context.l10n.text('noTransactionsHint'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              leading: CircleAvatar(
                child: Icon(
                  items[index].type == TransactionType.income
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                ),
              ),
              title: Text(
                items[index].description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${context.l10n.phrase(items[index].categoryName)} • ${DateFormat.MMMd().format(items[index].occurredAt)}',
              ),
              trailing: Text(
                '${items[index].type == TransactionType.income ? '+' : '−'} ${money(items[index].amount, hidden: hidden)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (index != items.length - 1) const Divider(height: 1),
          ],
          TextButton(
            onPressed: onViewAll,
            child: Text(context.l10n.phrase('View all transactions')),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    child: InteractiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Icon(icon, color: AppColors.emerald),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InteractiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: AppColors.emerald),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFC7CBD6), fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 20,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    backgroundImage: photoUrl?.isNotEmpty == true
        ? NetworkImage(photoUrl!)
        : null,
    child: photoUrl?.isNotEmpty == true
        ? null
        : Text(name.trim().isEmpty ? 'M' : name.trim().characters.first),
  );
}
