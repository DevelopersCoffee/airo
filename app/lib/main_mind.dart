import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';

/// Airo Mind. Pairs with `pubspec_mind.yaml`.
///
/// Record a meeting, watch it transcribe, read the minutes, search what was
/// said — with no network involved at any step.
void main() {
  runApp(const AiroMindApp());
}

class AiroMindApp extends StatefulWidget {
  const AiroMindApp({super.key});

  @override
  State<AiroMindApp> createState() => _AiroMindAppState();
}

class _AiroMindAppState extends State<AiroMindApp> {
  // Held here rather than rebuilt: it owns the loaded models and the
  // microphone, neither of which survives being recreated on a rebuild.
  final _service = MindService();

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Airo Mind',
      theme: ThemeData(useMaterial3: true),
      home: MindHomeScreen(service: _service),
    );
  }
}
