import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagePool', () {
    test('pick returns a variant from the pool', () {
      final msg = AiroVoice.loading.pick();
      expect(AiroVoice.loading.variants, contains(msg));
    });

    test('seed makes picks deterministic', () {
      AiroVoice.seed(42);
      final first = [for (var i = 0; i < 5; i++) AiroVoice.loading.pick()];
      AiroVoice.seed(42);
      final second = [for (var i = 0; i < 5; i++) AiroVoice.loading.pick()];
      expect(first, second);
    });

    test('pickWith appends detail on a new line', () {
      AiroVoice.seed(1);
      final headline = AiroVoice.errorGeneric.pick();
      AiroVoice.seed(1);
      final msg = AiroVoice.errorGeneric.pickWith(detail: 'boom');
      expect(msg, '$headline\nboom');
    });

    test('pickWith without detail returns headline only', () {
      final msg = AiroVoice.errorGeneric.pickWith();
      expect(msg.contains('\n'), isFalse);
    });

    test('every pool is non-empty', () {
      for (final pool in [
        AiroVoice.loading,
        AiroVoice.thinking,
        AiroVoice.searching,
        AiroVoice.buffering,
        AiroVoice.errorGeneric,
        AiroVoice.errorNetwork,
        AiroVoice.empty,
      ]) {
        expect(pool.variants, isNotEmpty);
      }
    });
  });
}
