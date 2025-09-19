import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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

  // GETTER: Check if an interstitial ad is loaded and ready to show
  bool get isInterstitialReady => interstitialAd != null;

  // Use platform-specific ad unit IDs (REPLACE WITH YOUR REAL IDs)
  static const String appOpenAdIdAndroid = 'ca-app-pub-your-android-app-open-id/1234567890';
  static const String appOpenAdIdIOS = 'ca-app-pub-your-ios-app-open-id/1234567890';
  
  DateTime? _lastAppOpenAdShownTime;
  bool _isAppOpenAdLoading = false;

  String _getAppOpenAdUnitId() {
    // Use test IDs for debug, real IDs for release
    if (kDebugMode) {
      return "ca-app-pub-3940256099942544/3419835294"; // Test ID
    } else {
      // Platform-specific real IDs (REPLACE THESE WITH YOUR ACTUAL IDs)
      if (Platform.isAndroid) return appOpenAdIdAndroid;
      if (Platform.isIOS) return appOpenAdIdIOS;
      return "ca-app-pub-3940256099942544/3419835294"; // Fallback test ID
    }
  }

  void loadAppOpenAd() {
    if (_isAppOpenAdLoading || appOpenAd != null) return;
    
    _isAppOpenAdLoading = true;
    
    final adUnitId = _getAppOpenAdUnitId();
    
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          appOpenAd = ad;
          isAppOpenAdLoaded = true;
          _isAppOpenAdLoading = false;
          print('App Open Ad loaded successfully');

          appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              isAppOpenAdLoaded = false;
              appOpenAd = null;
              _lastAppOpenAdShownTime = DateTime.now();
              UserActivityLogger.logUserActivity('ad_watched', 'app_open', 'dismissed');
              DeveloperAnalytics.trackAdEvent('completed', 'app_open', 'app_open_ad');
              // Wait before loading next ad
              Future.delayed(const Duration(minutes: 5), loadAppOpenAd);
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('Failed to show app open ad: $error');
              ad.dispose();
              isAppOpenAdLoaded = false;
              appOpenAd = null;
              _isAppOpenAdLoading = false;
              DeveloperAnalytics.trackAdEvent('error', 'app_open', 'show_failed');
              // Retry after shorter delay
              Future.delayed(const Duration(minutes: 2), loadAppOpenAd);
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('Failed to load app open ad: $error');
          isAppOpenAdLoaded = false;
          appOpenAd = null;
          _isAppOpenAdLoading = false;
          DeveloperAnalytics.trackAdEvent('error', 'app_open', 'load_failed');
          // Retry after delay with backoff
          Future.delayed(const Duration(minutes: 3), loadAppOpenAd);
        },
      ),
    );
  }

  // Show App Open Ad with cooldown and conditions
  Future<void> showAppOpenAd() async {
    // Don't show if premium is active
    final prefs = await SharedPreferences.getInstance();
    final premiumActive = prefs.getBool('isPremium') ?? false;
    if (premiumActive) {
      print('App Open Ad skipped: Premium active');
      return;
    }

    // Cooldown check - don't show ads too frequently
    final now = DateTime.now();
    if (_lastAppOpenAdShownTime != null && 
        now.difference(_lastAppOpenAdShownTime!) < const Duration(minutes: 5)) {
      print('App Open Ad skipped: Cooldown period');
      return;
    }

    if (isAppOpenAdLoaded && appOpenAd != null) {
      try {
        appOpenAd!.show();
        _lastAppOpenAdShownTime = DateTime.now();
        // Track app open ad impression
        DeveloperAnalytics.trackAdEvent('impression', 'app_open', 'app_open_ad');
        UserActivityLogger.logUserActivity('ad_impression', 'app_open', '');
        print('App Open Ad shown successfully');
      } catch (e) {
        print('Error showing app open ad: $e');
        DeveloperAnalytics.trackAdEvent('error', 'app_open', 'show_error');
      }
    } else {
      print('App Open Ad not ready. Loaded: $isAppOpenAdLoaded, Ad: ${appOpenAd != null}');
      // Try to load if not loaded
      if (!_isAppOpenAdLoading) {
        loadAppOpenAd();
      }
    }
  }

  void loadTopBanner({required VoidCallback onLoaded}) {
    topBanner = BannerAd(
      adUnitId: "ca-app-pub-3940256099942544/6300978111",
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          onLoaded();
          UserActivityLogger.logUserActivity('ad_impression', 'top_banner', '');
          DeveloperAnalytics.trackAdEvent('impression', 'banner', 'top_banner');
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          print('Failed to load top banner: $err');
        },
        onAdClicked: (ad) {
          UserActivityLogger.logUserActivity('ad_click', 'top_banner', '');
          DeveloperAnalytics.trackAdEvent('click', 'banner', 'top_banner');
        },
      ),
    )..load();
  }

  void loadBottomBanner({required VoidCallback onLoaded}) {
    bottomBanner = BannerAd(
      adUnitId: "ca-app-pub-3940256099942544/6300978111",
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          onLoaded();
          UserActivityLogger.logUserActivity('ad_impression', 'bottom_banner', '');
          DeveloperAnalytics.trackAdEvent('impression', 'banner', 'bottom_banner');
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          print('Failed to load bottom banner: $err');
        },
        onAdClicked: (ad) {
          UserActivityLogger.logUserActivity('ad_click', 'bottom_banner', '');
          DeveloperAnalytics.trackAdEvent('click', 'banner', 'top_banner');
        },
      ),
    )..load();
  }

  void loadRewardedAd({required Function(RewardedAd) onLoaded}) {
    RewardedAd.load(
      adUnitId: "ca-app-pub-3940256099942544/5224354917",
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          onLoaded(ad);
          UserActivityLogger.logUserActivity('ad_impression', 'rewarded', '');
          DeveloperAnalytics.trackAdEvent('impression', 'rewarded', 'rewarded_ad');
        },
        onAdFailedToLoad: (err) {
          print('Failed to load rewarded ad: $err');
          Future.delayed(
            const Duration(seconds: 15),
            () => loadRewardedAd(onLoaded: onLoaded),
          );
        },
      ),
    );
  }

  Future<void> showRewardedAd(RewardedAd ad, PremiumManager premiumManager) async {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        print('Failed to show rewarded ad: $err');
        ad.dispose();
      },
    );

    ad.show(onUserEarnedReward: (_, __) {
      UserActivityLogger.logUserActivity('ad_click', 'rewarded', 'premium_1hour');
      DeveloperAnalytics.trackAdEvent('click', 'rewarded', 'rewarded_ad');
      premiumManager.unlockPremium(hours: 1);
    });
  }

  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: "ca-app-pub-3940256099942544/1033173712",
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          interstitialAd = ad;
          UserActivityLogger.logUserActivity('ad_impression', 'interstitial', '');
          DeveloperAnalytics.trackAdEvent('impression', 'interstitial', 'interstitial_ad');

          interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              interstitialAd = null;
              loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              print('Failed to show interstitial ad: $err');
              ad.dispose();
              interstitialAd = null;
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (err) {
          print('Failed to load interstitial ad: $err');
          Future.delayed(const Duration(seconds: 15), loadInterstitial);
        },
      ),
    );
  }

  void showInterstitial() {
    if (interstitialAd != null) {
      interstitialAd!.show();
      UserActivityLogger.logUserActivity('ad_click', 'interstitial', '');
      DeveloperAnalytics.trackAdEvent('click', 'interstitial', 'interstitial_ad');
    } else {
      print('Tried to show interstitial ad, but it was not loaded.');
    }
  }

  void disposeAll() {
    topBanner?.dispose();
    bottomBanner?.dispose();
    rewardedAd?.dispose();
    interstitialAd?.dispose();
    appOpenAd?.dispose();
  }
}
