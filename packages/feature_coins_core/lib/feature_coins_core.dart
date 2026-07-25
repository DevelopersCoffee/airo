/// Pure domain layer of Airo Coins finance (money/budgets/groups):
/// entities, value models, repository contracts, and calculation engines.
/// Zero Flutter/app dependencies — see issue #1111 and ADR-0010.
library;

export 'src/entities/account.dart';
export 'src/entities/budget.dart';
export 'src/entities/category.dart';
export 'src/entities/group.dart';
export 'src/entities/group_member.dart';
export 'src/entities/investment.dart';
export 'src/entities/settlement.dart';
export 'src/entities/shared_expense.dart';
export 'src/entities/split_entry.dart';
export 'src/entities/subscription.dart';
export 'src/entities/transaction.dart';
export 'src/errors/coins_errors.dart';
export 'src/models/balance_summary.dart';
export 'src/models/budget_status.dart';
export 'src/models/currency.dart';
export 'src/models/debt_entry.dart';
export 'src/models/safe_to_spend.dart';
export 'src/repositories/account_repository.dart';
export 'src/repositories/budget_repository.dart' hide Result;
export 'src/repositories/group_repository.dart' hide Result;
export 'src/repositories/settlement_repository.dart' hide Result;
export 'src/repositories/transaction_repository.dart' hide Result;
export 'src/services/balance_engine.dart';
export 'src/services/budget_engine.dart';
export 'src/services/debt_simplifier.dart';
export 'src/services/finance_insight_service.dart';
export 'src/services/finance_message_parser.dart';
export 'src/services/quick_add_expense_parser.dart';
export 'src/services/split_calculator.dart';
