import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'ads_manager.dart'; // ADD THIS IMPORT

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();
  
  // Load first app open ad immediately
  final adsManager = AdsManager();
  adsManager.loadAppOpenAd();
  
  runApp(const QuickCalcApp());
}
