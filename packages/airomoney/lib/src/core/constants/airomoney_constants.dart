class AiroMoneyConstants {
  // Private constructor to prevent instantiation
  AiroMoneyConstants._();

  // App Information
  static const String packageName = 'airomoney';
  static const String packageVersion = '0.0.1';
  static const String packageDescription = 'Financial management package';

  // API Endpoints
  static const String transactionsEndpoint = '/api/transactions';
  static const String walletsEndpoint = '/api/wallets';
  static const String categoriesEndpoint = '/api/categories';
  static const String analyticsEndpoint = '/api/analytics';
  static const String budgetEndpoint = '/api/budget';

  // Feature Flags
  static const bool enableBudgeting = true;
  static const bool enableAnalytics = true;
  static const bool enableExport = true;
  static const bool enableNotifications = true;
  static const bool enableMultiCurrency = false;

  // Limits
  static const int maxTransactionsPerPage = 50;
  static const int maxWalletsPerUser = 10;
  static const int maxCategoriesPerUser = 20;
  static const double maxTransactionAmount = 1000000.0;
  static const double minTransactionAmount = 0.01;

  // Default Values
  static const String defaultCurrency = 'USD';
  static const String defaultCurrencySymbol = '\$';
  static const int defaultDecimalPlaces = 2;

  // Transaction Categories
  static const List<String> incomeCategories = [
    'salary',
    'freelance',
    'investment',
    'gift',
    'other_income',
  ];

  static const List<String> expenseCategories = [
    'food',
    'transport',
    'entertainment',
    'shopping',
    'bills',
    'healthcare',
    'education',
    'other_expense',
  ];

  // Wallet Types
  static const List<String> walletTypes = [
    'cash',
    'bank',
    'credit',
    'investment',
    'crypto',
  ];

  // UI Constants
  static const double cardElevation = 4.0;
  static const double compactCardElevation = 2.0;
  static const double buttonBorderRadius = 8.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);

  // Colors (Material 3 compatible)
  static const int primaryColorValue = 0xFF4CAF50; // Green for money
  static const int secondaryColorValue = 0xFF2196F3; // Blue
  static const int incomeColorValue = 0xFF4CAF50; // Green
  static const int expenseColorValue = 0xFFF44336; // Red
  static const int transferColorValue = 0xFFFF9800; // Orange

  // Asset Paths
  static const String iconsPath = 'packages/airomoney/assets/icons/';
  static const String imagesPath = 'packages/airomoney/assets/images/';
  static const String chartsPath = 'packages/airomoney/assets/charts/';

  // Storage Keys
  static const String transactionsKey = 'airomoney_transactions';
  static const String walletsKey = 'airomoney_wallets';
  static const String categoriesKey = 'airomoney_categories';
  static const String budgetKey = 'airomoney_budget';
  static const String settingsKey = 'airomoney_settings';
  static const String currencyKey = 'airomoney_currency';

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String monthYearFormat = 'MMMM yyyy';

  // Export Formats
  static const List<String> exportFormats = ['CSV', 'PDF', 'Excel'];

  // Notification Types
  static const String budgetExceededNotification = 'budget_exceeded';
  static const String lowBalanceNotification = 'low_balance';
  static const String recurringTransactionNotification = 'recurring_transaction';
  static const String monthlyReportNotification = 'monthly_report';

  // Analytics Periods
  static const List<String> analyticsPeriods = [
    'week',
    'month',
    'quarter',
    'year',
    'all_time',
  ];

  // Chart Colors
  static const List<int> chartColors = [
    0xFF4CAF50, // Green
    0xFFF44336, // Red
    0xFF2196F3, // Blue
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFF607D8B, // Blue Grey
    0xFF795548, // Brown
    0xFF009688, // Teal
    0xFFE91E63, // Pink
    0xFF3F51B5, // Indigo
  ];
}
