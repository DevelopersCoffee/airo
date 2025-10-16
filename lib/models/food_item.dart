import 'package:sqflite/sqflite.dart';

/// Food item model for storing food data
class FoodItem {
  final int? id;
  final String name;
  final String? description;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final String? imagePath;
  final String? extractedText;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String userId;

  FoodItem({
    this.id,
    required this.name,
    this.description,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.imagePath,
    this.extractedText,
    required this.createdAt,
    this.updatedAt,
    required this.userId,
  });

  /// Convert FoodItem to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'imagePath': imagePath,
      'extractedText': extractedText,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'userId': userId,
    };
  }

  /// Create FoodItem from JSON
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String?,
      calories: (json['calories'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      fiber: (json['fiber'] as num?)?.toDouble(),
      imagePath: json['imagePath'] as String?,
      extractedText: json['extractedText'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      userId: json['userId'] as String,
    );
  }

  /// Create a copy with modified fields
  FoodItem copyWith({
    int? id,
    String? name,
    String? description,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    String? imagePath,
    String? extractedText,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      imagePath: imagePath ?? this.imagePath,
      extractedText: extractedText ?? this.extractedText,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }

  @override
  String toString() {
    return 'FoodItem(id: $id, name: $name, calories: $calories, protein: $protein, carbs: $carbs, fat: $fat)';
  }
}

