import 'package:flutter/material.dart';
import 'ads_manager.dart';
import 'app.dart';
import 'premium_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Premium Manager (assuming it has an initialize method)
  await PremiumManager.initialize();
  
  // Initialize Ads ONLY if user is not premium
  if (!PremiumManager.isUserPremium()) {
    await AdsManager.initialize();
  }
  
  runApp(const App());
}

// You can also use a StatefulWidget for the main app to call dispose, but it's
// more common to handle this in the root widget (App). We'll do it in app.dart.
