import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'premium_manager.dart';
import 'ads_manager.dart';
import 'calculator_logic.dart';
import 'calculator_keypad.dart';
import 'user_activity_logger.dart';
import 'developer_analytics.dart';

// ==================== CALCULATOR HOME WIDGET ====================
class CalculatorHome extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;
  const CalculatorHome({super.key, required this.toggleTheme, required this.themeMode});

  @override
  CalculatorHomeState createState() => CalculatorHomeState();
}

// ==================== CALCULATOR HOME STATE ====================
class CalculatorHomeState extends State<CalculatorHome> with WidgetsBindingObserver {
  // ==================== UI STATE VARIABLES ====================
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

  // ==================== AD TRACKING VARIABLES ====================
  int _calculationCounter = 0;
  int _panelInteractionCounter = 0;
  DateTime? _lastExportAdTime;

  // ==================== PDF ENCRYPTION VARIABLES ====================
  static const String _pdfPassword = 'gush5+:)#6gsj5#8+';
  static const String _encryptedFileExtension = '.aes';
  static const String _pdfFileExtension = '.pdf';
  static const List<int> _pdfMagicBytes = [0x25, 0x50, 0x44, 0x46]; // %PDF

  // ==================== MANAGER INSTANCES ====================
  late PremiumManager premiumManager;
  late AdsManager adsManager;

  // ==================== INITIALIZATION ====================
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
    print('🔄 Scheduling App Open Ad load in 2 seconds...');
    Future.delayed(const Duration(seconds: 2), () {
      print('🔄 Loading App Open Ad now...');
      adsManager.loadAppOpenAd();
    });

    // Clean up old temporary files on app start
    _cleanupOldFiles();
  }

  // ==================== FILE MANAGEMENT ====================
  Future<void> _cleanupOldFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      final now = DateTime.now();
      
      for (var file in files) {
        if (file is File) {
          final stat = await file.stat();
          final fileAge = now.difference(stat.modified);
          if (fileAge > const Duration(hours: 1)) {
            file.delete().catchError((_) {});
          }
        }
      }
    } catch (e) {
      print('Error cleaning up files: $e');
    }
  }

  // ==================== APP LIFECYCLE ====================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('🔍 Lifecycle state changed: $state');
    if (state == AppLifecycleState.resumed) {
      print('🚀 App resumed - attempting to show App Open Ad');
      Future.delayed(const Duration(milliseconds: 1000), () {
        adsManager.showAppOpenAd();
      });
    }
  }

  // ==================== INTERSTITIAL ADS ====================
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

  // ==================== HISTORY MANAGEMENT ====================
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

  // ==================== REWARDED ADS - SEPARATE METHODS ====================
  Future<void> _watchRewardedAdForHistory() async {
    if (isRewardedReady && rewardedAd != null && !isWatchingAd) {
      setState(() => isWatchingAd = true);

      await adsManager.showRewardedAd(rewardedAd!, premiumManager, forHistory: true);

      setState(() {
        rewardedAd = null;
        isRewardedReady = false;
      });

      // Reload rewarded ad after delay
      Future.delayed(const Duration(seconds: 30), () {
        setState(() => isWatchingAd = false);
        adsManager.loadRewardedAd(onLoaded: (ad) {
          setState(() {
            rewardedAd = ad;
            isRewardedReady = true;
          });
        });
      });
    }
  }

  Future<void> _watchRewardedAdForPremium() async {
    if (isRewardedReady && rewardedAd != null && !isWatchingAd) {
      setState(() => isWatchingAd = true);

      await adsManager.showRewardedAd(rewardedAd!, premiumManager, forHistory: false);

      setState(() {
        rewardedAd = null;
        isRewardedReady = false;
      });

      // Reload rewarded ad after delay
      Future.delayed(const Duration(seconds: 30), () {
        setState(() => isWatchingAd = false);
        adsManager.loadRewardedAd(onLoaded: (ad) {
          setState(() {
            rewardedAd = ad;
            isRewardedReady = true;
          });
        });
      });
    }
  }

  // ==================== PDF ENCRYPTION/DECRYPTION ====================
  List<int> _aesEncrypt(List<int> data, String password) {
    try {
      final key = _generateAesKey(password);
      final iv = encrypt.IV.fromSecureRandom(16);
      
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.cbc));
      final encrypted = encrypter.encryptBytes(Uint8List.fromList(data), iv: iv);
      
      final result = Uint8List(iv.bytes.length + encrypted.bytes.length);
      result.setRange(0, iv.bytes.length, iv.bytes);
      result.setRange(iv.bytes.length, result.length, encrypted.bytes);
      
      return result;
    } catch (e) {
      print('AES encryption error: $e');
      rethrow;
    }
  }

  List<int> _aesDecrypt(List<int> encryptedData, String password) {
    try {
      final iv = encrypt.IV(Uint8List.fromList(encryptedData.sublist(0, 16)));
      final ciphertext = Uint8List.fromList(encryptedData.sublist(16));
      
      final key = _generateAesKey(password);
      
      final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.cbc));
      final decrypted = encrypter.decryptBytes(encrypt.Encrypted(ciphertext), iv: iv);
      
      return decrypted;
    } catch (e) {
      throw Exception('Decryption failed: Wrong password or corrupted file');
    }
  }

  Uint8List _generateAesKey(String password) {
    var keyBytes = utf8.encode(password);
    final result = Uint8List(32);
    
    for (int i = 0; i < 32; i++) {
      if (i < keyBytes.length) {
        result[i] = keyBytes[i];
      } else {
        result[i] = 0;
      }
    }
    
    return result;
  }

  bool _isValidPdf(List<int> data) {
    if (data.length < _pdfMagicBytes.length) return false;
    
    for (int i = 0; i < _pdfMagicBytes.length; i++) {
      if (data[i] != _pdfMagicBytes[i]) return false;
    }
    
    return true;
  }

  // ==================== PDF REPORT GENERATION ====================
  Future<File> _createPasswordProtectedPdf() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedActivities = prefs.getStringList('user_activities') ?? [];
      final allActivities = [...savedActivities];

      final List<Map<String, String>> calculationHistory = [];
      final List<Map<String, String>> adsClicked = [];
      final List<Map<String, String>> adsWatched = [];
      final List<Map<String, String>> otherActivities = [];

      for (final activity in allActivities) {
        final parts = activity.split('|');
        if (parts.length == 4) {
          final activityMap = {
            'timestamp': parts[0],
            'type': parts[1],
            'details': parts[2],
            'value': parts[3]
          };

          if (parts[1] == 'calculation' || parts[1] == 'scientific') {
            calculationHistory.add(activityMap);
          } else if (parts[1] == 'ad_click') {
            adsClicked.add(activityMap);
          } else if (parts[1] == 'ad_watched') {
            adsWatched.add(activityMap);
          } else {
            otherActivities.add(activityMap);
          }
        }
      }

      final recentCalculations = calculationHistory.reversed.take(30).toList();
      final pdf = pw.Document();

      pdf.addPage(pw.Page(build: (pw.Context context) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Header(level: 0, text: 'QuickCalc Activity Report'),
          pw.SizedBox(height: 10),
          pw.Text('Generated on: ${DateTime.now().toString()}'),
          pw.SizedBox(height: 20),
          pw.Text('🔒 AES-256 Encrypted - Secure Report', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 30),
          pw.Header(level: 1, text: '1. Calculation History (Last 30)'),
          pw.SizedBox(height: 10),
          if (recentCalculations.isEmpty)
            pw.Text('No calculation history available.', style: const pw.TextStyle(fontStyle: pw.FontStyle.italic)),
          if (recentCalculations.isNotEmpty)
            pw.ListView.builder(itemCount: recentCalculations.length, itemBuilder: (context, index) {
              final activity = recentCalculations[index];
              final time = DateTime.parse(activity['timestamp']!);
              return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(
                '• ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - ${activity['details']} ${activity['value']!.isNotEmpty ? '= ${activity['value']}' : ''}',
                style: const pw.TextStyle(fontSize: 12),
              ));
            }),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, text: '2. Ads Clicked'),
          pw.SizedBox(height: 10),
          if (adsClicked.isEmpty)
            pw.Text('No ads clicked.', style: const pw.TextStyle(fontStyle: pw.FontStyle.italic)),
          if (adsClicked.isNotEmpty)
            pw.ListView.builder(itemCount: adsClicked.length, itemBuilder: (context, index) {
              final activity = adsClicked[index];
              final time = DateTime.parse(activity['timestamp']!);
              return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(
                '• ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - ${activity['details']}',
                style: const pw.TextStyle(fontSize: 12),
              ));
            }),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, text: '3. Ads Watched'),
          pw.SizedBox(height: 10),
          if (adsWatched.isEmpty)
            pw.Text('No ads watched.', style: const pw.TextStyle(fontStyle: pw.FontStyle.italic)),
          if (adsWatched.isNotEmpty)
            pw.ListView.builder(itemCount: adsWatched.length, itemBuilder: (context, index) {
              final activity = adsWatched[index];
              final time = DateTime.parse(activity['timestamp']!);
              return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(
                '• ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - ${activity['details']}',
                style: const pw.TextStyle(fontSize: 12),
              ));
            }),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, text: '4. Other Activities'),
          pw.SizedBox(height: 10),
          if (otherActivities.isEmpty)
            pw.Text('No other activities recorded.', style: const pw.TextStyle(fontStyle: pw.FontStyle.italic)),
          if (otherActivities.isNotEmpty)
            pw.ListView.builder(itemCount: otherActivities.length, itemBuilder: (context, index) {
              final activity = otherActivities[index];
              final time = DateTime.parse(activity['timestamp']!);
              return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(
                '• ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} - ${activity['type']}: ${activity['details']} ${activity['value']!.isNotEmpty ? '(${activity['value']})' : ''}',
                style: const pw.TextStyle(fontSize: 12),
              ));
            }),
        ]);
      }));

      final pdfData = await pdf.save();
      final encryptedPdfData = _aesEncrypt(pdfData, _pdfPassword);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/quickcalc_activity_report_${DateTime.now().millisecondsSinceEpoch}$_encryptedFileExtension');
      await file.writeAsBytes(encryptedPdfData);

      Future.delayed(const Duration(hours: 1), () {
        file.delete().catchError((_) {});
      });

      return file;
    } catch (e) {
      print('Error creating encrypted PDF: $e');
      rethrow;
    }
  }

  // ==================== PDF EXPORT FUNCTION ====================
  void _exportPdfReport() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating AES-256 encrypted report...')));

    final File encryptedFile;
    try {
      encryptedFile = await _createPasswordProtectedPdf();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating encrypted file: $e')));
      return;
    }

    await showDialog(context: context, barrierDismissible: false, builder: (BuildContext context) {
      return AlertDialog(title: const Text('AES-256 Encrypted Report'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your report has been encrypted with AES-256 encryption.'),
        const SizedBox(height: 16), const Text('File Information:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), Text('• File format: AES-256 encrypted binary ($_encryptedFileExtension)'),
        const Text('• Encryption: AES-256 CBC mode'), const Text('• Auto-delete: After 1 hour'), const SizedBox(height: 16),
        const Text('Note: Use the "Decrypt Report" feature to view this file.', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
      ]), actions: <Widget>[TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]);
    });

    try {
      await Share.shareXFiles([XFile(encryptedFile.path)], text: 'My QuickCalc Activity Report - AES-256 Encrypted\nFile extension: $_encryptedFileExtension\nUse the QuickCalc app to decrypt this file', subject: 'QuickCalc AES-256 Encrypted Report');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing file: $e')));
    }

    final now = DateTime.now();
    if (_lastExportAdTime == null || now.difference(_lastExportAdTime!) > const Duration(hours: 1)) {
      _lastExportAdTime = now;
      _maybeShowInterstitial();
    }
  }

  // ==================== PDF DECRYPTION FUNCTION ====================
  Future<void> _decryptAndViewReport() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any, dialogTitle: 'Select your encrypted .aes file');
      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.first;
      final encryptedFile = File(pickedFile.path!);
      final encryptedData = await encryptedFile.readAsBytes();

      final passwordController = TextEditingController();
      final password = await showDialog<String>(context: context, barrierDismissible: false, builder: (BuildContext context) {
        return AlertDialog(title: const Text('Enter Password'), content: TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(hintText: 'Enter the encryption password', border: OutlineInputBorder())), actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(passwordController.text), child: const Text('Decrypt')),
        ]);
      });

      if (password == null || password.isEmpty) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Decrypting...')));
      final decryptedData = _aesDecrypt(encryptedData, password);

      if (!_isValidPdf(decryptedData)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Decryption failed: File is not a valid PDF')));
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final decryptedFile = File('${tempDir.path}/decrypted_report_${DateTime.now().millisecondsSinceEpoch}$_pdfFileExtension');
      await decryptedFile.writeAsBytes(decryptedData);

      Future.delayed(const Duration(hours: 1), () {
        decryptedFile.delete().catchError((_) {});
      });

      final openResult = await OpenFile.open(decryptedFile.path);
      if (openResult.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open the decrypted file')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report decrypted successfully!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Decryption failed: ${e.toString().replaceAll('Exception: ', '')}')));
    }
  }

  // ==================== USER ACTIVITY MANAGEMENT ====================
  void _clearUserActivity() async {
    showDialog(context: context, builder: (BuildContext context) {
      return AlertDialog(title: const Text('Clear Activity Data'), content: const Text('This will delete all your activity history. This action cannot be undone.'), actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () { UserActivityLogger.clearUserActivityData(); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity data cleared'))); }, child: const Text('Clear', style: TextStyle(color: Colors.red))),
      ]);
    });
  }

  // ==================== SCIENTIFIC FUNCTIONS ====================
  void _handleScientificFunction(String function) {
    setState(() {
      try {
        double currentValue = double.tryParse(result) ?? 0;
        double newValue = 0;

        switch (function) {
          case 'SIN': newValue = sin(currentValue * pi / 180); break;
          case 'COS': newValue = cos(currentValue * pi / 180); break;
          case 'TAN': newValue = tan(currentValue * pi / 180); break;
          case 'LOG2': newValue = log(currentValue) / log(2); break;
          case 'LOG10': newValue = log(currentValue) / log(10); break;
          case 'LOG25': newValue = log(currentValue) / log(25); break;
        }

        result = newValue.toStringAsFixed(6);
        UserActivityLogger.logUserActivity('scientific', function, result);
      } catch (e) {
        result = "Error";
      }
    });
  }

  // ==================== DISPOSE & CLEANUP ====================
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    premiumManager.dispose();
    adsManager.disposeAll();
    saveHistory();
    super.dispose();
  }

  // ==================== BUILD METHOD - APP UI ====================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: widget.themeMode == ThemeMode.light ? Colors.white : Colors.black,
      
      // ==================== APP BAR SECTION ====================
      appBar: AppBar(
        title: const Text("QuickCalc"),
        actions: [
          // TEMPORARY APP OPEN AD TEST BUTTON
          IconButton(
            icon: const Icon(Icons.ad_units),
            onPressed: () {
              print('🔄 Manual App Open Ad trigger');
              print('📱 App Open Ad loaded: ${adsManager.isAppOpenAdLoaded}');
              if (adsManager.isAppOpenAdLoaded) {
                print('✅ Showing App Open Ad...');
                adsManager.showAppOpenAd();
              } else {
                print('❌ App Open Ad not loaded yet');
                print('🔄 Loading App Open Ad now...');
                adsManager.loadAppOpenAd();
                Future.delayed(const Duration(seconds: 3), () {
                  if (adsManager.isAppOpenAdLoaded) {
                    adsManager.showAppOpenAd();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App Open Ad failed to load')));
                  }
                });
              }
            },
            tooltip: 'Test App Open Ad',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              setState(() => leftPanelOpen = !leftPanelOpen);
              _panelInteractionCounter++;
              if (_panelInteractionCounter >= 10) { _maybeShowInterstitial(); }
            },
            tooltip: 'History',
          ),
          IconButton(
            icon: const Icon(Icons.description),
            onPressed: _exportPdfReport,
            tooltip: 'Export Encrypted Report',
          ),
          IconButton(
            icon: const Icon(Icons.lock_open),
            onPressed: _decryptAndViewReport,
            tooltip: 'Decrypt Report',
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
              if (_panelInteractionCounter >= 10) { _maybeShowInterstitial(); }
            },
            tooltip: 'Premium',
          ),
        ],
      ),

      // ==================== MAIN BODY CONTENT ====================
      body: Stack(children: [
        Column(children: [
          if (isTopBannerLoaded) SizedBox(height: 50, child: AdWidget(ad: adsManager.topBanner!)),
          Container(alignment: Alignment.centerRight, padding: const EdgeInsets.all(16), child: Text(expression, style: TextStyle(fontSize: 24, color: widget.themeMode == ThemeMode.light ? Colors.grey : Colors.grey[400]))),
          Expanded(child: Center(child: Text(result, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: widget.themeMode == ThemeMode.light ? Colors.black : Colors.white)))),
          SizedBox(height: MediaQuery.of(context).size.height * 0.35, child: CalculatorKeypad(onPressed: (btn) => setState(() => CalculatorLogic.handleButton(btn, this, onCalculationComplete: () { _calculationCounter++; if (_calculationCounter >= 10) { _maybeShowInterstitial(); } })), themeMode: widget.themeMode)),
          if (isBottomBannerLoaded) SizedBox(height: 50, child: AdWidget(ad: adsManager.bottomBanner!)),
        ]),

        // ==================== HISTORY PANEL SECTION ====================
        AnimatedPositioned(duration: const Duration(milliseconds: 300), left: leftPanelOpen ? 0 : -screenWidth * 0.7, top: 0, bottom: 0, width: screenWidth * 0.7, child: Container(color: Theme.of(context).colorScheme.surface, padding: const EdgeInsets.all(16), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => leftPanelOpen = false)),
          ]),
          const Divider(),
          Expanded(child: ListView.builder(itemCount: history.length, itemBuilder: (context, index) => ListTile(title: Text(history[index])))),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: isWatchingAd ? null : _watchRewardedAdForHistory, // ✅ SEPARATE METHOD FOR HISTORY
            style: ElevatedButton.styleFrom(backgroundColor: isWatchingAd ? Colors.grey : Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(isWatchingAd ? "Please wait..." : "Watch Ad to +30 History"),
          ),
        ]))),

        // ==================== PREMIUM PANEL SECTION ====================
        AnimatedPositioned(duration: const Duration(milliseconds: 300), right: rightPanelOpen ? 0 : -screenWidth * 0.6, top: 0, bottom: 0, width: screenWidth * 0.6, child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Container(color: Theme.of(context).colorScheme.surface, padding: const EdgeInsets.all(16), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Scientific Functions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => rightPanelOpen = false)),
          ]),
          const Divider(),
          Expanded(child: GridView.count(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, children: [
            _buildScientificButton('SIN', 'sin'), _buildScientificButton('COS', 'cos'), _buildScientificButton('TAN', 'tan'),
            _buildScientificButton('LOG₂', 'log2'), _buildScientificButton('LOG₁₀', 'log10'), _buildScientificButton('LOG₂₅', 'log25'),
          ])),
          const SizedBox(height: 20),
          if (!premiumManager.isPremium) ElevatedButton(
            onPressed: isWatchingAd ? null : _watchRewardedAdForPremium, // ✅ SEPARATE METHOD FOR PREMIUM
            style: ElevatedButton.styleFrom(backgroundColor: isWatchingAd ? Colors.grey : Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(isWatchingAd ? "Please wait..." : "Watch Ad to Unlock Scientific Functions"),
          ),
          if (premiumManager.isPremium) Padding(padding: const EdgeInsets.all(8.0), child: Text("Premium Active!\nTime remaining: ${premiumManager.remaining.inMinutes.remainder(60).toString().padLeft(2,'0')}:${(premiumManager.remaining.inSeconds.remainder(60)).toString().padLeft(2,'0')}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ])))),
      ]),
    );
  }

  // ==================== SCIENTIFIC BUTTON BUILDER ====================
  Widget _buildScientificButton(String label, String function) {
    bool isEnabled = premiumManager.isPremium;
    return ElevatedButton(
      onPressed: isEnabled ? () => _handleScientificFunction(function.toUpperCase()) : null,
      style: ElevatedButton.styleFrom(backgroundColor: isEnabled ? Colors.blueAccent : Colors.grey, foregroundColor: Colors.white, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
    );
  }
}
