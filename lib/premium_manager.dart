import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumManager {
  DateTime? premiumUntil;
  Timer? _timer;
  Duration remaining = Duration.zero;

  // History slot tracking
  DateTime? _historyAdCooldownUntil;
  int _historySlots = 10; // Default slots
  Timer? _historyCooldownTimer;
  Duration _historyCooldownRemaining = Duration.zero;

  bool get isPremium =>
      premiumUntil != null && DateTime.now().isBefore(premiumUntil!);

  // History slot methods
  int get historySlots => _historySlots;
  Duration get historyCooldownRemaining => _historyCooldownRemaining;
  bool get isHistoryCooldownActive => 
      _historyAdCooldownUntil != null && DateTime.now().isBefore(_historyAdCooldownUntil!);

  Future<void> loadPremium() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt('premium_until');
    if (millis != null) {
      premiumUntil = DateTime.fromMillisecondsSinceEpoch(millis);
      _startTimer();
    }

    // Load history slot data
    final historySlots = prefs.getInt('history_slots');
    if (historySlots != null) {
      _historySlots = historySlots;
    }

    final historyCooldownMillis = prefs.getInt('history_cooldown_until');
    if (historyCooldownMillis != null) {
      _historyAdCooldownUntil = DateTime.fromMillisecondsSinceEpoch(historyCooldownMillis);
      _startHistoryCooldownTimer();
    }
  }

  Future<void> unlockPremium({required int hours}) async {
    premiumUntil = DateTime.now().add(Duration(hours: hours));
    _startTimer();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('premium_until', premiumUntil!.millisecondsSinceEpoch);
  }

  // History slot methods
  Future<void> addHistorySlots(int additionalSlots) async {
    _historySlots += additionalSlots;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('history_slots', _historySlots);
  }

  Future<void> startHistoryCooldown() async {
    _historyAdCooldownUntil = DateTime.now().add(const Duration(minutes: 20));
    _startHistoryCooldownTimer();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('history_cooldown_until', _historyAdCooldownUntil!.millisecondsSinceEpoch);
  }

  void _startHistoryCooldownTimer() {
    _historyCooldownTimer?.cancel();
    if (_historyAdCooldownUntil == null) return;
    
    _historyCooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final diff = _historyAdCooldownUntil!.difference(DateTime.now());
      _historyCooldownRemaining = diff.isNegative ? Duration.zero : diff;
      
      if (diff.isNegative) {
        _historyCooldownTimer?.cancel();
        _historyAdCooldownUntil = null;
        _historyCooldownRemaining = Duration.zero;
      }
    });
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

  void dispose() {
    _timer?.cancel();
    _historyCooldownTimer?.cancel();
  }
}
