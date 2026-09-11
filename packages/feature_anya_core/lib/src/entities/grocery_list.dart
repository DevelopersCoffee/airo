import 'package:equatable/equatable.dart';

import 'enums.dart';

class GroceryLine extends Equatable {
  const GroceryLine({
    required this.name,
    required this.quantityLabel,
    required this.aisle,
    this.fromUnmappedPdf = false,
  });

  final String name;
  final String quantityLabel;
  final GroceryAisle aisle;
  final bool fromUnmappedPdf;

  String get key => '${aisle.name}:${name.toLowerCase()}:${quantityLabel}';

  Map<String, Object?> toJson() => {
    'name': name,
    'quantityLabel': quantityLabel,
    'aisle': aisle.name,
    'fromUnmappedPdf': fromUnmappedPdf,
  };

  factory GroceryLine.fromJson(Map<String, Object?> json) => GroceryLine(
    name: json['name'] as String,
    quantityLabel: json['quantityLabel'] as String,
    aisle: GroceryAisle.values.byName(json['aisle'] as String),
    fromUnmappedPdf: json['fromUnmappedPdf'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [name, quantityLabel, aisle, fromUnmappedPdf];
}

class GroceryList extends Equatable {
  const GroceryList({required this.lines});

  final List<GroceryLine> lines;

  Map<GroceryAisle, List<GroceryLine>> get grouped {
    final map = <GroceryAisle, List<GroceryLine>>{};
    for (final line in lines) {
      map.putIfAbsent(line.aisle, () => []).add(line);
    }
    return map;
  }

  Map<String, Object?> toJson() => {
    'lines': lines.map((l) => l.toJson()).toList(),
  };

  factory GroceryList.fromJson(Map<String, Object?> json) => GroceryList(
    lines: [
      for (final line in json['lines'] as List<dynamic>)
        GroceryLine.fromJson(Map<String, Object?>.from(line as Map)),
    ],
  );

  @override
  List<Object?> get props => [lines];
}
