// lib/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Sign in user with email & password
  static Future<void> signInUser(String email, String password) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      debugPrint('Signed in as: ${userCredential.user?.email}');
    } catch (e) {
      debugPrint('Sign-in failed: $e');
    }
  }
}
