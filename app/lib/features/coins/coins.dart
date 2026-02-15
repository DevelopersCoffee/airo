/// Coins Feature Module
///
/// AI-native money management feature for the Airo super app.
/// Provides expense tracking, budget management, and expense splitting.
///
/// ## Features
/// - **Phase 1**: Core expense tracking, budget management, safe-to-spend
/// - **Phase 2**: Group expense splitting, settlements, debt simplification
/// - **Phase 3**: Mind AI conversational interface
/// - **Phase 4**: Receipt OCR scanning
///
/// ## Architecture
/// Follows Domain-Driven Design (DDD) with clean architecture:
/// - Domain Layer: Business entities, repositories, services
/// - Application Layer: State management (Riverpod), use cases
/// - Data Layer: Database implementations, mappers
/// - Presentation Layer: Screens, widgets
///
/// ## Usage
/// ```dart
/// import 'package:app/features/coins/coins.dart';
/// ```
library coins;

// Domain - Entities
export 'domain/entities/account.dart';
export 'domain/entities/budget.dart';
export 'domain/entities/category.dart';
export 'domain/entities/group.dart';
export 'domain/entities/group_member.dart';
export 'domain/entities/investment.dart';
export 'domain/entities/settlement.dart';
export 'domain/entities/shared_expense.dart';
export 'domain/entities/split_entry.dart';
export 'domain/entities/subscription.dart';
export 'domain/entities/transaction.dart';

// Domain - Models
export 'domain/models/balance_summary.dart';
export 'domain/models/budget_status.dart';
export 'domain/models/currency.dart';
export 'domain/models/debt_entry.dart';
export 'domain/models/safe_to_spend.dart';

// Domain - Repositories
export 'domain/repositories/account_repository.dart';
export 'domain/repositories/budget_repository.dart';
export 'domain/repositories/group_repository.dart';
export 'domain/repositories/settlement_repository.dart';
export 'domain/repositories/transaction_repository.dart';

// Domain - Services
export 'domain/services/balance_engine.dart';
export 'domain/services/budget_engine.dart';
export 'domain/services/debt_simplifier.dart';
export 'domain/services/split_calculator.dart';

// Domain - Errors
export 'domain/errors/coins_errors.dart';

// Application - Providers
export 'application/providers/budget_providers.dart';
export 'application/providers/dashboard_providers.dart';
export 'application/providers/expense_providers.dart';
export 'application/providers/group_providers.dart';
export 'application/providers/settlement_providers.dart';
export 'application/providers/split_providers.dart';

// Application - Use Cases
export 'application/use_cases/add_expense_use_case.dart';
export 'application/use_cases/add_split_use_case.dart';
export 'application/use_cases/calculate_balances_use_case.dart';
export 'application/use_cases/calculate_safe_to_spend_use_case.dart';
export 'application/use_cases/create_group_use_case.dart';
export 'application/use_cases/delete_expense_use_case.dart';
export 'application/use_cases/record_settlement_use_case.dart';
export 'application/use_cases/set_budget_use_case.dart';
export 'application/use_cases/update_expense_use_case.dart';

// Application - Services
export 'application/services/coins_notification_service.dart';
export 'application/services/coins_sync_service.dart';

// Data - Repositories
export 'data/repositories/account_repository_impl.dart';
export 'data/repositories/budget_repository_impl.dart';
export 'data/repositories/group_repository_impl.dart';
export 'data/repositories/settlement_repository_impl.dart';
export 'data/repositories/transaction_repository_impl.dart';

// Data - Datasources
export 'data/datasources/coins_local_datasource.dart';
export 'data/datasources/coins_local_datasource_impl.dart';

// Data - Mappers
export 'data/mappers/account_mapper.dart';
export 'data/mappers/budget_mapper.dart';
export 'data/mappers/group_mapper.dart';
export 'data/mappers/settlement_mapper.dart';
export 'data/mappers/transaction_mapper.dart';

// Presentation - Screens
export 'presentation/screens/add_expense_screen.dart';
export 'presentation/screens/add_split_expense_screen.dart';
export 'presentation/screens/budget_management_screen.dart';
export 'presentation/screens/coins_dashboard_screen.dart';
export 'presentation/screens/group_detail_screen.dart';
export 'presentation/screens/groups_list_screen.dart';

// Presentation - Widgets
export 'presentation/widgets/budget_progress_card.dart';
export 'presentation/widgets/expense_card.dart';
export 'presentation/widgets/member_avatar.dart';
export 'presentation/widgets/safe_to_spend_card.dart';

