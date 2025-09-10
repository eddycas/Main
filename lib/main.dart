import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:math_expressions/math_expressions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quickcalc',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  _CalculatorScreenState createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = "";
  String _result = "";
  int _calculationCount = 0;
  final List<String> _history = []; // ✅ Stores calculation history

  late BannerAd _topBannerAd;
  late BannerAd _bottomBannerAd;
  bool _isTopBannerLoaded = false;
  bool _isBottomBannerLoaded = false;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialReady = false;
  bool _isRewardedReady = false;

  @override
  void initState() {
    super.initState();
    _loadTopBanner();
    _loadBottomBanner();
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  void _loadTopBanner() {
    _topBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test banner ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() => _isTopBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Top banner failed: $error');
        },
      ),
    )..load();
  }

  void _loadBottomBanner() {
    _bottomBannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test banner ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() => _isBottomBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Bottom banner failed: $error');
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // Test interstitial
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed: $error');
        },
      ),
    );
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test rewarded
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedReady = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded failed: $error');
        },
      ),
    );
  }

  @override
  void dispose() {
    _topBannerAd.dispose();
    _bottomBannerAd.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _onButtonPressed(String value) {
    setState(() {
      if (value == "C") {
        _expression = "";
        _result = "";
      } else if (value == "=") {
        try {
          Parser p = Parser();
          Expression exp = p.parse(
              _expression.replaceAll("×", "*").replaceAll("÷", "/"));
          ContextModel cm = ContextModel();
          double eval = exp.evaluate(EvaluationType.REAL, cm);

          // ✅ No .0 unless decimal was used
          if (eval == eval.toInt()) {
            _result = eval.toInt().toString();
          } else {
            _result = eval.toString();
          }

          // ✅ Save to history
          _history.add("$_expression = $_result");

          _calculationCount++;
          if (_calculationCount % 3 == 0) {
            Future.delayed(const Duration(seconds: 10), () {
              if (_isRewardedReady && _rewardedAd != null) {
                _rewardedAd!.show(
                  onUserEarnedReward: (ad, reward) {
                    debugPrint("User earned reward: ${reward.amount} ${reward.type}");
                  },
                );
                _isRewardedReady = false;
                _rewardedAd = null;
                _loadRewardedAd(); // reload next one
              }
            });
          }

        } catch (e) {
          _result = "Error";
        }
      } else {
        _expression += value;
      }
    });
  }

  Widget _buildButton(String text, {Color color = Colors.white}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[900],
            padding: const EdgeInsets.all(20),
          ),
          onPressed: () => _onButtonPressed(text),
          child: Text(
            text,
            style: TextStyle(fontSize: 24, color: color),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Quickcalc"),
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            if (_isInterstitialReady && _interstitialAd != null) {
              _interstitialAd!.show();
              _isInterstitialReady = false;
              _interstitialAd = null;
              _loadInterstitialAd(); // reload next one
            } else {
              debugPrint("Settings pressed (Interstitial not ready)");
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // ✅ Navigate to history page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(history: _history),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Top Banner
          if (_isTopBannerLoaded)
            SizedBox(
              height: _topBannerAd.size.height.toDouble(),
              width: _topBannerAd.size.width.toDouble(),
              child: AdWidget(ad: _topBannerAd),
            ),
          // ✅ Calculator Display
          Expanded(
            child: Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_expression,
                      style:
                          const TextStyle(fontSize: 32, color: Colors.white70)),
                  const SizedBox(height: 10),
                  Text(_result,
                      style:
                          const TextStyle(fontSize: 48, color: Colors.white)),
                ],
              ),
            ),
          ),
          // ✅ Keypad
          Column(
            children: [
              Row(children: [
                _buildButton("7"),
                _buildButton("8"),
                _buildButton("9"),
                _buildButton("÷", color: Colors.orange)
              ]),
              Row(children: [
                _buildButton("4"),
                _buildButton("5"),
                _buildButton("6"),
                _buildButton("×", color: Colors.orange)
              ]),
              Row(children: [
                _buildButton("1"),
                _buildButton("2"),
                _buildButton("3"),
                _buildButton("-", color: Colors.orange)
              ]),
              Row(children: [
                _buildButton("0"),
                _buildButton("."),
                _buildButton("=", color: Colors.green),
                _buildButton("+", color: Colors.orange)
              ]),
              Row(children: [_buildButton("C", color: Colors.red)]),
            ],
          ),
          // ✅ Bottom Banner
          if (_isBottomBannerLoaded)
            SizedBox(
              height: _bottomBannerAd.size.height.toDouble(),
              width: _bottomBannerAd.size.width.toDouble(),
              child: AdWidget(ad: _bottomBannerAd),
            ),
        ],
      ),
    );
  }
}

// ✅ History Screen
class HistoryScreen extends StatelessWidget {
  final List<String> history;
  const HistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: history.isEmpty
          ? const Center(child: Text("No history yet"))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(history[index]),
                );
              },
            ),
    );
  }
}
