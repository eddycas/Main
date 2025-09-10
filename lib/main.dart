​// ============================

// PART 1: MAIN SETUP & SIGN-IN SCREEN (Updated)

// ============================

import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:firebase_analytics/observer.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:device_info_plus/device_info_plus.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'dart:async';

import 'package:math_expressions/math_expressions.dart';

import 'firebase_options.dart';

import 'auth_service.dart';



void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(

    options: DefaultFirebaseOptions.currentPlatform,

  );

  await MobileAds.instance.initialize();

  runApp(const MyApp());

}



class MyApp extends StatelessWidget {

  const MyApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver observer =

      FirebaseAnalyticsObserver(analytics: analytics);



  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      title: 'Quickcalc',

      theme: ThemeData.dark().copyWith(

        scaffoldBackgroundColor: Colors.black,

      ),

      navigatorObservers: [observer],

      home: const SignInScreen(),

    );

  }

}



// ============================

// ✅ Sign-In Screen

// ============================

class SignInScreen extends StatefulWidget {

  const SignInScreen({super.key});

  @override

  _SignInScreenState createState() => _SignInScreenState();

}



class _SignInScreenState extends State<SignInScreen> {

  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;



  void _signIn() async {

    setState(() => _isLoading = true);

    try {

      UserCredential userCredential = await AuthService.signInUser(

          emailController.text.trim(), passwordController.text.trim());

      debugPrint('Signed in as: ${userCredential.user?.email}');

      Navigator.pushReplacement(

        context,

        MaterialPageRoute(builder: (_) => const CalculatorScreen()),

      );

    } catch (e) {

      debugPrint('Sign-in failed: $e');

      ScaffoldMessenger.of(context)

          .showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));

    }

    setState(() => _isLoading = false);

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      body: Center(

        child: Padding(

          padding: const EdgeInsets.all(24.0),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              TextField(

                controller: emailController,

                decoration: const InputDecoration(labelText: 'Email'),

              ),

              const SizedBox(height: 12),

              TextField(

                controller: passwordController,

                decoration: const InputDecoration(labelText: 'Password'),

                obscureText: true,

              ),

              const SizedBox(height: 20),

              _isLoading

                  ? const CircularProgressIndicator()

                  : ElevatedButton(

                      onPressed: _signIn,

                      child: const Text('Sign In'),

                    ),

            ],

          ),

        ),

      ),

    );

  }

}



// ============================

// PART 2: CALCULATOR SCREEN SETUP & STATE VARIABLES (Partial)

// ============================

class CalculatorScreen extends StatefulWidget {

  const CalculatorScreen({super.key});

  @override

  _CalculatorScreenState createState() => _CalculatorScreenState();

}



class _CalculatorScreenState extends State<CalculatorScreen> {

  // ============================

  // Calculator state

  // ============================

  String _expression = "";

  String _result = "";

  int _calculationCount = 0;

  final List<String> _history = [];



  // ============================

  // Ads

  // ============================

  late BannerAd _topBannerAd;

  late BannerAd _bottomBannerAd;

  InterstitialAd? _interstitialAd;

  RewardedAd? _rewardedAd;

  bool _isTopBannerLoaded = false;

  bool _isBottomBannerLoaded = false;

  bool _isInterstitialReady = false;

  bool _isRewardedReady = false;



  // ============================

  // User / Device info

  // ============================

  User? currentUser;

  String deviceInfo = "unknown";

  Map<String, double> adRevenueByUser = {};

  double revenueLast24h = 0;

  double revenueLast7d = 0;

  double revenueLast30d = 0;



  // ============================

  // Premium / Reward tracking

  // ============================

  bool _hasPremium = false;

  DateTime? _lastRewardAdTime;



  // ============================

  // Timers

  // ============================

  Timer? _idleTimer;

  DateTime? _lastInterstitialTime;

  DateTime? _lastButtonPress;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      _initializeUserAndDevice();

      _loadPremium();

    });

    _loadTopBanner();

    _loadBottomBanner();

    _loadInterstitialAd();

    _loadRewardedAd();

    _startIdleTimer();

  }



  // ============================

  // Initialize user and device info

  // ============================

  Future<void> _initializeUserAndDevice() async {

    currentUser = FirebaseAuth.instance.currentUser;

    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

    if (Theme.of(context).platform == TargetPlatform.android) {

      AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;

      deviceInfo = "${androidInfo.manufacturer} ${androidInfo.model}";

    } else {

      IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;

      deviceInfo = "${iosInfo.name} ${iosInfo.model}";

    }

    debugPrint("Device info: $deviceInfo");

  }



  // ============================

  // Persistent premium

  // ============================

  Future<void> _loadPremium() async {

    final prefs = await SharedPreferences.getInstance();

    _hasPremium = prefs.getBool('hasPremium') ?? false;

    int? lastRewardMillis = prefs.getInt('lastRewardTime');

    if (lastRewardMillis != null) {

      _lastRewardAdTime =

          DateTime.fromMillisecondsSinceEpoch(lastRewardMillis);

      // Expire premium after 1 hour

      if (DateTime.now().difference(_lastRewardAdTime!) >

          const Duration(hours: 1)) {

        _hasPremium = false;

      }

    }

    setState(() {});

  }



  Future<void> _savePremium() async {

    final prefs = await SharedPreferences.getInstance();

    prefs.setBool('hasPremium', _hasPremium);

    if (_lastRewardAdTime != null) {

      prefs.setInt(

          'lastRewardTime', _lastRewardAdTime!.millisecondsSinceEpoch);

    }

  }



  // ============================

  // Update last button press (for idle ad logic)

  // ============================

  void _updateLastButtonPress() {

    _lastButtonPress = DateTime.now();

  }

}



// ============================

// PART 3: ADS LOGIC & IDLE TIMER (Updated)

// ============================

extension AdHelpers on _CalculatorScreenState {

  // ============================

  // Log ad click / revenue

  // ============================

  void _logAdClick(String adType, {String? page, double revenue = 0.0}) async {

    if (currentUser != null) {

      final now = DateTime.now();

      final clickId = "${currentUser!.uid}_${now.millisecondsSinceEpoch}";

      // Track revenue per user

      adRevenueByUser[currentUser!.uid] =

          (adRevenueByUser[currentUser!.uid] ?? 0) + revenue;

      // Update last periods (simplified; can add persistent storage)

      revenueLast24h += revenue;

      revenueLast7d += revenue;

      revenueLast30d += revenue;



      // Firebase Analytics

      MyApp.analytics.logEvent(

        name: 'ad_clicked',

        parameters: {

          'click_id': clickId,

          'ad_type': adType,

          'page': page ?? 'calculator_screen',

          'user_email': currentUser!.email,

          'user_id': currentUser!.uid,

          'device': deviceInfo,

          'timestamp': now.toIso8601String(),

          'date': "${now.year}-${now.month}-${now.day}",

          'time': "${now.hour}:${now.minute}:${now.second}",

          'revenue': revenue,

        },

      );



      debugPrint(

          'Logged ad click: $adType by ${currentUser!.email} at ${now.toIso8601String()} (Revenue: $revenue)');

    }

  }



  // ============================

  // Idle Timer for Interstitial Ads

  // ============================

  void _startIdleTimer() {

    _idleTimer?.cancel();

    _idleTimer = Timer.periodic(const Duration(seconds: 1), (_) {

      if (_lastInterstitialTime == null ||

          DateTime.now().difference(_lastInterstitialTime!) >

              const Duration(minutes: 15)) {

        if (_lastButtonPress != null &&

            DateTime.now().difference(_lastButtonPress!) >

                const Duration(seconds: 20)) {

          _showInterstitialIfReady();

        }

      }

    });

  }



  // ============================

  // Load Top Banner

  // ============================

  void _loadTopBanner() {

    _topBannerAd = BannerAd(

      adUnitId: 'ca-app-pub-3940256099942544/6300978111',

      size: AdSize.banner,

      request: const AdRequest(),

      listener: BannerAdListener(

        onAdLoaded: (_) => setState(() => _isTopBannerLoaded = true),

        onAdFailedToLoad: (ad, error) {

          ad.dispose();

          debugPrint('Top banner failed: $error');

        },

        onAdOpened: (_) => _logAdClick("top_banner", revenue: 0.05),

      ),

    )..load();

  }



  // ============================

  // Load Bottom Banner

  // ============================

  void _loadBottomBanner() {

    _bottomBannerAd = BannerAd(

      adUnitId: 'ca-app-pub-3940256099942544/6300978111',

      size: AdSize.banner,

      request: const AdRequest(),

      listener: BannerAdListener(

        onAdLoaded: (_) => setState(() => _isBottomBannerLoaded = true),

        onAdFailedToLoad: (ad, error) {

          ad.dispose();

          debugPrint('Bottom banner failed: $error');

        },

        onAdOpened: (_) => _logAdClick("bottom_banner", revenue: 0.05),

      ),

    )..load();

  }



  // ============================

  // Load Interstitial Ad

  // ============================

  void _loadInterstitialAd() {

    InterstitialAd.load(

      adUnitId: 'ca-app-pub-3940256099942544/1033173712',

      request: const AdRequest(),

      adLoadCallback: InterstitialAdLoadCallback(

        onAdLoaded: (ad) {

          _interstitialAd = ad;

          _isInterstitialReady = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(

            onAdShowedFullScreenContent: (_) =>

                _logAdClick("interstitial", revenue: 0.15),

            onAdDismissedFullScreenContent: (_) {

              _interstitialAd = null;

              _isInterstitialReady = false;

              _lastInterstitialTime = DateTime.now();

              _loadInterstitialAd(); // reload

            },

          );

        },

        onAdFailedToLoad: (error) => debugPrint('Interstitial failed: $error'),

      ),

    );

  }



  // ============================

  // Load Rewarded Ad

  // ============================

  void _loadRewardedAd() {

    RewardedAd.load(

      adUnitId: 'ca-app-pub-3940256099942544/5224354917',

      request: const AdRequest(),

      rewardedAdLoadCallback: RewardedAdLoadCallback(

        onAdLoaded: (ad) {

          _rewardedAd = ad;

          _isRewardedReady = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(

            onAdShowedFullScreenContent: (_) =>

                _logAdClick("rewarded", revenue: 0.2),

            onAdDismissedFullScreenContent: (_) {

              _rewardedAd = null;

              _isRewardedReady = false;

              _lastRewardAdTime = DateTime.now();

              _savePremium(); // persist premium state

              _loadRewardedAd(); // reload

            },

          );

        },

        onAdFailedToLoad: (error) => debugPrint('Rewarded failed: $error'),

      ),

    );

  }



  // ============================

  // Show Interstitial if ready

  // ============================

  void _showInterstitialIfReady() {

    if (_isInterstitialReady && _interstitialAd != null) {

      _interstitialAd!.show();

      _isInterstitialReady = false;

      _interstitialAd = null;

    }

  }



  // ============================

  // Show Rewarded Ad if eligible

  // ============================

  void _showRewardedIfEligible() {

    if (_calculationCount >= 5 &&

        (_lastRewardAdTime == null ||

            DateTime.now().difference(_lastRewardAdTime!) >

                const Duration(minutes: 30))) {

      if (_isRewardedReady && _rewardedAd != null) {

        _rewardedAd!.show(onUserEarnedReward: (ad, reward) {

          debugPrint(

              "User earned reward: ${reward.amount} ${reward.type}");

          _lastRewardAdTime = DateTime.now();

          _hasPremium = true;

          _savePremium();

        });

        _isRewardedReady = false;

        _rewardedAd = null;

      }

    }

  }

}



// ============================

// PART 4: CALCULATOR LOGIC, HISTORY, & PREMIUM

// ============================

extension CalculatorHelpers on _CalculatorScreenState {

  // ============================

  // Update last button press for idle timer

  // ============================

  void _updateLastButtonPress() {

    _lastButtonPress = DateTime.now();

  }



  // ============================

  // Calculator Button Logic

  // ============================

  void _onButtonPressed(String value) {

    _updateLastButtonPress(); // reset idle timer

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

          _result = eval == eval.toInt() ? eval.toInt().toString() : eval.toString();

          _history.add("$_expression = $_result");

          _calculationCount++;

          _showRewardedIfEligible();

          _saveHistory();

        } catch (e) {

          _result = "Error";

        }

      } else {

        _expression += value;

      }

    });

  }



  // ============================

  // Persistent History

  // ============================

  Future<void> _loadHistory() async {

    final prefs = await SharedPreferences.getInstance();

    _history.clear();

    _history.addAll(prefs.getStringList('calc_history') ?? []);

  }



  Future<void> _saveHistory() async {

    final prefs = await SharedPreferences.getInstance();

    prefs.setStringList('calc_history', _history);

  }



  // ============================

  // Persistent Premium Storage

  // ============================

  Future<void> _loadPremium() async {

    final prefs = await SharedPreferences.getInstance();

    _hasPremium = prefs.getBool('has_premium') ?? false;

  }



  Future<void> _savePremium() async {

    final prefs = await SharedPreferences.getInstance();

    prefs.setBool('has_premium', _hasPremium);

  }



  // ============================

  // Slide-Out Scientific Panel

  // ============================

  bool _isSciPanelOpen = false;

  void _toggleSciPanel() {

    if (_hasPremium) {

      setState(() => _isSciPanelOpen = !_isSciPanelOpen);

    } else {

      // Offer reward ad for temporary premium

      _showRewardForPremium();

    }

  }



  void _showRewardForPremium() {

    if (_isRewardedReady && _rewardedAd != null) {

      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {

        setState(() => _hasPremium = true);

        _lastRewardAdTime = DateTime.now();

        _savePremium();

        debugPrint("Premium granted for 1hr or session");

      });

    } else {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text("Rewarded ad not ready yet.")),

      );

    }

  }



  // ============================

  // Build Calculator Button Widget

  // ============================

  Widget _buildButton(String text, {Color color = Colors.white30}) {

    return Expanded(

      child: Padding(

        padding: const EdgeInsets.all(4.0),

        child: ElevatedButton(

          onPressed: () => _onButtonPressed(text),

          style: ElevatedButton.styleFrom(

            backgroundColor: color,

            shape: RoundedRectangleBorder(

              borderRadius: BorderRadius.circular(12),

            ),

            padding: const EdgeInsets.symmetric(vertical: 20),

          ),

          child: Text(text, style: const TextStyle(fontSize: 24)),

        ),

      ),

    );

  }

}



// ============================

// PART 5: BUILD METHOD & UI

// ============================

@override

Widget build(BuildContext context) {

  return Scaffold(

    appBar: AppBar(

      backgroundColor: Colors.black,

      title: const Text("Quickcalc"),

      leading: IconButton(

        icon: const Icon(Icons.settings),

        onPressed: _showSettingsScreen,

      ),

      actions: [

        IconButton(

          icon: const Icon(Icons.history),

          onPressed: () {

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

    body: Stack(

      children: [

        Column(

          children: [

            if (_isTopBannerLoaded)

              SizedBox(

                height: _topBannerAd.size.height.toDouble(),

                width: _topBannerAd.size.width.toDouble(),

                child: AdWidget(ad: _topBannerAd),

              ),

            Expanded(

              child: Container(

                alignment: Alignment.bottomRight,

                padding: const EdgeInsets.all(20),

                child: Column(

                  mainAxisAlignment: MainAxisAlignment.end,

                  crossAxisAlignment: CrossAxisAlignment.end,

                  children: [

                    Text(

                      _expression,

                      style: const TextStyle(fontSize: 32, color: Colors.white70),

                    ),

                    const SizedBox(height: 10),

                    Text(

                      _result,

                      style: const TextStyle(fontSize: 48, color: Colors.white),

                    ),

                  ],

                ),

              ),

            ),

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

            if (_isBottomBannerLoaded)

              SizedBox(

                height: _bottomBannerAd.size.height.toDouble(),

                width: _bottomBannerAd.size.width.toDouble(),

                child: AdWidget(ad: _bottomBannerAd),

              ),

          ],

        ),



        // ============================

        // Slide-Out Scientific Calculator

        // ============================

        Positioned(

          right: _isSciPanelOpen ? 0 : -MediaQuery.of(context).size.width / 2,

          top: MediaQuery.of(context).size.height / 4,

          height: MediaQuery.of(context).size.height / 2,

          width: MediaQuery.of(context).size.width / 2,

          child: Container(

            color: Colors.grey[900]?.withOpacity(0.95),

            child: Column(

              children: [

                Row(children: [

                  _buildButton("sin"),

                  _buildButton("cos"),

                  _buildButton("tan")

                ]),

                Row(children: [

                  _buildButton("log"),

                  _buildButton("ln"),

                  _buildButton("√")

                ]),

                Row(children: [

                  _buildButton("^"),

                  _buildButton("("),

                  _buildButton(")")

                ]),

              ],

            ),

          ),

        ),



        // Half-circle button to toggle scientific panel

        Positioned(

          right: 0,

          top: MediaQuery.of(context).size.height / 2 - 30,

          child: GestureDetector(

            onTap: _toggleSciPanel,

            child: Container(

              width: 60,

              height: 60,

              decoration: BoxDecoration(

                color: Colors.orange,

                borderRadius: const BorderRadius.only(

                  topLeft: Radius.circular(30),

                  bottomLeft: Radius.circular(30),

                ),

              ),

              child: const Icon(Icons.arrow_left, color: Colors.white),

            ),

          ),

        ),

      ],

    ),

  );

}



// ============================

// SETTINGS SCREEN NAVIGATION

// ============================

void _showSettingsScreen() {

  Navigator.push(

    context,

    MaterialPageRoute(builder: (_) => const SettingsScreen()),

  );

}



// ============================

// HISTORY SCREEN

// ============================

class HistoryScreen extends StatelessWidget {

  final List<String> history;

  const HistoryScreen({super.key, required this.history});

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text("History")),

      body: ListView.builder(

        itemCount: history.length,

        itemBuilder: (context, index) {

          return ListTile(title: Text(history[index]));

        },

      ),

    );

  }

}



// ============================

// SETTINGS SCREEN (Placeholder)

// ============================

class SettingsScreen extends StatelessWidget {

  const SettingsScreen({super.key});

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text("Settings")),

      body: const Center(child: Text("Settings go here")),

    );

  }

}
