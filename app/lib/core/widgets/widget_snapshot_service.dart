import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/home/presentation/dashboard_provider.dart';

enum WidgetPrivacy { hidden, visible }

enum WidgetTheme { system, light, dark }

class WidgetPreferences {
  const WidgetPreferences({
    this.privacy = WidgetPrivacy.hidden,
    this.theme = WidgetTheme.system,
    this.insight = 'safe_to_spend',
    this.market = 'usd_pkr',
    this.quickActions = const ['expense', 'udhaar', 'savings'],
  });
  final WidgetPrivacy privacy;
  final WidgetTheme theme;
  final String insight;
  final String market;
  final List<String> quickActions;
  factory WidgetPreferences.fromMap(Map<Object?, Object?> map) =>
      WidgetPreferences(
        privacy: map['privacy'] == 'visible'
            ? WidgetPrivacy.visible
            : WidgetPrivacy.hidden,
        theme: WidgetTheme.values.firstWhere(
          (value) => value.name == map['theme'],
          orElse: () => WidgetTheme.system,
        ),
        insight: map['insight'] as String? ?? 'safe_to_spend',
        market: map['market'] as String? ?? 'usd_pkr',
        quickActions: ('${map['quickActions'] ?? 'expense,udhaar,savings'}')
            .split(',')
            .where((value) => value.isNotEmpty)
            .take(3)
            .toList(),
      );
  Map<String, Object?> toMap() => {
    'privacy': privacy.name,
    'theme': theme.name,
    'insight': insight,
    'market': market,
    'quickActions': quickActions.join(','),
  };
}

class WidgetSnapshotService {
  const WidgetSnapshotService();
  static const _channel = MethodChannel('pk.pakpocket.pakpocket/widgets');

  Future<void> publish(
    HomeDashboardData value, {
    double? netWorth,
    int? healthScore,
    double? solarProgress,
    String? zakatReview,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final markets = <String, String>{};
    for (final point in value.pakistanToday) {
      markets[point.seriesKey] =
          '${point.value.toStringAsFixed(2)} ${point.unit}|${point.sourceName}|${point.freshness.name}';
    }
    await _channel.invokeMethod<void>('publish', {
      'income': value.finance.income,
      'expenses': value.finance.expenses,
      'remaining': value.finance.availableBalance,
      'budgetPercent': value.budgetProgress * 100,
      'safeToSpend': value.safeToSpend,
      'upcoming': value.upcomingTotal,
      'receivable': value.ledger.toReceive,
      'payable': value.ledger.toPay,
      'savingsGoal': value.savingsGoals.firstOrNull?.name ?? '',
      'savingsProgress': value.savingsGoals.firstOrNull?.progress ?? 0,
      'markets': markets,
      'updatedAt': DateTime.now().toIso8601String(),
      'fuelMonthly': value.categories
          .where((item) => item.categoryName.toLowerCase() == 'fuel')
          .fold<double>(0, (sum, item) => sum + item.amount),
      'netWorth': netWorth ?? 0,
      'healthScore': healthScore ?? 0,
      'solarProgress': solarProgress ?? 0,
      'zakatReview': zakatReview ?? 'Not scheduled',
    });
  }

  Future<void> configure(WidgetPreferences value) async {
    try {
      await _channel.invokeMethod<void>('configure', value.toMap());
    } on MissingPluginException {
      // Home-screen widgets are Android-only. Other platforms keep defaults.
    }
  }

  Future<WidgetPreferences> load() async {
    try {
      final value = await _channel.invokeMethod<Map<Object?, Object?>>('load');
      return WidgetPreferences.fromMap(value ?? const {});
    } on MissingPluginException {
      return const WidgetPreferences();
    }
  }
}
