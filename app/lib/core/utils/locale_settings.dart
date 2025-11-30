import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_formatter.dart';

/// User locale settings for the app
class LocaleSettings {
  final String locale;
  final String currency;
  final String dateFormat;
  final String timeFormat;
  final String numberFormat;

  const LocaleSettings({
    this.locale = 'en_IN',
    this.currency = 'INR',
    this.dateFormat = 'dd/MM/yyyy',
    this.timeFormat = 'HH:mm',
    this.numberFormat = '#,##,##0.00', // Indian numbering system
  });

  /// Default settings for India
  static const LocaleSettings india = LocaleSettings();

  /// Default settings for US
  static const LocaleSettings us = LocaleSettings(
    locale: 'en_US',
    currency: 'USD',
    dateFormat: 'MM/dd/yyyy',
    numberFormat: '#,##0.00',
  );

  /// Get currency formatter for current settings
  CurrencyFormatter get currencyFormatter =>
      CurrencyFormatter.fromCode(currency);

  /// Get supported currency enum
  SupportedCurrency get supportedCurrency =>
      SupportedCurrency.fromCode(currency);

  LocaleSettings copyWith({
    String? locale,
    String? currency,
    String? dateFormat,
    String? timeFormat,
    String? numberFormat,
  }) {
    return LocaleSettings(
      locale: locale ?? this.locale,
      currency: currency ?? this.currency,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      numberFormat: numberFormat ?? this.numberFormat,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locale': locale,
      'currency': currency,
      'dateFormat': dateFormat,
      'timeFormat': timeFormat,
      'numberFormat': numberFormat,
    };
  }

  factory LocaleSettings.fromJson(Map<String, dynamic> json) {
    return LocaleSettings(
      locale: json['locale'] as String? ?? 'en_IN',
      currency: json['currency'] as String? ?? 'INR',
      dateFormat: json['dateFormat'] as String? ?? 'dd/MM/yyyy',
      timeFormat: json['timeFormat'] as String? ?? 'HH:mm',
      numberFormat: json['numberFormat'] as String? ?? '#,##,##0.00',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocaleSettings &&
        other.locale == locale &&
        other.currency == currency &&
        other.dateFormat == dateFormat &&
        other.timeFormat == timeFormat &&
        other.numberFormat == numberFormat;
  }

  @override
  int get hashCode => Object.hash(
        locale,
        currency,
        dateFormat,
        timeFormat,
        numberFormat,
      );
}

/// Provider for locale settings
class LocaleSettingsNotifier extends StateNotifier<LocaleSettings> {
  static const String _storageKey = 'airo_locale_settings';
  SharedPreferences? _prefs;

  LocaleSettingsNotifier() : super(LocaleSettings.india) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final jsonStr = _prefs?.getString(_storageKey);
      if (jsonStr != null) {
        state = LocaleSettings.fromJson(jsonDecode(jsonStr));
      }
    } catch (e) {
      debugPrint('Error loading locale settings: $e');
      // Keep default India settings on error
    }
  }

  Future<void> updateSettings(LocaleSettings settings) async {
    state = settings;
    await _prefs?.setString(_storageKey, jsonEncode(settings.toJson()));
  }

  Future<void> setCurrency(String currency) async {
    await updateSettings(state.copyWith(currency: currency));
  }

  Future<void> setLocale(String locale) async {
    await updateSettings(state.copyWith(locale: locale));
  }

  Future<void> resetToDefaults() async {
    await updateSettings(LocaleSettings.india);
  }
}

/// Global locale settings provider
final localeSettingsProvider =
    StateNotifierProvider<LocaleSettingsNotifier, LocaleSettings>((ref) {
  return LocaleSettingsNotifier();
});

/// Currency formatter provider (derived from locale settings)
final currencyFormatterProvider = Provider<CurrencyFormatter>((ref) {
  final settings = ref.watch(localeSettingsProvider);
  return settings.currencyFormatter;
});

