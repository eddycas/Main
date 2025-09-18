import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'premium_manager.dart';
import 'ads_manager.dart';
import 'calculator_logic.dart';
import 'calculator_keypad.dart';
import 'user_activity_logger.dart';
import 'developer_analytics.dart';

class CalculatorHome extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;
  const CalculatorHome({super.key, required this.toggleTheme, required this.themeMode});

  @override
  CalculatorHomeState createState() => CalculatorHomeState();
}

class CalculatorHomeState extends State<CalculatorHome> with WidgetsBindingObserver {
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
  bool isWatchingAd = false;

  // Counters for interstitial ad triggers
  int _calculationCounter = 0;
  int _panelInteractionCounter = 0;
  // Timer for PDF export cooldown
  DateTime? _lastExportAdTime;

  // PDF password
  static const String _pdfPassword = 'gush5+$:)#6gsj5#8+';

  late PremiumManager premiumManager;
  late AdsManager adsManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    premiumManager = PremiumManager();
    adsManager = AdsManager();
    _loadHistory();
    premiumManager.loadPremium();

    // Load all ads
    adsManager.loadTopBanner(onLoaded: () => setState(() => isTopBannerLoaded = true));
    adsManager.loadBottomBanner(onLoaded: () => setState(() => isBottomBannerLoaded = true));
    adsManager.loadRewardedAd(onLoaded: (ad) {
      setState(() {
        rewardedAd = ad;
        isRewardedReady = true;
      });
    });
    adsManager.loadInterstitial();

    // Load app open ad
    Future.delayed(const Duration(seconds: 2), () {
      adsManager.loadAppOpenAd();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        adsManager.showAppOpenAd();
      });
    }
  }

  void _maybeShowInterstitial() {
    if (adsManager.isInterstitialReady) {
      adsManager.showInterstitial();
      _calculationCounter = 0;
      _panelInteractionCounter = 0;
    } else {
      print("Interstitial not ready. Loading for next time.");
      adsManager.loadInterstitial();
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHistory = prefs.getStringList('calc_history') ?? [];
    setState(() {
      history.addAll(savedHistory);
    });
  }

  Future<void> saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('calc_history', history);
  }

  Future<void> _watchRewardedAd() async {
    if (isRewardedReady && rewardedAd != null && !isWatchingAd) {
      setState(() => isWatchingAd = true);

      await adsManager.showRewardedAd(rewardedAd!, premiumManager);

      setState(() {
        rewardedAd = null;
        isRewardedReady = false;
      });

      Future.delayed(const Duration(seconds: 30), () {
        setState(() => isWatchingAd = false);
      });

      adsManager.loadRewardedAd(onLoaded: (ad) {
        setState(() {
          rewardedAd = ad;
          isRewardedReady = true;
        });
      });
    }
  }

  Future<File> _createPasswordProtectedPdf() async {
    try {
      // Get user activities for the report
      final prefs = await SharedPreferences.getInstance();
      final savedActivities = prefs.getStringList('user_activities') ?? [];
      final allActivities = [...savedActivities];

      // Organize activities into sections
      final List<Map<String, String>> calculationHistory = [];
      final List<Map<String, String>> adsClicked = [];
      final List<Map<String, String>> adsWatched = [];
      final List<Map<String, String>> otherActivities = [];

      for (final activity in allActivities) {
        final parts = activity.split('|');
        if (parts.length == 4) {
          final timestamp = parts[0];
          final type = parts[1];
          final details = parts[2];
          final value = parts[3];

          final activityMap = {
            'timestamp': timestamp,
            'type': type,
            'details': details,
            'value': value
          };

          if (type == 'calculation' || type == 'scientific') {
            calculationHistory.add(activityMap);
          } else if (type == 'ad_click') {
            adsClicked.add(activityMap);
          } else if (type == 'ad_watched') {
            adsWatched.add(activityMap);
          } else {
            otherActivities.add(activityMap);
          }
        }
      }

      // Get last ~30 calculations (most recent first)
      final recentCalculations = calculationHistory.reversed.take(30).toList();

      // Create PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Header(level: 0, text: 'QuickCalc Activity Report'),
                pw.SizedBox(height: 10),
                pw.Text('Generated on: ${DateTime.now().toString()}'),
                pw.SizedBox(height: 20),
                pw.Text('🔒 Password Protected - Secure Report', 
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 30),

                // Section 1: Calculation History
                pw.Header(level: 1, text: '1. Calculation History (Last 30)'),
                pw.SizedBox(height: 10),
                if (recentCalculations.isEmpty)
                  pw.Text('No calculation history available.', style: const pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                if (recentCalculations.isNotEmpty)
                  pw.ListView.builder(
                    itemCount: recentCalculations.length,
                    itemBuilder: (context, index) {
                      final activity = recentCalculations[index];
                      final time = DateTime.parse(activity['timestamp']!);
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          '• ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - ${activity['details']} ${activity['value']!.isNotEmpty ? '= ${activity['value']}' : ''}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                pw.SizedBox(height: 20),

                // Section 2: Ads Clicked
                pw.Header(level: 1, text: '2. Ads Clicked'),
                pw.SizedBox(height: 10),
                if (adsClicked.isEmpty)
                  pw.Text('No ads clicked.', style: const pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                if (adsClicked.isNotEmpty)
                  pw.ListView.builder(
                    itemCount: adsClicked.length,
                    itemBuilder: (context, index) {
                      final activity = adsClicked[index];
                      final time = DateTime.parse(activity['timestamp']!);
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          '• ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - ${activity['details']}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                pw.SizedBox(height: 20),

                // Section 3: Ads Watched
                pw.Header(level: 1, text: '3. Ads Watched'),
                pw.SizedBox(height: 10),
                if (adsWatched.isEmpty)
                  pw.Text('No ads watched.', style: const pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                if (adsWatched.isNotEmpty)
                  pw.ListView.builder(
                    itemCount: adsWatched.length,
                    itemBuilder: (context, index) {
                      final activity = adsWatched[index];
                      final time = DateTime.parse(activity['timestamp']!);
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          '• ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - ${activity['details']}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                pw.SizedBox(height: 20),

                // Section 4: Other Activities
                pw.Header(level: 1, text: '4. Other Activities'),
                pw.SizedBox(height: 10),
                if (otherActivities.isEmpty)
                  pw.Text('No other activities recorded.', style: const pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                if (otherActivities.isNotEmpty)
                  pw.ListView.builder(
                    itemCount: otherActivities.length,
                    itemBuilder: (context, index) {
                      final activity = otherActivities[index];
                      final time = DateTime.parse(activity['timestamp']!);
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          '• ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - ${activity['type']}: ${activity['details']} ${activity['value']!.isNotEmpty ? '(${activity['value']})' : ''}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      );

      // Save PDF with simple password protection
      final pdfData = await pdf.save(
        password: _pdfPassword,
        userPassword: _pdfPassword,
        permissions: const pw.PdfPermissions(
          copy: true,
          modify: false,
          print: true,
          add: false,
        ),
        encrypt: true,
      );

      // Save encrypted PDF to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/quickcalc_activity_report.pdf');
      await file.writeAsBytes(pdfData);

      return file;
    } catch (e) {
      print('Error creating password-protected PDF: $e');
      rethrow;
    }
  }

  void _exportPdfReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating password-protected PDF report...')),
    );

    final File pdfFile;
    try {
      pdfFile = await _createPasswordProtectedPdf();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
      return;
    }

    // Show the dialog explaining the password protection
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('PDF Password Protected'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your report has been protected with a password.'),
              SizedBox(height: 16),
              Text('When you open this PDF in any PDF reader:'),
              SizedBox(height: 8),
              Text('• You will see a password prompt'),
              Text('• Enter the password to view the content'),
              Text('• Works with Adobe Reader, Preview, Chrome, etc.'),
              SizedBox(height: 16),
              Text(
                'The password ensures only authorized users can access your activity data.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    // Share the password-protected PDF
    try {
      await Share.shareXFiles([XFile(pdfFile.path)],
          text: 'My QuickCalc Activity Report - Password protected for security',
          subject: 'QuickCalc Password Protected Report');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing PDF: $e')),
      );
    }

    // Trigger interstitial after PDF export, but only once per hour
    final now = DateTime.now();
    if (_lastExportAdTime == null || now.difference(_lastExportAdTime!) > const Duration(hours: 1)) {
      _lastExportAdTime = now;
      _maybeShowInterstitial();
    }

    // Clean up the temporary file after a short delay
    Future.delayed(const Duration(seconds: 30), () {
      pdfFile.delete().catchError((_) {});
    });
  }

  void _clearUserActivity() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Activity Data'),
        content: const Text('This will delete all your activity history. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              UserActivityLogger.clearUserActivityData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Activity data cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _handleScientificFunction(String function) {
    setState(() {
      try {
        double currentValue = double.tryParse(result) ?? 0;
        double newValue = 0;

        switch (function) {
          case 'SIN':
            newValue = sin(currentValue * pi / 180);
            break;
          case 'COS':
            newValue = cos(currentValue * pi / 180);
            break;
          case 'TAN':
            newValue = tan(currentValue * pi / 180);
            break;
          case 'LOG2':
            newValue = log(currentValue) / log(2);
            break;
          case 'LOG10':
            newValue = log(currentValue) / log(10);
            break;
          case 'LOG25':
            newValue = log(currentValue) / log(25);
            break;
        }

        result = newValue.toStringAsFixed(6);
        UserActivityLogger.logUserActivity('scientific', function, result);
      } catch (e) {
        result = "Error";
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    premiumManager.dispose();
    adsManager.disposeAll();
    saveHistory();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: widget.themeMode == ThemeMode.light ? Colors.white : Colors.black,
      appBar: AppBar(
        title: const Text("QuickCalc"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              setState(() => leftPanelOpen = !leftPanelOpen);
              _panelInteractionCounter++;
              if (_panelInteractionCounter >= 10) {
                _maybeShowInterstitial();
              }
            },
            tooltip: 'History',
          ),
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: _exportPdfReport,
            tooltip: 'Export PDF Report',
          ),
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: widget.toggleTheme,
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.star),
            onPressed: () {
              setState(() => rightPanelOpen = !rightPanelOpen);
              _panelInteractionCounter++;
              if (_panelInteractionCounter >= 10) {
                _maybeShowInterstitial();
              }
            },
            tooltip: 'Premium',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (isTopBannerLoaded)
                SizedBox(height: 50, child: AdWidget(ad: adsManager.topBanner!)),
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
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.35,
                child: CalculatorKeypad(
                  onPressed: (btn) => setState(() => CalculatorLogic.handleButton(btn, this, onCalculationComplete: () {
                    _calculationCounter++;
                    if (_calculationCounter >= 10) {
                      _maybeShowInterstitial();
                    }
                  })),
                  themeMode: widget.themeMode,
                ),
              ),
              if (isBottomBannerLoaded)
                SizedBox(height: 50, child: AdWidget(ad: adsManager.bottomBanner!)),
            ],
          ),
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
                    onPressed: isWatchingAd ? null : _watchRewardedAd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isWatchingAd ? Colors.grey : Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isWatchingAd ? "Please wait..." : "Watch Ad to +30 History"),
                  ),
                ],
              ),
            ),
          ),
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
                        const Text("Scientific Functions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => rightPanelOpen = false)),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          _buildScientificButton('SIN', 'sin'),
                          _buildScientificButton('COS', 'cos'),
                          _buildScientificButton('TAN', 'tan'),
                          _buildScientificButton('LOG₂', 'log2'),
                          _buildScientificButton('LOG₁₀', 'log10'),
                          _buildScientificButton('LOG₂₅', 'log25'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!premiumManager.isPremium)
                      ElevatedButton(
                        onPressed: isWatchingAd ? null : _watchRewardedAd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isWatchingAd ? Colors.grey : Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isWatchingAd ? "Please wait..." : "Watch Ad to Unlock Scientific Functions"),
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScientificButton(String label, String function) {
    bool isEnabled = premiumManager.isPremium;
    return ElevatedButton(
      onPressed: isEnabled
          ? () => _handleScientificFunction(function.toUpperCase())
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? Colors.blueAccent : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }
}
