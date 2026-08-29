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
        path: '/advanced',
        builder: (_, _) => const AdvancedFeaturesScreen(),
      ),
    ],
  );
});
