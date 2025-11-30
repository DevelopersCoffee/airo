/// Fake OCR client for deterministic testing
///
/// This client returns pre-defined OCR results instead of using ML Kit,
/// allowing tests to be fast, deterministic, and run without device dependencies.

/// Result of OCR processing
class OcrResult {
  final String text;
  final double confidence;
  final List<OcrBlock> blocks;

  const OcrResult({
    required this.text,
    required this.confidence,
    this.blocks = const [],
  });
}

/// OCR text block with position
class OcrBlock {
  final String text;
  final double confidence;
  final OcrRect boundingBox;

  const OcrBlock({
    required this.text,
    required this.confidence,
    required this.boundingBox,
  });
}

/// Bounding rectangle for OCR block
class OcrRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const OcrRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}

/// Abstract OCR client interface
abstract class OcrClient {
  /// Process an image and extract text
  Future<OcrResult> processImage(String imagePath);

  /// Process image bytes and extract text
  Future<OcrResult> processImageBytes(List<int> bytes);

  /// Dispose resources
  void dispose();
}

/// Fake OCR client for testing
class FakeOcrClient implements OcrClient {
  /// Map of image paths to predefined OCR results
  final Map<String, OcrResult> _fixtures;

  /// Default result for unknown images
  final OcrResult _defaultResult;

  /// Call log for verification
  final List<String> callLog = [];

  FakeOcrClient({
    Map<String, OcrResult>? fixtures,
    OcrResult? defaultResult,
  })  : _fixtures = fixtures ?? {},
        _defaultResult = defaultResult ??
            const OcrResult(
              text: 'No text detected',
              confidence: 0.0,
            );

  /// Add a fixture for a specific image path
  void addFixture(String imagePath, OcrResult result) {
    _fixtures[imagePath] = result;
  }

  /// Set fixture by name (convenience method)
  void setOcrResult(String name, String text, {double confidence = 0.95}) {
    _fixtures[name] = OcrResult(text: text, confidence: confidence);
  }

  @override
  Future<OcrResult> processImage(String imagePath) async {
    callLog.add('processImage:$imagePath');
    // Simulate async processing delay (short for tests)
    await Future.delayed(const Duration(milliseconds: 10));
    return _fixtures[imagePath] ?? _defaultResult;
  }

  @override
  Future<OcrResult> processImageBytes(List<int> bytes) async {
    callLog.add('processImageBytes:${bytes.length} bytes');
    await Future.delayed(const Duration(milliseconds: 10));
    // Use hash of bytes as key for fixture lookup
    final key = 'bytes:${bytes.hashCode}';
    return _fixtures[key] ?? _defaultResult;
  }

  @override
  void dispose() {
    callLog.add('dispose');
  }

  /// Reset call log
  void reset() {
    callLog.clear();
  }

  /// Verify a method was called
  bool wasCalled(String method) {
    return callLog.any((call) => call.startsWith(method));
  }

  /// Get number of times a method was called
  int callCount(String method) {
    return callLog.where((call) => call.startsWith(method)).length;
  }
}

