import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import 'feedback_screen.dart';

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

  String _themeLabel(BuildContext context, ThemeMode mode) => switch (mode) {
    ThemeMode.system => context.l10n.phrase('System default (Auto)'),
    ThemeMode.light => context.l10n.phrase('Light'),
    ThemeMode.dark => context.l10n.phrase('Dark'),
  };

  Future<void> _showAppearancePicker(ThemeMode current) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sheetContext.l10n.phrase('Appearance'),
              style: Theme.of(
                sheetContext,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              sheetContext.l10n.phrase(
                'System default follows your phone appearance automatically.',
              ),
            ),
            const SizedBox(height: 18),
            for (final option in [
              (ThemeMode.system, Icons.brightness_auto_rounded),
              (ThemeMode.light, Icons.light_mode_rounded),
              (ThemeMode.dark, Icons.dark_mode_rounded),
            ])
              Card(
                child: ListTile(
                  onTap: () async {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .setTheme(option.$1);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  leading: Icon(option.$2),
                  title: Text(_themeLabel(sheetContext, option.$1)),
                  trailing: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: current == option.$1
                        ? const Icon(
                            Icons.check_circle_rounded,
                            key: ValueKey(true),
                            color: AppColors.emerald,
                          )
                        : const Icon(
                            Icons.circle_outlined,
                            key: ValueKey(false),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _taxYearLabel(String financialYear) {
    final endYear = financialYear.split('-').last;
    return 'FY $financialYear / TY 20$endYear';
  }

  String _marlaLabel(BuildContext context, double value) {
    final number = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
    return '$number ${context.l10n.phrase('sq ft')}';
  }

  Future<void> _showTaxYearPicker(String current) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sheetContext.l10n.phrase('Select tax year'),
              style: Theme.of(
                sheetContext,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              sheetContext.l10n.phrase(
                'Pakistan tax years run from 1 July to 30 June. Calculator rates change when a new Finance Act takes effect.',
              ),
            ),
            const SizedBox(height: 18),
            for (final year in ['2026-27', '2025-26'])
              Card(
                child: ListTile(
                  onTap: () async {
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .setTaxYear(year);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(_taxYearLabel(year)),
                  subtitle: Text(
                    year == '2026-27'
                        ? sheetContext.l10n.phrase(
                            'Current • FBR Finance Act 2026',
                          )
                        : sheetContext.l10n.phrase('FBR Finance Act 2025'),
                  ),
                  trailing: Icon(
                    current == year
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: current == year ? AppColors.emerald : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMarlaPicker(double current) async {
    final selected = await showModalBottomSheet<double?>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sheetContext.l10n.phrase('Select Marla standard'),
              style: Theme.of(
                sheetContext,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              sheetContext.l10n.phrase(
                'Marla size varies by authority and housing society. Confirm it from the approved plan or property documents.',
              ),
            ),
            const SizedBox(height: 18),
            for (final option in [
              (225.0, 'Lahore and many modern housing schemes'),
              (250.0, 'Used by some housing societies'),
              (272.25, 'Traditional standard and ICT'),
            ])
              Card(
                child: ListTile(
                  onTap: () => Navigator.pop(sheetContext, option.$1),
                  leading: const Icon(Icons.square_foot_rounded),
                  title: Text(_marlaLabel(sheetContext, option.$1)),
                  subtitle: Text(sheetContext.l10n.phrase(option.$2)),
                  trailing: Icon(
                    (current - option.$1).abs() < .001
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: (current - option.$1).abs() < .001
                        ? AppColors.emerald
                        : null,
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: () => Navigator.pop(sheetContext, -1),
              icon: const Icon(Icons.edit_outlined),
              label: Text(sheetContext.l10n.phrase('Enter custom size')),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected > 0) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setMarlaSquareFeet(selected);
      return;
    }
    final controller = TextEditingController(text: current.toString());
    final custom = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.phrase('Custom Marla size')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: dialogContext.l10n.phrase('Square feet per Marla'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value != null && value > 0) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: Text(dialogContext.l10n.phrase('Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (custom != null) {
      await ref
          .read(settingsControllerProvider.notifier)
          .setMarlaSquareFeet(custom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final isGuest = ref.watch(authControllerProvider).user?.isGuest == true;
    final hasUnreadNotifications =
        ref.watch(notificationInboxUnreadProvider).asData?.value ?? false;
    final settings = ref.watch(settingsControllerProvider);
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
                title: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.phrase('Assalam-o-Alaikum'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.emerald,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          if (profile?.fullName.trim().isNotEmpty == true)
                            Text(
                              profile!.fullName.trim(),
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
                          icon: Icons.notifications_active_outlined,
                          label: context.l10n.phrase('Markaz Alerts'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/notifications'),
                        ),
                        _SettingsTile(
                          icon: Icons.tune_rounded,
                          label: context.l10n.phrase('Notification settings'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/notification-settings'),
                        ),
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
                        _SettingsTile(
                          icon: Icons.palette_outlined,
                          label: context.l10n.phrase('Appearance'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _themeLabel(context, settings.themeMode),
                                style: const TextStyle(
                                  color: AppColors.emerald,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () =>
                              _showAppearancePicker(settings.themeMode),
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_taxYearLabel(settings.taxYear)),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => _showTaxYearPicker(settings.taxYear),
                        ),
                        _SettingsTile(
                          icon: Icons.square_foot,
                          label: context.l10n.phrase('Marla Standard'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _marlaLabel(context, settings.marlaSquareFeet),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () =>
                              _showMarlaPicker(settings.marlaSquareFeet),
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
                          icon: Icons.feedback_outlined,
                          label: context.l10n.phrase('Send Feedback'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FeedbackScreen(),
                            ),
                          ),
                        ),
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
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(99),
            child: CircleAvatar(
              radius: 54,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh,
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
  Widget build(BuildContext context) => Material(
    color: Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: .90),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
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
      color: Theme.of(context).colorScheme.surfaceContainer,
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
        color: selected
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected
              ? AppColors.emerald
              : Theme.of(context).colorScheme.onSurfaceVariant,
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
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: .90),
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
          style: const TextStyle(color: Color(0xFFC7CBD6)),
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
