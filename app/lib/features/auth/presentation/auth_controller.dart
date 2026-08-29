import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/app_database.dart';
import '../../../core/sync/encrypted_sync_service.dart';
import '../data/firebase_auth_repository.dart';
import '../domain/auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const UnconfiguredAuthRepository(),
);
final authControllerProvider = NotifierProvider<AuthController, AuthSession>(
  AuthController.new,
);

class AuthController extends Notifier<AuthSession> {
  static const _guestSessionKey = 'active_guest_session_owner_v1';
  bool guest = false;
  String? _guestOwner;
  bool _claimGuestData = false;
  Timer? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _syncing = false;
  @override
  AuthSession build() {
    _initialize();
    return const AuthSession();
  }

  Future<void> _initialize() async {
    final preferences = await SharedPreferences.getInstance();
    var savedGuestOwner = preferences.getString(_guestSessionKey);
    if (savedGuestOwner == null &&
        (preferences.getBool('offline_guest_session') ?? false)) {
      savedGuestOwner =
          'guest:${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
      await preferences.setString(_guestSessionKey, savedGuestOwner);
      await preferences.remove('offline_guest_session');
    }
    if (savedGuestOwner != null && savedGuestOwner.startsWith('guest:')) {
      guest = true;
      _guestOwner = savedGuestOwner;
      await ref
          .read(appDatabaseProvider)
          .startGuestSession(savedGuestOwner.substring('guest:'.length));
      state = AuthSession(
        status: AuthStatus.signedIn,
        user: AuthUser(
          id: savedGuestOwner,
          displayName: 'Guest',
          isGuest: true,
        ),
      );
    }
    final sessionListener = ref
        .read(authRepositoryProvider)
        .sessionChanges()
        .listen((user) async {
          if (user != null) {
            final database = ref.read(appDatabaseProvider);
            if (_guestOwner != null) {
              if (_claimGuestData) {
                await database.claimGuestSession(_guestOwner!, user.id);
              } else {
                await database.discardOwner(_guestOwner!);
                await database.activateAccount(user.id);
              }
            } else {
              await database.activateAccount(user.id);
            }
            guest = false;
            _guestOwner = null;
            _claimGuestData = false;
            await preferences.remove(_guestSessionKey);
            state = AuthSession(status: AuthStatus.signedIn, user: user);
            _startAutomaticSync(user.id);
          } else if (!guest) {
            _stopAutomaticSync();
            state = const AuthSession(status: AuthStatus.signedOut);
          }
        });
    ref.onDispose(() {
      sessionListener.cancel();
      _stopAutomaticSync();
    });
  }

  void _startAutomaticSync(String uid) {
    _stopAutomaticSync();
    unawaited(_sync(uid));
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_sync(uid));
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (!results.contains(ConnectivityResult.none)) {
        unawaited(_sync(uid));
      }
    });
  }

  Future<void> _sync(String uid) async {
    if (_syncing) return;
    _syncing = true;
    try {
      await ref.read(encryptedSyncServiceProvider).synchronize(uid);
    } catch (_) {
      // The encrypted outbox remains durable and is retried automatically.
    } finally {
      _syncing = false;
    }
  }

  void _stopAutomaticSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  Future<void> signIn(String email, String password) {
    _claimGuestData = false;
    return _run(
      () => ref.read(authRepositoryProvider).signInWithEmail(email, password),
    );
  }

  Future<void> signUp(String name, String email, String password) {
    _claimGuestData = guest;
    return _run(
      () => ref
          .read(authRepositoryProvider)
          .signUpWithEmail(name, email, password),
    );
  }

  Future<void> google() {
    _claimGuestData = false;
    return _run(() => ref.read(authRepositoryProvider).signInWithGoogle());
  }

  Future<void> facebook() {
    _claimGuestData = false;
    return _run(() => ref.read(authRepositoryProvider).signInWithFacebook());
  }

  Future<void> reset(String email) => _run(
    () => ref.read(authRepositoryProvider).resetPassword(email),
    success: 'Password reset email sent.',
  );
  Future<void> continueOffline() async {
    guest = true;
    _guestOwner =
        'guest:${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    await ref
        .read(appDatabaseProvider)
        .startGuestSession(_guestOwner!.substring('guest:'.length));
    await (await SharedPreferences.getInstance()).setString(
      _guestSessionKey,
      _guestOwner!,
    );
    state = AuthSession(
      status: AuthStatus.signedIn,
      user: AuthUser(id: _guestOwner!, displayName: 'Guest', isGuest: true),
    );
  }

  Future<void> signOut() async {
    if (guest && _guestOwner != null) {
      await ref.read(appDatabaseProvider).discardOwner(_guestOwner!);
    } else {
      await ref.read(authRepositoryProvider).signOut();
    }
    guest = false;
    _guestOwner = null;
    _claimGuestData = false;
    await (await SharedPreferences.getInstance()).remove(_guestSessionKey);
    state = const AuthSession(status: AuthStatus.signedOut);
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    final previous = state;
    state = state.copyWith(busy: true, error: null);
    try {
      await action();
      if (success != null) {
        state = AuthSession(status: AuthStatus.signedOut, error: success);
      }
    } on AuthFailure catch (error) {
      _claimGuestData = false;
      state = AuthSession(
        status: previous.status,
        user: previous.user,
        error: error.message,
      );
    } finally {
      if (state.busy) state = state.copyWith(busy: false);
    }
  }
}
