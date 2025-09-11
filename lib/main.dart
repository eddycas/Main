import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:firebase_analytics/observer.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:math_expressions/math_expressions.dart';

import 'package:device_info_plus/device_info_plus.dart';

import 'firebase_options.dart';



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

        inputDecorationTheme: const InputDecorationTheme(

          filled: true,

          fillColor: Colors.white10,

          border: OutlineInputBorder(),

        ),

      ),

      navigatorObservers: [observer],

      home: const SignInScreen(),

    );

  }

}



// ✅ Sign-In Screen (Email + Google)

class SignInScreen extends StatefulWidget {

  const SignInScreen({super.key});



  @override

  State<SignInScreen> createState() => _SignInScreenState();

}



class _SignInScreenState extends State<SignInScreen> {

  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;



  Future<void> _signInWithEmail() async {

    setState(() => _isLoading = true);

    try {

      UserCredential user = await FirebaseAuth.instance

          .signInWithEmailAndPassword(

        email: emailController.text.trim(),

        password: passwordController.text.trim(),

      );

      _navigateToCalculator(user.user);

    } catch (e) {

      _showError("Email sign-in failed: $e");

    }

    setState(() => _isLoading = false);

  }



  Future<void> _signUpWithEmail() async {

    setState(() => _isLoading = true);

    try {

      UserCredential user = await FirebaseAuth.instance

          .createUserWithEmailAndPassword(

        email: emailController.text.trim(),

        password: passwordController.text.trim(),

      );

      _navigateToCalculator(user.user);

    } catch (e) {

      _showError("Email sign-up failed: $e");

    }

    setState(() => _isLoading = false);

  }



  Future<void> _signInWithGoogle() async {

    try {

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =

          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(

        accessToken: googleAuth.accessToken,

        idToken: googleAuth.idToken,

      );

      UserCredential user =

          await FirebaseAuth.instance.signInWithCredential(credential);

      _navigateToCalculator(user.user);

    } catch (e) {

      _showError("Google sign-in failed: $e");

    }

  }



  void _navigateToCalculator(User? user) {

    if (user != null) {

      Navigator.pushReplacement(

        context,

        MaterialPageRoute(builder: (_) => CalculatorScreen(user: user)),

      );

    }

  }



  void _showError(String message) {

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(

      content: Text(message),

      backgroundColor: Colors.red,

    ));

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      body: Center(

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(24.0),

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Text("Quickcalc Login",

                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),

              const SizedBox(height: 20),

              TextField(

                controller: emailController,

                decoration: const InputDecoration(labelText: "Email"),

              ),

              const SizedBox(height: 12),

              TextField(

                controller: passwordController,

                decoration: const InputDecoration(labelText: "Password"),

                obscureText: true,

              ),

              const SizedBox(height: 20),

              _isLoading

                  ? const CircularProgressIndicator()

                  : Column(

                      children: [

                        ElevatedButton(

                          onPressed: _signInWithEmail,

                          child: const Text("Sign In"),

                        ),

                        ElevatedButton(

                          onPressed: _signUpWithEmail,

                          child: const Text("Sign Up"),

                        ),

                        const Divider(height: 30),

                        ElevatedButton.icon(

                          onPressed: _signInWithGoogle,

                          icon: const Icon(Icons.login),

                          label: const Text("Sign In with Google"),

                          style: ElevatedButton.styleFrom(

                            backgroundColor: Colors.redAccent,

                          ),

                        ),

                      ],

                    ),

            ],

          ),

        ),

      ),

    );

  }

}



// ✅ Calculator Screen

class CalculatorScreen extends StatefulWidget {

  final User user;

  const CalculatorScreen({super.key, required this.user});



  @override

  State<CalculatorScreen> createState() => _CalculatorScreenState();

}



class _CalculatorScreenState extends State<CalculatorScreen> {

  String _expression = "";

  String _result = "";

  int _calculationCount = 0;

  final List<String> _history = [];



  late BannerAd _topBannerAd;

  late BannerAd _bottomBannerAd;

  bool _isTopBannerLoaded = false;

  bool _isBottomBannerLoaded = false;



  InterstitialAd? _interstitialAd;

  RewardedAd? _rewardedAd;

  bool _isInterstitialReady = false;

  bool _isRewardedReady = false;



  String? deviceInfo = "";

  DateTime? premiumUntil;



  @override

  void initState() {

    super.initState();

    _loadTopBanner();

    _loadBottomBanner();

    _loadInterstitialAd();

    _loadRewardedAd();

    _getDeviceInfo();

  }



  Future<void> _getDeviceInfo() async {

    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

    if (Theme.of(context).platform == TargetPlatform.android) {

      AndroidDeviceInfo android = await deviceInfoPlugin.androidInfo;

      deviceInfo = "${android.manufacturer} ${android.model}";

    } else {

      IosDeviceInfo ios = await deviceInfoPlugin.iosInfo;

      deviceInfo = "${ios.name} ${ios.model}";

    }

  }



  bool get _isPremium =>

      premiumUntil != null && DateTime.now().isBefore(premiumUntil!);

  

// ============================

  // Calculator Button Logic

  // ============================

  void _onButtonPressed(String value) {

    setState(() {

      if (value == "C") {

        _expression = "";

        _result = "";

      } else if (value == "=") {

        try {

          Parser p = Parser();

          Expression exp =

              p.parse(_expression.replaceAll("×", "*").replaceAll("÷", "/"));

          ContextModel cm = ContextModel();

          double eval = exp.evaluate(EvaluationType.REAL, cm);

          _result = eval == eval.toInt() ? eval.toInt().toString() : eval.toString();

          _history.add("$_expression = $_result");

          _calculationCount++;

          _checkRewardedAd();

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

  // Ads Loading

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

          debugPrint("Top banner failed: $error");

        },

        onAdOpened: (_) => _logAdClick("top_banner", revenue: 0.05),

      ),

    )..load();

  }



  void _loadBottomBanner() {

    _bottomBannerAd = BannerAd(

      adUnitId: 'ca-app-pub-3940256099942544/6300978111',

      size: AdSize.banner,

      request: const AdRequest(),

      listener: BannerAdListener(

        onAdLoaded: (_) => setState(() => _isBottomBannerLoaded = true),

        onAdFailedToLoad: (ad, error) {

          ad.dispose();

          debugPrint("Bottom banner failed: $error");

        },

        onAdOpened: (_) => _logAdClick("bottom_banner", revenue: 0.05),

      ),

    )..load();

  }



  // ============================

  // Interstitial & Rewarded

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

              _loadInterstitialAd();

            },

          );

        },

        onAdFailedToLoad: (error) => debugPrint("Interstitial failed: $error"),

      ),

    );

  }



  void _loadRewardedAd() {

    RewardedAd.load(

      adUnitId: 'ca-app-pub-3940256099942544/5224354917',

      request: const AdRequest(),

      rewardedAdLoadCallback: RewardedAdLoadCallback(

        onAdLoaded: (ad) {

          _rewardedAd = ad;

          _isRewardedReady = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(

            onAdDismissedFullScreenContent: (_) {

              _rewardedAd = null;

              _isRewardedReady = false;

              _loadRewardedAd();

            },

          );

        },

        onAdFailedToLoad: (error) => debugPrint("Rewarded failed: $error"),

      ),

    );

  }



  void _checkRewardedAd() {

    if (_calculationCount >= 5 && _isRewardedReady && _rewardedAd != null) {

      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {

        premiumUntil = DateTime.now().add(const Duration(hours: 1));

      });

      _isRewardedReady = false;

      _rewardedAd = null;

    }

  }



  void _logAdClick(String adType, {double revenue = 0.0}) {

    debugPrint("Ad clicked: $adType, revenue: $revenue, user: ${widget.user.email}");

  }



// ============================

  // Build Calculator Buttons

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



  // ============================

  // Build UI

  // ============================

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text("QuickCalc"),

        backgroundColor: Colors.black,

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

          IconButton(

            icon: const Icon(Icons.settings),

            onPressed: () => _showSettingsScreen(),

          ),

        ],

      ),

      body: Column(

        children: [

          if (_isTopBannerLoaded)

            SizedBox(

              height: _topBannerAd.size.height.toDouble(),

              width: _topBannerAd.size.width.toDouble(),

              child: AdWidget(ad: _topBannerAd),

            ),

          Expanded(

            child: Container(

              padding: const EdgeInsets.all(20),

              alignment: Alignment.bottomRight,

              child: Column(

                mainAxisAlignment: MainAxisAlignment.end,

                crossAxisAlignment: CrossAxisAlignment.end,

                children: [

                  Text(_expression,

                      style: const TextStyle(fontSize: 32, color: Colors.white70)),

                  const SizedBox(height: 10),

                  Text(_result,

                      style: const TextStyle(fontSize: 48, color: Colors.white)),

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

    );

  }



  // ============================

  // Settings & History Navigation

  // ============================

  void _showSettingsScreen() {

    Navigator.push(

      context,

      MaterialPageRoute(builder: (_) => const SettingsScreen()),

    );

  }

}



// ============================

// History Screen

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

// Settings Screen

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
