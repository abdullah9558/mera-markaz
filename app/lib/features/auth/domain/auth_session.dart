class AuthUser {
  const AuthUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isGuest = false,
  });
  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isGuest;
}

enum AuthStatus { loading, signedOut, signedIn }

class AuthSession {
  const AuthSession({
    this.status = AuthStatus.loading,
    this.user,
    this.busy = false,
    this.error,
  });
  final AuthStatus status;
  final AuthUser? user;
  final bool busy;
  final String? error;
  AuthSession copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool? busy,
    String? error,
  }) => AuthSession(
    status: status ?? this.status,
    user: user ?? this.user,
    busy: busy ?? this.busy,
    error: error,
  );
}

abstract interface class AuthRepository {
  bool get configured;
  Stream<AuthUser?> sessionChanges();
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String name, String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signInWithGoogle();
  Future<void> signOut();
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}
