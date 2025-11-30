import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airomoney/airomoney.dart';

void main() {
  group('AiroMoney Package', () {
    test('AiroMoneyConstants has expected default values', () {
      expect(AiroMoneyConstants.packageName, 'airomoney');
      expect(AiroMoneyConstants.packageVersion, isNotEmpty);
      expect(AiroMoneyConstants.defaultCurrency, 'USD');
      expect(AiroMoneyConstants.defaultDecimalPlaces, 2);
    });

    test('AiroMoneyTheme provides valid light theme', () {
      final theme = AiroMoneyTheme.lightTheme;
      expect(theme, isNotNull);
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
    });

    test('AiroMoneyTheme provides valid dark theme', () {
      final theme = AiroMoneyTheme.darkTheme;
      expect(theme, isNotNull);
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    test('AiroMoneyTheme has financial colors defined', () {
      expect(AiroMoneyTheme.incomeColor, isNotNull);
      expect(AiroMoneyTheme.expenseColor, isNotNull);
      expect(AiroMoneyTheme.transferColor, isNotNull);
    });

    test('AiroMoneyTheme getCategoryColor returns correct colors', () {
      expect(AiroMoneyTheme.getCategoryColor('food'), isA<Color>());
      expect(
        AiroMoneyTheme.getCategoryColor('unknown'),
        AiroMoneyTheme.primaryColor,
      );
    });

    test('AiroMoneyTheme getTransactionColor returns correct colors', () {
      expect(
        AiroMoneyTheme.getTransactionColor('income'),
        AiroMoneyTheme.incomeColor,
      );
      expect(
        AiroMoneyTheme.getTransactionColor('expense'),
        AiroMoneyTheme.expenseColor,
      );
      expect(
        AiroMoneyTheme.getTransactionColor('transfer'),
        AiroMoneyTheme.transferColor,
      );
    });

    test('AiroMoneyConstants has expense and income categories', () {
      expect(AiroMoneyConstants.expenseCategories, isNotEmpty);
      expect(AiroMoneyConstants.incomeCategories, isNotEmpty);
      expect(AiroMoneyConstants.expenseCategories, contains('food'));
      expect(AiroMoneyConstants.incomeCategories, contains('salary'));
    });
  });
}
