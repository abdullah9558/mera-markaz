import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/expenses/presentation/expenses_screen.dart';
import '../../features/fuel/presentation/vehicles_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/savings/presentation/savings_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/v1_more_screen.dart';
import '../../features/timeline/presentation/timeline_screen.dart';
import '../../features/tools/presentation/tools_screen.dart';
import '../../features/udhaar/presentation/udhaar_screen.dart';
import '../../shared/presentation/app_shell.dart';
import '../../shared/presentation/calculator_screen.dart';
import '../config/release_config.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authControllerProvider.select((state) => state.user?.id));
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (_, _) => const _UnavailableRouteScreen(),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
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
              GoRoute(path: '/tools', builder: (_, _) => const ToolsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/more', builder: (_, _) => const V1MoreScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/tool/:name',
        redirect: (_, state) =>
            ReleaseConfig.enabledTools.contains(state.pathParameters['name'])
            ? null
            : '/tools',
        builder: (_, state) =>
            CalculatorScreen(name: state.pathParameters['name'] ?? 'tools'),
      ),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      GoRoute(path: '/savings', builder: (_, _) => const SavingsScreen()),
      GoRoute(path: '/history', builder: (_, _) => const TimelineScreen()),
      GoRoute(path: '/udhaar', builder: (_, _) => const UdhaarScreen()),
      GoRoute(path: '/vehicles', builder: (_, _) => const VehiclesScreen()),
    ],
  );
});

class _UnavailableRouteScreen extends StatelessWidget {
  const _UnavailableRouteScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MeraMarkaz')),
    body: Center(
      child: FilledButton.icon(
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.home_rounded),
        label: const Text('Back to Home'),
      ),
    ),
  );
}
