import 'package:equatable/equatable.dart';

/// Deterministic nutrition snapshot. Source of truth is the catalog or an
/// explicit imported value — never an LLM guess.
class Nutrition extends Equatable {
  const Nutrition({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  static const zero = Nutrition(calories: 0, proteinG: 0, carbsG: 0, fatG: 0);

  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  Nutrition scaled(double factor) => Nutrition(
    calories: (calories * factor).round(),
    proteinG: proteinG * factor,
    carbsG: carbsG * factor,
    fatG: fatG * factor,
  );

  Nutrition operator +(Nutrition other) => Nutrition(
    calories: calories + other.calories,
    proteinG: proteinG + other.proteinG,
    carbsG: carbsG + other.carbsG,
    fatG: fatG + other.fatG,
  );

  Map<String, Object?> toJson() => {
    'calories': calories,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
  };

  factory Nutrition.fromJson(Map<String, Object?> json) => Nutrition(
    calories: json['calories'] as int,
    proteinG: (json['proteinG'] as num).toDouble(),
    carbsG: (json['carbsG'] as num).toDouble(),
    fatG: (json['fatG'] as num).toDouble(),
  );

  @override
  List<Object?> get props => [calories, proteinG, carbsG, fatG];
}
