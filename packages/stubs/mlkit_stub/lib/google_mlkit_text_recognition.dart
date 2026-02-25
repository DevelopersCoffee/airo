/// Stub implementation of google_mlkit_text_recognition for TV builds
/// Saves ~10MB by not including ML Kit native libraries
library;

import 'dart:io';

/// Text recognition script
enum TextRecognitionScript {
  latin,
  chinese,
  devanagari,
  japanese,
  korean,
}

/// Input image for ML Kit
class InputImage {
  final String? filePath;
  final List<int>? bytes;
  
  InputImage._({this.filePath, this.bytes});
  
  /// Create input image from file
  static InputImage fromFile(File file) {
    return InputImage._(filePath: file.path);
  }
  
  /// Create input image from bytes
  static InputImage fromBytes(List<int> bytes, InputImageMetadata metadata) {
    return InputImage._(bytes: bytes);
  }
}

/// Input image metadata
class InputImageMetadata {
  final int width;
  final int height;
  final int rotation;
  final int format;
  
  InputImageMetadata({
    required this.width,
    required this.height,
    required this.rotation,
    required this.format,
  });
}

/// Recognized text result
class RecognizedText {
  final String text;
  final List<TextBlock> blocks;
  
  RecognizedText({required this.text, required this.blocks});
}

/// Text block
class TextBlock {
  final String text;
  final List<TextLine> lines;
  final List<int> cornerPoints;
  
  TextBlock({required this.text, required this.lines, required this.cornerPoints});
}

/// Text line
class TextLine {
  final String text;
  final List<TextElement> elements;
  final List<int> cornerPoints;
  
  TextLine({required this.text, required this.elements, required this.cornerPoints});
}

/// Text element
class TextElement {
  final String text;
  final List<int> cornerPoints;
  
  TextElement({required this.text, required this.cornerPoints});
}

/// Stub TextRecognizer - returns empty results
class TextRecognizer {
  final TextRecognitionScript script;
  
  TextRecognizer({this.script = TextRecognitionScript.latin});
  
  /// Process image - returns empty result on TV
  Future<RecognizedText> processImage(InputImage inputImage) async {
    // Return empty result - OCR not available on TV
    return RecognizedText(text: '', blocks: []);
  }
  
  /// Close the recognizer
  Future<void> close() async {}
}

