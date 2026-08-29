import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/sync/cloud_device_service.dart';
import '../../auth/presentation/auth_controller.dart';

class AuthorizedDevicesScreen extends ConsumerWidget {
  const AuthorizedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null || user.isGuest) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.phrase('Authorized devices'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.phrase(
                'Sign in to manage devices used for encrypted cloud recovery.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final service = CloudDeviceService();
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.phrase('Authorized devices'))),
      body: StreamBuilder<List<AuthorizedDevice>>(
        stream: service.devices(user.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(context.l10n.phrase('Devices could not be loaded.')),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final devices = snapshot.data!;
          if (devices.isEmpty) {
            return Center(
              child: Text(context.l10n.phrase('No cloud devices registered.')),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: devices.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final device = devices[index];
              return ListTile(
                leading: const Icon(Icons.phone_android),
                title: Text(device.label),
                subtitle: Text(context.l10n.phrase(device.status)),
                trailing: device.status == 'revoked'
                    ? null
                    : TextButton(
                        onPressed: () => service.revoke(user.id, device.id),
                        child: Text(context.l10n.phrase('Revoke')),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
