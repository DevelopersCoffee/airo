import 'package:feature_assistant/feature_assistant.dart';
import 'package:feature_coin/feature_coin.dart';

class RouteNames {
  // Private constructor to prevent instantiation
  RouteNames._();

  // Route paths
  static const String home = '/';
  static const String airo = '/airo';
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String settings = '/settings';

  // Assistant (Airo Mind). Owned by packages/feature_assistant so the super
  // app and the standalone Mind shell mount identical paths.
  static const String assistant = AssistantRouteNames.assistant;
  static const String assistantChat = AssistantRouteNames.chat;
  static const String assistantNotifications =
      AssistantRouteNames.notifications;
  static const String assistantProfile = AssistantRouteNames.profile;
  static const String assistantModels = AssistantRouteNames.models;
  static const String assistantDeviceCapabilities =
      AssistantRouteNames.deviceCapabilities;
  static const String assistantModelAdvisor = AssistantRouteNames.modelAdvisor;
  static const String assistantPromptLab = AssistantRouteNames.promptLab;
  static const String assistantAudioScribe = AssistantRouteNames.audioScribe;
  static const String assistantAgentSkills = AssistantRouteNames.agentSkills;
  static const String assistantMobileActions =
      AssistantRouteNames.mobileActions;
  static const String wellbeing = AssistantRouteNames.wellbeing;

  // Bill Split
  static const String billSplit = '/money/split';

  // Coins Feature Routes
  static const String coinsDashboard = 'coins_dashboard';
  static const String coinsAddExpense = 'coins_add_expense';
  static const String coinsBudgets = 'coins_budgets';
  static const String coinsGroups = 'coins_groups';
  static const String coinsGroupDetail = 'coins_group_detail';
  static const String coinsAddSplit = 'coins_add_split';
  // Owned by packages/feature_coin so both shells mount the same names.
  static const String coinVault = CoinVaultRouteNames.vault;
  static const String coinVaultAdd = CoinVaultRouteNames.add;
  static const String coinVaultEdit = CoinVaultRouteNames.edit;

  // Coins Full Paths (for direct navigation)
  static const String coinsDashboardPath = '/money/dashboard';
  static const String coinsAddExpensePath = '/money/add-expense';
  static const String coinsBudgetsPath = '/money/budgets';
  static const String coinsGroupsPath = '/money/groups';
  static const String coinVaultPath = '/money/vault';
}
