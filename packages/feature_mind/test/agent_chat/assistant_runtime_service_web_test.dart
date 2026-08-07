import 'package:flutter_test/flutter_test.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';

void main() {
  test('litertWebRuntimeInitFailedMessage explains the browser failure', () {
    expect(litertWebRuntimeInitFailedMessage, contains('browser'));
    expect(litertWebRuntimeInitFailedMessage, isNotEmpty);
  });
}
