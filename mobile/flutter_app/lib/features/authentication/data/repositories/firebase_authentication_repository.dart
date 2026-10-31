import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/authenticated_user.dart';
import '../../domain/repositories/authentication_repository.dart';

class FirebaseAuthenticationRepository implements AuthenticationRepository {
  FirebaseAuthenticationRepository({
    required FirebaseAuth authentication,
  }) : _authentication = authentication;

  final FirebaseAuth _authentication;
  Future<void>? _googleInitialization;
  bool _googleInitialized = false;

  @override
  Stream<AuthenticatedUser?> authStateChanges() =>
      _authentication.userChanges().map(_toAuthenticatedUser);

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final result = await _authentication.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user;
      if (user == null) {
        throw const AuthenticationFailure(
          'Account creation did not return a user. Please try again.',
        );
      }
      await user.updateDisplayName(displayName.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthenticationFailure(_authErrorMessage(error));
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _authentication.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthenticationFailure(_authErrorMessage(error));
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      try {
        await (_googleInitialization ??= GoogleSignIn.instance.initialize());
        _googleInitialized = true;
      } on Exception {
        _googleInitialization = null;
        rethrow;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthenticationFailure(
          'Google sign-in is not configured for this Android app. Add the app signing SHA fingerprints in Firebase, enable Google as an Authentication provider, then download the updated google-services.json.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _authentication.signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthenticationFailure(_authErrorMessage(error));
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return;
      throw AuthenticationFailure(
        'Google sign-in failed (${error.code.name}). Check that Google is enabled in Firebase Authentication and that this Android app has its SHA fingerprints configured.',
      );
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _authentication.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthenticationFailure(_authErrorMessage(error));
    }
  }

  @override
  Future<void> signOut() async {
    if (_googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
    await _authentication.signOut();
  }

  AuthenticatedUser? _toAuthenticatedUser(User? user) {
    if (user == null) return null;
    return AuthenticatedUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
  }

  String _authErrorMessage(FirebaseAuthException error) => switch (error.code) {
    'email-already-in-use' => 'An account already exists for that email.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Choose a password with at least 6 characters.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'The email or password is incorrect.',
    'network-request-failed' =>
      'Could not reach Firebase. Check your internet connection and try again.',
    'operation-not-allowed' =>
      'This sign-in method is not enabled in Firebase Authentication yet.',
    'too-many-requests' => 'Too many attempts. Wait a little and try again.',
    _ => error.message ?? 'Authentication failed (${error.code}).',
  };
}
