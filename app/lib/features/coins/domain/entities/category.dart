import 'package:equatable/equatable.dart';

/// Category types
enum CategoryType {
  expense('Expense'),
  income('Income'),
  both('Both');

  final String displayName;
  const CategoryType(this.displayName);
}

/// Category entity for organizing transactions
///
/// Supports hierarchical categories with parent-child relationships.
///
/// Phase: 1 (Foundation)
/// See: docs/features/coins/DOMAIN_API_CONTRACTS.md
class Category extends Equatable {
  final String id;
  final String name;
  final String? parentId; // For subcategories
  final CategoryType type;
  final String iconName;
  final String color; // Hex color code
  final bool isSystem; // Built-in vs user-created
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Category({
    required this.id,
    required this.name,
    this.parentId,
    required this.type,
    required this.iconName,
    required this.color,
    this.isSystem = false,
    this.sortOrder = 0,
    this.isArchived = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Check if this is a subcategory
  bool get isSubcategory => parentId != null;

  /// Create a copy with updated fields
  Category copyWith({
    String? id,
    String? name,
    String? parentId,
    CategoryType? type,
    String? iconName,
    String? color,
    bool? isSystem,
    int? sortOrder,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      type: type ?? this.type,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      isSystem: isSystem ?? this.isSystem,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        parentId,
        type,
        iconName,
        color,
        isSystem,
        sortOrder,
        isArchived,
        createdAt,
        updatedAt,
      ];
}

