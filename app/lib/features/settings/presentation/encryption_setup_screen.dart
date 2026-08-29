import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/security/biometric_service.dart';
import '../../../core/security/crypto/key_enrollment_service.dart';
import '../../../core/sync/cloud_device_service.dart';
import '../../../core/sync/encrypted_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';

class EncryptionSetupScreen extends ConsumerStatefulWidget {
  const EncryptionSetupScreen({super.key});

  @override
  ConsumerState<EncryptionSetupScreen> createState() =>
      _EncryptionSetupScreenState();
}

class _EncryptionSetupScreenState extends ConsumerState<EncryptionSetupScreen> {
  final _service = KeyEnrollmentService();
  bool _loading = true;
  bool _confirmed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null || user.isGuest) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final exists = await _service.hasEnrollment(user.id);
      final confirmed = exists && await _service.isConfirmed(user.id);
      if (exists && !confirmed) await _service.removeLocalEnrollment(user.id);
      if (mounted) setState(() => _confirmed = confirmed);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = context.l10n.phrase('Secure setup could not be loaded.'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enroll() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null || user.isGuest) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final biometric = ref.read(biometricServiceProvider);
      if (await biometric.isAvailable() && !await biometric.authenticate()) {
        return;
      }
      final enrollment = await _service.enroll(user.id);
      if (!mounted) return;
      final accepted = await _confirmRecoveryKey(enrollment.recoveryKey);
      if (accepted) {
        await _service.confirmEnrollment(user.id);
        final cloud = CloudDeviceService(enrollment: _service);
        await cloud.registerCurrentDevice(user.id);
        await cloud.uploadRecoveryEnvelope(user.id);
      } else {
        await _service.removeLocalEnrollment(user.id);
      }
      if (mounted) setState(() => _confirmed = accepted);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.l10n.phrase(
            'Secure setup failed. Nothing was changed.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _recover() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null || user.isGuest) return;
    final controller = TextEditingController();
    final key = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.phrase('Restore encrypted data')),
        content: TextField(
          controller: controller,
          autocorrect: false,
          enableSuggestions: false,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: dialogContext.l10n.phrase('Recovery key'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.phrase('Cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(dialogContext.l10n.phrase('Restore')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (key == null || key.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cloud = CloudDeviceService(enrollment: _service);
      final wrapped = await cloud.downloadRecoveryEnvelope(user.id);
      await _service.recoverAndEnrollDevice(user.id, key, wrapped);
      await cloud.registerCurrentDevice(user.id);
      await ref.read(encryptedSyncServiceProvider).synchronize(user.id);
      if (mounted) setState(() => _confirmed = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = context.l10n.phrase(
            'Recovery failed. Check the recovery key and try again.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmRecoveryKey(String recoveryKey) async {
    final controller = TextEditingController();
    final expected = recoveryKey.substring(recoveryKey.length - 8);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.key_outlined, color: AppColors.emerald),
        title: Text(dialogContext.l10n.phrase('Save your recovery key')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                dialogContext.l10n.phrase(
                  'This key is shown once. Keep it somewhere private and separate from this phone. Mera Markaz cannot recover encrypted data without an authorized device or this key.',
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(
                  recoveryKey,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontFamily: 'monospace', height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                dialogContext.l10n.phrase(
                  'Enter the final 8 characters to confirm that you saved it.',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                textDirection: TextDirection.ltr,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: dialogContext.l10n.phrase('Final 8 characters'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.phrase('Cancel setup')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim() == expected,
            ),
            child: Text(dialogContext.l10n.phrase('Confirm recovery key')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final isGuest = user == null || user.isGuest;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.phrase('Local encryption & optional recovery'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(
            _confirmed ? Icons.verified_user : Icons.shield_outlined,
            size: 72,
            color: AppColors.emerald,
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.phrase(
              _confirmed
                  ? 'Optional recovery is configured for this account.'
                  : 'Local financial data is encrypted automatically on this device.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.phrase(
              isGuest
                  ? 'Guest data is encrypted locally. Sign in only if you want optional cloud backup and recovery later.'
                  : 'No action is required for local encryption. You may optionally create a recovery key for future encrypted cloud backup and another-device restore.',
            ),
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (!_confirmed && !isGuest)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _enroll,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(
                      context.l10n.phrase('Set up optional recovery'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _recover,
                    icon: const Icon(Icons.restore_outlined),
                    label: Text(
                      context.l10n.phrase('Restore with recovery key'),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
