import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

class DeveloperAnalytics {
  static FirebaseAnalytics? _analytics;
  
  static Future<void> init() async {
    await Firebase.initializeApp();
    _analytics = FirebaseAnalytics.instance;
    
    await _analytics!.setAnalyticsCollectionEnabled(true);
    // Removed setUserId(null) as it's not needed for anonymous tracking
  }
  
  static Future<void> trackAdEvent(String eventType, String adType, String adUnitId) async {
    if (_analytics == null) await init();
    
    try {
      await _analytics!.logEvent(
        name: 'ad_$eventType',
        parameters: {
          'ad_type': adType,
          'ad_unit': adUnitId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      
      print('Developer analytics: $eventType for $adType');
    } catch (e) {
      print('Error sending to Firebase Analytics: $e');
    }
  }
  
  static Future<void> trackCalculationStats(String operation, int digitCount) async {
    if (_analytics == null) await init();
    
    try {
      await _analytics!.logEvent(
        name: 'calculation_stats',
        parameters: {
          'operation': operation,
          'digit_count': digitCount,
          'hour_of_day': DateTime.now().hour,
        },
      );
    } catch (e) {
      print('Error tracking calculation stats: $e');
    }
  }
}
