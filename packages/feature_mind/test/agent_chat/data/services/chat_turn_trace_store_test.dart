import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/agent_chat/data/services/chat_turn_trace_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  ChatTurnTrace _trace(String runId) {
    return ChatTurnTraceBuilder(runId: runId)
        .runtime(id: 'offline-qwen', routing: ChatTurnRouting.local)
        .plugin('draft-diet-plan')
        .prompt(summary: 'Make me a 7 day diet plan')
        .abort(reason: ChatTurnStopReason.processKilled)
        .build();
  }

  test('chat turn traces round-trip by run id', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ChatTurnTraceStore(
      preferences: await SharedPreferences.getInstance(),
    );
    final trace = _trace('run-diet-1');
    await store.upsert(trace);

    final loaded = await store.byRunId('run-diet-1');
    expect(loaded, isNotNull);
    expect(loaded!.pluginId, 'draft-diet-plan');
    expect(loaded.lifecycle, ChatTurnLifecycle.aborted);
    expect(loaded.stopReason, ChatTurnStopReason.processKilled);
  });

  test('clearing chat traces wipes stored runs', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ChatTurnTraceStore(
      preferences: await SharedPreferences.getInstance(),
    );
    await store.upsert(_trace('run-diet-1'));
    await store.clear();
    expect(await store.byRunId('run-diet-1'), isNull);
  });
}
