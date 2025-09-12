import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'premium_manager.dart';

class AdsManager {
  BannerAd? topBanner;
  BannerAd? bottomBanner;
  RewardedAd? rewardedAd;
  InterstitialAd? interstitialAd;

  // ---------------- BANNERS ----------------
  void loadTopBanner({required VoidCallback onLoaded}) {
    topBanner = BannerAd(
      adUnitId: "ca-app-pub-3940256099942544/6300978111",
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  void loadBottomBanner({required VoidCallback onLoaded}) {
    bottomBanner = BannerAd(
      adUnitId: "ca-app-pub-3940256099942544/6300978111",
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  // ---------------- REWARDED ----------------
  void loadRewardedAd({required Function(RewardedAd) onLoaded}) {
    RewardedAd.load(
      adUnitId: "ca-app-pub-3940256099942544/5224354917",
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => onLoaded(ad),
        onAdFailedToLoad: (_) {
          Future.delayed(
            const Duration(seconds: 15),
            () => loadRewardedAd(onLoaded: onLoaded),
          );
        },
      ),
    );
  }

  Future<void> showRewardedAd(RewardedAd ad, PremiumManager premiumManager) async {
    ad.show(onUserEarnedReward: (_, __) {
      premiumManager.unlockPremium(hours: 1);
    });
  }

  // ---------------- INTERSTITIAL ----------------
  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: "ca-app-pub-3940256099942544/1033173712", // Test ad unit
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          interstitialAd = ad;
          // Setup callback to reload after closed
          interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              loadInterstitial(); // Reload for next use
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              loadInterstitial(); // Reload on failure
            },
          );
        },
        onAdFailedToLoad: (error) {
          // Retry after 15 seconds if failed
          Future.delayed(const Duration(seconds: 15), loadInterstitial);
        },
      ),
    );
  }

  void showInterstitial() {
    if (interstitialAd != null) {
      interstitialAd!.show();
      interstitialAd = null; // Ensure we reload next
    }
  }

  // ---------------- DISPOSE ----------------
  void disposeAll() {
    topBanner?.dispose();
    bottomBanner?.dispose();
    rewardedAd?.dispose();
    interstitialAd?.dispose();
  }
}
