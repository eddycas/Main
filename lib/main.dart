​// main.dart (QuickCalc Best-of-Both-Worlds Version)

import 'dart:async';

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_expressions/math_expressions.dart';



void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();

  runApp(const QuickCalcApp());

}



// ============================

// UUID Helper

// ============================

Future<String> getUserUUID() async {

  final prefs = await SharedPreferences.getInstance();

  String? uuid = prefs.getString('user_uuid');

  if (uuid == null) {

    uuid = Random().nextInt(1000000000).toString();

    await prefs.setString('user_uuid', uuid);

  }

  return uuid;

}



// ============================

// QuickCalc App

// ============================

class QuickCalcApp extends StatefulWidget {

  const QuickCalcApp({super.key});

  @override

  State<QuickCalcApp> createState() => _QuickCalcAppState();

}



class _QuickCalcAppState extends State<QuickCalcApp> {

  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() => setState(() {

        _themeMode =

            _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;

      });



  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      title: 'QuickCalc',

      debugShowCheckedModeBanner: false,

      theme: ThemeData.light(useMaterial3: true),

      darkTheme: ThemeData.dark(useMaterial3: true),

      themeMode: _themeMode,

      home: CalculatorHome(toggleTheme: _toggleTheme),

    );

  }

}



// ============================

// Premium Manager

// ============================

class PremiumManager {

  DateTime? premiumUntil;

  Timer? _timer;

  Duration remaining = Duration.zero;



  bool get isPremium =>

      premiumUntil != null && DateTime.now().isBefore(premiumUntil!);



  Future<void> loadPremium() async {

    final prefs = await SharedPreferences.getInstance();

    final millis = prefs.getInt('premium_until');

    if (millis != null) {

      premiumUntil = DateTime.fromMillisecondsSinceEpoch(millis);

      _startTimer();

    }

  }



  Future<void> unlockPremium({required int hours}) async {

    premiumUntil = DateTime.now().add(Duration(hours: hours));

    _startTimer();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(

        'premium_until', premiumUntil!.millisecondsSinceEpoch);

  }



  void _startTimer() {

    _timer?.cancel();

    if (premiumUntil == null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {

      final diff = premiumUntil!.difference(DateTime.now());

      remaining = diff.isNegative ? Duration.zero : diff;

      if (diff.isNegative) {

        _timer?.cancel();

        premiumUntil = null;

      }

    });

  }



  void dispose() => _timer?.cancel();

}



// ============================

// Ads Manager

// ============================

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

        onAdLoaded: onLoaded,

        onAdFailedToLoad: (_) {

          Future.delayed(const Duration(seconds: 15),

              () => loadRewardedAd(onLoaded: onLoaded));

        },

      ),

    );

  }



  Future<void> showRewardedAd(

      RewardedAd ad, PremiumManager premiumManager) async {

    ad.show(onUserEarnedReward: (_, __) {

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

          interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(

            onAdDismissedFullScreenContent: (ad) {

              ad.dispose();

              loadInterstitial();

            },

            onAdFailedToShowFullScreenContent: (ad, _) {

              ad.dispose();

              loadInterstitial();

            },

          );

        },

        onAdFailedToLoad: (_) {

          Future.delayed(const Duration(seconds: 15), loadInterstitial);

        },

      ),

    );

  }



  void showInterstitial() {

    if (interstitialAd != null) {

      interstitialAd!.show();

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



// ============================

// Calculator Logic

// ============================

class CalculatorLogic {

  static void handleButton(String btn, CalculatorHomeState state) {

    if (btn == '=') {

      try {

        if (state.expression.isEmpty) return;

        String exp = state.expression.replaceAll('×', '*').replaceAll('÷', '/');

        Parser p = Parser();

        Expression expression = p.parse(exp);

        ContextModel cm = ContextModel();

        double eval = expression.evaluate(EvaluationType.REAL, cm);

        state.result = eval % 1 == 0 ? eval.toInt().toString() : eval.toString();

        state.history.insert(0, "${state.expression} = ${state.result}");

        state.expression = "";

        state.lastCalculationSuccessful = true;

      } catch (_) {

        state.result = "Error";

        state.lastCalculationSuccessful = false;

      }

    } else if (btn == 'C') {

      state.expression = "";

      state.result = "0";

    } else if (btn == 'DEL') {

      if (state.expression.isNotEmpty) {

        state.expression = state.expression.substring(0, state.expression.length - 1);

      }

      if (state.expression.isEmpty) state.result = "0";

    } else if (btn == 'M+') {

      state.memory = double.tryParse(state.result) ?? 0;

    } else if (btn == 'M-') {

      state.memory -= double.tryParse(state.result) ?? 0;

    } else if (btn == 'MR') {

      state.expression += state.memory.toString();

    } else if (btn == 'MC') {

      state.memory = 0;

    } else {

      state.expression += btn;

      state.result = state.expression;

    }

  }

}



// ============================

// Calculator Keypad

// ============================

class CalculatorKeypad extends StatelessWidget {

  final void Function(String) onPressed;

  const CalculatorKeypad({super.key, required this.onPressed});



  @override

  Widget build(BuildContext context) {

    final buttons = [

      ['7', '8', '9', '÷'],

      ['4', '5', '6', '×'],

      ['1', '2', '3', '-'],

      ['0', '.', '=', '+'],

      ['C', 'DEL', 'M+', 'M-', 'MR', 'MC']

    ];



    return Column(

      mainAxisAlignment: MainAxisAlignment.center,

      children: buttons.map((row) {

        return Expanded(

          child: Row(

            mainAxisAlignment: MainAxisAlignment.center,

            children: row.map((btn) {

              return Expanded(

                child: Padding(

                  padding: const EdgeInsets.all(4.0),

                  child: ElevatedButton(

                    onPressed: () => onPressed(btn),

                    style: ElevatedButton.styleFrom(

                      backgroundColor: Colors.amberAccent,

                      foregroundColor: Colors.black,

                    ),

                    child: Text(btn, style: const TextStyle(fontSize: 24)),

                  ),

                ),

              );

            }).toList(),

          ),

        );

      }).toList(),

    );

  }

}



// ============================

// Calculator Home

// ============================

class CalculatorHome extends StatefulWidget {

  final VoidCallback toggleTheme;

  const CalculatorHome({super.key, required this.toggleTheme});

  @override

  CalculatorHomeState createState() => CalculatorHomeState();

}



class CalculatorHomeState extends State<CalculatorHome> {

  String expression = "";

  String result = "0";

  final List<String> history = [];

  double memory = 0;



  bool panelOpen = false;

  bool isTopBannerLoaded = false;

  bool isBottomBannerLoaded = false;

  RewardedAd? rewardedAd;

  bool isRewardedReady = false;



  int calculationCount = 0;

  bool lastCalculationSuccessful = false;



  late PremiumManager premiumManager;

  late AdsManager adsManager;



  DateTime? lastInterstitialTime;

  DateTime? lastRewardedTime;



  @override

  void initState() {

    super.initState();

    premiumManager = PremiumManager();

    adsManager = AdsManager();

    _loadCooldowns();

    premiumManager.loadPremium();



    adsManager.loadTopBanner(onLoaded: () => setState(() => isTopBannerLoaded = true));

    adsManager.loadBottomBanner(onLoaded: () => setState(() => isBottomBannerLoaded = true));



    adsManager.loadRewardedAd(onLoaded: (ad) {

      rewardedAd = ad;

      isRewardedReady = true;

    });



    adsManager.loadInterstitial();

  }



  Future<void> _loadCooldowns() async {

    final prefs = await SharedPreferences.getInstance();

    final interstitialMillis = prefs.getInt('last_interstitial_time');

    if (interstitialMillis != null) lastInterstitialTime = DateTime.fromMillisecondsSinceEpoch(interstitialMillis);



    final rewardedMillis = prefs.getInt('last_rewarded_time');

    if (rewardedMillis != null) lastRewardedTime = DateTime.fromMillisecondsSinceEpoch(rewardedMillis);

  }



  Future<void> _saveInterstitialTime() async {

    final prefs = await SharedPreferences.getInstance();

    lastInterstitialTime = DateTime.now();

    await prefs.setInt('last_interstitial_time', lastInterstitialTime!.millisecondsSinceEpoch);

  }



  Future<void> _saveRewardedTime() async {

    final prefs = await SharedPreferences.getInstance();

    lastRewardedTime = DateTime.now();

    await prefs.setInt('last_rewarded_time', lastRewardedTime!.millisecondsSinceEpoch);

  }



  bool _canShowInterstitial() =>

      lastInterstitialTime == null || DateTime.now().difference(lastInterstitialTime!) >= const Duration(minutes: 20);



  bool _canShowRewarded() =>

      lastRewardedTime == null || DateTime.now().difference(lastRewardedTime!) >= const Duration(hours: 1);



  void handleCalculation(String btn) async {

    setState(() => CalculatorLogic.handleButton(btn, this));



    if (lastCalculationSuccessful) {

      calculationCount++;

      bool showInterstitial = calculationCount % 20 == 0 && _canShowInterstitial();

      bool showRewarded = calculationCount % 50 == 0 && _canShowRewarded() && isRewardedReady;



      if (showInterstitial) {

        adsManager.showInterstitial();

        await _saveInterstitialTime();

      }

      if (showRewarded && rewardedAd != null) {

        await adsManager.showRewardedAd(rewardedAd!, premiumManager);

        await _saveRewardedTime();

        rewardedAd = null;

        isRewardedReady = false;

        adsManager.loadRewardedAd(onLoaded: (ad) {

          rewardedAd = ad;

          isRewardedReady = true;

        });

      }

    }

  }



  @override

  void dispose() {

    premiumManager.dispose();

    adsManager.disposeAll();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text("QuickCalc"),

        actions: [

          IconButton(icon: const Icon(Icons.color_lens), onPressed: widget.toggleTheme),

          IconButton(icon: const Icon(Icons.history), onPressed: () => setState(() => panelOpen = !panelOpen)),

        ],

      ),

      body: Stack(

        children: [

          Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              if (isTopBannerLoaded)

                SizedBox(height: 50, child: AdWidget(ad: adsManager.topBanner!)),

              Expanded(

                child: Center(

                  child: Text(

                    result,

                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),

                  ),

                ),

              ),

              Expanded(child: CalculatorKeypad(onPressed: handleCalculation)),

              if (isBottomBannerLoaded)

                SizedBox(height: 50, child: AdWidget(ad: adsManager.bottomBanner!)),

            ],

          ),

          AnimatedPositioned(

            duration: const Duration(milliseconds: 300),

            right: panelOpen ? 0 : -MediaQuery.of(context).size.width * 0.7,

            top: 0,

            bottom: 0,

            width: MediaQuery.of(context).size.width * 0.7,

            child: Container(

              color: Theme.of(context).colorScheme.surface,

              padding: const EdgeInsets.all(16),

              child: Column(

                children: [

                  Row(

                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [

                      const Text("History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

                      IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => panelOpen = false)),

                    ],

                  ),

                  const Divider(),

                  Expanded(

                    child: ListView.builder(

                      itemCount: history.length,

                      itemBuilder: (context, index) => ListTile(title: Text(history[index])),

                    ),

                  ),

                  if (!premiumManager.isPremium)

                    ElevatedButton(

                      onPressed: isRewardedReady && rewardedAd != null

                          ? () async {

                              await adsManager.showRewardedAd(rewardedAd!, premiumManager);

                              await _saveRewardedTime();

                              rewardedAd = null;

                              isRewardedReady = false;

                              adsManager.loadRewardedAd(onLoaded: (ad) {

                                rewardedAd = ad;

                                isRewardedReady = true;

                              });

                              setState(() {}); // Refresh UI after reward

                            }

                          : null,

                      style: ElevatedButton.styleFrom(

                        backgroundColor: Colors.amber,

                        foregroundColor: Colors.black,

                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),

                      ),

                      child: const Text("Watch Ad for Premium", style: TextStyle(fontSize: 16)),

                    ),

                  if (premiumManager.isPremium)

                    Padding(

                      padding: const EdgeInsets.symmetric(vertical: 8.0),

                      child: Text(

                        "Premium Active: ${premiumManager.remaining.inMinutes} min left",

                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),

                      ),

                    ),

                ],

              ),

            ),

          ),

        ],

      ),

    );

  }

}
