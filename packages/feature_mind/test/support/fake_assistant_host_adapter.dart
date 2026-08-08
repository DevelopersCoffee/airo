import 'package:core_ai/core_ai.dart' show SafetyProfile;
import 'package:feature_mind/src/host/assistant_host_adapter.dart';
import 'package:flutter/material.dart';

/// Test double for [AssistantHostAdapter].
///
/// Every member is inert by default so a widget test can pump an assistant
/// screen without any host service; individual behaviours are opted into
/// through the constructor.
class FakeAssistantHostAdapter extends AssistantHostAdapter {
  FakeAssistantHostAdapter({
    this.currentUser,
    this.safetyProfile = SafetyProfile.strict,
    this.autoFallbackEnabled = true,
    this.modelContextLength = 2048,
    this.isAndroidHost = false,
    this.speakResult = true,
    this.onIngest,
  });

  /// Optional stub for [ingestFinanceMessage]; returns `null` when unset.
  final Future<AssistantFinanceIngestion?> Function(String message)? onIngest;

  @override
  final AssistantHostUser? currentUser;

  @override
  final SafetyProfile safetyProfile;

  @override
  final bool autoFallbackEnabled;

  @override
  int modelContextLength;

  @override
  final bool isAndroidHost;

  final bool speakResult;

  /// Records, in call order, which members the screen under test reached for.
  final List<String> calls = <String>[];

  /// Messages passed to [ingestFinanceMessage].
  final List<String> ingestedMessages = <String>[];

  @override
  Future<void> signOutAndReturnToLogin(BuildContext context) async {
    calls.add('signOutAndReturnToLogin');
  }

  @override
  void openHostSettings(BuildContext context) => calls.add('openHostSettings');

  @override
  void openHttpStatusReference(BuildContext context) =>
      calls.add('openHttpStatusReference');

  @override
  void openDictionaryDemo(BuildContext context) =>
      calls.add('openDictionaryDemo');

  @override
  Future<bool> speakAloud(String text) async {
    calls.add('speakAloud:$text');
    return speakResult;
  }

  @override
  Widget wrapWithDictionarySelection({required Widget child}) => child;

  @override
  void showWordDefinition(BuildContext context, String word) =>
      calls.add('showWordDefinition:$word');

  @override
  Widget dictionaryAwareText(String text) => Text(text);

  @override
  Future<void> showBugReportDialog(BuildContext context) async {
    calls.add('showBugReportDialog');
  }

  @override
  Widget aiPreferencesSection() =>
      const SizedBox.shrink(key: Key('fake-ai-preferences-section'));

  @override
  Future<void> setModelContextLength(int tokens) async {
    calls.add('setModelContextLength:$tokens');
    modelContextLength = tokens;
  }

  @override
  Future<void> repairModelPackage(String packageId) async {
    calls.add('repairModelPackage:$packageId');
  }

  @override
  Future<AssistantFinanceIngestion?> ingestFinanceMessage(String message) {
    ingestedMessages.add(message);
    final handler = onIngest;
    if (handler == null) return Future<AssistantFinanceIngestion?>.value();
    return handler(message);
  }
}
