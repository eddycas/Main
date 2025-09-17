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

  // FIX: Make AdsManager a singleton (global instance)
  static final AdsManager _instance = AdsManager._internal();
  factory AdsManager() => _instance;
  AdsManager._internal(); // Private constructor

  // GETTER: Check if an interstitial ad is loaded and ready to show
  bool get isInterstitialReady => interstitialAd != null;

  // FIX: Track if an app open ad is showing to prevent multiple ads
  bool _isShowingAppOpen = false;

  // FIX: Updated App Open Ad loading
  void loadAppOpenAd() {
    // Don't load if already loaded or currently showing
    if (isAppOpenAdLoaded || _isShowingAppOpen) return;

    AppOpenAd.load(
      adUnitId: "ca-app-pub-3940256099942544/3419835294", // Test app open ad ID
      request: const AdRequest(),
      orientation: AppOpenAd.orientationPortrait,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          appOpenAd = ad;
          isAppOpenAdLoaded = true;
          print('App Open Ad loaded successfully');

          // Set full screen content callback
          appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              _isShowingAppOpen = false;
              ad.dispose();
              isAppOpenAdLoaded = false;
              loadAppOpenAd(); // Load next app open ad
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('Failed to show app open ad: $error');
              _isShowingAppOpen = false;
              ad.dispose();
              isAppOpenAdLoaded = false;
              loadAppOpenAd(); // Load next app open ad
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('Failed to load app open ad: $error');
          isAppOpenAdLoaded = false;
          // Retry after delay
          Future.delayed(const Duration(minutes: 1), loadAppOpenAd);
        },
      ),
    );
  }

  // FIX: Improved Show App Open Ad method
  Future<void> showAppOpenAd() async {
    // Prevent showing if already showing, not loaded, or premium
    if (_isShowingAppOpen || !isAppOpenAdLoaded || appOpenAd == null) {
      print('App Open Ad not ready to show.');
      return;
    }

    try {
      _isShowingAppOpen = true;
      appOpenAd!.show();
      // Track app open ad impression
      DeveloperAnalytics.trackAdEvent('impression', 'app_open', 'app_open_ad');
      UserActivityLogger.logUserActivity('ad_impression', 'app_open', '');
    } catch (e) {
      _isShowingAppOpen = false;
      print('Error showing app open ad: $e');
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
          DeveloperAnalytics.trackAdEvent('click', 'banner', 'bottom_banner');
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
