import '../entities/authenticated_user.dart';

abstract interface class AuthenticationRepository {
  Stream<AuthenticatedUser?> authStateChanges();

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> signInWithGoogle();

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

class AuthenticationFailure implements Exception {
  const AuthenticationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
