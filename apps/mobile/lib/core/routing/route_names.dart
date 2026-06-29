class RouteNames {
  // Private constructor to prevent instantiation
  RouteNames._();

  // Route paths
  static const String home = '/';
  static const String airo = '/airo';
  static const String airomoney = '/airomoney';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String settings = '/settings';

  // Bill Split
  static const String billSplit = '/money/split';

  // Coins Feature Routes
  static const String coinsDashboard = 'coins_dashboard';
  static const String coinsAddExpense = 'coins_add_expense';
  static const String coinsBudgets = 'coins_budgets';
  static const String coinsGroups = 'coins_groups';
  static const String coinsGroupDetail = 'coins_group_detail';
  static const String coinsAddSplit = 'coins_add_split';

  // Coins Full Paths (for direct navigation)
  static const String coinsDashboardPath = '/money/dashboard';
  static const String coinsAddExpensePath = '/money/add-expense';
  static const String coinsBudgetsPath = '/money/budgets';
  static const String coinsGroupsPath = '/money/groups';
}
