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
          UserActivityLogger.logUserActivity('ad_loaded', 'rewarded', '');
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
    bool adCompleted = false;
    
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (adCompleted) {
          UserActivityLogger.logUserActivity('ad_watched', 'rewarded', 'premium_1hour');
          DeveloperAnalytics.trackAdEvent('watched', 'rewarded', 'rewarded_ad');
        }
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        print('Failed to show rewarded ad: $err');
        ad.dispose();
      },
    );
    
    ad.show(onUserEarnedReward: (_, reward) {
      adCompleted = true;
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
          UserActivityLogger.logUserActivity('ad_loaded', 'interstitial', '');
          
          interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              UserActivityLogger.logUserActivity('ad_watched', 'interstitial', '');
              DeveloperAnalytics.trackAdEvent('watched', 'interstitial', 'interstitial_ad');
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
      UserActivityLogger.logUserActivity('ad_click', 'interstitial', '');
      DeveloperAnalytics.trackAdEvent('click', 'interstitial', 'interstitial_ad');
    }
  }

  void disposeAll() {
    topBanner?.dispose();
    bottomBanner?.dispose();
    rewardedAd?.dispose();
    interstitialAd?.dispose();
  }
}
