// lib/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Singleton instance
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // -------------------- SIGN IN --------------------
  /// Signs in the user with Google and returns the Firebase credential
  Future<UserCredential?> signInWithGoogleAndReturnCredential() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Google sign-in cancelled');
        return null;
      }

      // Obtain authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      final userCredential =
          await _auth.signInWithCredential(credential);
      debugPrint(
          'Signed in as: ${userCredential.user?.email}, New user: ${userCredential.additionalUserInfo?.isNewUser}');
      return userCredential;
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      rethrow; // allow SlidePanel to catch and show error
    }
  }

  // -------------------- SIMPLE SIGN IN --------------------
  /// Signs in the user with Google (doesn't return credential)
  Future<void> signInWithGoogle() async {
    try {
      await signInWithGoogleAndReturnCredential();
    } catch (e) {
      rethrow;
    }
  }

  // -------------------- SIGN OUT --------------------
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
      debugPrint('Signed out successfully');
    } catch (e) {
      debugPrint('Sign-out failed: $e');
      rethrow;
    }
  }
}
