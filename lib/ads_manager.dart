import 'package:flutter/material.dart'; // ADD THIS IMPORT
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'user_activity_logger.dart';
import 'developer_analytics.dart';
import 'premium_manager.dart';

class AdsManager {
  BannerAd? topBanner;
  BannerAd? bottomBanner;
  RewardedAd? rewardedAd;
  InterstitialAd? interstitialAd;

  void loadTopBanner({required VoidCallback onLoaded}) {
    topBanner = BannerAd(
      adUnitId: "ca-app-pub-3940256099942544/6300978111",
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          onLoaded();
          // USER tracking
          UserActivityLogger.logUserActivity('ad_impression', 'top_banner', '');
          // DEVELOPER tracking
          DeveloperAnalytics.trackAdEvent('impression', 'banner', 'top_banner');
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          print('Failed to load top banner: $err');
        },
        onAdClicked: (ad) {
          // USER tracking
          UserActivityLogger.logUserActivity('ad_click', 'top_banner', '');
          // DEVELOPER tracking
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
          // USER tracking
          UserActivityLogger.logUserActivity('ad_impression', 'bottom_banner', '');
          // DEVELOPER tracking
          DeveloperAnalytics.trackAdEvent('impression', 'banner', 'bottom_banner');
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          print('Failed to load bottom banner: $err');
        },
        onAdClicked: (ad) {
          // USER tracking
          UserActivityLogger.logUserActivity('ad_click', 'bottom_banner', '');
          // DEVELOPER tracking
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
          // USER tracking
          UserActivityLogger.logUserActivity('ad_impression', 'rewarded', '');
          // DEVELOPER tracking
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
      // USER tracking
      UserActivityLogger.logUserActivity('ad_click', 'rewarded', 'premium_1hour');
      // DEVELOPER tracking
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
          // USER tracking
          UserActivityLogger.logUserActivity('ad_impression', 'interstitial', '');
          // DEVELOPER tracking
          DeveloperAnalytics.trackAdEvent('impression', 'interstitial', 'interstitial_ad');
          
          interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              print('Failed to show interstitial ad: $err');
              ad.dispose();
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
      // USER tracking
      UserActivityLogger.logUserActivity('ad_click', 'interstitial', '');
      // DEVELOPER tracking
      DeveloperAnalytics.trackAdEvent('click', 'interstitial', 'interstitial_ad');
      interstitialAd = null;
    }
  }

  void disposeAll() {
    topBanner?.dispose();
    bottomBanner?.dispose();
    rewardedAd?.dispose();
    interstitialAd?.dispose();
  }
}
