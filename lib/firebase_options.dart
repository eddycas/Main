// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: '', // No Web API Key for this project
      appId: '1:839664223458:android:17c7b54599f0b190430abb',
      messagingSenderId: '839664223458',
      projectId: 'quickcalc-f0290',
      storageBucket: '', // Optional, leave empty if not used
      authDomain: '', // Optional
      measurementId: '', // Optional
    );
  }
}
