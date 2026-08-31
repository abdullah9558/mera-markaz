import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../profile/presentation/edit_profile_screen.dart';
import '../../profile/presentation/profile_controller.dart';
import 'feedback_screen.dart';
import 'legal_screen.dart';
import 'privacy_data_screen.dart';
import 'settings_controller.dart';

class V1MoreScreen extends ConsumerWidget {
  const V1MoreScreen({super.key});

  Future<void> _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final profile = ref.watch(userProfileProvider).asData?.value;
    final guest = user?.isGuest ?? true;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.phrase('More'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
              title: Text(user?.displayName ?? context.l10n.phrase('Guest')),
              subtitle: Text(
                guest
                    ? context.l10n.phrase('Your data is stored on this device')
                    : context.l10n.phrase('Account and cloud sync enabled'),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(
                context,
                guest
                    ? const AuthScreen(
                        allowGuest: false,
                        popOnAuthenticated: true,
                      )
                    : profile == null
                    ? const SizedBox.shrink()
                    : EditProfileScreen(profile: profile),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.history_rounded,
            title: 'History',
            onTap: () => context.push('/history'),
          ),
          _Tile(
            icon: Icons.search_rounded,
            title: 'Search',
            onTap: () => context.push('/search'),
          ),
          _Tile(
            icon: Icons.savings_rounded,
            title: 'Savings goals',
            onTap: () => context.push('/savings'),
          ),
          _Tile(
            icon: Icons.handshake_rounded,
            title: 'Udhaar',
            onTap: () => context.push('/udhaar'),
          ),
          const Divider(height: 28),
          _Tile(
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: settings.languageCode == 'ur' ? 'اردو' : 'English',
            onTap: () => ref
                .read(settingsControllerProvider.notifier)
                .setLanguage(settings.languageCode == 'en' ? 'ur' : 'en'),
          ),
          _Tile(
            icon: Icons.brightness_6_rounded,
            title: 'Appearance',
            subtitle: settings.themeMode.name,
            onTap: () async {
              final mode = await showModalBottomSheet<ThemeMode>(
                context: context,
                builder: (sheet) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: ThemeMode.values
                        .map(
                          (mode) => ListTile(
                            leading: Icon(
                              mode == settings.themeMode
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                            ),
                            title: Text(
                              context.l10n.phrase(
                                mode == ThemeMode.system
                                    ? 'System default (Auto)'
                                    : mode.name,
                              ),
                            ),
                            onTap: () => Navigator.pop(sheet, mode),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
              if (mode != null) {
                await ref
                    .read(settingsControllerProvider.notifier)
                    .setTheme(mode);
              }
            },
          ),
          _Tile(
            icon: Icons.security_rounded,
            title: 'Privacy, backup & data',
            onTap: () => _open(context, const PrivacyDataScreen()),
          ),
          _Tile(
            icon: Icons.feedback_outlined,
            title: 'Feedback & support',
            onTap: () => _open(context, const FeedbackScreen()),
          ),
          _Tile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () => _open(
              context,
              const LegalScreen(document: LegalDocument.privacy),
            ),
          ),
          _Tile(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            onTap: () => _open(
              context,
              const LegalScreen(document: LegalDocument.terms),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.l10n.phrase('Sign out')),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              context.l10n.phrase('MeraMarkaz version 1.0.0'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(context.l10n.phrase(title)),
      subtitle: subtitle == null ? null : Text(context.l10n.phrase(subtitle!)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
