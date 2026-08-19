import 'package:feature_mind/src/models/model_descriptor_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pinnedMultilingualSpeechModel matches Rust optional_files pin', () {
    expect(pinnedMultilingualSpeechModel.fileName, 'ggml-tiny.bin');
    expect(pinnedMultilingualSpeechModel.sizeBytes, 77691713);
    expect(
      pinnedMultilingualSpeechModel.sha256,
      'be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21',
    );
  });

  test('pinnedSmallMultilingualSpeechModel matches Rust optional_files pin', () {
    expect(pinnedSmallMultilingualSpeechModel.fileName, 'ggml-small.bin');
    expect(pinnedSmallMultilingualSpeechModel.sizeBytes, 487601967);
    expect(
      pinnedSmallMultilingualSpeechModel.sha256,
      '1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b',
    );
  });
}
