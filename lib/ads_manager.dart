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

  // ✅ USE GOOGLE'S TEST AD UNIT IDs
  static const String topBannerAdId = 'ca-app-pub-3940256099942544/6300978111';
  static const String bottomBannerAdId = 'ca-app-pub-3940256099942544/6300978111';
  static const String rewardedAdId = 'ca-app-pub-3940256099942544/5224354917';
  static const String interstitialAdId = 'ca-app-pub-3940256099942544/1033173712';
  static const String appOpenAdIdAndroid = 'ca-app-pub-3940256099942544/9253755937';
  static const String appOpenAdIdIOS = 'ca-app-pub-3940256099942544/9253755937';
  
  DateTime? _lastAppOpenAdShownTime;
  bool _isAppOpenAdLoading = false;

  // ✅ ALWAYS USE TEST ADS FOR NOW
  String _getAdUnitId(String realId, String testId) {
    return testId;
  }

  String _getAppOpenAdUnitId() {
    return _getAdUnitId(
      Platform.isAndroid ? appOpenAdIdAndroid : appOpenAdIdIOS,
      "ca-app-pub-3940256099942544/3419835294"
    );
  }

  String _getTopBannerAdUnitId() {
    return _getAdUnitId(topBannerAdId, "ca-app-pub-3940256099942544/6300978111");
  }

  String _getBottomBannerAdUnitId() {
    return _getAdUnitId(bottomBannerAdId, "ca-app-pub-3940256099942544/6300978111");
  }

  String _getRewardedAdUnitId() {
    return _getAdUnitId(rewardedAdId, "ca-app-pub-3940256099942544/5224354917");
  }

  String _getInterstitialAdUnitId() {
    return _getAdUnitId(interstitialAdId, "ca-app-pub-3940256099942544/1033173712");
  }

  // BANNER ADS
  Future<void> loadTopBanner({VoidCallback? onLoaded}) async {
    try {
      topBanner = BannerAd(
        size: AdSize.banner,
        adUnitId: _getTopBannerAdUnitId(),
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('✅ Top banner ad loaded');
            onLoaded?.call();
            UserActivityLogger.logUserActivity('ad_loaded', 'banner_top', '');
          },
          onAdFailedToLoad: (ad, error) {
            print('❌ Failed to load top banner: $error');
            topBanner = null;
            Future.delayed(const Duration(seconds: 30), () => loadTopBanner(onLoaded: onLoaded));
          },
        ),
      );
      await topBanner!.load();
    } catch (e) {
      print('❌ Error loading top banner: $e');
    }
  }

  Future<void> loadBottomBanner({VoidCallback? onLoaded}) async {
    try {
      bottomBanner = BannerAd(
        size: AdSize.banner,
        adUnitId: _getBottomBannerAdUnitId(),
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            print('✅ Bottom banner ad loaded');
            onLoaded?.call();
            UserActivityLogger.logUserActivity('ad_loaded', 'banner_bottom', '');
          },
          onAdFailedToLoad: (ad, error) {
            print('❌ Failed to load bottom banner: $error');
            bottomBanner = null;
            Future.delayed(const Duration(seconds: 30), () => loadBottomBanner(onLoaded: onLoaded));
          },
        ),
      );
      await bottomBanner!.load();
    } catch (e) {
      print('❌ Error loading bottom banner: $e');
    }
  }

  // REWARDED AD
  Future<void> loadRewardedAd({Function(RewardedAd)? onLoaded}) async {
    try {
      await RewardedAd.load(
        adUnitId: _getRewardedAdUnitId(),
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            rewardedAd = ad;
            print('✅ Rewarded ad loaded');
            onLoaded?.call(ad);
            UserActivityLogger.logUserActivity('ad_loaded', 'rewarded', '');
          },
          onAdFailedToLoad: (error) {
            print('❌ Failed to load rewarded ad: $error');
            rewardedAd = null;
            Future.delayed(const Duration(seconds: 30), () => loadRewardedAd(onLoaded: onLoaded));
          },
        ),
      );
    } catch (e) {
      print('❌ Error loading rewarded ad: $e');
    }
  }

  Future<void> showRewardedAd(RewardedAd ad, PremiumManager premiumManager, {bool forHistory = false}) async {
    try {
      await ad.show(onUserEarnedReward: (ad, reward) {
        print('🎉 User earned reward: ${reward.amount} ${reward.type}');
        
        if (forHistory) {
          // Reward for history panel: Add history slots
          premiumManager.addHistorySlots(30); // Add 30 history slots
          UserActivityLogger.logUserActivity('ad_watched', 'rewarded_history', '30_slots_added');
          DeveloperAnalytics.trackAdEvent('completed', 'rewarded', 'history_slots');
        } else {
          // Reward for premium panel: Add premium time
          premiumManager.unlockPremium(hours: 1); // Give 1 hour premium
          UserActivityLogger.logUserActivity('ad_watched', 'rewarded_premium', '1_hour_premium');
          DeveloperAnalytics.trackAdEvent('completed', 'rewarded', 'premium_time');
        }
      });
    } catch (e) {
      print('❌ Error showing rewarded ad: $e');
    }
  }

  // INTERSTITIAL AD
  Future<void> loadInterstitial() async {
    try {
      await InterstitialAd.load(
        adUnitId: _getInterstitialAdUnitId(),
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            interstitialAd = ad;
            print('✅ Interstitial ad loaded');
            UserActivityLogger.logUserActivity('ad_loaded', 'interstitial', '');
            
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                print('📤 Interstitial dismissed');
                ad.dispose();
                interstitialAd = null;
                Future.delayed(const Duration(seconds: 5), loadInterstitial);
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                print('❌ Failed to show interstitial: $error');
                ad.dispose();
                interstitialAd = null;
                Future.delayed(const Duration(seconds: 10), loadInterstitial);
              },
            );
          },
          onAdFailedToLoad: (error) {
            print('❌ Failed to load interstitial: $error');
            interstitialAd = null;
            Future.delayed(const Duration(seconds: 30), loadInterstitial);
          },
        ),
      );
    } catch (e) {
      print('❌ Error loading interstitial: $e');
    }
  }

  Future<void> showInterstitial() async {
    if (interstitialAd != null) {
      try {
        await interstitialAd!.show();
        UserActivityLogger.logUserActivity('ad_watched', 'interstitial', 'shown');
        DeveloperAnalytics.trackAdEvent('shown', 'interstitial', 'interstitial_ad');
      } catch (e) {
        print('❌ Error showing interstitial: $e');
      }
    } else {
      print('⚠️ Interstitial ad not ready');
      loadInterstitial();
    }
  }

  // APP OPEN AD
  void loadAppOpenAd() {
    if (_isAppOpenAdLoading || appOpenAd != null) return;
    
    _isAppOpenAdLoading = true;
    print('🔄 LOADING App Open Ad with ID: ${_getAppOpenAdUnitId()}');
    
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

  // DISPOSE ALL ADS
  void disposeAll() {
    topBanner?.dispose();
    bottomBanner?.dispose();
    rewardedAd?.dispose();
    interstitialAd?.dispose();
    appOpenAd?.dispose();
    
    topBanner = null;
    bottomBanner = null;
    rewardedAd = null;
    interstitialAd = null;
    appOpenAd = null;
    isAppOpenAdLoaded = false;
    
    print('🗑️ All ads disposed');
  }
}
