import 'package:equatable/equatable.dart';

import 'enums.dart';

/// One food line. [quantityRaw] is the original string from a PDF or editor.
class FoodItem extends Equatable {
  const FoodItem({
    required this.name,
    required this.quantityRaw,
    this.quantityUninterpreted = false,
  });

  final String name;
  final String quantityRaw;
  final bool quantityUninterpreted;

  FoodItem copyWith({
    String? name,
    String? quantityRaw,
    bool? quantityUninterpreted,
  }) => FoodItem(
    name: name ?? this.name,
    quantityRaw: quantityRaw ?? this.quantityRaw,
    quantityUninterpreted: quantityUninterpreted ?? this.quantityUninterpreted,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'quantityRaw': quantityRaw,
    'quantityUninterpreted': quantityUninterpreted,
  };

  factory FoodItem.fromJson(Map<String, Object?> json) => FoodItem(
    name: json['name'] as String,
    quantityRaw: json['quantityRaw'] as String,
    quantityUninterpreted: json['quantityUninterpreted'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [name, quantityRaw, quantityUninterpreted];
}

class MealSlot extends Equatable {
  const MealSlot({
    required this.type,
    required this.items,
    this.time,
    this.catalogMealId,
  });

  final MealType type;
  final String? time;
  final List<FoodItem> items;
  final String? catalogMealId;

  MealSlot copyWith({
    MealType? type,
    String? time,
    List<FoodItem>? items,
    String? catalogMealId,
  }) => MealSlot(
    type: type ?? this.type,
    time: time ?? this.time,
    items: items ?? this.items,
    catalogMealId: catalogMealId ?? this.catalogMealId,
  );

  Map<String, Object?> toJson() => {
    'type': type.name,
    'time': time,
    'items': items.map((item) => item.toJson()).toList(),
    'catalogMealId': catalogMealId,
  };

  factory MealSlot.fromJson(Map<String, Object?> json) => MealSlot(
    type: MealType.values.byName(json['type'] as String),
    time: json['time'] as String?,
    items: [
      for (final item in json['items'] as List<dynamic>)
        FoodItem.fromJson(Map<String, Object?>.from(item as Map)),
    ],
    catalogMealId: json['catalogMealId'] as String?,
  );

  @override
  List<Object?> get props => [type, time, items, catalogMealId];
}

class DietDay extends Equatable {
  const DietDay({required this.dayNumber, required this.meals, this.weekday});

  final int dayNumber;
  final Weekday? weekday;
  final List<MealSlot> meals;

  DietDay copyWith({int? dayNumber, Weekday? weekday, List<MealSlot>? meals}) =>
      DietDay(
        dayNumber: dayNumber ?? this.dayNumber,
        weekday: weekday ?? this.weekday,
        meals: meals ?? this.meals,
      );

  Map<String, Object?> toJson() => {
    'dayNumber': dayNumber,
    'weekday': weekday?.name,
    'meals': meals.map((m) => m.toJson()).toList(),
  };

  factory DietDay.fromJson(Map<String, Object?> json) => DietDay(
    dayNumber: json['dayNumber'] as int,
    weekday: json['weekday'] == null
        ? null
        : Weekday.values.byName(json['weekday'] as String),
    meals: [
      for (final meal in json['meals'] as List<dynamic>)
        MealSlot.fromJson(Map<String, Object?>.from(meal as Map)),
    ],
  );

  @override
  List<Object?> get props => [dayNumber, weekday, meals];
}

class DietRule extends Equatable {
  const DietRule({this.allowedFoods = const [], this.avoidFoods = const []});

  final List<String> allowedFoods;
  final List<String> avoidFoods;

  Map<String, Object?> toJson() => {
    'allowedFoods': allowedFoods,
    'avoidFoods': avoidFoods,
  };

  factory DietRule.fromJson(Map<String, Object?> json) => DietRule(
    allowedFoods: [
      for (final item in json['allowedFoods'] as List<dynamic>? ?? const [])
        item as String,
    ],
    avoidFoods: [
      for (final item in json['avoidFoods'] as List<dynamic>? ?? const [])
        item as String,
    ],
  );

  @override
  List<Object?> get props => [allowedFoods, avoidFoods];
}

class DietPhase extends Equatable {
  const DietPhase({required this.id, required this.name, required this.days});

  final String id;
  final String name;
  final List<DietDay> days;

  DietPhase copyWith({String? id, String? name, List<DietDay>? days}) =>
      DietPhase(
        id: id ?? this.id,
        name: name ?? this.name,
        days: days ?? this.days,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'days': days.map((d) => d.toJson()).toList(),
  };

  factory DietPhase.fromJson(Map<String, Object?> json) => DietPhase(
    id: json['id'] as String,
    name: json['name'] as String,
    days: [
      for (final day in json['days'] as List<dynamic>)
        DietDay.fromJson(Map<String, Object?>.from(day as Map)),
    ],
  );

  @override
  List<Object?> get props => [id, name, days];
}

class DietProgram extends Equatable {
  const DietProgram({
    required this.id,
    required this.title,
    required this.source,
    required this.phases,
    this.rules = const DietRule(),
    this.guidelines = const [],
  });

  final String id;
  final String title;
  final ProgramSource source;
  final List<DietPhase> phases;
  final DietRule rules;
  final List<String> guidelines;

  List<DietDay> get allDays => [for (final phase in phases) ...phase.days];

  DietProgram copyWith({
    String? id,
    String? title,
    ProgramSource? source,
    List<DietPhase>? phases,
    DietRule? rules,
    List<String>? guidelines,
  }) => DietProgram(
    id: id ?? this.id,
    title: title ?? this.title,
    source: source ?? this.source,
    phases: phases ?? this.phases,
    rules: rules ?? this.rules,
    guidelines: guidelines ?? this.guidelines,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'source': source.name,
    'phases': phases.map((p) => p.toJson()).toList(),
    'rules': rules.toJson(),
    'guidelines': guidelines,
  };

  factory DietProgram.fromJson(Map<String, Object?> json) => DietProgram(
    id: json['id'] as String,
    title: json['title'] as String,
    source: ProgramSource.values.byName(json['source'] as String),
    phases: [
      for (final phase in json['phases'] as List<dynamic>)
        DietPhase.fromJson(Map<String, Object?>.from(phase as Map)),
    ],
    rules: json['rules'] == null
        ? const DietRule()
        : DietRule.fromJson(Map<String, Object?>.from(json['rules']! as Map)),
    guidelines: [
      for (final line in json['guidelines'] as List<dynamic>? ?? const [])
        line as String,
    ],
  );

  @override
  List<Object?> get props => [id, title, source, phases, rules, guidelines];
}
