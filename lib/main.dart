import 'package:flutter/material.dart';
import 'app.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // ← Initialize Firebase first
  await MobileAds.instance.initialize();
  runApp(const QuickCalcApp());
}
