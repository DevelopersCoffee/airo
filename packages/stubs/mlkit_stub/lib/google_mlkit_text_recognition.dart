/// Stub implementation of google_mlkit_text_recognition for TV builds
/// Saves ~10MB by not including ML Kit native libraries
library;

import 'dart:io';

/// Text recognition script
enum TextRecognitionScript { latin, chinese, devanagari, japanese, korean }

/// Input image for ML Kit
class InputImage {
  InputImage._({this.filePath, this.bytes});
  final String? filePath;
  final List<int>? bytes;

  /// Create input image from file
  static InputImage fromFile(File file) => InputImage._(filePath: file.path);

  /// Create input image from bytes
  static InputImage fromBytes(List<int> bytes, InputImageMetadata metadata) =>
      InputImage._(bytes: bytes);
}

/// Input image metadata
class InputImageMetadata {
  InputImageMetadata({
    required this.width,
    required this.height,
    required this.rotation,
    required this.format,
  });
  final int width;
  final int height;
  final int rotation;
  final int format;
}

/// Recognized text result
class RecognizedText {
  RecognizedText({required this.text, required this.blocks});
  final String text;
  final List<TextBlock> blocks;
}

/// Text block
class TextBlock {
  TextBlock({
    required this.text,
    required this.lines,
    required this.cornerPoints,
  });
  final String text;
  final List<TextLine> lines;
  final List<int> cornerPoints;
}

/// Text line
class TextLine {
  TextLine({
    required this.text,
    required this.elements,
    required this.cornerPoints,
  });
  final String text;
  final List<TextElement> elements;
  final List<int> cornerPoints;
}

/// Text element
class TextElement {
  TextElement({required this.text, required this.cornerPoints});
  final String text;
  final List<int> cornerPoints;
}

/// Stub TextRecognizer - returns empty results
class TextRecognizer {
  TextRecognizer({this.script = TextRecognitionScript.latin});
  final TextRecognitionScript script;

  /// Process image - returns empty result on TV
  Future<RecognizedText> processImage(InputImage inputImage) async {
    // Return empty result - OCR not available on TV
    return RecognizedText(text: '', blocks: []);
  }

  /// Close the recognizer
  Future<void> close() async {}
}
