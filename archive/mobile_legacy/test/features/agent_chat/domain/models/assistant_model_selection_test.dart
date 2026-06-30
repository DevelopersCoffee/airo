import 'package:airo_app/features/agent_chat/domain/models/assistant_model_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('assistant model selection helpers', () {
    test('encodes offline model ids with a stable prefix', () {
      expect(
        assistantModelIdForOfflineModel('gemma-4-e2b-it-litertlm'),
        'offline-gemma-4-e2b-it-litertlm',
      );
    });

    test('decodes offline assistant ids', () {
      expect(
        offlineModelIdFromAssistantModelId('offline-gemma-4-e2b-it-litertlm'),
        'gemma-4-e2b-it-litertlm',
      );
      expect(
        offlineModelIdFromAssistantModelId(geminiNanoAssistantModelId),
        isNull,
      );
    });

    test('detects offline assistant ids', () {
      expect(isOfflineAssistantModelId('offline-phi-3-mini-4k-q4'), isTrue);
      expect(isOfflineAssistantModelId(geminiCloudAssistantModelId), isFalse);
    });
  });
}
