import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/biometric_service.dart';
import '../domain/auth_session.dart';
import 'auth_controller.dart';
import 'auth_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  String? _checkedUserId;
  bool _checking = false;
  bool _unlocked = false;

  Future<void> _checkBiometric(AuthUser user) async {
    if (_checking || _checkedUserId == user.id) return;
    _checking = true;
    _checkedUserId = user.id;
    if (mounted) setState(() {});
    final service = ref.read(biometricServiceProvider);
    final enabled = !user.isGuest && await service.isEnabled(user.id);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _unlocked = !enabled;
    });
  }

  Future<void> _retry() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    setState(() => _checking = true);
    final authenticated = await ref
        .read(biometricServiceProvider)
        .authenticate();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _unlocked = authenticated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider);
    if (session.status == AuthStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session.status == AuthStatus.signedOut) {
      _checkedUserId = null;
      _unlocked = false;
      return const AuthScreen();
    }
    final user = session.user!;
    if (user.isGuest) return widget.child;
    if (_checkedUserId != user.id) {
      _unlocked = false;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkBiometric(user),
      );
    }
    if (_unlocked) return widget.child;
    return AuthScreen(allowGuest: false, onBiometric: _retry);
  }
}
