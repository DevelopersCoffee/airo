import 'package:flutter/material.dart';
import '../constants/airomoney_constants.dart';

class AiroMoneyTheme {
  // Private constructor to prevent instantiation
  AiroMoneyTheme._();

  // Primary colors
  static const Color primaryColor = Color(AiroMoneyConstants.primaryColorValue);
  static const Color secondaryColor = Color(
    AiroMoneyConstants.secondaryColorValue,
  );
  static const Color incomeColor = Color(AiroMoneyConstants.incomeColorValue);
  static const Color expenseColor = Color(AiroMoneyConstants.expenseColorValue);
  static const Color transferColor = Color(
    AiroMoneyConstants.transferColorValue,
  );

  // Additional financial colors
  static const Color profitColor = Color(0xFF4CAF50);
  static const Color lossColor = Color(0xFFF44336);
  static const Color neutralColor = Color(0xFF9E9E9E);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color infoColor = Color(0xFF2196F3);

  // Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        secondary: secondaryColor,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AiroMoneyConstants.buttonBorderRadius,
            ),
          ),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AiroMoneyConstants.buttonBorderRadius,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AiroMoneyConstants.buttonBorderRadius,
            ),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AiroMoneyConstants.cardElevation,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        prefixIconColor: primaryColor,
        suffixIconColor: primaryColor,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: const TextStyle(fontSize: 12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }

  // Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        secondary: secondaryColor,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AiroMoneyConstants.buttonBorderRadius,
            ),
          ),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AiroMoneyConstants.buttonBorderRadius,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AiroMoneyConstants.buttonBorderRadius,
            ),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AiroMoneyConstants.cardElevation,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        prefixIconColor: primaryColor,
        suffixIconColor: primaryColor,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: const TextStyle(fontSize: 12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }

  // Custom color extensions for financial data
  static const Map<String, Color> financialColors = {
    'income': incomeColor,
    'expense': expenseColor,
    'transfer': transferColor,
    'profit': profitColor,
    'loss': lossColor,
    'neutral': neutralColor,
    'warning': warningColor,
    'info': infoColor,
  };

  // Category colors
  static const Map<String, Color> categoryColors = {
    'salary': Color(0xFF4CAF50),
    'freelance': Color(0xFF8BC34A),
    'investment': Color(0xFF2196F3),
    'gift': Color(0xFFE91E63),
    'other_income': Color(0xFF00BCD4),
    'food': Color(0xFFFF5722),
    'transport': Color(0xFF3F51B5),
    'entertainment': Color(0xFF9C27B0),
    'shopping': Color(0xFFFF9800),
    'bills': Color(0xFF607D8B),
    'healthcare': Color(0xFFF44336),
    'education': Color(0xFF009688),
    'other_expense': Color(0xFF795548),
  };

  // Wallet type colors
  static const Map<String, Color> walletColors = {
    'cash': Color(0xFF4CAF50),
    'bank': Color(0xFF2196F3),
    'credit': Color(0xFFFF9800),
    'investment': Color(0xFF9C27B0),
    'crypto': Color(0xFFFFEB3B),
  };

  // Helper methods
  static Color getCategoryColor(String category) {
    return categoryColors[category] ?? primaryColor;
  }

  static Color getWalletColor(String walletType) {
    return walletColors[walletType] ?? primaryColor;
  }

  static Color getTransactionColor(String transactionType) {
    switch (transactionType.toLowerCase()) {
      case 'income':
        return incomeColor;
      case 'expense':
        return expenseColor;
      case 'transfer':
        return transferColor;
      default:
        return neutralColor;
    }
  }
}
