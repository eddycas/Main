import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthManager {
  StreamSubscription<User?>? _authSub;

  void initAuthListener(void Function(User?) onChange) {
    _authSub = FirebaseAuth.instance.authStateChanges().listen(onChange);
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (_) {}
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  void dispose() {
    _authSub?.cancel();
  }
}
