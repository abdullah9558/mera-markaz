import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/presentation/brand_widgets.dart';
import '../../../shared/presentation/notification_popup.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/edit_profile_screen.dart';
import '../../profile/presentation/profile_controller.dart';
import 'encryption_setup_screen.dart';
import 'authorized_devices_screen.dart';
import 'privacy_data_screen.dart';
import 'settings_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool biometric = false;
  bool biometricAvailable = false;
  bool biometricLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBiometric());
  }

  Future<void> _loadBiometric() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null || user.isGuest) {
      if (mounted) setState(() => biometricLoading = false);
      return;
    }
    final service = ref.read(biometricServiceProvider);
    final results = await Future.wait([
      service.isAvailable(),
      service.isEnabled(user.id),
    ]);
    if (!mounted) return;
    setState(() {
      biometricAvailable = results[0];
      biometric = results[1];
      biometricLoading = false;
    });
  }

  Future<void> _changeBiometric(bool enabled) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null || user.isGuest || !biometricAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.phrase(
              'Fingerprint authentication is not available on this device.',
            ),
          ),
        ),
      );
      return;
    }
    setState(() => biometricLoading = true);
    final service = ref.read(biometricServiceProvider);
    final authenticated = await service.authenticate();
    if (!mounted) return;
    if (!authenticated) {
      setState(() => biometricLoading = false);
      return;
    }
    await service.setEnabled(user.id, enabled);
    if (!mounted) return;
    setState(() {
      biometric = enabled;
      biometricLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final isGuest = ref.watch(authControllerProvider).user?.isGuest == true;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.surface.withValues(alpha: .94),
                title: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .12),
                        ),
                      ),
                      child: const Icon(Icons.person_outline),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.text('greeting'),
                      style: const TextStyle(
                        color: AppColors.emerald,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () => showNotificationPopup(context),
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                sliver: SliverList.list(
                  children: [
                    _ProfileHero(
                      profile: profile,
                      onEdit: profile == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditProfileScreen(profile: profile),
                              ),
                            ),
                    ),
                    if (isGuest) ...[
                      const SizedBox(height: 18),
                      const _GuestAccountCard(),
                    ],
                    const SizedBox(height: 24),
                    _SettingsCard(
                      title: context.l10n.phrase('MY ACCOUNT'),
                      children: [
                        _SettingsTile(
                          icon: Icons.manage_accounts_outlined,
                          label: context.l10n.phrase('Edit Profile'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: profile == null
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditProfileScreen(profile: profile),
                                  ),
                                ),
                        ),
                        _SettingsTile(
                          icon: Icons.translate,
                          label: context.l10n.phrase('Language'),
                          trailing: _LanguageSwitch(
                            selected: ref
                                .watch(settingsControllerProvider)
                                .languageCode,
                            onChanged: (value) => ref
                                .read(settingsControllerProvider.notifier)
                                .setLanguage(value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SettingsCard(
                      title: context.l10n.phrase('FINANCIAL SETTINGS'),
                      children: [
                        _SettingsTile(
                          icon: Icons.payments_outlined,
                          label: context.l10n.phrase('Default Currency'),
                          trailing: Text(
                            context.l10n.phrase('PKR'),
                            style: const TextStyle(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.calendar_month_outlined,
                          label: context.l10n.phrase('Tax Year'),
                          trailing: Text(context.l10n.phrase('2024–25')),
                        ),
                        _SettingsTile(
                          icon: Icons.square_foot,
                          label: context.l10n.phrase('Marla Standard'),
                          trailing: Text(context.l10n.phrase('225 sq ft')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SettingsCard(
                      title: context.l10n.phrase('SECURITY'),
                      children: [
                        _SettingsTile(
                          icon: Icons.fingerprint,
                          label: context.l10n.phrase('Biometric Lock'),
                          trailing: Switch(
                            value: biometric,
                            onChanged: biometricLoading
                                ? null
                                : _changeBiometric,
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.policy_outlined,
                          label: context.l10n.phrase('Data Privacy'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyDataScreen(),
                            ),
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.enhanced_encryption_outlined,
                          label: context.l10n.phrase(
                            'Local encryption & optional recovery',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EncryptionSetupScreen(),
                            ),
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.devices_other_outlined,
                          label: context.l10n.phrase('Authorized devices'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AuthorizedDevicesScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SettingsCard(
                      title: context.l10n.phrase('SUPPORT & DATA'),
                      children: [
                        _SettingsTile(
                          icon: Icons.star_outline,
                          label: context.l10n.phrase('Rate App'),
                        ),
                        _SettingsTile(
                          icon: Icons.share_outlined,
                          label: context.l10n.phrase('Share Mera Markaz'),
                        ),
                        _SettingsTile(
                          icon: Icons.help_outline,
                          label: context.l10n.phrase('Help Center'),
                        ),
                        _SettingsTile(
                          icon: Icons.download_outlined,
                          label: context.l10n.phrase('Export Data (CSV/PDF)'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyDataScreen(),
                            ),
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.delete_outline,
                          label: context.l10n.phrase('Delete All Data'),
                          destructive: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyDataScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).signOut(),
                      icon: const Icon(Icons.logout),
                      label: Text(context.l10n.phrase('Sign out')),
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.onEdit});
  final UserProfile? profile;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final name = profile?.fullName.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(99),
            child: CircleAvatar(
              radius: 54,
              backgroundColor: AppColors.surfaceContainer,
              backgroundImage: profile?.photoUrl?.isNotEmpty == true
                  ? NetworkImage(profile!.photoUrl!)
                  : null,
              child: profile?.photoUrl?.isNotEmpty == true
                  ? null
                  : const Icon(
                      Icons.account_circle_outlined,
                      size: 58,
                      color: AppColors.emerald,
                    ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            name == null || name.isEmpty
                ? context.l10n.phrase('Mera Markaz User')
                : name,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh.withValues(alpha: .86),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withValues(alpha: .13)),
    ),
    child: Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.emerald,
                letterSpacing: 1.2,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        ...children,
      ],
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 64,
    shape: const Border(top: BorderSide(color: Color(0x183D4A40))),
    leading: Icon(icon, color: destructive ? const Color(0xFFFF9D96) : null),
    title: Text(
      label,
      style: TextStyle(color: destructive ? const Color(0xFFFF9D96) : null),
    ),
    trailing: trailing,
    onTap: onTap,
  );
}

class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFF0A1F1C),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LanguageOption(
          label: 'EN',
          selected: selected == 'en',
          onTap: () => onChanged('en'),
        ),
        _LanguageOption(
          label: 'اردو',
          selected: selected == 'ur',
          onTap: () => onChanged('ur'),
        ),
      ],
    ),
  );
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(11),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppColors.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.emerald : const Color(0xFFBCCABD),
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _GuestAccountCard extends StatelessWidget {
  const _GuestAccountCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh.withValues(alpha: .86),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: AppColors.emerald.withValues(alpha: .35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.phrase('Temporary guest session'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.phrase(
            'Create an account to keep your current activity. Sign in to an existing account to discard this temporary activity and restore that account.',
          ),
          style: const TextStyle(color: Color(0xFFBCCABD)),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AuthScreen(
                initialSignup: true,
                allowGuest: false,
                popOnAuthenticated: true,
              ),
            ),
          ),
          child: Text(context.l10n.phrase('Create account & keep data')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const AuthScreen(allowGuest: false, popOnAuthenticated: true),
            ),
          ),
          child: Text(context.l10n.phrase('Sign in to existing account')),
        ),
      ],
    ),
  );
}
