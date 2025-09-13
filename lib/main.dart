import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:math_expressions/math_expressions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _output = "0";
  String _expression = "";
  final List<String> _history = [];
  int _calculationCount = 0;
  bool _isPremium = false;
  DateTime? _premiumUntil;
  Timer? _premiumTimer;
  Duration _premiumTimeLeft = Duration.zero;
  
  // Ads
  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isBannerAdReady = false;
  bool _isInterstitialAdReady = false;
  bool _isRewardedAdReady = false;
  
  // Panel states
  bool _isHistoryPanelOpen = false;
  bool _isToolsPanelOpen = false;
  
  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadAds();
  }
  
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history.addAll(prefs.getStringList('history') ?? []);
      _calculationCount = prefs.getInt('calculationCount') ?? 0;
      
      final premiumUntilMillis = prefs.getInt('premiumUntil');
      if (premiumUntilMillis != null) {
        _premiumUntil = DateTime.fromMillisecondsSinceEpoch(premiumUntilMillis);
        _isPremium = _premiumUntil!.isAfter(DateTime.now());
        if (_isPremium) {
          _startPremiumTimer();
        }
      }
    });
  }
  
  void _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('history', _history);
    prefs.setInt('calculationCount', _calculationCount);
    if (_premiumUntil != null) {
      prefs.setInt('premiumUntil', _premiumUntil!.millisecondsSinceEpoch);
    }
  }
  
  void _loadAds() {
    _loadBannerAd();
    _loadInterstitialAd();
    _loadRewardedAd();
  }
  
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test ad ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }
  
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', // Test ad ID
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _interstitialAd = ad;
            _isInterstitialAdReady = true;
          });
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialAdReady = false;
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialAdReady = false;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdReady = false;
          _interstitialAd = null;
        },
      ),
    );
  }
  
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test ad ID
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdReady = true;
          });
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isRewardedAdReady = false;
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isRewardedAdReady = false;
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isRewardedAdReady = false;
          _rewardedAd = null;
        },
      ),
    );
  }
  
  void _showInterstitialAd() {
    if (_isInterstitialAdReady) {
      _interstitialAd!.show();
    }
  }
  
  void _showRewardedAd() {
    if (_isRewardedAdReady) {
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        _activatePremium(60); // 1 hour premium
      });
    }
  }
  
  void _activatePremium(int minutes) {
    setState(() {
      _premiumUntil = DateTime.now().add(Duration(minutes: minutes));
      _isPremium = true;
      _startPremiumTimer();
    });
    _savePreferences();
  }
  
  void _startPremiumTimer() {
    _premiumTimer?.cancel();
    _premiumTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_premiumUntil != null) {
        final now = DateTime.now();
        if (_premiumUntil!.isAfter(now)) {
          setState(() {
            _premiumTimeLeft = _premiumUntil!.difference(now);
          });
        } else {
          setState(() {
            _isPremium = false;
            _premiumUntil = null;
            _premiumTimeLeft = Duration.zero;
          });
          _premiumTimer?.cancel();
          _savePreferences();
        }
      }
    });
  }
  
  void _buttonPressed(String buttonText) {
    setState(() {
      if (buttonText == "C") {
        _output = "0";
        _expression = "";
      } else if (buttonText == "=") {
        _expression = _expression.replaceAll('×', '*');
        _expression = _expression.replaceAll('÷', '/');
        
        try {
          Parser p = Parser();
          Expression exp = p.parse(_expression);
          ContextModel cm = ContextModel();
          double eval = exp.evaluate(EvaluationType.REAL, cm);
          
          _output = eval.toString();
          _history.add("$_expression = $_output");
          
          // Limit history for non-premium users
          if (!_isPremium && _history.length > 10) {
            _history.removeAt(0);
          }
          
          _calculationCount++;
          
          // Show interstitial ad after every 10 calculations
          if (_calculationCount % 10 == 0) {
            _showInterstitialAd();
          }
          
          _expression = "";
        } catch (e) {
          _output = "Error";
        }
      } else if (buttonText == "⌫") {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        if (_expression.isEmpty) {
          _output = "0";
        }
      } else {
        if (_expression.isEmpty && _output != "0") {
          _expression = _output;
        }
        _expression += buttonText;
        _output = _expression;
      }
      
      _savePreferences();
    });
  }
  
  void _advancedFunction(String function) {
    if (!_isPremium) return;
    
    try {
      double value = double.tryParse(_output) ?? 0;
      double result = 0;
      
      switch (function) {
        case "sin":
          result = sin(value * pi / 180);
          break;
        case "cos":
          result = cos(value * pi / 180);
          break;
        case "tan":
          result = tan(value * pi / 180);
          break;
        case "log2":
          result = log(value) / ln2;
          break;
        case "log10":
          result = log(value) / ln10;
          break;
      }
      
      setState(() {
        _output = result.toString();
        _history.add("$function($value) = $_output");
        
        // Limit history for non-premium users
        if (!_isPremium && _history.length > 10) {
          _history.removeAt(0);
        }
        
        _savePreferences();
      });
    } catch (e) {
      setState(() {
        _output = "Error";
      });
    }
  }
  
  @override
  void dispose() {
    _premiumTimer?.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              setState(() {
                _isHistoryPanelOpen = true;
                _isToolsPanelOpen = false;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Display area
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.bottomRight,
                  child: Text(
                    _output,
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              
              // Calculator buttons
              Expanded(
                flex: 3,
                child: GridView.count(
                  crossAxisCount: 4,
                  padding: const EdgeInsets.all(8),
                  childAspectRatio: 1.2,
                  children: [
                    _buildButton("C", Colors.red),
                    _buildButton("%", Colors.blue),
                    _buildButton("⌫", Colors.blue),
                    _buildButton("÷", Colors.blue),
                    _buildButton("7"),
                    _buildButton("8"),
                    _buildButton("9"),
                    _buildButton("×", Colors.blue),
                    _buildButton("4"),
                    _buildButton("5"),
                    _buildButton("6"),
                    _buildButton("-", Colors.blue),
                    _buildButton("1"),
                    _buildButton("2"),
                    _buildButton("3"),
                    _buildButton("+", Colors.blue),
                    _buildButton("0"),
                    _buildButton("."),
                    _buildButton("=", Colors.green),
                  ],
                ),
              ),
              
              // Banner ad
              if (_isBannerAdReady && !_isPremium)
                Container(
                  height: 50,
                  alignment: Alignment.center,
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
          
          // History panel (from left)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: _isHistoryPanelOpen ? 0 : -MediaQuery.of(context).size.width * 0.8,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.8,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "History",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _isHistoryPanelOpen = false;
                          });
                        },
                      ),
                    ],
                  ),
                  
                  const Divider(),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_history[index]),
                        );
                      },
                    ),
                  ),
                  
                  if (!_isPremium)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Center(
                        child: ElevatedButton(
                          onPressed: _showRewardedAd,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text("Watch Ad for Unlimited History (24hrs)"),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Tools panel (from right)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            right: _isToolsPanelOpen ? 0 : -MediaQuery.of(context).size.width * 0.7,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.7,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Premium Tools",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isPremium ? Colors.green : Colors.grey,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _isToolsPanelOpen = false;
                          });
                        },
                      ),
                    ],
                  ),
                  
                  const Divider(),
                  
                  if (_isPremium && _premiumUntil != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        "Premium Time: ${_premiumTimeLeft.inMinutes}m ${_premiumTimeLeft.inSeconds.remainder(60)}s",
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    childAspectRatio: 1.5,
                    children: [
                      _buildAdvancedButton("sin", _isPremium),
                      _buildAdvancedButton("cos", _isPremium),
                      _buildAdvancedButton("tan", _isPremium),
                      _buildAdvancedButton("log2", _isPremium),
                      _buildAdvancedButton("log10", _isPremium),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  if (!_isPremium)
                    Center(
                      child: ElevatedButton(
                        onPressed: _showRewardedAd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text("Watch Ad for Premium Access (1hr)"),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Transparent handle for tools panel
          if (!_isToolsPanelOpen)
            Positioned(
              right: 0,
              top: MediaQuery.of(context).size.height / 2 - 30,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isToolsPanelOpen = true;
                    _isHistoryPanelOpen = false;
                  });
                },
                child: Container(
                  width: 20,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                  child: const Icon(Icons.chevron_left, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildButton(String text, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: () => _buttonPressed(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.grey[200],
          foregroundColor: color != null ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
  
  Widget _buildAdvancedButton(String text, bool isEnabled) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: isEnabled ? () => _advancedFunction(text) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? Colors.blue : Colors.grey[300],
          foregroundColor: isEnabled ? Colors.white : Colors.grey[500],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
