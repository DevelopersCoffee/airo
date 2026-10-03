import '../entities/category.dart';

/// System categories shown in the NFC / quick capture category step.
///
/// Matches the reel's eight expense labels while reusing the Coins category
/// entity shape (Material icon names, not emoji — consistent with the
/// dashboard and add-expense screens).
class NfcQuickExpenseCategories {
  const NfcQuickExpenseCategories._();

  static final DateTime _seedCreatedAt = DateTime(2026);

  static const List<NfcQuickExpenseCategoryOption> options = [
    NfcQuickExpenseCategoryOption(
      id: 'food',
      label: 'Food',
      iconName: 'restaurant',
      color: '#16A34A',
    ),
    NfcQuickExpenseCategoryOption(
      id: 'transport',
      label: 'Transport',
      iconName: 'directions_car',
      color: '#2563EB',
    ),
    NfcQuickExpenseCategoryOption(
      id: 'shopping',
      label: 'Shopping',
      iconName: 'shopping_bag',
      color: '#9333EA',
    ),
    NfcQuickExpenseCategoryOption(
      id: 'bills',
      label: 'Bills',
      iconName: 'receipt_long',
      color: '#EA580C',
    ),
    NfcQuickExpenseCategoryOption(
      id: 'entertainment',
      label: 'Entertainment',
      iconName: 'movie',
      color: '#DB2777',
    ),
    NfcQuickExpenseCategoryOption(
      id: 'health',
      label: 'Health',
      iconName: 'medical_services',
      color: '#0891B2',
    ),
    NfcQuickExpenseCategoryOption(
      id: 'personal',
      label: 'Personal',
      iconName: 'person',
      color: '#4F46E5',
    ),
    NfcQuickExpenseCategoryOption(
      id: 'other',
      label: 'Other',
      iconName: 'more_horiz',
      color: '#64748B',
    ),
  ];

  static List<Category> asCategoryEntities() {
    return [
      for (var i = 0; i < options.length; i++)
        Category(
          id: options[i].id,
          name: options[i].label,
          type: CategoryType.expense,
          iconName: options[i].iconName,
          color: options[i].color,
          isSystem: true,
          sortOrder: i + 1,
          createdAt: _seedCreatedAt,
        ),
    ];
  }

  static NfcQuickExpenseCategoryOption? byId(String id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }
}

class NfcQuickExpenseCategoryOption {
  const NfcQuickExpenseCategoryOption({
    required this.id,
    required this.label,
    required this.iconName,
    required this.color,
  });

  final String id;
  final String label;
  final String iconName;
  final String color;
}
