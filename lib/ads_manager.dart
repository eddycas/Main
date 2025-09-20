import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_activity_logger.dart';
import 'developer_analytics.dart';
import 'premium_manager.dart';

class AdsManager {
  BannerAd? topBanner;
  BannerAd? bottomBanner;
  RewardedAd? rewardedAd;
  InterstitialAd? interstitialAd;
  AppOpenAd? appOpenAd;
  bool isAppOpenAdLoaded = false;

  bool get isInterstitialReady => interstitialAd != null;

  static const String appOpenAdIdAndroid = 'ca-app-pub-your-android-app-open-id/1234567890';
  static const String appOpenAdIdIOS = 'ca-app-pub-your-ios-app-open-id/1234567890';
  
  DateTime? _lastAppOpenAdShownTime;
  bool _isAppOpenAdLoading = false;

  String _getAppOpenAdUnitId() {
    if (kDebugMode) {
      return "ca-app-pub-3940256099942544/3419835294";
    } else {
      if (Platform.isAndroid) return appOpenAdIdAndroid;
      if (Platform.isIOS) return appOpenAdIdIOS;
      return "ca-app-pub-3940256099942544/3419835294";
    }
  }

  void loadAppOpenAd() {
    if (_isAppOpenAdLoading || appOpenAd != null) return;
    
    _isAppOpenAdLoading = true;
    print('🔄 FORCE LOADING App Open Ad...');
    
    final adUnitId = _getAppOpenAdUnitId();
    
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          appOpenAd = ad;
          isAppOpenAdLoaded = true;
          _isAppOpenAdLoading = false;
          print('✅ App Open Ad loaded successfully');

          appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              print('🎉 App Open Ad showed successfully');
              _lastAppOpenAdShownTime = DateTime.now();
              UserActivityLogger.logUserActivity('ad_watched', 'app_open', 'shown');
              DeveloperAnalytics.trackAdEvent('shown', 'app_open', 'app_open_ad');
            },
            onAdDismissedFullScreenContent: (ad) {
              print('📤 App Open Ad dismissed');
              ad.dispose();
              isAppOpenAdLoaded = false;
              appOpenAd = null;
              Future.delayed(const Duration(seconds: 5), loadAppOpenAd);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ Failed to show app open ad: $error');
              ad.dispose();
              isAppOpenAdLoaded = false;
              appOpenAd = null;
              _isAppOpenAdLoading = false;
              Future.delayed(const Duration(seconds: 10), loadAppOpenAd);
            },
            onAdClicked: (ad) {
              UserActivityLogger.logUserActivity('ad_click', 'app_open', '');
              DeveloperAnalytics.trackAdEvent('click', 'app_open', 'app_open_ad');
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('❌ Failed to load app open ad: $error');
          isAppOpenAdLoaded = false;
          appOpenAd = null;
          _isAppOpenAdLoading = false;
          Future.delayed(const Duration(seconds: 15), loadAppOpenAd);
        },
      ),
    );
  }

  Future<void> showAppOpenAd() async {
    print('\n=== APP OPEN AD ATTEMPT ===');
    
    final prefs = await SharedPreferences.getInstance();
    final premiumActive = prefs.getBool('isPremium') ?? false;
    if (premiumActive) {
      print('❌ App Open Ad skipped: Premium active');
      return;
    }

    final now = DateTime.now();
    if (_lastAppOpenAdShownTime != null && 
        now.difference(_lastAppOpenAdShownTime!) < const Duration(seconds: 10)) {
      print('⏰ App Open Ad skipped: Cooldown period (10s)');
      return;
    }

    if (isAppOpenAdLoaded && appOpenAd != null) {
      try {
        print('✅ Showing App Open Ad...');
        appOpenAd!.show();
        _lastAppOpenAdShownTime = DateTime.now();
      } catch (e) {
        print('❌ Error showing app open ad: $e');
        loadAppOpenAd();
      }
    } else {
      print('❌ App Open Ad not ready. Loaded: $isAppOpenAdLoaded');
      print('🔄 Loading new App Open Ad...');
      loadAppOpenAd();
    }
  }

  // ... REST OF YOUR METHODS (banner, rewarded, interstitial) ...
  // Keep your existing banner, rewarded, and interstitial methods here
  // They were already correct in the previous version
}
