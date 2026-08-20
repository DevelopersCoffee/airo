import 'package:meta/meta.dart';

/// Machine-stable reason Airo picked (or would pick) a model.
enum WhySelectedCode {
  automatic,
  installed,
  fitsMemory,
  language,
  context,
  taskFit,
  compact,
  official,
  override,
}

/// One human-readable selection reason. Codes stay stable; [message] is
/// English for the Why drawer and must not name a product surface.
@immutable
class WhySelectedReason {
  const WhySelectedReason({required this.code, required this.message});

  final WhySelectedCode code;
  final String message;
}

/// Explanation for a ranked pick. The UI renders this; it must not invent
/// extra reasons from model ids.
@immutable
class WhySelected {
  const WhySelected({
    required this.modelId,
    required this.automatic,
    required this.reasons,
  });

  final String modelId;
  final bool automatic;
  final List<WhySelectedReason> reasons;
}
