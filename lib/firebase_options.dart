// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'AIzaSyDW9wQz_4DEk-HympMC-uCrrcai4y3vZcY', // Your actual API key
      appId: '1:839664223458:android:17c7b54599f0b190430abb', // Android App ID
      messagingSenderId: '839664223458',
      projectId: 'quickcalc-f0290',
      storageBucket: 'quickcalc-f0290.firebasestorage.app',
      authDomain: '',       // optional, leave empty if unused
      measurementId: '',    // optional, leave empty if unused
    );
  }
}
