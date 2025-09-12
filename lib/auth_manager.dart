import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthManager {
  // Singleton pattern
  AuthManager._privateConstructor();
  static final AuthManager instance = AuthManager._privateConstructor();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  StreamSubscription<User?>? _authSub;

  /// Initialize auth state listener
  void initAuthListener(void Function(User?) onChange) {
    _authSub = _auth.authStateChanges().listen(onChange);
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // user cancelled

      final googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw AuthException("Missing Google authentication tokens.");
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
    } catch (e, st) {
      developer.log("Sign-in error", error: e, stackTrace: st);
      throw AuthException("Failed to sign in with Google: $e");
    }
  }

  /// Sign in and return UserCredential (to check if new user)
  Future<UserCredential?> signInWithGoogleAndReturnCredential() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw AuthException("Missing Google authentication tokens.");
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e, st) {
      developer.log("Sign-up error", error: e, stackTrace: st);
      return null;
    }
  }

  /// Sign out from both Firebase and Google
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e, st) {
      developer.log("Sign-out error", error: e, stackTrace: st);
      throw AuthException("Failed to sign out: $e");
    }
  }

  /// Dispose auth listener
  Future<void> dispose() async {
    await _authSub?.cancel();
  }
}
