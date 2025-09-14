import 'package:flutter/material.dart';
import 'home.dart'; // MAKE SURE this import exists

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
      home: CalculatorHome(toggleTheme: _toggleTheme, themeMode: _themeMode),
    );
  }
}
