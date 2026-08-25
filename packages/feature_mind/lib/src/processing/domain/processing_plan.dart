import 'package:flutter/foundation.dart';

import 'processing_profile.dart';

/// Planner output: what strategy was chosen and why (shown in UI).
@immutable
class ProcessingPlan {
  const ProcessingPlan({
    required this.intent,
    required this.requestedProfile,
    required this.effectiveProfile,
    required this.memoryBudgetMb,
    required this.modelTierLabel,
    required this.summaryLine,
    required this.detailLines,
    this.audioDurationSec,
    this.audioBytes,
  });

  final ProcessingIntent intent;
  final ProcessingProfile requestedProfile;
  final ProcessingProfile effectiveProfile;
  final int memoryBudgetMb;
  final String modelTierLabel;
  final String summaryLine;
  final List<String> detailLines;
  final int? audioDurationSec;
  final int? audioBytes;

  String get transparencyLabel => summaryLine;

  String get detailText => detailLines.join('\n');
}
