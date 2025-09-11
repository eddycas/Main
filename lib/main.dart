import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:math_expressions/math_expressions.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';



void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await MobileAds.instance.initialize();

  runApp(const MyApp());

}



class MyApp extends StatefulWidget {

  const MyApp({super.key});

  @override

  State<MyApp> createState() => _MyAppState();

}



class _MyAppState extends State<MyApp> {

  ThemeMode _themeMode = ThemeMode.dark;



  void updateTheme(ThemeMode mode) => setState(() => _themeMode = mode);



  @override

  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: 'QuickCalc',

      themeMode: _themeMode,

      theme: ThemeData.light().copyWith(scaffoldBackgroundColor: Colors.white),

      darkTheme: ThemeData.dark().copyWith(

        scaffoldBackgroundColor: Colors.black,

        inputDecorationTheme: const InputDecorationTheme(

          filled: true,

          fillColor: Colors.white10,

          border: OutlineInputBorder(),

        ),

      ),

      home: const LandingScreen(),

    );

  }

}



class LandingScreen extends StatelessWidget {

  const LandingScreen({super.key});



  @override

  Widget build(BuildContext context) {

    return FutureBuilder<User?>(

      future: Future.value(FirebaseAuth.instance.currentUser),

      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {

          return const Scaffold(body: Center(child: CircularProgressIndicator()));

        } else {

          if (snapshot.hasData && snapshot.data != null) {

            return CalculatorScreen(user: snapshot.data!);

          } else {

            return SignInScreen();

          }

        }

      },

    );

  }

}



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

      UserCredential user = await FirebaseAuth.instance.signInWithEmailAndPassword(

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

      UserCredential user = await FirebaseAuth.instance.createUserWithEmailAndPassword(

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

      final GoogleSignInAuthentication? googleAuth = await googleUser.authentication;

      if (googleAuth?.accessToken == null || googleAuth?.idToken == null) {

        _showError("Google authentication failed.");

        return;

      }

      final credential = GoogleAuthProvider.credential(

        accessToken: googleAuth!.accessToken,

        idToken: googleAuth.idToken,

      );

      UserCredential user = await FirebaseAuth.instance.signInWithCredential(credential);

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

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text(message), backgroundColor: Colors.red),

    );

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

              const Text("QuickCalc Login", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),

              const SizedBox(height: 20),

              TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email")),

              const SizedBox(height: 12),

              TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Password"), obscureText: true),

              const SizedBox(height: 20),

              _isLoading

                  ? const CircularProgressIndicator()

                  : Column(

                      children: [

                        ElevatedButton(onPressed: _signInWithEmail, child: const Text("Sign In")),

                        ElevatedButton(onPressed: _signUpWithEmail, child: const Text("Sign Up")),

                        const Divider(height: 30),

                        ElevatedButton.icon(

                          onPressed: _signInWithGoogle,

                          icon: const Icon(Icons.login),

                          label: const Text("Sign In with Google"),

                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),

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

  DateTime? premiumUntil;



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

    _loadHistory();

    _loadTopBanner();

    _loadBottomBanner();

    _loadInterstitialAd();

    _loadRewardedAd();

  }



  @override

  void dispose() {

    _topBannerAd.dispose();

    _bottomBannerAd.dispose();

    _interstitialAd?.dispose();

    _rewardedAd?.dispose();

    super.dispose();

  }



  Future<void> _loadHistory() async {

    final prefs = await SharedPreferences.getInstance();

    _history.clear();

    _history.addAll(prefs.getStringList('calc_history') ?? []);

  }



  Future<void> _saveHistory() async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList('calc_history', _history);

  }



  bool get _isPremium => premiumUntil != null && DateTime.now().isBefore(premiumUntil!);



  void _onButtonPressed(String value) {

    setState(() {

      if (value == "C") {

        _expression = "";

        _result = "";

      } else if (value == "=") {

        try {

          Parser p = Parser();

          Expression exp = p.parse(_expression.replaceAll("×", "*").replaceAll("÷", "/"));

          ContextModel cm = ContextModel();

          double eval = exp.evaluate(EvaluationType.REAL, cm);

          _result = eval.isFinite

              ? (eval == eval.toInt() ? eval.toInt().toString() : eval.toString())

              : "Error";

          _history.add("$_expression = $_result");

          _calculationCount++;

          _checkRewardedAd();

          _saveHistory();

        } catch (_) {

          _result = "Error";

        }

      } else {

        _expression += value;

      }

    });

  }



  void _loadTopBanner() {

    _topBannerAd = BannerAd(

      adUnitId: 'ca-app-pub-3940256099942544/6300978111',

      size: AdSize.banner,

      request: const AdRequest(),

      listener: BannerAdListener(

        onAdLoaded: (_) => setState(() => _isTopBannerLoaded = true),

        onAdFailedToLoad: (ad, _) => ad.dispose(),

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

        onAdFailedToLoad: (ad, _) => ad.dispose(),

        onAdOpened: (_) => _logAdClick("bottom_banner", revenue: 0.05),

      ),

    )..load();

  }



  void _loadInterstitialAd() {

    InterstitialAd.load(

      adUnitId: 'ca-app-pub-3940256099942544/1033173712',

      request: const AdRequest(),

      adLoadCallback: InterstitialAdLoadCallback(

        onAdLoaded: (ad) {

          _interstitialAd = ad;

          _isInterstitialReady = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(

            onAdShowedFullScreenContent: (_) => _logAdClick("interstitial", revenue: 0.15),

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

      onAdFailedToLoad: (error) {

        debugPrint("Rewarded Ad failed: $error");

        _isRewardedReady = false;

      },

    ),

  );

}



void _checkRewardedAd() {

  if (_calculationCount % 10 == 0 && !_isPremium && _isRewardedReady) {

    _rewardedAd?.show(

      onUserEarnedReward: (ad, reward) {

        setState(() {

          premiumUntil = DateTime.now().add(const Duration(hours: 1));

        });

      },

    );

  }

}



void _logAdClick(String adType, {double revenue = 0}) {

  debugPrint("Ad clicked: $adType, revenue: $revenue");

}



Widget _buildButton(String text, {Color? color}) {

  return ElevatedButton(

    onPressed: () => _onButtonPressed(text),

    style: ElevatedButton.styleFrom(

      backgroundColor: color ?? Colors.blueGrey,

      minimumSize: const Size(70, 70),

    ),

    child: Text(text, style: const TextStyle(fontSize: 24)),

  );

}



@override

Widget build(BuildContext context) {

  return Scaffold(

    appBar: AppBar(

      title: Text("QuickCalc - ${widget.user.email}"),

      actions: [

        IconButton(

          icon: const Icon(Icons.logout),

          onPressed: () async {

            await FirebaseAuth.instance.signOut();

            Navigator.pushReplacement(

                context, MaterialPageRoute(builder: (_) => const LandingScreen()));

          },

        ),

      ],

    ),

    body: Column(

      children: [

        if (_isTopBannerLoaded) SizedBox(height: 50, child: AdWidget(ad: _topBannerAd)),

        Expanded(

          child: Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              Text(_expression, style: const TextStyle(fontSize: 32)),

              const SizedBox(height: 10),

              Text(_result, style: const TextStyle(fontSize: 28, color: Colors.greenAccent)),

              const SizedBox(height: 20),

              Wrap(

                spacing: 10,

                runSpacing: 10,

                children: [

                  ...["7","8","9","÷","4","5","6","×","1","2","3","-","0",".","=","+"].map(

                      (e) => _buildButton(e, color: e == "=" ? Colors.orange : null)),

                  _buildButton("C", color: Colors.red),

                ],

              ),

            ],

          ),

        ),

        if (_isBottomBannerLoaded) SizedBox(height: 50, child: AdWidget(ad: _bottomBannerAd)),

      ],

    ),

  );

}
