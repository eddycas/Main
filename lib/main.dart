import 'dart:async';
import 'dart:math';
import 'dart:ui';

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
      home: CalculatorHome(toggleTheme: _toggleTheme, themeMode: _themeMode),
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
    await prefs.setInt('premium_until', premiumUntil!.millisecondsSinceEpoch);
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
        onAdLoaded: (_) {
          print('Top banner ad loaded successfully');
          onLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          print('Top banner failed to load: $error');
          ad.dispose();
          // Retry after 30 seconds
          Future.delayed(const Duration(seconds: 30), () {
            loadTopBanner(onLoaded: onLoaded);
          });
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
          print('Bottom banner ad loaded successfully');
          onLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          print('Bottom banner failed to load: $error');
          ad.dispose();
          // Retry after 30 seconds
          Future.delayed(const Duration(seconds: 30), () {
            loadBottomBanner(onLoaded: onLoaded);
          });
        },
      ),
    )..load();
  }

  void loadRewardedAd({required Function(RewardedAd) onLoaded}) {
    RewardedAd.load(
      adUnitId: "ca-app-pub-3940256099942544/5224354917",
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (error) {
          print('Failed to load rewarded ad: $error');
          Future.delayed(
              const Duration(seconds: 15),
              () => loadRewardedAd(
                  onLoaded: onLoaded));
        },
      ),
    );
  }

  Future<void> showRewardedAd(
      RewardedAd ad, PremiumManager premiumManager) async {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('Failed to show rewarded ad: $error');
        ad.dispose();
      },
    );
    
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
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('Failed to show interstitial ad: $error');
              ad.dispose();
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('Failed to load interstitial ad: $error');
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
        String exp =
            state.expression.replaceAll('×', '*').replaceAll('÷', '/');
        Parser p = Parser();
        Expression expression = p.parse(exp);
        ContextModel cm = ContextModel();
        double eval = expression.evaluate(EvaluationType.REAL, cm);
        state.result = eval % 1 == 0 ? eval.toInt().toString() : eval.toString();

        if (state.lastCalculationSuccessful) {
          state.history.insert(0, "${state.expression} = ${state.result}");
          if (state.history.length > 10) state.history.removeLast();
        }

        state.expression = "";
        state.lastCalculationSuccessful = true;
        state._saveHistory();
      } catch (_) {
        state.result = "Error";
        state.lastCalculationSuccessful = false;
      }
    } else if (btn == 'C') {
      state.expression = "";
      state.result = "0";
    } else if (btn == 'DEL') {
      if (state.expression.isNotEmpty) {
        state.expression =
            state.expression.substring(0, state.expression.length - 1);
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
  final ThemeMode themeMode;

  const CalculatorKeypad({super.key, required this.onPressed, required this.themeMode});

  @override
  Widget build(BuildContext context) {
    final buttons = [
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['0', '.', '=', '+'],
      ['C', 'DEL']
    ];

    Color getButtonColor(String btn) => themeMode == ThemeMode.light ? Colors.white : Colors.grey[850]!;

    Color getTextColor(String btn) {
      if (btn == 'DEL') return Colors.red;
      if (['+', '-', '×', '÷', '='].contains(btn)) return Colors.blue;
      return themeMode == ThemeMode.light ? Colors.black : Colors.white;
    }

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
                      shape: const CircleBorder(),
                      backgroundColor: getButtonColor(btn),
                      foregroundColor: getTextColor(btn),
                      shadowColor: Colors.black54,
                      elevation: 5,
                      padding: const EdgeInsets.all(26),
                    ),
                    child: Text(btn, style: TextStyle(fontSize: 32, color: getTextColor(btn))),
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
  final ThemeMode themeMode;
  const CalculatorHome({super.key, required this.toggleTheme, required this.themeMode});

  @override
  CalculatorHomeState createState() => CalculatorHomeState();
}

class CalculatorHomeState extends State<CalculatorHome> {
  String expression = "";
  String result = "0";
  final List<String> history = [];
  double memory = 0;
  bool leftPanelOpen = false;
  bool rightPanelOpen = false;
  bool isTopBannerLoaded = false;
  bool isBottomBannerLoaded = false;
  RewardedAd? rewardedAd;
  bool isRewardedReady = false;
  bool lastCalculationSuccessful = false;

  late PremiumManager premiumManager;
  late AdsManager adsManager;

  @override
  void initState() {
    super.initState();
    premiumManager = PremiumManager();
    adsManager = AdsManager();
    _loadHistory();
    premiumManager.loadPremium();
    
    // Load ads after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      adsManager.loadTopBanner(onLoaded: () => setState(() => isTopBannerLoaded = true));
      adsManager.loadBottomBanner(onLoaded: () => setState(() => isBottomBannerLoaded = true));
      adsManager.loadRewardedAd(onLoaded: (ad) {
        setState(() {
          rewardedAd = ad;
          isRewardedReady = true;
        });
      });
      adsManager.loadInterstitial();
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHistory = prefs.getStringList('calc_history') ?? [];
    setState(() {
      history.addAll(savedHistory);
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('calc_history', history);
  }

  Future<void> _watchRewardedAd() async {
    if (isRewardedReady && rewardedAd != null) {
      await adsManager.showRewardedAd(rewardedAd!, premiumManager);
      setState(() {
        rewardedAd = null;
        isRewardedReady = false;
      });
      adsManager.loadRewardedAd(onLoaded: (ad) {
        setState(() {
          rewardedAd = ad;
          isRewardedReady = true;
        });
      });
    }
  }

  @override
  void dispose() {
    premiumManager.dispose();
    adsManager.disposeAll();
    _saveHistory();
    super.dispose();
  }

  // BANNER AD WIDGET - FIXED VERSION
  Widget _buildTopBanner() {
    if (premiumManager.isPremium) {
      return SizedBox.shrink(); // Hide if premium
    }
    
    if (!isTopBannerLoaded) {
      return SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    
    if (adsManager.topBanner == null) {
      return SizedBox(
        height: 50,
        child: Center(child: Text('Ad loading...', style: TextStyle(fontSize: 12))),
      );
    }
    
    return Container(
      width: double.infinity, // CRITICAL FIX: Full width
      height: adsManager.topBanner!.size.height.toDouble(),
      alignment: Alignment.center,
      color: Colors.transparent,
      child: AdWidget(ad: adsManager.topBanner!),
    );
  }

  Widget _buildBottomBanner() {
    if (premiumManager.isPremium) {
      return SizedBox.shrink(); // Hide if premium
    }
    
    if (!isBottomBannerLoaded) {
      return SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    
    if (adsManager.bottomBanner == null) {
      return SizedBox(
        height: 50,
        child: Center(child: Text('Ad loading...', style: TextStyle(fontSize: 12))),
      );
    }
    
    return Container(
      width: double.infinity, // CRITICAL FIX: Full width
      height: adsManager.bottomBanner!.size.height.toDouble(),
      alignment: Alignment.center,
      color: Colors.transparent,
      child: AdWidget(ad: adsManager.bottomBanner!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: widget.themeMode == ThemeMode.light ? Colors.white : Colors.black,
      appBar: AppBar(
        title: const Text("QuickCalc"),
        actions: [
          IconButton(icon: const Icon(Icons.color_lens), onPressed: widget.toggleTheme),
          IconButton(icon: const Icon(Icons.history), onPressed: () => setState(() => leftPanelOpen = !leftPanelOpen)),
          IconButton(icon: const Icon(Icons.star), onPressed: () => setState(() => rightPanelOpen = !rightPanelOpen)),
        ],
      ),
      body: Stack(
        children: [
          // Main Column
          Column(
            children: [
              // TOP BANNER - FIXED
              _buildTopBanner(),
              
              // Expression display
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.all(16),
                child: Text(
                  expression,
                  style: TextStyle(
                    fontSize: 24,
                    color: widget.themeMode == ThemeMode.light ? Colors.grey : Colors.grey[400],
                  ),
                ),
              ),
              
              // Result display
              Expanded(
                child: Center(
                  child: Text(
                    result,
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: widget.themeMode == ThemeMode.light ? Colors.black : Colors.white),
                  ),
                ),
              ),
              
              // Keypad
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: CalculatorKeypad(
                  onPressed: (btn) => setState(() => CalculatorLogic.handleButton(btn, this)),
                  themeMode: widget.themeMode,
                ),
              ),
              
              // BOTTOM BANNER - FIXED
              _buildBottomBanner(),
            ],
          ),

          // History Panel (Left)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: leftPanelOpen ? 0 : -screenWidth * 0.7,
            top: 0,
            bottom: 0,
            width: screenWidth * 0.7,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => leftPanelOpen = false)),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) => ListTile(title: Text(history[index])),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _watchRewardedAd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Watch Ad to +30 History"),
                  ),
                ],
              ),
            ),
          ),

          // Premium Panel (Right)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            right: rightPanelOpen ? 0 : -screenWidth * 0.6,
            top: 0,
            bottom: 0,
            width: screenWidth * 0.6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Premium", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => rightPanelOpen = false)),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!premiumManager.isPremium)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Not a Premium User. Unlock features by watching ads.",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          if (!premiumManager.isPremium)
                            ElevatedButton(
                              onPressed: _watchRewardedAd,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Watch Ad to Unlock Premium"),
                            ),
                          if (premiumManager.isPremium)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Premium Active!\nTime remaining: ${premiumManager.remaining.inMinutes.remainder(60).toString().padLeft(2,'0')}:${(premiumManager.remaining.inSeconds.remainder(60)).toString().padLeft(2,'0')}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              children: List.generate(4, (index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      Container(
                                        color: Colors.blueAccent,
                                        alignment: Alignment.center,
                                        child: const Text(
                                          "Premium Btn",
                                          style: TextStyle(color: Colors.white, fontSize: 16),
                                        ),
                                      ),
                                      if (!premiumManager.isPremium)
                                        BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                          child: Container(color: Colors.black.withOpacity(0)),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
