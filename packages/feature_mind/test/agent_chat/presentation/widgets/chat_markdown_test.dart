import 'package:feature_mind/src/agent_chat/presentation/widgets/chat_markdown.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hides ** around Gemma-style headings', () {
    const source =
        '**Understanding the Concept**\n\n'
        'A queue is a FIFO data structure.\n\n'
        '**Using a Stack**\n\n'
        'A stack is LIFO.';

    expect(
      chatMarkdownPlainText(source),
      'Understanding the Concept\n\n'
      'A queue is a FIFO data structure.\n\n'
      'Using a Stack\n\n'
      'A stack is LIFO.',
    );

    final spans = chatMarkdownSpans(source, style: const TextStyle());
    expect(
      spans.whereType<TextSpan>().any(
        (span) =>
            span.text == 'Understanding the Concept' &&
            span.style?.fontWeight == FontWeight.w700,
      ),
      isTrue,
    );
  });

  test('renders italic, inline code, and ATX headings without markers', () {
    expect(chatMarkdownPlainText('*FIFO* vs `Stack`'), 'FIFO vs Stack');
    expect(chatMarkdownPlainText('## Implementation'), 'Implementation');
    expect(chatMarkdownPlainText('- first\n* second'), '• first\n• second');
  });

  test('leaves unmatched asterisks in place', () {
    expect(chatMarkdownPlainText('2*3 = 6'), '2*3 = 6');
    expect(chatMarkdownPlainText('**still open'), '**still open');
  });
}
