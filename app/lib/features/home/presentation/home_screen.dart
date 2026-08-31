import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../shared/presentation/brand_widgets.dart';
import '../../profile/presentation/profile_controller.dart';
import 'dashboard_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _money(num value, bool hidden) => hidden
      ? 'Rs. ••••••'
      : 'Rs. ${NumberFormat.decimalPattern('en_PK').format(value)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeDashboardProvider);
    final privacy = ref.watch(privacyModeProvider);
    final profile = ref.watch(userProfileProvider).asData?.value;
    final name = profile?.fullName.trim() ?? '';
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(homeDashboardProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Row(
                  children: [
                    const BrandMark(size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.phrase('Assalam-o-Alaikum'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (name.isNotEmpty)
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          ref.read(privacyModeProvider.notifier).toggle(),
                      icon: Icon(
                        privacy
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push('/search'),
                      icon: const Icon(Icons.search_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                data.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (error, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        context.l10n.phrase(
                          'Could not load your dashboard. Pull down to try again.',
                        ),
                      ),
                    ),
                  ),
                  data: (value) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.l10n.phrase('Spent this month')),
                              const SizedBox(height: 6),
                              Text(
                                _money(value.finance.expenses, privacy),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value: value.budgetProgress.clamp(0, 1),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                value.budget == null
                                    ? context.l10n.phrase(
                                        'Set a monthly budget to track your progress',
                                      )
                                    : '${context.l10n.phrase('Budget remaining')}: ${_money(value.budgetRemaining ?? 0, privacy)}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _Action(
                            label: 'Add expense',
                            icon: Icons.add_card_rounded,
                            onTap: () => context.go('/expenses'),
                          ),
                          _Action(
                            label: 'Udhaar',
                            icon: Icons.handshake_rounded,
                            onTap: () => context.push('/udhaar'),
                          ),
                          _Action(
                            label: 'Savings',
                            icon: Icons.savings_rounded,
                            onTap: () => context.push('/savings'),
                          ),
                          _Action(
                            label: 'Calculators',
                            icon: Icons.calculate_rounded,
                            onTap: () => context.go('/tools'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Text(
                        context.l10n.phrase('Recent expenses'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (value.recentTransactions.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              context.l10n.phrase(
                                'No expenses yet. Add your first expense to get started.',
                              ),
                            ),
                          ),
                        )
                      else
                        ...value.recentTransactions.map(
                          (item) => Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.receipt_long_rounded),
                              ),
                              title: Text(item.description),
                              subtitle: Text(item.categoryName),
                              trailing: Text(
                                _money(item.amount, privacy),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/history'),
                        icon: const Icon(Icons.history_rounded),
                        label: Text(context.l10n.phrase('View history')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 58) / 2,
    child: FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(context.l10n.phrase(label)),
    ),
  );
}
