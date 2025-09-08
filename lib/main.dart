import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rewarded Ad Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AdsScreen(),
    );
  }
}

class AdsScreen extends StatefulWidget {
  @override
  _AdsScreenState createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  BannerAd? _topBanner;
  BannerAd? _bottomBanner;
  RewardedAd? _rewardedAd;

  int _solvedEquations = 0;

  @override
  void initState() {
    super.initState();
    _loadTopBanner();
    _loadBottomBanner();
    _loadRewardedAd();
  }

  void _loadTopBanner() {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-3940256099942544/2934735716';

    _topBanner = BannerAd(
      adUnitId: adUnitId,
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => print('Top banner loaded'),
        onAdFailedToLoad: (ad, err) {
          print('Top banner failed: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadBottomBanner() {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-3940256099942544/2934735716';

    _bottomBanner = BannerAd(
      adUnitId: adUnitId,
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => print('Bottom banner loaded'),
        onAdFailedToLoad: (ad, err) {
          print('Bottom banner failed: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  void _loadRewardedAd() {
    final adUnitId = Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/5224354917'
        : 'ca-app-pub-3940256099942544/1712485313';

    RewardedAd.load(
      adUnitId: adUnitId,
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('Rewarded ad loaded');
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (err) {
          print('Rewarded ad failed: $err');
        },
      ),
    );
  }

  void _checkAndShowRewardedAd() {
    _solvedEquations++;
    print('Equations solved: $_solvedEquations');

    if (_solvedEquations >= 3) {
      if (_rewardedAd != null) {
        _rewardedAd!.show(
          onUserEarnedReward: (ad, reward) {
            print('User earned reward: ${reward.amount} ${reward.type}');
          },
        );
        _rewardedAd = null;
        _loadRewardedAd(); // preload next rewarded ad
        _solvedEquations = 0; // reset counter
      } else {
        print('Rewarded ad not loaded yet.');
      }
    }
  }

  @override
  void dispose() {
    _topBanner?.dispose();
    _bottomBanner?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rewarded Ad Example')),
      body: Column(
        children: [
          if (_topBanner != null)
            Container(
              width: _topBanner!.size.width.toDouble(),
              height: _topBanner!.size.height.toDouble(),
              child: AdWidget(ad: _topBanner!),
            ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Solve equations: $_solvedEquations/3'),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _checkAndShowRewardedAd,
                    child: Text('Solve Equation'),
                  ),
                ],
              ),
            ),
          ),
          if (_bottomBanner != null)
            Container(
              width: _bottomBanner!.size.width.toDouble(),
              height: _bottomBanner!.size.height.toDouble(),
              child: AdWidget(ad: _bottomBanner!),
            ),
        ],
      ),
    );
  }
}
