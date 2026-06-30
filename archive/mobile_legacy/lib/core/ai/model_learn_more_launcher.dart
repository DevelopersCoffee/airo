import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

typedef LaunchModelUrl = Future<bool> Function(Uri uri, {LaunchMode mode});

Future<void> launchModelLearnMore(
  BuildContext context,
  OfflineModelInfo model, {
  LaunchModelUrl? launchUrlCallback,
}) async {
  final uri = model.learnMoreUri;
  if (uri == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No official model page is available yet.')),
    );
    return;
  }

  final launch = launchUrlCallback ?? launchUrl;

  try {
    final opened = await launch(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open the model page for ${model.name}.'),
        ),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open the model page for ${model.name}.'),
      ),
    );
  }
}
