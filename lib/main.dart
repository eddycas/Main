import 'dart:async';

import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:math_expressions/math_expressions.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';



Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await MobileAds.instance.initialize();

  runApp(const QuickCalcApp());

}



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



class CalculatorHome extends StatefulWidget {

  final VoidCallback toggleTheme;

  const CalculatorHome({super.key, required this.toggleTheme});



  @override

  State<CalculatorHome> createState() => _CalculatorHomeState();

}



class _CalculatorHomeState extends State<CalculatorHome> {

  String _expression = "";

  String _result = "0";

  final List<String> _history = [];

  double _memory = 0;



  RewardedAd? _rewardedAd;

  bool _isRewardedReady = false;

  DateTime? _premiumUntil;

  Timer? _premiumTimer;

  Duration _premiumRemaining = Duration.zero;



  bool _panelOpen = false;

  late double _panelWidth;

  late double _screenWidth;

  late double _screenHeight;

  bool _isDraggingHandle = false;

  double _dragStartX = 0.0;

  double _panelStartOffset = 0.0;



  BannerAd? _topBanner;

  BannerAd? _bottomBanner;

  bool _isTopBannerLoaded = false;

  bool _isBottomBannerLoaded = false;



  User? _user;

  StreamSubscription<User?>? _authSub;



  @override

  void initState() {

    super.initState();

    _user = FirebaseAuth.instance.currentUser;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {

      setState(() {

        _user = u;

      });

      _loadHistory();

      _loadPremiumForUser();

    });



    _loadHistory();

    _loadPremiumForUser();

    _loadRewardedAd();

    _loadTopBanner();

    _loadBottomBanner();

  }



  @override

  void dispose() {

    _rewardedAd?.dispose();

    _topBanner?.dispose();

    _bottomBanner?.dispose();

    _authSub?.cancel();

    _premiumTimer?.cancel();

    super.dispose();

  }



  // -------------------- HISTORY & PREMIUM --------------------



  String _historyKey() => 'calc_history_${_user?.uid ?? 'guest'}';



  Future<void> _loadHistory() async {

    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getStringList(_historyKey()) ?? [];

    setState(() {

      _history.clear();

      _history.addAll(saved);

    });

  }



  Future<void> _saveHistory() async {

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_historyKey(), _history);

  }



  String _premiumKey() => 'premium_until_${_user?.uid ?? 'guest'}';



  Future<void> _loadPremiumForUser() async {

    final prefs = await SharedPreferences.getInstance();

    final millis = prefs.getInt(_premiumKey());

    if (millis != null) {

      setState(() {

        _premiumUntil = DateTime.fromMillisecondsSinceEpoch(millis);

        _startPremiumTimer();

      });

    } else {

      setState(() {

        _premiumUntil = null;

        _premiumRemaining = Duration.zero;

      });

    }

  }



  Future<void> _savePremiumForUser() async {

    final prefs = await SharedPreferences.getInstance();

    if (_premiumUntil != null) {

      await prefs.setInt(

          _premiumKey(), _premiumUntil!.millisecondsSinceEpoch);

    } else {

      await prefs.remove(_premiumKey());

    }

  }



  bool get _isPremium =>

      _premiumUntil != null && DateTime.now().isBefore(_premiumUntil!);



  void _startPremiumTimer() {

    _premiumTimer?.cancel();

    if (_premiumUntil == null) return;



    _premiumTimer = Timer.periodic(const Duration(seconds: 1), (_) {

      final remaining = _premiumUntil!.difference(DateTime.now());

      if (remaining.isNegative) {

        _premiumTimer?.cancel();

        setState(() {

          _premiumUntil = null;

          _premiumRemaining = Duration.zero;

        });

      } else {

        setState(() {

          _premiumRemaining = remaining;

        });

      }

    });

  }



  // -------------------- AD LOAD --------------------



  void _loadRewardedAd() {

    RewardedAd.load(

      adUnitId: "ca-app-pub-3940256099942544/5224354917",

      request: const AdRequest(),

      rewardedAdLoadCallback: RewardedAdLoadCallback(

        onAdLoaded: (ad) {

          _rewardedAd = ad;

          _isRewardedReady = true;

          ad.fullScreenContentCallback = FullScreenContentCallback(

            onAdDismissedFullScreenContent: (ad) {

              ad.dispose();

              _isRewardedReady = false;

              _loadRewardedAd();

            },

            onAdFailedToShowFullScreenContent: (ad, error) {

              ad.dispose();

              _isRewardedReady = false;

              _loadRewardedAd();

            },

          );

        },

        onAdFailedToLoad: (err) {

          _isRewardedReady = false;

          Future.delayed(const Duration(seconds: 15), _loadRewardedAd);

        },

      ),

    );

  }



  void _loadTopBanner() {

    _topBanner = BannerAd(

      adUnitId: "ca-app-pub-3940256099942544/6300978111",

      size: AdSize.banner,

      request: const AdRequest(),

      listener: BannerAdListener(

        onAdLoaded: (_) => setState(() => _isTopBannerLoaded = true),

        onAdFailedToLoad: (ad, _) => ad.dispose(),

      ),

    )..load();

  }



  void _loadBottomBanner() {

    _bottomBanner = BannerAd(

      adUnitId: "ca-app-pub-3940256099942544/6300978111",

      size: AdSize.banner,

      request: const AdRequest(),

      listener: BannerAdListener(

        onAdLoaded: (_) => setState(() => _isBottomBannerLoaded = true),

        onAdFailedToLoad: (ad, _) => ad.dispose(),

      ),

    )..load();

  }



  Future<void> _showRewardedUnlock() async {

    if (!_isRewardedReady || _rewardedAd == null) {

      ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Reward ad not ready. Try again later.')));

      return;

    }

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) async {

      setState(() {

        _premiumUntil = DateTime.now().add(const Duration(hours: 1));

        _startPremiumTimer();

      });

      await _savePremiumForUser();

      ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('Scientific tools unlocked for 1 hour.')));

    });

    _rewardedAd = null;

    _isRewardedReady = false;

  }



// -------------------- CALCULATOR LOGIC --------------------



void _appendExpression(String value) => setState(() => _expression += value);



void _clearExpression() => setState(() {

  _expression = "";

  _result = "0";

});



void _deleteLast() {

  setState(() {

    if (_expression.isNotEmpty) {

      _expression = _expression.substring(0, _expression.length - 1);

    }

    if (_expression.isEmpty) {

      _result = "0";

    }

  });

}



void _evaluateExpression() {

  try {

    Parser p = Parser();

    Expression exp = p.parse(

      _expression.replaceAll('×', '*').replaceAll('÷', '/')

    );

    ContextModel cm = ContextModel();

    double eval = exp.evaluate(EvaluationType.REAL, cm);

    

    // Format result: remove trailing .0 for integers

    String formattedResult = eval % 1 == 0 ? eval.toInt().toString() : eval.toString();



    setState(() {

      _result = formattedResult;

      _history.insert(0, "$_expression = $formattedResult");

    });

    _saveHistory();

  } catch (_) {

    setState(() => _result = "Error");

  }

}

      

  // -------------------- PANEL --------------------

void _togglePanel() => setState(() => _panelOpen = !_panelOpen);



Widget _buildSlidePanel() {

  return Stack(

    children: [

      // Background blur when panel is open

      if (_panelOpen)

        GestureDetector(

          onTap: _togglePanel,

          child: AnimatedOpacity(

            duration: const Duration(milliseconds: 200),

            opacity: _panelOpen ? 1.0 : 0.0,

            child: BackdropFilter(

              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),

              child: Container(color: Colors.black.withOpacity(0.2)),

            ),

          ),

        ),



      // Sliding panel

      AnimatedPositioned(

        duration: const Duration(milliseconds: 200),

        right: _panelOpen ? 0 : -_panelWidth,

        top: _screenHeight * 0.125,

        height: _screenHeight * 0.75,

        width: _panelWidth,

        child: GestureDetector(

          onHorizontalDragUpdate: (details) {

            // Update panel position based on drag delta

            double newOffset = (_panelOpen ? 0 : -_panelWidth) + details.delta.dx;

            newOffset = newOffset.clamp(-_panelWidth, 0);

            setState(() {

              _panelOpen = newOffset >= -_panelWidth / 2;

            });

          },

          onHorizontalDragEnd: (details) {

            // Snap panel open or closed based on current position

            setState(() {

              _panelOpen = _panelOpen;

            });

          },

          child: ClipRRect(

            borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),

            child: Container(

              color: Colors.white,

              child: Column(

                children: [

                  ListTile(

                    title: const Text("Toggle Theme"),

                    onTap: widget.toggleTheme,

                  ),

                  if (_user == null)

                    ListTile(

                      title: const Text("Sign In"),

                      onTap: _signInWithGoogle,

                    )

                  else

                    ListTile(

                      title: Text("Signed in as ${_user!.email}"),

                      subtitle: const Text("Tap to sign out"),

                      onTap: _signOut,

                    ),

                  if (_user != null && !_isPremium)

                    ListTile(

                      title: const Text("Unlock Scientific Tools (1hr)"),

                      subtitle: Text(_isRewardedReady

                          ? "Watch ad to unlock"

                          : "Ad loading..."),

                      enabled: _isRewardedReady,

                      onTap: _showRewardedUnlock,

                    ),

                  if (_isPremium)

                    ListTile(

                      title: const Text("Scientific Tools Unlocked"),

                      subtitle: Text(

                          "Time remaining: ${_premiumRemaining.inMinutes}:${(_premiumRemaining.inSeconds % 60).toString().padLeft(2, '0')}"),

                    ),

                  const Divider(),

                  Expanded(

                    child: ListView(

                      children:

                          _history.map((h) => ListTile(title: Text(h))).toList(),

                    ),

                  ),

                ],

              ),

            ),

          ),

        ),

      ),



      // Drag handle

      Positioned(

        right: _panelOpen ? _panelWidth - 20 : 0,

        top: _screenHeight / 2 - 40,

        child: GestureDetector(

          onTap: _togglePanel,

          onHorizontalDragUpdate: (d) {

            double delta = d.delta.dx;

            setState(() {

              if (_panelOpen) {

                if (delta < -20) _panelOpen = false;

              } else {

                if (delta > 20) _panelOpen = true;

              }

            });

          },

          child: Container(

            width: 20,

            height: 80,

            decoration: BoxDecoration(

              color: Colors.blueGrey,

              borderRadius: BorderRadius.circular(10),

            ),

          ),

        ),

      ),

    ],

  );

}



  // -------------------- GOOGLE SIGN IN --------------------



  Future<void> _signInWithGoogle() async {

    try {

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(

        accessToken: googleAuth.accessToken,

        idToken: googleAuth.idToken,

      );

      await FirebaseAuth.instance.signInWithCredential(credential);

    } catch (_) {}

  }



  Future<void> _signOut() async {

    await FirebaseAuth.instance.signOut();

    await GoogleSignIn().signOut();

  }

}
