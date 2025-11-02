import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bedtime mode state notifier
class BedtimeModeNotifier extends StateNotifier<bool> {
  static const String _prefKey = 'bedtime_mode_enabled';
  static const int _autoEnableHour = 22; // 10 PM
  static const int _autoDisableHour = 6; // 6 AM

  late SharedPreferences _prefs;
  Timer? _scheduleTimer;

  BedtimeModeNotifier() : super(false) {
    _initialize();
  }

  /// Initialize bedtime mode
  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load saved preference
    final saved = _prefs.getBool(_prefKey) ?? false;
    state = saved;

    // Start auto-schedule
    _startAutoSchedule();
  }

  /// Toggle bedtime mode
  Future<void> toggle([bool? value]) async {
    final newValue = value ?? !state;
    state = newValue;
    await _prefs.setBool(_prefKey, newValue);
  }

  /// Enable bedtime mode
  Future<void> enable() async {
    await toggle(true);
  }

  /// Disable bedtime mode
  Future<void> disable() async {
    await toggle(false);
  }

  /// Start auto-schedule for bedtime mode
  void _startAutoSchedule() {
    // Check every 5 minutes
    _scheduleTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkAndUpdateBedtimeMode();
    });

    // Also check immediately
    _checkAndUpdateBedtimeMode();
  }

  /// Check current time and update bedtime mode
  void _checkAndUpdateBedtimeMode() {
    final now = DateTime.now();
    final hour = now.hour;

    // Enable bedtime mode between 22:00 and 06:00
    final shouldBeBedtime = hour >= _autoEnableHour || hour < _autoDisableHour;

    // Only update if state changed
    if (state != shouldBeBedtime) {
      state = shouldBeBedtime;
      _prefs.setBool(_prefKey, shouldBeBedtime);
    }
  }

  @override
  void dispose() {
    _scheduleTimer?.cancel();
    super.dispose();
  }
}

/// Bedtime mode provider
final bedtimeModeProvider =
    StateNotifierProvider<BedtimeModeNotifier, bool>((ref) {
  return BedtimeModeNotifier();
});

/// Sleep timer provider (in minutes)
final sleepTimerProvider = StateNotifierProvider<SleepTimerNotifier, int>((ref) {
  return SleepTimerNotifier();
});

/// Sleep timer state notifier
class SleepTimerNotifier extends StateNotifier<int> {
  Timer? _timer;

  SleepTimerNotifier() : super(0);

  /// Set sleep timer in minutes
  void setSleepTimer(int minutes) {
    // Cancel existing timer
    _timer?.cancel();

    if (minutes <= 0) {
      state = 0;
      return;
    }

    state = minutes;

    // Decrement every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      state--;
      if (state <= 0) {
        _timer?.cancel();
        state = 0;
        // TODO: Trigger sleep action (pause music, close reader, etc.)
      }
    });
  }

  /// Cancel sleep timer
  void cancelSleepTimer() {
    _timer?.cancel();
    state = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Do Not Disturb mode provider
final doNotDisturbProvider =
    StateNotifierProvider<DoNotDisturbNotifier, bool>((ref) {
  return DoNotDisturbNotifier();
});

/// Do Not Disturb state notifier
class DoNotDisturbNotifier extends StateNotifier<bool> {
  static const String _prefKey = 'do_not_disturb_enabled';

  late SharedPreferences _prefs;

  DoNotDisturbNotifier() : super(false) {
    _initialize();
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getBool(_prefKey) ?? false;
    state = saved;
  }

  Future<void> toggle([bool? value]) async {
    final newValue = value ?? !state;
    state = newValue;
    await _prefs.setBool(_prefKey, newValue);
  }

  Future<void> enable() async {
    await toggle(true);
  }

  Future<void> disable() async {
    await toggle(false);
  }
}

/// Blue light filter intensity provider (0.0 to 1.0)
final blueLightFilterProvider =
    StateNotifierProvider<BlueLightFilterNotifier, double>((ref) {
  return BlueLightFilterNotifier();
});

/// Blue light filter state notifier
class BlueLightFilterNotifier extends StateNotifier<double> {
  static const String _prefKey = 'blue_light_filter_intensity';

  late SharedPreferences _prefs;

  BlueLightFilterNotifier() : super(0.0) {
    _initialize();
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getDouble(_prefKey) ?? 0.0;
    state = saved;
  }

  Future<void> setIntensity(double intensity) async {
    final clamped = intensity.clamp(0.0, 1.0);
    state = clamped;
    await _prefs.setDouble(_prefKey, clamped);
  }
}

