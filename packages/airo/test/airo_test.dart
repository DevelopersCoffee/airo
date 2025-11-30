import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airo/airo.dart';

void main() {
  group('Airo Package', () {
    test('AiroConstants has expected default values', () {
      expect(AiroConstants.packageName, 'airo');
      expect(AiroConstants.packageVersion, isNotEmpty);
      expect(AiroConstants.maxTokensPerRequest, greaterThan(0));
    });

    test('AiroTheme provides valid light theme', () {
      final theme = AiroTheme.lightTheme;
      expect(theme, isNotNull);
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
    });

    test('AiroTheme provides valid dark theme', () {
      final theme = AiroTheme.darkTheme;
      expect(theme, isNotNull);
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    test('AiroTheme has custom colors defined', () {
      expect(AiroTheme.primaryColor, isNotNull);
      expect(AiroTheme.secondaryColor, isNotNull);
      expect(AiroTheme.errorColor, isNotNull);
      expect(AiroTheme.successColor, isNotNull);
    });
  });
}
