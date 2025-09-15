import 'package:flutter/material.dart';
import 'home.dart';

class QuickCalcApp extends StatefulWidget {
  const QuickCalcApp({super.key});

  @override
  State<QuickCalcApp> createState() => _QuickCalcAppState();
}

class _QuickCalcAppState extends State<QuickCalcApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // ADD THIS
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // ADD THIS
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Forward lifecycle events to home screen
    final homeState = context.findAncestorStateOfType<CalculatorHomeState>();
    homeState?.didChangeAppLifecycleState(state);
  }

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
