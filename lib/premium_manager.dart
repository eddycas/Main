import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumManager {
  DateTime? premiumUntil;
  Timer? _timer;
  Duration remaining = Duration.zero;

  bool get isPremium =>
      premiumUntil != null && DateTime.now().isBefore(premiumUntil!);

  Future<void> loadPremium() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('premium_until');
    if (millis != null) {
      premiumUntil = DateTime.fromMillisecondsSinceEpoch(millis);
      _startTimer();
    }
  }

  Future<void> unlockPremium({required int hours}) async {
    premiumUntil = DateTime.now().add(Duration(hours: hours));
    _startTimer();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('premium_until', premiumUntil!.millisecondsSinceEpoch);
  }

  void _startTimer() {
    _timer?.cancel();
    if (premiumUntil == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = premiumUntil!.difference(DateTime.now());
      remaining = diff.isNegative ? Duration.zero : diff;
      if (diff.isNegative) {
        _timer?.cancel();
        premiumUntil = null;
      }
    });
  }

  void dispose() => _timer?.cancel();
}
