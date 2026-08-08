import 'package:flutter/material.dart';

import '../../data/services/assistant_runtime_service.dart';

void showAssistantFallbackNotification(
  BuildContext context,
  AssistantRuntimeFallbackDecision fallback,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Switched from ${fallback.failedRuntimeName} to ${fallback.fallbackRuntimeName}: ${fallback.reason}',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
