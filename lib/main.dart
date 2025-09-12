// Full Dart file — copy & paste into your project (main.dart)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';

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

  void _toggleTheme() => setState(() => _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);

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

// ----------------------
// Calculator Home
// ----------------------
class CalculatorHome extends StatefulWidget {
  final VoidCallback toggleTheme;
  const CalculatorHome({super.key, required this.toggleTheme});

  @override
  State<CalculatorHome> createState() => _CalculatorHomeState();
}

class _CalculatorHomeState extends State<CalculatorHome> {
  // Calculator state
  String _expression = "";
  String _result = "0";
  final List<String> _history = [];
  double _memory = 0;

  // Ads & premium
  RewardedAd? _rewardedAd;
  bool _isRewardedReady = false;
  DateTime? _premiumUntil;

  // Panel (right-side scientific panel)
  bool _panelOpen = false;
  late double _panelWidth;
  late double _screenWidth;
  late double _screenHeight;
  // draggable handle - used for UX (tap/drag)
  bool _isDraggingHandle = false;
  double _dragStartX = 0.0;
  double _panelStartOffset = 0.0; // 0 = closed, 1 = open

  // Banner Ads (optional)
  BannerAd? _topBanner;
  BannerAd? _bottomBanner;
  bool _isTopBannerLoaded = false;
  bool _isBottomBannerLoaded = false;

  // Auth listener
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
      // reload user-specific history & premium when user changes
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
    super.dispose();
  }

  // ----------------------
  // History (per-user)
  // ----------------------
  String _historyKey() {
    final id = _user?.uid ?? 'guest';
    return 'calc_history_$id';
  }

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

  // ----------------------
  // Premium persistence
  // ----------------------
  String _premiumKey() {
    final id = _user?.uid ?? 'guest';
    return 'premium_until_$id';
  }

  Future<void> _loadPremiumForUser() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_premiumKey());
    if (millis != null) {
      setState(() {
        _premiumUntil = DateTime.fromMillisecondsSinceEpoch(millis);
      });
    } else {
      setState(() => _premiumUntil = null);
    }
  }

  Future<void> _savePremiumForUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (_premiumUntil != null) {
      await prefs.setInt(_premiumKey(), _premiumUntil!.millisecondsSinceEpoch);
    } else {
      await prefs.remove(_premiumKey());
    }
  }

  bool get _isPremium => _premiumUntil != null && DateTime.now().isBefore(_premiumUntil!);

  // ----------------------
  // Rewarded ad (unlock premium 1hr)
  // ----------------------
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: RewardedAd.testAdUnitId,
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
          // try again later (not aggressive)
          Future.delayed(const Duration(seconds: 15), _loadRewardedAd);
        },
      ),
    );
  }

  Future<void> _showRewardedUnlock() async {
    if (!_isRewardedReady || _rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reward ad not ready. Try later.')));
      return;
    }
    _rewardedAd!.show(onUserEarnedReward: (ad, reward) async {
      setState(() {
        _premiumUntil = DateTime.now().add(const Duration(hours: 1));
      });
      await _savePremiumForUser();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scientific tools unlocked for 1 hour.')));
    });
    _rewardedAd = null;
    _isRewardedReady = false;
  }

  // ----------------------
  // Banner helpers
  // ----------------------
  void _loadTopBanner() {
    _topBanner = BannerAd(
      adUnitId: BannerAd.testAdUnitId,
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
      adUnitId: BannerAd.testAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBottomBannerLoaded = true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  // ----------------------
  // Calculator logic
  // ----------------------
  void _onPressed(String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (value == "C") {
        _expression = "";
        _result = "0";
      } else if (value == "=") {
        _calculate();
      } else {
        _expression += value;
      }
    });
  }

  void _calculate() {
    try {
      // allow ×/÷ and common functions — translate to math_expressions syntax
      final input = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      Parser p = Parser();
      Expression exp = p.parse(input);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      setState(() {
        _result = eval.toString();
        _history.insert(0, "$_expression = $_result");
        if (_history.length > 50) _history.removeLast();
      });
      _saveHistory();
      _expression = "";
    } catch (e) {
      setState(() => _result = "Error");
    }
  }

  void _copyResult() {
    Clipboard.setData(ClipboardData(text: _result));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Result copied to clipboard")));
  }

  void _memoryAction(String action) {
    double current = double.tryParse(_result) ?? 0;
    setState(() {
      if (action == "M+") {
        _memory += current;
      } else if (action == "M-") {
        _memory -= current;
      } else if (action == "MR") {
        _expression += _memory.toString();
      } else if (action == "MC") {
        _memory = 0;
      }
    });
  }

  void _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey());
    setState(() {
      _history.clear();
    });
  }

  // ----------------------
  // Auth helpers (email + google)
  // ----------------------
  Future<void> _signInWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed in')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
    }
  }

  Future<void> _signUpWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created & signed in')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign up failed: $e')));
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // user cancelled
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed in with Google')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign in failed: $e')));
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out')));
  }

  // ----------------------
  // Panel open/close (drag/tap handle)
  // ----------------------
  void _togglePanel() {
    setState(() => _panelOpen = !_panelOpen);
  }

  void _onHandleDragStart(DragStartDetails d) {
    _isDraggingHandle = true;
    _dragStartX = d.globalPosition.dx;
    _panelStartOffset = _panelOpen ? 1.0 : 0.0;
  }

  void _onHandleDragUpdate(DragUpdateDetails d) {
    // determine open fraction based on drag delta
    final dx = _dragStartX - d.globalPosition.dx; // drag to left to open
    final openFraction = (_panelStartOffset + dx / _panelWidth).clamp(0.0, 1.0);
    setState(() {
      _panelOpen = openFraction > 0.5;
    });
  }

  void _onHandleDragEnd(DragEndDetails d) {
    _isDraggingHandle = false;
  }

  // ----------------------
  // UI
  // ----------------------
  Widget _buildCalcButton(String v, {Color? color, VoidCallback? onTap, int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: InkWell(
          onTap: onTap ?? () => _onPressed(v),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color ?? Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(children: [_buildCalcButton("7"), _buildCalcButton("8"), _buildCalcButton("9"), _buildCalcButton("÷", color: Colors.orange)]),
        Row(children: [_buildCalcButton("4"), _buildCalcButton("5"), _buildCalcButton("6"), _buildCalcButton("×", color: Colors.orange)]),
        Row(children: [_buildCalcButton("1"), _buildCalcButton("2"), _buildCalcButton("3"), _buildCalcButton("-", color: Colors.orange)]),
        Row(children: [_buildCalcButton("0"), _buildCalcButton("."), _buildCalcButton("C", color: Colors.red), _buildCalcButton("+", color: Colors.orange)]),
        Row(children: [_buildCalcButton("=", color: Colors.green, flex: 1)]),
        Row(children: [
          _buildCalcButton("M+", onTap: () => _memoryAction("M+")),
          _buildCalcButton("M-", onTap: () => _memoryAction("M-")),
          _buildCalcButton("MR", onTap: () => _memoryAction("MR")),
          _buildCalcButton("MC", onTap: () => _memoryAction("MC")),
        ]),
      ],
    );
  }

  // Scientific tools panel content (locked if not signed in)
  Widget _scientificPanelContent() {
    final signedIn = _user != null;
    return Container(
      height: _screenHeight * 0.5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        child: signedIn
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Scientific Tools", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(onPressed: () => setState(() => _expression += "sin("), child: const Text("sin(")),
                      ElevatedButton(onPressed: () => setState(() => _expression += "cos("), child: const Text("cos(")),
                      ElevatedButton(onPressed: () => setState(() => _expression += "tan("), child: const Text("tan(")),
                      ElevatedButton(onPressed: () => setState(() => _expression += "log("), child: const Text("log(")),
                      ElevatedButton(onPressed: () => setState(() => _expression += "^"), child: const Text("^")),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isPremium)
                    const Text("Premium active — tools unlocked", style: TextStyle(color: Colors.green))
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Unlock premium tools:", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Row(children: [
                          ElevatedButton.icon(onPressed: () async {
                            if (_user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must sign in to get premium access.')));
                              return;
                            }
                            await _showRewardedUnlock();
                          }, icon: const Icon(Icons.play_circle_fill), label: const Text("Watch Ad (1hr)")),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment flow not implemented (placeholder).')));
                          }, icon: const Icon(Icons.payment), label: const Text("Buy")),
                        ])
                      ],
                    ),
                  const Spacer(),
                  Text("Signed in as: ${_user?.email ?? '—'}", style: const TextStyle(fontSize: 12)),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 8),
                    const Text("Scientific tools require an account", textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuthScreen(onDone: () {
                        // after auth, reload history & premium
                        _loadHistory();
                        _loadPremiumForUser();
                        Navigator.pop(context);
                      }))),
                      child: const Text("Sign In / Sign Up"),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ----------------------
  // Build main Scaffold
  // ----------------------
  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _panelWidth = _screenWidth * 0.56; // panel width ~56% of screen
    final panelHeight = _screenHeight * 0.5; // cut 25% top and bottom (total 50% shorter)

    final panelRightClosedOffset = -_panelWidth + 36; // show small edge for handle (36 px)
    final panelRightOpenOffset = 0.0;

    final panelRight = _panelOpen ? panelRightOpenOffset : panelRightClosedOffset;

    return Scaffold(
      appBar: AppBar(
        title: Text('QuickCalc ${_user != null ? "- ${_user!.email}" : ""}'),
        actions: [
          IconButton(icon: const Icon(Icons.history), onPressed: _showHistoryModal),
          IconButton(icon: const Icon(Icons.brightness_6), onPressed: widget.toggleTheme),
          if (_user != null)
            IconButton(icon: const Icon(Icons.logout), onPressed: _signOut)
          else
            IconButton(
                icon: const Icon(Icons.person),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => AuthScreen(onDone: () {
                        _loadHistory();
                        _loadPremiumForUser();
                        Navigator.pop(context);
                      })));
                }),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isTopBannerLoaded && _topBanner != null)
                SizedBox(width: _topBanner!.size.width.toDouble(), height: _topBanner!.size.height.toDouble(), child: AdWidget(ad: _topBanner!)),
              Expanded(
                child: GestureDetector(
                  onLongPress: _copyResult,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.bottomRight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: Text(_expression, style: const TextStyle(fontSize: 24), textAlign: TextAlign.right),
                        ),
                        const SizedBox(height: 10),
                        Text(_result, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(icon: const Icon(Icons.copy), onPressed: _copyResult),
                            IconButton(icon: const Icon(Icons.menu), onPressed: () {
                              // open settings: includes history clear, sign in/out, premium status
                              showModalBottomSheet(context: context, builder: (_) => _settingsSheet());
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildKeypad(),
              ),
              if (_isBottomBannerLoaded && _bottomBanner != null)
                SizedBox(width: _bottomBanner!.size.width.toDouble(), height: _bottomBanner!.size.height.toDouble(), child: AdWidget(ad: _bottomBanner!)),
            ],
          ),

          // Right-hand scientific panel (positioned)
          Positioned(
            top: (_screenHeight - panelHeight) / 2,
            right: panelRight,
            child: GestureDetector(
              onHorizontalDragStart: _onHandleDragStart,
              onHorizontalDragUpdate: _onHandleDragUpdate,
              onHorizontalDragEnd: _onHandleDragEnd,
              child: Row(
                children: [
                  // Panel body (with curved left edge)
                  SizedBox(
                    width: _panelWidth,
                    height: panelHeight,
                    child: _scientificPanelContent(),
                  ),
                  // Handle (small circular button visible even when closed)
                  Container(
                    width: 36,
                    height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                    ),
                    child: GestureDetector(
                      onTap: _togglePanel,
                      child: const Icon(Icons.chevron_left, color: Colors.white),
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

  // Settings sheet
  Widget _settingsSheet() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: const Text('Account'), subtitle: Text(_user?.email ?? 'Not signed in')),
          if (_user == null)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign In / Sign Up'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuthScreen(onDone: () {
                    _loadHistory();
                    _loadPremiumForUser();
                    Navigator.pop(context);
                  }))),
            )
          else
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                await _signOut();
                Navigator.pop(context);
              },
            ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Clear History'),
            onTap: () {
              _clearHistory();
              Navigator.pop(context);
            },
          ),
          Divider(),
          ListTile(
            leading: const Icon(Icons.star),
            title: const Text('Premium Status'),
            subtitle: Text(_isPremium ? 'Premium until ${_premiumUntil!}' : 'Not premium'),
          ),
          if (!_isPremium && _user != null)
            ListTile(
              leading: const Icon(Icons.play_circle),
              title: const Text('Unlock Premium (watch ad)'),
              onTap: () {
                Navigator.pop(context);
                _showRewardedUnlock();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(padding: EdgeInsets.all(12), child: Text('Calculation History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              if (_history.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('No history yet'))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) => ListTile(title: Text(_history[index])),
                  ),
                ),
              TextButton(onPressed: _clearHistory, child: const Text('Clear History')),
            ],
          ),
        );
      },
    );
  }
}

// ----------------------
// Authentication screen (email + google)
// ----------------------
class AuthScreen extends StatefulWidget {
  final VoidCallback? onDone;
  const AuthScreen({super.key, this.onDone});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _emailCtrl.text.trim(), password: _passCtrl.text);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed in')));
      widget.onDone?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: _emailCtrl.text.trim(), password: _passCtrl.text);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created')));
      widget.onDone?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign up error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _loading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed in with Google')));
      widget.onDone?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign in failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: _passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
              const SizedBox(height: 20),
              if (_loading) const CircularProgressIndicator() else Column(children: [
                ElevatedButton(onPressed: _signIn, child: const Text('Sign In')),
                ElevatedButton(onPressed: _signUp, child: const Text('Sign Up')),
                const Divider(),
                ElevatedButton.icon(onPressed: _googleSignIn, icon: const Icon(Icons.login), label: const Text('Sign in with Google')),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
