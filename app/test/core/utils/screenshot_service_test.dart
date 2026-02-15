import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/core/utils/screenshot_service.dart';

void main() {
  group('ScreenshotService', () {
    group('isWithinGitHubLimit', () {
      test('returns true for bytes under 30KB', () {
        // 20KB of data
        final bytes = Uint8List(20 * 1024);

        final result = ScreenshotService.isWithinGitHubLimit(bytes);

        expect(result, isTrue);
      });

      test('returns true for bytes exactly at 30KB', () {
        // Exactly 30KB
        final bytes = Uint8List(30 * 1024);

        final result = ScreenshotService.isWithinGitHubLimit(bytes);

        expect(result, isTrue);
      });

      test('returns false for bytes over 30KB', () {
        // 31KB of data
        final bytes = Uint8List(31 * 1024);

        final result = ScreenshotService.isWithinGitHubLimit(bytes);

        expect(result, isFalse);
      });

      test('returns false for large images', () {
        // 100KB of data
        final bytes = Uint8List(100 * 1024);

        final result = ScreenshotService.isWithinGitHubLimit(bytes);

        expect(result, isFalse);
      });

      test('returns true for empty bytes', () {
        final bytes = Uint8List(0);

        final result = ScreenshotService.isWithinGitHubLimit(bytes);

        expect(result, isTrue);
      });
    });

    group('getSizeWarning', () {
      test('returns null for small images', () {
        // 15KB of data
        final bytes = Uint8List(15 * 1024);

        final warning = ScreenshotService.getSizeWarning(bytes);

        expect(warning, isNull);
      });

      test('returns warning for large images', () {
        // 50KB of data
        final bytes = Uint8List(50 * 1024);

        final warning = ScreenshotService.getSizeWarning(bytes);

        expect(warning, isNotNull);
        expect(warning, contains('50.0 KB'));
        expect(warning, contains('compressed'));
      });

      test('returns warning message with correct size', () {
        // 75KB of data
        final bytes = Uint8List((75 * 1024).toInt());

        final warning = ScreenshotService.getSizeWarning(bytes);

        expect(warning, isNotNull);
        expect(warning, contains('75.0 KB'));
      });
    });

    group('toBase64DataUrl', () {
      test('generates valid data URL prefix', () {
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

        final dataUrl = ScreenshotService.toBase64DataUrl(bytes);

        expect(dataUrl, startsWith('data:image/png;base64,'));
      });

      test('generates valid base64 content', () {
        final bytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG header

        final dataUrl = ScreenshotService.toBase64DataUrl(bytes);

        expect(dataUrl, contains('iVBORw'));
      });

      test('handles empty bytes', () {
        final bytes = Uint8List(0);

        final dataUrl = ScreenshotService.toBase64DataUrl(bytes);

        expect(dataUrl, equals('data:image/png;base64,'));
      });
    });

    group('toMarkdownImage', () {
      test('generates valid markdown image syntax', () {
        final bytes = Uint8List.fromList([1, 2, 3]);

        final markdown = ScreenshotService.toMarkdownImage(bytes);

        expect(markdown, startsWith('![Screenshot](data:image/png;base64,'));
        expect(markdown, endsWith(')'));
      });

      test('uses custom alt text', () {
        final bytes = Uint8List.fromList([1, 2, 3]);

        final markdown = ScreenshotService.toMarkdownImage(
          bytes,
          alt: 'Bug Screenshot',
        );

        expect(markdown, startsWith('![Bug Screenshot]('));
      });

      test('default alt text is Screenshot', () {
        final bytes = Uint8List.fromList([1, 2, 3]);

        final markdown = ScreenshotService.toMarkdownImage(bytes);

        expect(markdown, startsWith('![Screenshot]('));
      });
    });

    group('maxGitHubBytes constant', () {
      test('is set to 30KB', () {
        expect(ScreenshotService.maxGitHubBytes, equals(30 * 1024));
      });
    });
  });
}

