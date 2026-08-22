import 'package:feature_mind/src/search/meeting_text_chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeetingTextChunker', () {
    const chunker = MeetingTextChunker(maxChars: 40, overlapChars: 10);

    test('returns empty for empty input', () {
      expect(chunker.chunk(), isEmpty);
      expect(chunker.chunk(fallbackText: '   '), isEmpty);
    });

    test('prefers segments over fallback text', () {
      final chunks = chunker.chunk(
        segments: const ['alpha.', 'beta.', 'gamma.'],
        fallbackText: 'this fallback must not appear',
      );

      expect(chunks, isNotEmpty);
      expect(chunks.every((c) => !c.text.contains('fallback')), isTrue);
      expect(chunks.map((c) => c.text).join(' '), contains('alpha'));
      expect(chunks.map((c) => c.text).join(' '), contains('gamma'));
    });

    test('splits long segment lists into overlapping windows', () {
      final chunks = chunker.chunk(
        segments: List.generate(12, (i) => 'segment$i'),
      );

      expect(chunks.length, greaterThan(1));
      expect(chunks.first.id, 'chunk-0');
      // Overlap walks back prior segments into the next window.
      final firstParts = chunks.first.text.split(' ').toSet();
      final secondParts = chunks[1].text.split(' ').toSet();
      expect(firstParts.intersection(secondParts), isNotEmpty);
    });

    test('keeps a short meeting as a single chunk', () {
      final chunks = chunker.chunk(fallbackText: 'short meeting notes');

      expect(chunks, hasLength(1));
      expect(chunks.single.text, 'short meeting notes');
    });
  });
}
