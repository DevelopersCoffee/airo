import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

class _FakeContentSource extends ContentSource {
  const _FakeContentSource({required super.id, required super.label})
    : super(
        capabilities: const ContentSourceCapabilities(
          hasEpg: true,
          hasVod: true,
        ),
      );

  @override
  ContentSourceKind get kind => ContentSourceKind.xtream;
}

void main() {
  group('ContentSourceCredentialRef', () {
    test('toString never leaks the key', () {
      const ref = ContentSourceCredentialRef('source-1');
      expect(ref.toString(), 'ContentSourceCredentialRef(redacted)');
      expect(ref.toString(), isNot(contains('source-1')));
    });

    test('equality is key-based', () {
      expect(
        const ContentSourceCredentialRef('a'),
        const ContentSourceCredentialRef('a'),
      );
      expect(
        const ContentSourceCredentialRef('a'),
        isNot(const ContentSourceCredentialRef('b')),
      );
    });
  });

  group('ContentSource', () {
    test('exposes kind and capabilities', () {
      const source = _FakeContentSource(id: 'src-1', label: 'My Provider');
      expect(source.kind, ContentSourceKind.xtream);
      expect(source.capabilities.hasEpg, isTrue);
      expect(source.capabilities.hasVod, isTrue);
      expect(source.capabilities.hasCatchup, isFalse);
    });

    test('toString identifies kind/id/label without leaking secrets', () {
      const source = _FakeContentSource(id: 'src-1', label: 'My Provider');
      expect(
        source.toString(),
        'ContentSource(kind: xtream, id: src-1, label: My Provider)',
      );
    });
  });
}
