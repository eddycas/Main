import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AdAnalytics {
  static bool _firebaseInitialized = false;
  
  // Initialize Firebase
  static Future<void> _initializeFirebase() async {
    if (!_firebaseInitialized) {
      await Firebase.initializeApp();
      _firebaseInitialized = true;
    }
  }

  static Future<void> trackAdImpression(String adUnitId, String adType) async {
    final timestamp = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing impressions or create new list
    final impressions = prefs.getStringList('ad_impressions') ?? [];
    impressions.add('$timestamp|$adUnitId|$adType|impression');
    
    // Save back to storage
    await prefs.setStringList('ad_impressions', impressions.take(1000).toList());
    
    // Send to Firebase
    _sendToFirebase('impression', adUnitId, adType, timestamp);
    
    print('Ad impression tracked: $adUnitId at $timestamp');
  }

  static Future<void> trackAdClick(String adUnitId, String adType) async {
    final timestamp = DateTime.now().toIso8601String();
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing clicks or create new list
    final clicks = prefs.getStringList('ad_clicks') ?? [];
    clicks.add('$timestamp|$adUnitId|$adType|click');
    
    // Save back to storage
    await prefs.setStringList('ad_clicks', clicks.take(1000).toList());
    
    // Send to Firebase
    _sendToFirebase('click', adUnitId, adType, timestamp);
    
    print('Ad click tracked: $adUnitId at $timestamp');
  }

  // Send data to Firebase Firestore
  static Future<void> _sendToFirebase(String eventType, String adUnitId, String adType, String timestamp) async {
    try {
      await _initializeFirebase();
      
      final firestore = FirebaseFirestore.instance;
      
      await firestore.collection('ad_analytics').add({
        'event_type': eventType,
        'ad_unit_id': adUnitId,
        'ad_type': adType,
        'timestamp': timestamp,
        'server_timestamp': FieldValue.serverTimestamp(),
        'app_version': '1.0.0',
        'platform': 'flutter',
      });
      
      print('✅ Analytics data sent to Firebase successfully');
    } catch (e) {
      print('❌ Error sending to Firebase: $e');
      // Data remains stored locally and can be sent later
    }
  }

  // Send all pending analytics to Firebase
  static Future<void> sendPendingAnalytics() async {
    try {
      await _initializeFirebase();
      
      final prefs = await SharedPreferences.getInstance();
      final impressions = prefs.getStringList('ad_impressions') ?? [];
      final clicks = prefs.getStringList('ad_clicks') ?? [];
      
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      
      // Send all pending impressions
      for (final impression in impressions) {
        final parts = impression.split('|');
        if (parts.length == 4) {
          final docRef = firestore.collection('ad_analytics').doc();
          batch.set(docRef, {
            'event_type': 'impression',
            'ad_unit_id': parts[1],
            'ad_type': parts[2],
            'timestamp': parts[0],
            'server_timestamp': FieldValue.serverTimestamp(),
            'app_version': '1.0.0',
            'platform': 'flutter',
            'synced_later': true, // Mark as synced later
          });
        }
      }
      
      // Send all pending clicks
      for (final click in clicks) {
        final parts = click.split('|');
        if (parts.length == 4) {
          final docRef = firestore.collection('ad_analytics').doc();
          batch.set(docRef, {
            'event_type': 'click',
            'ad_unit_id': parts[1],
            'ad_type': parts[2],
            'timestamp': parts[0],
            'server_timestamp': FieldValue.serverTimestamp(),
            'app_version': '1.0.0',
            'platform': 'flutter',
            'synced_later': true,
          });
        }
      }
      
      await batch.commit();
      
      // Clear local storage after successful sync
      await prefs.remove('ad_impressions');
      await prefs.remove('ad_clicks');
      
      print('✅ All pending analytics sent to Firebase');
    } catch (e) {
      print('❌ Error sending pending analytics to Firebase: $e');
    }
  }

  // For debugging purposes
  static Future<void> printAnalytics() async {
    final prefs = await SharedPreferences.getInstance();
    final impressions = prefs.getStringList('ad_impressions') ?? [];
    final clicks = prefs.getStringList('ad_clicks') ?? [];
    
    print('=== AD ANALYTICS (FOR DEVELOPER ONLY) ===');
    print('Impressions: ${impressions.length}');
    impressions.take(5).forEach(print);
    print('Clicks: ${clicks.length}');
    clicks.take(5).forEach(print);
    print('=========================================');
  }
}
