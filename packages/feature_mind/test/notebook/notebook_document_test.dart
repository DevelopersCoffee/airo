import 'package:feature_mind/src/notebook/domain/notebook_document.dart';
import 'package:feature_mind/src/notebook/domain/notebook_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simple notes encode as plaintext so the skeleton stays readable', () {
    const doc = NotebookDocument(body: 'milk, eggs');
    expect(doc.isPlain, isTrue);
    expect(doc.encode(), 'milk, eggs');
    expect(NotebookDocument.decode('milk, eggs').body, 'milk, eggs');
  });

  test('tagged notes round-trip through the v1 envelope', () {
    const doc = NotebookDocument(
      body: 'follow up',
      transcript: 'we should ship friday',
      summary: 'Ship on Friday.',
      keyPoints: ['Ship Friday', 'Tell Priya'],
      tags: ['work'],
      labels: ['meeting'],
      languageCode: 'hi',
      source: NotebookSource.live,
      meetingId: 'm1',
    );

    final decoded = NotebookDocument.decode(doc.encode());
    expect(decoded, doc);
    expect(decoded.encode(), contains('airo.mind.notebook.v1'));
  });

  test('unknown JSON and torn envelopes fall back to plaintext', () {
    expect(NotebookDocument.decode('{"no":"schema"}').body, '{"no":"schema"}');
    expect(NotebookDocument.decode('{not-json').body, '{not-json');
    expect(NotebookDocument.decode('').body, isEmpty);
  });

  test('preview prefers summary then body then transcript', () {
    expect(
      const NotebookDocument(
        summary: 'Recap',
        body: 'notes',
        transcript: 'talk',
      ).preview,
      'Recap',
    );
    expect(const NotebookDocument(body: 'notes').preview, 'notes');
    expect(const NotebookDocument(transcript: 'talk').preview, 'talk');
  });
}
