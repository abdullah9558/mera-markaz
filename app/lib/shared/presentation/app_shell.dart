import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, Icons.home, context.l10n.text('home')),
      (
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet,
        context.l10n.text('expenses'),
      ),
      (Icons.handshake_outlined, Icons.handshake, context.l10n.text('udhaar')),
      (Icons.calculate_outlined, Icons.calculate, context.l10n.text('tools')),
      (Icons.person_outline, Icons.person, context.l10n.text('profile')),
    ];
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLow.withValues(alpha: .98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: .12)),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withValues(alpha: .08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 78,
            child: Row(
              children: List.generate(items.length, (index) {
                final selected = navigationShell.currentIndex == index;
                final item = items[index];
                return Expanded(
                  child: InkWell(
                    onTap: () => navigationShell.goBranch(
                      index,
                      initialLocation: selected,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.$2 : item.$1,
                          color: selected
                              ? AppColors.emerald
                              : const Color(0xFFBCCABD),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected
                                ? AppColors.emerald
                                : const Color(0xFFBCCABD),
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
