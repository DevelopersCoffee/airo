import 'package:equatable/equatable.dart';

import 'enums.dart';

class DietProfile extends Equatable {
  const DietProfile({
    required this.dietType,
    required this.householdSize,
    required this.weeklyBudget,
    required this.cookingDays,
    required this.moods,
    this.allergies = '',
    this.dislikes = '',
    this.age,
    this.heightCm,
    this.weightKg,
    this.preferredStore = '',
  });

  final DietType dietType;
  final int householdSize;
  final double weeklyBudget;
  final List<Weekday> cookingDays;
  final Set<FoodMood> moods;
  final String allergies;
  final String dislikes;
  final int? age;
  final int? heightCm;
  final double? weightKg;
  final String preferredStore;

  DietProfile copyWith({
    DietType? dietType,
    int? householdSize,
    double? weeklyBudget,
    List<Weekday>? cookingDays,
    Set<FoodMood>? moods,
    String? allergies,
    String? dislikes,
    int? age,
    int? heightCm,
    double? weightKg,
    String? preferredStore,
  }) => DietProfile(
    dietType: dietType ?? this.dietType,
    householdSize: householdSize ?? this.householdSize,
    weeklyBudget: weeklyBudget ?? this.weeklyBudget,
    cookingDays: cookingDays ?? this.cookingDays,
    moods: moods ?? this.moods,
    allergies: allergies ?? this.allergies,
    dislikes: dislikes ?? this.dislikes,
    age: age ?? this.age,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    preferredStore: preferredStore ?? this.preferredStore,
  );

  Map<String, Object?> toJson() => {
    'dietType': dietType.name,
    'householdSize': householdSize,
    'weeklyBudget': weeklyBudget,
    'cookingDays': cookingDays.map((d) => d.name).toList(),
    'moods': moods.map((m) => m.name).toList(),
    'allergies': allergies,
    'dislikes': dislikes,
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'preferredStore': preferredStore,
  };

  factory DietProfile.fromJson(Map<String, Object?> json) => DietProfile(
    dietType: DietType.values.byName(json['dietType'] as String),
    householdSize: json['householdSize'] as int,
    weeklyBudget: (json['weeklyBudget'] as num).toDouble(),
    cookingDays: [
      for (final name in json['cookingDays'] as List<dynamic>)
        Weekday.values.byName(name as String),
    ],
    moods: {
      for (final name in json['moods'] as List<dynamic>)
        FoodMood.values.byName(name as String),
    },
    allergies: json['allergies'] as String? ?? '',
    dislikes: json['dislikes'] as String? ?? '',
    age: json['age'] as int?,
    heightCm: json['heightCm'] as int?,
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    preferredStore: json['preferredStore'] as String? ?? '',
  );

  @override
  List<Object?> get props => [
    dietType,
    householdSize,
    weeklyBudget,
    cookingDays,
    moods,
    allergies,
    dislikes,
    age,
    heightCm,
    weightKg,
    preferredStore,
  ];
}
