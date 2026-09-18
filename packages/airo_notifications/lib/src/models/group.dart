import 'package:equatable/equatable.dart';

enum AiroGroupingStrategy {
  none('none'),
  stack('stack'),
  summary('summary'),
  replace('replace'),
  merge('merge');

  const AiroGroupingStrategy(this.stableId);
  final String stableId;

  static AiroGroupingStrategy parse(String value) {
    return AiroGroupingStrategy.values.firstWhere(
      (e) => e.stableId == value,
      orElse: () => AiroGroupingStrategy.none,
    );
  }
}

class AiroNotificationGroup extends Equatable {
  const AiroNotificationGroup({
    required this.id,
    this.strategy = AiroGroupingStrategy.stack,
    this.summaryTitle,
    this.summaryFormat,
    this.debounceWindow = const Duration(seconds: 5),
    this.maxItems = 10,
  });

  final String id;
  final AiroGroupingStrategy strategy;
  final String? summaryTitle;
  final String? summaryFormat;
  final Duration debounceWindow;
  final int maxItems;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'strategy': strategy.stableId,
      if (summaryTitle != null) 'summary_title': summaryTitle,
      if (summaryFormat != null) 'summary_format': summaryFormat,
      'debounce_window_ms': debounceWindow.inMilliseconds,
      'max_items': maxItems,
    };
  }

  factory AiroNotificationGroup.fromJson(Map<String, Object?> json) {
    return AiroNotificationGroup(
      id: json['id'] as String,
      strategy: AiroGroupingStrategy.parse(json['strategy'] as String? ?? ''),
      summaryTitle: json['summary_title'] as String?,
      summaryFormat: json['summary_format'] as String?,
      debounceWindow: Duration(
        milliseconds: json['debounce_window_ms'] as int? ?? 5000,
      ),
      maxItems: json['max_items'] as int? ?? 10,
    );
  }

  @override
  List<Object?> get props => [
        id,
        strategy,
        summaryTitle,
        summaryFormat,
        debounceWindow,
        maxItems,
      ];
}
