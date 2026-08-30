import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
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
import 'dashboard_provider.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(homeDashboardProvider);
    final dashboard = dashboardState.asData?.value;
    final finance = dashboard?.finance;
    final ledger = dashboard?.ledger;
    final privacy = ref.watch(privacyModeProvider);
    final score = ref.watch(markazScoreProvider).asData?.value;
    final insights = ref.watch(financialInsightsProvider).asData?.value;
    final profile = ref.watch(userProfileProvider).asData?.value;
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
                    _BalanceCard(
                      balance: _money(
                        finance?.availableBalance ?? 0,
                        hidden: privacy,
                      ),
                      income: _money(finance?.income ?? 0, hidden: privacy),
                      expense: _money(finance?.expenses ?? 0, hidden: privacy),
                      change: finance?.expenseChange,
                    ),
                    if (dashboard?.budget != null) ...[
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
                            value: _money(ledger?.toPay ?? 0, hidden: privacy),
                            color: const Color(0xFFFFB4AB),
                            onTap: () => context.go('/udhaar'),
                          ),
                        ),
                      ],
                    ),
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
                              : (Localizations.localeOf(context).languageCode ==
                                        'ur'
                                    ? insights!.first.urduMessage
                                    : insights!.first.message),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
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
                    const SizedBox(height: 26),
                    _SectionHeading(context.l10n.phrase('Recent transactions')),
                    const SizedBox(height: 12),
                    _RecentTransactions(
                      items: dashboard?.recentTransactions ?? const [],
                      hidden: privacy,
                      money: _money,
                      onViewAll: () => context.push('/history'),
                    ),
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
                ),
              ),
            ],
          ),
        ),
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
