import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AdAnalytics {
  static FirebaseAnalytics? _analytics;
  
  // Initialize Firebase Analytics
  static Future<void> _initializeAnalytics() async {
    await Firebase.initializeApp();
    _analytics = FirebaseAnalytics.instance;
  }

  static Future<void> trackAdImpression(String adUnitId, String adType) async {
    final timestamp = DateTime.now();
    
    // Send to Firebase Analytics
    await _sendToFirebaseAnalytics('impression', adUnitId, adType, timestamp);
    
    print('Ad impression tracked: $adUnitId at ${timestamp.toIso8601String()}');
  }

  static Future<void> trackAdClick(String adUnitId, String adType) async {
    final timestamp = DateTime.now();
    
    // Send to Firebase Analytics
    await _sendToFirebaseAnalytics('click', adUnitId, adType, timestamp);
    
    print('Ad click tracked: $adUnitId at ${timestamp.toIso8601String()}');
  }

  // Send data to Firebase Analytics
  static Future<void> _sendToFirebaseAnalytics(String eventType, String adUnitId, String adType, DateTime timestamp) async {
    try {
      if (_analytics == null) {
        await _initializeAnalytics();
      }
      
      await _analytics!.logEvent(
        name: 'ad_$eventType',
        parameters: {
          'ad_unit_id': adUnitId,
          'ad_type': adType,
          'timestamp': timestamp.toIso8601String(),
          'ad_platform': 'admob',
          'event_timestamp': timestamp.millisecondsSinceEpoch,
        },
      );
      
      print('✅ Analytics data sent to Firebase Analytics');
    } catch (e) {
      print('❌ Error sending to Firebase Analytics: $e');
    }
  }

  // For debugging purposes
  static Future<void> printAnalyticsSummary() async {
    print('=== FIREBASE ANALYTICS ACTIVE ===');
    print('Tracking ad impressions and clicks in real-time');
    print('View data at: https://console.firebase.google.com/');
    print('==================================');
  }
}
