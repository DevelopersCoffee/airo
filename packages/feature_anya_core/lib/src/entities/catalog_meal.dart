import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'ingredient.dart';
import 'nutrition.dart';

class CatalogMeal extends Equatable {
  const CatalogMeal({
    required this.id,
    required this.name,
    required this.servings,
    required this.nutrition,
    required this.cookTimeMinutes,
    required this.diet,
    required this.moods,
    required this.ingredients,
    required this.instructions,
    required this.estimatedCost,
  });

  final String id;
  final String name;
  final int servings;
  final Nutrition nutrition;
  final int cookTimeMinutes;

  /// Strictest animal-product level this meal satisfies.
  final DietType diet;
  final Set<FoodMood> moods;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final double estimatedCost;

  bool isAllowedFor({
    required DietType userDiet,
    required String allergies,
    required String dislikes,
  }) {
    if (!_matchesDiet(userDiet)) return false;
    final banned = _tokens('$allergies, $dislikes');
    if (banned.isEmpty) return true;
    final haystack = [
      name.toLowerCase(),
      ...ingredients.map((i) => i.name.toLowerCase()),
    ].join(' ');
    return banned.every((token) => !haystack.contains(token));
  }

  bool _matchesDiet(DietType user) {
    return switch (user) {
      DietType.vegan => diet == DietType.vegan,
      DietType.vegetarian =>
        diet == DietType.vegan || diet == DietType.vegetarian,
      DietType.pescatarian => diet != DietType.none,
      DietType.none => true,
    };
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'servings': servings,
    'nutrition': nutrition.toJson(),
    'cookTimeMinutes': cookTimeMinutes,
    'diet': diet.name,
    'moods': moods.map((m) => m.name).toList(),
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'instructions': instructions,
    'estimatedCost': estimatedCost,
  };

  factory CatalogMeal.fromJson(Map<String, Object?> json) => CatalogMeal(
    id: json['id'] as String,
    name: json['name'] as String,
    servings: json['servings'] as int,
    nutrition: Nutrition.fromJson(
      Map<String, Object?>.from(json['nutrition']! as Map),
    ),
    cookTimeMinutes: json['cookTimeMinutes'] as int,
    diet: DietType.values.byName(json['diet'] as String),
    moods: {
      for (final name in json['moods'] as List<dynamic>)
        FoodMood.values.byName(name as String),
    },
    ingredients: [
      for (final item in json['ingredients'] as List<dynamic>)
        Ingredient.fromJson(Map<String, Object?>.from(item as Map)),
    ],
    instructions: [
      for (final step in json['instructions'] as List<dynamic>) step as String,
    ],
    estimatedCost: (json['estimatedCost'] as num).toDouble(),
  );

  @override
  List<Object?> get props => [
    id,
    name,
    servings,
    nutrition,
    cookTimeMinutes,
    diet,
    moods,
    ingredients,
    instructions,
    estimatedCost,
  ];
}

List<String> _tokens(String raw) => raw
    .split(RegExp(r'[,;\n]'))
    .map((part) => part.trim().toLowerCase())
    .where((part) => part.isNotEmpty)
    .toList();
