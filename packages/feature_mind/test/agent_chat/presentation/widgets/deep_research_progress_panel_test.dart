import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/presentation/widgets/deep_research_progress_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders structured steps instead of model thinking', (
    tester,
  ) async {
    const session = ResearchSession(
      request: ResearchRequest(question: 'Pixel 9 offline LLM'),
      events: [
        ResearchEvent(
          kind: ResearchEventKind.planningStarted,
          label: 'Understanding question',
        ),
        ResearchEvent(
          kind: ResearchEventKind.planCreated,
          label: 'Creating research plan',
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DeepResearchProgressPanel(session: session)),
      ),
    );

    expect(
      find.byKey(const Key('agent_chat_deep_research_progress')),
      findsOneWidget,
    );
    expect(find.text('RESEARCHING'), findsOneWidget);
    expect(find.text('Understanding question'), findsOneWidget);
    expect(find.text('Creating research plan'), findsOneWidget);
    expect(find.textContaining('I think'), findsNothing);
  });
}
