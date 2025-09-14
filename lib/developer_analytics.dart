import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

class DeveloperAnalytics {
  static FirebaseAnalytics? _analytics;
  
  static Future<void> init() async {
    await Firebase.initializeApp();
    _analytics = FirebaseAnalytics.instance;
    
    // Set user privacy settings - NO personal data collection
    await _analytics!.setAnalyticsCollectionEnabled(true);
    await _analytics!.setUserId(null); // Explicitly no user ID
  }
  
  // Track ad events for YOUR analytics (NO user data)
  static Future<void> trackAdEvent(String eventType, String adType, String adUnitId) async {
    if (_analytics == null) await init();
    
    try {
      await _analytics!.logEvent(
        name: 'ad_$eventType',
        parameters: {
          'ad_type': adType,
          'ad_unit': adUnitId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          // NO user identifiers, NO personal data
        },
      );
      
      print('Developer analytics: $eventType for $adType');
    } catch (e) {
      print('Error sending to Firebase Analytics: $e');
    }
  }
  
  // Track aggregated calculation stats (NO individual data)
  static Future<void> trackCalculationStats(String operation, int digitCount) async {
    if (_analytics == null) await init();
    
    try {
      await _analytics!.logEvent(
        name: 'calculation_stats',
        parameters: {
          'operation': operation,
          'digit_count': digitCount,
          'hour_of_day': DateTime.now().hour,
          // NO actual numbers, NO results, NO user data
        },
      );
    } catch (e) {
      print('Error tracking calculation stats: $e');
    }
  }
  
  // Track app usage events
  static Future<void> trackAppEvent(String eventName, [Map<String, dynamic>? params]) async {
    if (_analytics == null) await init();
    
    try {
      await _analytics!.logEvent(
        name: eventName,
        parameters: params,
      );
    } catch (e) {
      print('Error tracking app event: $e');
    }
  }
}
