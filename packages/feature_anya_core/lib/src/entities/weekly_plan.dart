import 'package:equatable/equatable.dart';

import 'catalog_meal.dart';
import 'diet_profile.dart';
import 'enums.dart';
import 'nutrition.dart';

class PlannedMeal extends Equatable {
  const PlannedMeal({
    required this.id,
    required this.weekday,
    required this.mealType,
    required this.meal,
    required this.servings,
  });

  final String id;
  final Weekday weekday;
  final MealType mealType;
  final CatalogMeal meal;
  final int servings;

  double get servingFactor => servings / meal.servings;

  Nutrition get nutrition => meal.nutrition.scaled(servingFactor);

  double get estimatedCost => meal.estimatedCost * servingFactor;

  Map<String, Object?> toJson() => {
    'id': id,
    'weekday': weekday.name,
    'mealType': mealType.name,
    'meal': meal.toJson(),
    'servings': servings,
  };

  factory PlannedMeal.fromJson(Map<String, Object?> json) => PlannedMeal(
    id: json['id'] as String,
    weekday: Weekday.values.byName(json['weekday'] as String),
    mealType: MealType.values.byName(json['mealType'] as String),
    meal: CatalogMeal.fromJson(Map<String, Object?>.from(json['meal']! as Map)),
    servings: json['servings'] as int,
  );

  @override
  List<Object?> get props => [id, weekday, mealType, meal, servings];
}

class WeeklyPlan extends Equatable {
  const WeeklyPlan({
    required this.weekStartIso,
    required this.profile,
    required this.meals,
  });

  final String weekStartIso;
  final DietProfile profile;
  final List<PlannedMeal> meals;

  Nutrition get totals =>
      meals.fold(Nutrition.zero, (sum, m) => sum + m.nutrition);

  double get estimatedCost =>
      meals.fold(0.0, (sum, m) => sum + m.estimatedCost);

  bool get overBudget => estimatedCost > profile.weeklyBudget;

  Map<String, Object?> toJson() => {
    'weekStartIso': weekStartIso,
    'profile': profile.toJson(),
    'meals': meals.map((m) => m.toJson()).toList(),
  };

  factory WeeklyPlan.fromJson(Map<String, Object?> json) => WeeklyPlan(
    weekStartIso: json['weekStartIso'] as String,
    profile: DietProfile.fromJson(
      Map<String, Object?>.from(json['profile']! as Map),
    ),
    meals: [
      for (final meal in json['meals'] as List<dynamic>)
        PlannedMeal.fromJson(Map<String, Object?>.from(meal as Map)),
    ],
  );

  @override
  List<Object?> get props => [weekStartIso, profile, meals];
}
