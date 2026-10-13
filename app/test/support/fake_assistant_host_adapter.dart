import 'package:core_ai/core_ai.dart' show SafetyProfile;
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';

/// Minimal host double for app-layer widget tests.
class FakeAssistantHostAdapter extends AssistantHostAdapter {
  FakeAssistantHostAdapter({
    SafetyProfile safetyProfile = SafetyProfile.strict,
    this.autoFallbackEnabled = true,
    int modelContextLength = 2048,
    this.isAndroidHost = false,
  }) : safetyProfile = safetyProfile,
       modelContextLength = modelContextLength;

  final List<String> calls = <String>[];

  @override
  final SafetyProfile safetyProfile;

  @override
  final bool autoFallbackEnabled;

  @override
  int modelContextLength;

  @override
  final bool isAndroidHost;

  @override
  AssistantHostUser? get currentUser => null;

  @override
  Future<void> signOutAndReturnToLogin(BuildContext context) async {}

  @override
  void openHostSettings(BuildContext context) => calls.add('openHostSettings');

  @override
  void openHttpStatusReference(BuildContext context) {}

  @override
  void openDictionaryDemo(BuildContext context) {}

  @override
  Future<bool> speakAloud(String text) async => true;

  @override
  Widget wrapWithDictionarySelection({required Widget child}) => child;

  @override
  void showWordDefinition(BuildContext context, String word) {}

  @override
  Widget dictionaryAwareText(String text) => Text(text);

  @override
  Future<void> showBugReportDialog(BuildContext context) async {}

  @override
  Widget aiPreferencesSection() =>
      const SizedBox.shrink(key: Key('fake-ai-preferences-section'));

  @override
  Future<void> setModelContextLength(int tokens) async {
    modelContextLength = tokens;
  }

  @override
  Future<void> repairModelPackage(String packageId) async {}

  @override
  Future<AssistantFinanceIngestion?> ingestFinanceMessage(
    String message,
  ) async => null;
}
