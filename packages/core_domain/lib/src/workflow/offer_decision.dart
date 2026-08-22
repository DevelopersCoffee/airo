import 'package:meta/meta.dart';

enum OfferDecisionKind {
  offerable,
  notOfferable,
  alreadyOffered;

  static OfferDecisionKind fromJson(String value) {
    switch (value) {
      case 'offerable':
        return OfferDecisionKind.offerable;
      case 'not_offerable':
        return OfferDecisionKind.notOfferable;
      case 'already_offered':
        return OfferDecisionKind.alreadyOffered;
      default:
        throw ArgumentError('Unknown offer decision: $value');
    }
  }

  String toJson() {
    switch (this) {
      case OfferDecisionKind.offerable:
        return 'offerable';
      case OfferDecisionKind.notOfferable:
        return 'not_offerable';
      case OfferDecisionKind.alreadyOffered:
        return 'already_offered';
    }
  }
}

@immutable
class OfferDecision {
  const OfferDecision({
    required this.kind,
    this.reason = '',
  });

  final OfferDecisionKind kind;
  final String reason;

  bool get isOfferable => kind == OfferDecisionKind.offerable;

  factory OfferDecision.fromJson(Map<String, dynamic> json) => OfferDecision(
    kind: OfferDecisionKind.fromJson(json['kind'] as String),
    reason: json['reason'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.toJson(),
    if (reason.isNotEmpty) 'reason': reason,
  };
}
