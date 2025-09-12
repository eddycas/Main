import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'slide_panel.dart';
import 'calculator_keypad.dart';
import 'calculator_logic.dart';
import 'ads_manager.dart';
import 'premium_manager.dart';
import 'auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalculatorHome extends StatefulWidget {
  final VoidCallback toggleTheme;
  const CalculatorHome({super.key, required this.toggleTheme});

  @override
  CalculatorHomeState createState() => CalculatorHomeState();
}

class CalculatorHomeState extends State<CalculatorHome> {
  // -------------------- VARIABLES --------------------
  String expression = "";
  String result = "0";
  final List<String> history = [];
  double memory = 0;

  late double screenWidth;
  late double screenHeight;
  late double panelWidth;
  bool panelOpen = false;

  BannerAd? topBanner;
  BannerAd? bottomBanner;
  bool isTopBannerLoaded = false;
  bool isBottomBannerLoaded = false;

  RewardedAd? rewardedAd;
  bool isRewardedReady = false;

  User? user;

  int calculationCount = 0;

  // -------------------- MANAGERS --------------------
  late PremiumManager premiumManager;
  late AdsManager adsManager;

  VoidCallback? onShowInterstitial;

  @override
  void initState() {
    super.initState();

    premiumManager = PremiumManager();
    adsManager = AdsManager();

    // Get current user
    user = FirebaseAuth.instance.currentUser;

    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((u) {
      setState(() {
        user = u;
      });
      premiumManager.loadPremium(u);
    });

    // Load banners
    adsManager.loadTopBanner(onLoaded: () => setState(() => isTopBannerLoaded = true));
    adsManager.loadBottomBanner(onLoaded: () => setState(() => isBottomBannerLoaded = true));

    // Load rewarded ad
    adsManager.loadRewardedAd(onLoaded: (ad) {
      rewardedAd = ad;
      isRewardedReady = true;
    });

    // Load interstitial
    adsManager.loadInterstitial();
    onShowInterstitial = () => adsManager.showInterstitial();
  }

  @override
  void dispose() {
    adsManager.disposeAll();
    premiumManager.dispose();
    super.dispose();
  }

  void togglePanel() => setState(() => panelOpen = !panelOpen);

  // -------------------- CALCULATION HANDLER --------------------
  void handleCalculation(String btn) {
    setState(() {
      CalculatorLogic.handleButton(btn, this);
      calculationCount++;

      // Show interstitial every 10 calculations
      if (calculationCount % 10 == 0) {
        onShowInterstitial?.call();
      }
    });
  }

  // -------------------- REWARDED HANDLER --------------------
  Future<void> handleShowRewarded() async {
    if (rewardedAd != null) {
      await adsManager.showRewardedAd(rewardedAd!, premiumManager);
      setState(() {
        rewardedAd = null;
        isRewardedReady = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    panelWidth = screenWidth * 0.7;

    return Scaffold(
      appBar: AppBar(title: const Text("QuickCalc")),
      body: Stack(
        children: [
          Column(
            children: [
              if (isTopBannerLoaded && adsManager.topBanner != null)
                SizedBox(
                  width: adsManager.topBanner!.size.width.toDouble(),
                  height: adsManager.topBanner!.size.height.toDouble(),
                  child: AdWidget(ad: adsManager.topBanner!),
                ),
              // Result Box
              Container(
                width: screenWidth * 0.9,
                height: screenHeight * 0.4,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  result,
                  style: const TextStyle(fontSize: 48),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CalculatorKeypad(
                onPressed: handleCalculation,
              ),
              if (isBottomBannerLoaded && adsManager.bottomBanner != null)
                SizedBox(
                  width: adsManager.bottomBanner!.size.width.toDouble(),
                  height: adsManager.bottomBanner!.size.height.toDouble(),
                  child: AdWidget(ad: adsManager.bottomBanner!),
                ),
            ],
          ),
          SlidePanel(
            panelOpen: panelOpen,
            panelWidth: panelWidth,
            screenHeight: screenHeight,
            togglePanel: togglePanel,
            history: history,
            user: user,
            premiumManager: premiumManager,
            showRewarded: handleShowRewarded,
            toggleTheme: widget.toggleTheme,
          ),
        ],
      ),
    );
  }
}
