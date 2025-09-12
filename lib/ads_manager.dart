import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'premium_manager.dart';

class AdsManager {
  BannerAd? topBanner;
  BannerAd? bottomBanner;
  RewardedAd? rewardedAd;

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

  void disposeAll() {
    topBanner?.dispose();
    bottomBanner?.dispose();
    rewardedAd?.dispose();
  }
}
