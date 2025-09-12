import 'package:flutter/material.dart';
import 'slide_panel.dart';
import 'calculator_keypad.dart';
import 'calculator_logic.dart';
import 'ads_manager.dart';
import 'premium_manager.dart';
import 'auth_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalculatorHome extends StatefulWidget {
  final VoidCallback toggleTheme;
  const CalculatorHome({super.key, required this.toggleTheme});

  @override
  State<CalculatorHome> createState() => _CalculatorHomeState();
}

class _CalculatorHomeState extends State<CalculatorHome> {
  // -------------------- VARIABLES --------------------
  String _expression = "";
  String _result = "0";
  final List<String> _history = [];
  double _memory = 0;

  late double _screenWidth;
  late double _screenHeight;
  late double _panelWidth;
  bool _panelOpen = false;

  BannerAd? _topBanner;
  BannerAd? _bottomBanner;
  bool _isTopBannerLoaded = false;
  bool _isBottomBannerLoaded = false;

  RewardedAd? _rewardedAd;
  bool _isRewardedReady = false;

  User? _user;

  // -------------------- MANAGERS --------------------
  late PremiumManager _premiumManager;
  late AdsManager _adsManager;
  late AuthManager _authManager;

  @override
  void initState() {
    super.initState();

    _premiumManager = PremiumManager();
    _adsManager = AdsManager();
    _authManager = AuthManager();

    _user = FirebaseAuth.instance.currentUser;

    _authManager.initAuthListener((u) {
      setState(() {
        _user = u;
      });
      _premiumManager.loadPremium(u);
    });

    _adsManager.loadTopBanner(onLoaded: () => setState(() => _isTopBannerLoaded = true));
    _adsManager.loadBottomBanner(onLoaded: () => setState(() => _isBottomBannerLoaded = true));
    _adsManager.loadRewardedAd(onLoaded: (ad) {
      _rewardedAd = ad;
      _isRewardedReady = true;
    });
  }

  @override
  void dispose() {
    _adsManager.disposeAll();
    _premiumManager.dispose();
    _authManager.dispose();
    super.dispose();
  }

  void _togglePanel() => setState(() => _panelOpen = !_panelOpen);

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _panelWidth = _screenWidth * 0.7;

    return Scaffold(
      appBar: AppBar(title: const Text("QuickCalc")),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isTopBannerLoaded && _adsManager.topBanner != null)
                SizedBox(
                  width: _adsManager.topBanner!.size.width.toDouble(),
                  height: _adsManager.topBanner!.size.height.toDouble(),
                  child: AdWidget(ad: _adsManager.topBanner!),
                ),
              Expanded(
                child: Center(
                  child: Text(
                    _result,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
              CalculatorKeypad(
                onPressed: (btn) {
                  setState(() {
                    CalculatorLogic.handleButton(btn, this);
                  });
                },
              ),
              if (_isBottomBannerLoaded && _adsManager.bottomBanner != null)
                SizedBox(
                  width: _adsManager.bottomBanner!.size.width.toDouble(),
                  height: _adsManager.bottomBanner!.size.height.toDouble(),
                  child: AdWidget(ad: _adsManager.bottomBanner!),
                ),
            ],
          ),
          SlidePanel(
            panelOpen: _panelOpen,
            panelWidth: _panelWidth,
            screenHeight: _screenHeight,
            togglePanel: _togglePanel,
            history: _history,
            user: _user,
            premiumManager: _premiumManager,
            signIn: _authManager.signInWithGoogle,
            signOut: _authManager.signOut,
            showRewarded: () async {
              if (_rewardedAd != null) {
                await _adsManager.showRewardedAd(_rewardedAd!, _premiumManager);
                setState(() {
                  _rewardedAd = null;
                  _isRewardedReady = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}

