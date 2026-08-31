import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/settings/presentation/profile_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/savings/presentation/savings_screen.dart';
import '../../features/intelligence/presentation/markaz_ai_screen.dart';
import '../../features/timeline/presentation/timeline_screen.dart';
import '../../features/recurring/presentation/recurring_screen.dart';
import '../../features/tools/presentation/tools_screen.dart';
import '../../features/udhaar/presentation/udhaar_screen.dart';
import '../../features/fuel/presentation/vehicles_screen.dart';
import '../../features/advanced/presentation/advanced_features_screen.dart';
import '../../features/pakistan_live/presentation/pakistan_live_screen.dart';
import '../../features/home/presentation/dashboard_customization_screen.dart';
import '../../features/pakistan_live/presentation/exchange_center_screen.dart';
import '../../features/pakistan_live/presentation/watchlist_screen.dart';
import '../../features/personal_finance/presentation/personal_finance_center_screen.dart';
import '../../features/electricity/presentation/energy_intelligence_screen.dart';
import '../../features/metals/presentation/gold_zakat_center_screen.dart';
import '../../features/advanced_finance/presentation/advanced_finance_screen.dart';
import '../../features/settings/presentation/widget_settings_screen.dart';
import '../../features/settings/presentation/notifications_screen.dart';
import '../../features/settings/presentation/markaz_alerts_screen.dart';
import '../../features/pakistan_specific/presentation/pakistan_specific_center_screen.dart';
import '../../shared/presentation/app_shell.dart';
import '../../shared/presentation/calculator_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authControllerProvider.select((state) => state.user?.id));
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/expenses',
                builder: (_, _) => const ExpensesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/udhaar', builder: (_, _) => const UdhaarScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/tools', builder: (_, _) => const ToolsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/tool/:name',
        builder: (_, state) =>
            CalculatorScreen(name: state.pathParameters['name'] ?? 'tools'),
      ),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/savings', builder: (_, _) => const SavingsScreen()),
      GoRoute(path: '/markaz-ai', builder: (_, _) => const MarkazAiScreen()),
      GoRoute(path: '/history', builder: (_, _) => const TimelineScreen()),
      GoRoute(path: '/recurring', builder: (_, _) => const RecurringScreen()),
      GoRoute(path: '/vehicles', builder: (_, _) => const VehiclesScreen()),
      GoRoute(
        path: '/pakistan-live',
        builder: (_, _) => const PakistanLiveScreen(),
      ),
      GoRoute(
        path: '/customize-home',
        builder: (_, _) => const DashboardCustomizationScreen(),
      ),
      GoRoute(
        path: '/exchange',
        builder: (_, _) => const ExchangeCenterScreen(),
      ),
      GoRoute(path: '/watchlists', builder: (_, _) => const WatchlistScreen()),
      GoRoute(
        path: '/personal-finance',
        builder: (_, _) => const PersonalFinanceCenterScreen(),
      ),
      GoRoute(
        path: '/energy-intelligence',
        builder: (_, _) => const EnergyIntelligenceScreen(),
      ),
      GoRoute(
        path: '/gold-zakat',
        builder: (_, _) => const GoldZakatCenterScreen(),
      ),
      GoRoute(
        path: '/advanced-finance',
        builder: (_, _) => const AdvancedFinanceScreen(),
      ),
      GoRoute(
        path: '/pakistan-specific',
        builder: (_, _) => const PakistanSpecificCenterScreen(),
      ),
      GoRoute(
        path: '/widget-settings',
        builder: (_, _) => const WidgetSettingsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const MarkazAlertsScreen(),
      ),
      GoRoute(
        path: '/notification-settings',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/advanced',
        builder: (_, _) => const AdvancedFeaturesScreen(),
      ),
    ],
  );
});
