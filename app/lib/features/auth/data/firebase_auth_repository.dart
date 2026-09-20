import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/auth_session.dart';

class FirebaseAuthRepository implements AuthRepository {
  static const _googleServerClientId =
      '773756309489-bil1d91mf3p7a7kq2cf0l1s6epvs9fcu.apps.googleusercontent.com';

  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;
  bool googleInitialized = false;
  @override
  bool get configured => true;
  AuthUser _map(User user) => AuthUser(
    id: user.uid,
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoURL,
  );
  @override
  Stream<AuthUser?> sessionChanges() =>
      _auth.userChanges().map((user) => user == null ? null : _map(user));
  @override
  Future<void> signInWithEmail(String email, String password) => _guard(
    () => _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );
  @override
  Future<void> signUpWithEmail(String name, String email, String password) =>
      _guard(() async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await credential.user?.updateDisplayName(name.trim());
        await credential.user?.sendEmailVerification();
      });
  @override
  Future<void> resetPassword(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));
  @override
  Future<void> signInWithGoogle() => _guard(() async {
    if (!googleInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: _googleServerClientId,
      );
      googleInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final authentication = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: authentication.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user != null) {
      if ((user.displayName?.trim().isEmpty ?? true) &&
          (account.displayName?.trim().isNotEmpty ?? false)) {
        await user.updateDisplayName(account.displayName!.trim());
      }
      if ((user.photoURL?.trim().isEmpty ?? true) &&
          (account.photoUrl?.trim().isNotEmpty ?? false)) {
        await user.updatePhotoURL(account.photoUrl);
      }
      await user.reload();
    }
  });
  @override
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(error.code, _message(error.code));
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw AuthFailure('provider-error', '$error');
    }
  }

  String _message(String code) => switch (code) {
    'invalid-email' => 'Enter a valid email address.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'Email or password is incorrect.',
    'email-already-in-use' => 'An account already exists for this email.',
    'weak-password' => 'Use a stronger password with at least 6 characters.',
    'network-request-failed' => 'Check your internet connection and try again.',
    'too-many-requests' => 'Too many attempts. Please try again later.',
    'account-exists-with-different-credential' =>
      'This email already uses a different sign-in method.',
    _ => 'Authentication failed. Please try again.',
  };
}

class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository();
  @override
  bool get configured => false;
  @override
  Stream<AuthUser?> sessionChanges() => Stream.value(null);
  Never _unavailable() => throw const AuthFailure(
    'firebase-unconfigured',
    'Firebase is not configured for this build.',
  );
  @override
  Future<void> signInWithEmail(String email, String password) async =>
      _unavailable();
  @override
  Future<void> signUpWithEmail(
    String name,
    String email,
    String password,
  ) async => _unavailable();
  @override
  Future<void> resetPassword(String email) async => _unavailable();
  @override
  Future<void> signInWithGoogle() async => _unavailable();
  @override
  Future<void> signOut() async {}
}
