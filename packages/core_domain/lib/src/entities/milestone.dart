import 'package:meta/meta.dart';

import 'action_item.dart';
import 'life_track.dart';

@immutable
class Milestone {
  const Milestone({
    required this.id,
    required this.trackId,
    required this.name,
    required this.objective,
    required this.sortOrder,
    required this.status,
    required this.actionItems,
  });

  final String id;
  final String trackId;
  final String name;
  final String objective;
  final int sortOrder;
  final ItemStatus status;
  final List<ActionItem> actionItems;

  double get progress {
    if (actionItems.isEmpty) return 0;
    final activeItems = actionItems
        .where((item) => item.status != ItemStatus.skipped)
        .toList(growable: false);
    if (activeItems.isEmpty) return 0;
    final completed = activeItems
        .where((item) => item.status == ItemStatus.done)
        .length;
    return completed / activeItems.length;
  }

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
    id: json['id'] as String,
    trackId: json['track_id'] as String,
    name: json['name'] as String,
    objective: json['objective'] as String,
    sortOrder: json['sort_order'] as int,
    status: _itemStatusFromJson(json['status'] as String),
    actionItems: ((json['action_items'] as List?) ?? const [])
        .map((item) => ActionItem.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'track_id': trackId,
    'name': name,
    'objective': objective,
    'sort_order': sortOrder,
    'status': status.name,
    'action_items': actionItems
        .map((item) => item.toJson())
        .toList(growable: false),
    'progress': progress,
  };

  Milestone copyWith({
    String? id,
    String? trackId,
    String? name,
    String? objective,
    int? sortOrder,
    ItemStatus? status,
    List<ActionItem>? actionItems,
  }) => Milestone(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    name: name ?? this.name,
    objective: objective ?? this.objective,
    sortOrder: sortOrder ?? this.sortOrder,
    status: status ?? this.status,
    actionItems: actionItems ?? this.actionItems,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Milestone &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          trackId == other.trackId &&
          name == other.name &&
          objective == other.objective &&
          sortOrder == other.sortOrder &&
          status == other.status &&
          _listEquals(actionItems, other.actionItems);

  @override
  int get hashCode => Object.hash(
    id,
    trackId,
    name,
    objective,
    sortOrder,
    status,
    Object.hashAll(actionItems),
  );
}

ItemStatus _itemStatusFromJson(String value) =>
    ItemStatus.values.firstWhere((item) => item.name == value);

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
