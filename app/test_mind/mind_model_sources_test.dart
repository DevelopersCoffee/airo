import 'dart:io';

import 'package:airo_app/core/mind/mind_model_sources.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every model Airo Mind pins must have somewhere to come from.
///
/// The registry lives in Rust (`ADR-0018 §2`) and the URLs live in this shell,
/// which is the split that lets hosting change without touching the runtime —
/// but a split with nothing checking it is how a model gets added upstream and
/// the app dead-ends on a fresh install with no source for it (#1554). This
/// test reads the pinned registry directly out of the Rust source so the two
/// halves cannot drift silently.
List<String> _pinnedFileNames() {
  final source = File(
    '../rust/airo_mind_core/src/models.rs',
  ).readAsStringSync();
  // Only the const registry — the crate's own unit tests below `#[cfg(test)]`
  // restate file names in fixtures, and those are not shipped models.
  final registry = source.split('#[cfg(test)]').first;
  return [
    for (final match in RegExp(r'file_name:\s*"([^"]+)"').allMatches(registry))
      match.group(1)!,
  ];
}

/// HF (and other hosts) sometimes publish a different basename than the pinned
/// on-disk install target. The download pipeline renames on install; this map
/// records those exceptions so the URL check stays strict for every other model.
const Map<String, String> _remoteDownloadBasenames = {
  'ecapa_tdnn_tiny_int8.onnx': 'ecapa-speaker-v1.onnx',
};

void main() {
  test('the pinned registry is readable and non-empty', () {
    expect(_pinnedFileNames(), isNotEmpty);
  });

  test('every pinned model has a download URL in this shell', () {
    for (final fileName in _pinnedFileNames()) {
      final url = mindModelDownloadUrls[fileName];
      expect(
        url,
        isNotNull,
        reason:
            '$fileName is pinned in airo_mind_core::models but this shell has '
            'no source for it, so a fresh install cannot acquire it.',
      );
      expect(Uri.parse(url!).scheme, 'https');
      // The download service refuses anything but HTTPS, and the file name at
      // the end is what makes a mismatched pin obvious on sight.
      final remoteName = _remoteDownloadBasenames[fileName] ?? fileName;
      expect(url, endsWith(remoteName));
    }
  });

  test('the map carries no model the registry does not pin', () {
    expect(mindModelDownloadUrls.keys, unorderedEquals(_pinnedFileNames()));
  });

  test('the lookup answers by pinned file name', () {
    expect(
      mindModelDownloadUrlFor(
        const RequiredModel(
          fileName: 'ggml-tiny.en.bin',
          sizeBytes: 77704715,
          sha256:
              '921e4cf8686fdd993dcd081a5da5b6c365bfde1162e72b08d75ac75289920b1f',
        ),
      ),
      mindModelDownloadUrls['ggml-tiny.en.bin'],
    );
    expect(
      mindModelDownloadUrlFor(
        const RequiredModel(fileName: 'not-a-model', sizeBytes: 1, sha256: 'x'),
      ),
      isNull,
    );
  });
}
