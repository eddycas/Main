import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumManager {
  DateTime? premiumUntil;
  Timer? _timer;
  Duration remaining = Duration.zero;

  bool get isPremium => premiumUntil != null && DateTime.now().isBefore(premiumUntil!);

  String _premiumKey([User? user]) => 'premium_until_${user?.uid ?? 'guest'}';

  Future<void> loadPremium(User? user) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_premiumKey(user));
    if (millis != null) {
      premiumUntil = DateTime.fromMillisecondsSinceEpoch(millis);
      _startTimer();
    }
  }

  Future<void> unlockPremium({required int hours, User? user}) async {
    premiumUntil = DateTime.now().add(Duration(hours: hours));
    _startTimer();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_premiumKey(user), premiumUntil!.millisecondsSinceEpoch);
  }

  void _startTimer() {
    _timer?.cancel();
    if (premiumUntil == null) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = premiumUntil!.difference(DateTime.now());
      if (diff.isNegative) {
        _timer?.cancel();
        premiumUntil = null;
        remaining = Duration.zero;
      } else {
        remaining = diff;
      }
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}
