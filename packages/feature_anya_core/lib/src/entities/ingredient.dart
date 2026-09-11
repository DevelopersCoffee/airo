import 'package:equatable/equatable.dart';

import 'enums.dart';

class Ingredient extends Equatable {
  const Ingredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.aisle,
  });

  final String name;
  final double quantity;
  final String unit;
  final GroceryAisle aisle;

  Ingredient scaled(double factor) => Ingredient(
    name: name,
    quantity: quantity * factor,
    unit: unit,
    aisle: aisle,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'aisle': aisle.name,
  };

  factory Ingredient.fromJson(Map<String, Object?> json) => Ingredient(
    name: json['name'] as String,
    quantity: (json['quantity'] as num).toDouble(),
    unit: json['unit'] as String,
    aisle: GroceryAisle.values.byName(json['aisle'] as String),
  );

  @override
  List<Object?> get props => [name, quantity, unit, aisle];
}
