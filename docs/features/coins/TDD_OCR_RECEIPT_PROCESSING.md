# Technical Design Document: OCR Receipt Processing Pipeline

## Document Information

| Field | Value |
|-------|-------|
| **Feature** | Coins - Receipt Scanning & Processing |
| **Author** | Airo Engineering Team |
| **Status** | Draft |
| **Created** | 2026-02-15 |
| **Last Updated** | 2026-02-15 |

---

## 1. Overview

### 1.1 Purpose

The OCR Receipt Processing Pipeline enables users to scan physical receipts using their device camera, extract structured financial data automatically, and log expenses or splits with minimal manual input.

### 1.2 Goals

- Extract receipt data with ≥ 85% accuracy
- Process receipts in < 3 seconds end-to-end
- Support 100% on-device processing for privacy
- Handle poor quality images gracefully
- Support multi-currency receipts (INR, USD, EUR)

### 1.3 Non-Goals

- Cloud-based OCR processing
- Multi-page receipt scanning (initial release)
- Handwritten receipt recognition
- Non-receipt document scanning (invoices, statements)

---

## 2. Architecture

### 2.1 High-Level Pipeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Receipt Processing Pipeline                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────┐ │
│  │   Camera     │   │    Image     │   │   ML Kit    │   │  Gemma   │ │
│  │   Capture    │──▶│ Preprocessor │──▶│     OCR     │──▶│  Parser  │ │
│  └──────────────┘   └──────────────┘   └──────────────┘   └──────────┘ │
│         │                  │                  │                │       │
│         ▼                  ▼                  ▼                ▼       │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────┐ │
│  │   Gallery    │   │   Quality    │   │     Raw      │   │Structured│ │
│  │   Import     │   │  Validation  │   │     Text     │   │   Data   │ │
│  └──────────────┘   └──────────────┘   └──────────────┘   └──────────┘ │
│                                                                │       │
│                                                                ▼       │
│                                                         ┌──────────┐  │
│                                                         │ Category │  │
│                                                         │Classifier│  │
│                                                         └──────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Storage Layer                                   │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────────────────┐│
│  │ Receipt Image  │  │  OCR Raw Text  │  │ TransactionEntry (Drift)   ││
│  │  (encrypted)   │  │   (indexed)    │  │                            ││
│  └────────────────┘  └────────────────┘  └────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Integration Points

| Component | Package | Purpose |
|-----------|---------|---------|
| ML Kit OCR | `google_mlkit_text_recognition` | On-device text extraction |
| Gemma 1B (int4) | `core_ai` via `GGUFModelClient` | Structured parsing |
| Image Picker | `image_picker` | Camera/gallery access |
| Image Processing | `image` package | Preprocessing |
| Storage | `app_database.dart` | Transaction persistence |
| Encryption | `flutter_secure_storage` | Receipt image encryption |

---

## 3. Image Preprocessing

### 3.1 Quality Validation Checks

```dart
/// Image quality validation result
class ImageQualityResult {
  final bool isAcceptable;
  final double brightnessScore;    // 0.0 - 1.0
  final double sharpnessScore;     // 0.0 - 1.0
  final double contrastScore;      // 0.0 - 1.0
  final ImageOrientation orientation;
  final List<QualityIssue> issues;
  
  bool get needsEnhancement => 
    brightnessScore < 0.4 || sharpnessScore < 0.5;
}

enum QualityIssue {
  tooDark,
  tooBlurry,
  lowContrast,
  partialCapture,
  rotated,
  glare,
}
```

### 3.2 Preprocessing Steps

| Step | Purpose | Implementation |
|------|---------|----------------|
| 1. Orientation detection | Correct rotated images | EXIF metadata + edge detection |
| 2. Auto-rotate | Ensure text is upright | OpenCV rotation |
| 3. Brightness normalization | Handle dark/bright images | Histogram equalization |
| 4. Contrast enhancement | Improve text visibility | CLAHE algorithm |
| 5. Noise reduction | Remove artifacts | Gaussian blur (light) |
| 6. Binarization | Black/white for OCR | Adaptive thresholding |
| 7. Deskew | Straighten tilted receipts | Hough line detection |

### 3.3 Preprocessor Implementation

```dart
/// Receipt image preprocessor
class ReceiptImagePreprocessor {
  /// Preprocess image for OCR
  Future<PreprocessedImage> preprocess(File imageFile) async {
    // 1. Load and decode image
    final bytes = await imageFile.readAsBytes();
    var image = img.decodeImage(bytes)!;
    
    // 2. Fix orientation from EXIF
    image = img.bakeOrientation(image);
    
    // 3. Check quality
    final quality = _assessQuality(image);
    
    if (!quality.isAcceptable) {
      throw ImageQualityException(quality.issues);
    }
    
    // 4. Apply enhancements if needed
    if (quality.needsEnhancement) {
      image = _enhanceImage(image);
    }
    
    // 5. Convert to format suitable for ML Kit
    return PreprocessedImage(
      image: image,
      quality: quality,
      originalPath: imageFile.path,
    );
  }
}
```

---

## 4. ML Kit OCR Integration

### 4.1 Text Recognition Setup

```dart
/// ML Kit text recognizer wrapper
class ReceiptTextRecognizer {
  final TextRecognizer _recognizer;

  ReceiptTextRecognizer()
    : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract text from preprocessed image
  Future<RecognizedReceiptText> recognize(PreprocessedImage image) async {
    final inputImage = InputImage.fromFile(image.file);
    final recognizedText = await _recognizer.processImage(inputImage);

    return RecognizedReceiptText(
      fullText: recognizedText.text,
      blocks: recognizedText.blocks.map(_toBlock).toList(),
      confidence: _calculateOverallConfidence(recognizedText),
    );
  }

  /// Convert ML Kit block to our model
  TextBlock _toBlock(ml.TextBlock block) {
    return TextBlock(
      text: block.text,
      boundingBox: block.boundingBox,
      lines: block.lines.map(_toLine).toList(),
      cornerPoints: block.cornerPoints,
    );
  }

  void dispose() => _recognizer.close();
}
```

### 4.2 Text Recognition Output Model

```dart
/// Recognized text from receipt
class RecognizedReceiptText {
  final String fullText;
  final List<TextBlock> blocks;
  final double confidence;

  /// Get text sorted by vertical position (top to bottom)
  List<String> get sortedLines {
    final allLines = blocks.expand((b) => b.lines).toList();
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    return allLines.map((l) => l.text).toList();
  }
}

class TextBlock {
  final String text;
  final Rect boundingBox;
  final List<TextLine> lines;
  final List<Point> cornerPoints;
}

class TextLine {
  final String text;
  final Rect boundingBox;
  final List<TextElement> elements;
  final double confidence;
}
```

---

## 5. Structured Parsing with Gemma 1B

### 5.1 Parsing Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   Gemma Structured Parser                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐│
│  │  Raw OCR     │   │   Prompt     │   │   Gemma 1B (int4)    ││
│  │    Text      │──▶│   Builder    │──▶│    Inference         ││
│  └──────────────┘   └──────────────┘   └──────────────────────┘│
│                                                │                │
│                                                ▼                │
│                          ┌──────────────────────────────────┐  │
│                          │  JSON Response Parser            │  │
│                          │  - Validate structure            │  │
│                          │  - Extract fields                │  │
│                          │  - Handle parse errors           │  │
│                          └──────────────────────────────────┘  │
│                                                │                │
│                                                ▼                │
│                          ┌──────────────────────────────────┐  │
│                          │  ParsedReceipt                   │  │
│                          │  - vendor, date, total           │  │
│                          │  - line items, tax, currency     │  │
│                          └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Parsing Prompt Template

```
You are a receipt parser. Extract structured data from the OCR text below.

OCR Text:
"""
{ocr_text}
"""

Rules:
- Extract vendor name from header/logo area
- Find total amount (look for "Total", "Grand Total", "Amount Due")
- Convert amounts to paise (multiply by 100): "₹450.50" → 45050
- Parse date in ISO format: "15/02/2026" → "2026-02-15"
- Extract individual line items with names and amounts
- Identify tax (GST/VAT) if present
- Detect currency from symbols: ₹=INR, $=USD, €=EUR

Respond with JSON only:
{
  "vendor": "Store Name",
  "date": "2026-02-15",
  "currency": "INR",
  "line_items": [
    {"name": "Item 1", "quantity": 1, "amount_paise": 15000},
    {"name": "Item 2", "quantity": 2, "amount_paise": 30000}
  ],
  "subtotal_paise": 45000,
  "tax_paise": 8100,
  "tax_type": "GST",
  "total_paise": 53100,
  "confidence": 0.92
}
```

### 5.3 Parser Implementation

```dart
/// Gemma-powered receipt parser
class GemmaReceiptParser {
  final LLMRouter _llmRouter;

  GemmaReceiptParser(this._llmRouter);

  /// Parse OCR text into structured receipt
  Future<Result<ParsedReceipt>> parse(RecognizedReceiptText ocrResult) async {
    // 1. Build prompt
    final prompt = _buildPrompt(ocrResult.fullText);

    // 2. Get LLM client (prefer on-device)
    final client = await _llmRouter.route(
      prompt: prompt,
      preferOnDevice: true,
    );

    // 3. Generate response
    final response = await client.generate(prompt);

    return response.when(
      ok: (llmResponse) {
        try {
          final json = jsonDecode(llmResponse.text);
          return Result.ok(_parseJson(json));
        } catch (e) {
          return Result.err(ReceiptParseError('Failed to parse JSON: $e'));
        }
      },
      err: (error) => Result.err(ReceiptParseError(error.toString())),
    );
  }

  ParsedReceipt _parseJson(Map<String, dynamic> json) {
    return ParsedReceipt(
      vendor: json['vendor'] as String?,
      date: DateTime.tryParse(json['date'] ?? ''),
      currency: Currency.fromCode(json['currency'] ?? 'INR'),
      lineItems: (json['line_items'] as List? ?? [])
          .map((item) => LineItem.fromJson(item))
          .toList(),
      subtotalPaise: json['subtotal_paise'] as int?,
      taxPaise: json['tax_paise'] as int?,
      taxType: json['tax_type'] as String?,
      totalPaise: json['total_paise'] as int? ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
```

### 5.4 Parsed Receipt Model

```dart
/// Structured receipt data
class ParsedReceipt {
  final String? vendor;
  final DateTime? date;
  final Currency currency;
  final List<LineItem> lineItems;
  final int? subtotalPaise;
  final int? taxPaise;
  final String? taxType;
  final int totalPaise;
  final double confidence;
  final String? rawOcrText;

  const ParsedReceipt({
    this.vendor,
    this.date,
    this.currency = Currency.inr,
    this.lineItems = const [],
    this.subtotalPaise,
    this.taxPaise,
    this.taxType,
    required this.totalPaise,
    this.confidence = 0.0,
    this.rawOcrText,
  });

  /// Check if receipt has required fields
  bool get isValid => totalPaise > 0 && confidence >= 0.7;

  /// Get formatted total
  String get formattedTotal =>
    '${currency.symbol}${(totalPaise / 100).toStringAsFixed(2)}';
}

class LineItem {
  final String name;
  final int quantity;
  final int amountPaise;

  const LineItem({
    required this.name,
    this.quantity = 1,
    required this.amountPaise,
  });

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
    name: json['name'] as String? ?? 'Unknown Item',
    quantity: json['quantity'] as int? ?? 1,
    amountPaise: json['amount_paise'] as int? ?? 0,
  );
}
```

---

## 6. Category Classification

### 6.1 Category Detection Strategy

```dart
/// Receipt category classifier
class ReceiptCategoryClassifier {
  /// Classify receipt into expense category
  ExpenseCategory classify(ParsedReceipt receipt) {
    // 1. Try vendor-based classification
    final vendorCategory = _classifyByVendor(receipt.vendor);
    if (vendorCategory != null) return vendorCategory;

    // 2. Try line-item based classification
    final itemCategory = _classifyByItems(receipt.lineItems);
    if (itemCategory != null) return itemCategory;

    // 3. Fallback to LLM classification
    return _classifyWithLLM(receipt);
  }

  ExpenseCategory? _classifyByVendor(String? vendor) {
    if (vendor == null) return null;
    final normalized = vendor.toLowerCase();

    // Restaurant/Food patterns
    if (_foodPatterns.any((p) => normalized.contains(p))) {
      return ExpenseCategory.food;
    }

    // Transport patterns
    if (_transportPatterns.any((p) => normalized.contains(p))) {
      return ExpenseCategory.transport;
    }

    // Shopping patterns
    if (_shoppingPatterns.any((p) => normalized.contains(p))) {
      return ExpenseCategory.shopping;
    }

    return null;
  }

  static const _foodPatterns = [
    'restaurant', 'cafe', 'coffee', 'pizza', 'burger',
    'swiggy', 'zomato', 'dominos', 'mcdonald', 'starbucks',
    'bakery', 'dhaba', 'kitchen', 'food', 'eat',
  ];

  static const _transportPatterns = [
    'uber', 'ola', 'rapido', 'petrol', 'fuel', 'parking',
    'metro', 'bus', 'train', 'flight', 'airways', 'cab',
  ];

  static const _shoppingPatterns = [
    'amazon', 'flipkart', 'mall', 'store', 'mart', 'retail',
    'reliance', 'dmart', 'big bazaar', 'lifestyle', 'westside',
  ];
}

enum ExpenseCategory {
  food('Food & Dining', '🍔'),
  transport('Transport', '🚗'),
  shopping('Shopping', '🛍️'),
  bills('Bills & Utilities', '📱'),
  entertainment('Entertainment', '🎬'),
  health('Health', '💊'),
  groceries('Groceries', '🛒'),
  travel('Travel', '✈️'),
  education('Education', '📚'),
  other('Other', '📦');

  final String label;
  final String emoji;
  const ExpenseCategory(this.label, this.emoji);
}
```

---

## 7. Fallback Mechanisms

### 7.1 Fallback Strategy

```
┌───────────────────┐
│  Image Quality    │
│     Check         │
└─────────┬─────────┘
          │ Pass
          ▼
┌───────────────────┐     ┌─────────────────────┐
│    ML Kit OCR     │────▶│  OCR Confidence     │
│                   │     │      < 70%          │
└─────────┬─────────┘     └──────────┬──────────┘
          │                          │
          │ OCR OK                   ▼
          ▼               ┌─────────────────────┐
┌───────────────────┐     │  Show Manual Entry  │
│   Gemma Parser    │     │   + Partial Data    │
│                   │     └─────────────────────┘
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐     ┌─────────────────────┐
│ Parse Confidence  │────▶│  Confidence < 70%   │
│     Check         │     │                     │
└─────────┬─────────┘     └──────────┬──────────┘
          │                          │
          │ ≥ 70%                    ▼
          ▼               ┌─────────────────────┐
┌───────────────────┐     │  Show Preview +     │
│   Auto-populate   │     │  Editable Fields    │
│   Transaction     │     └─────────────────────┘
└───────────────────┘
```

### 7.2 Partial Data Handling

```dart
/// Handle partial OCR results
class PartialReceiptHandler {
  /// Create editable form from partial data
  ReceiptFormData createForm(ParsedReceipt? receipt, RecognizedReceiptText ocr) {
    return ReceiptFormData(
      // Use parsed data if available, otherwise null
      vendor: receipt?.vendor,
      amount: receipt?.totalPaise != null
          ? (receipt!.totalPaise / 100).toString()
          : null,
      date: receipt?.date ?? DateTime.now(),
      category: receipt != null
          ? _classifier.classify(receipt)
          : null,

      // Provide OCR text for manual extraction
      rawText: ocr.fullText,
      suggestedAmounts: _extractAmounts(ocr.fullText),

      // Track what needs user input
      missingFields: _getMissingFields(receipt),
    );
  }

  List<String> _getMissingFields(ParsedReceipt? receipt) {
    final missing = <String>[];
    if (receipt?.totalPaise == null || receipt!.totalPaise <= 0) {
      missing.add('amount');
    }
    if (receipt?.vendor == null) {
      missing.add('vendor');
    }
    if (receipt?.date == null) {
      missing.add('date');
    }
    return missing;
  }
}
```

---

## 8. Local Storage

### 8.1 Storage Strategy

| Data | Storage Location | Encryption | Retention |
|------|-----------------|------------|-----------|
| Receipt images | App Documents folder | AES-256 | Until transaction deleted |
| OCR raw text | SQLite (Drift) | SQLCipher | Indexed for search |
| Parsed data | TransactionEntries table | SQLCipher | Permanent |
| Processing cache | Temporary folder | None | Cleared after processing |

### 8.2 Receipt Storage Implementation

```dart
/// Receipt storage service
class ReceiptStorageService {
  final FlutterSecureStorage _secureStorage;
  final AppDatabase _database;

  /// Save receipt image with encryption
  Future<String> saveReceiptImage(File imageFile, String transactionId) async {
    // 1. Generate encryption key for this receipt
    final key = await _secureStorage.read(key: 'receipt_encryption_key')
        ?? await _generateAndStoreKey();

    // 2. Encrypt image
    final bytes = await imageFile.readAsBytes();
    final encrypted = _encrypt(bytes, key);

    // 3. Save to app documents
    final dir = await getApplicationDocumentsDirectory();
    final receiptDir = Directory('${dir.path}/receipts');
    await receiptDir.create(recursive: true);

    final receiptPath = '${receiptDir.path}/$transactionId.enc';
    final receiptFile = File(receiptPath);
    await receiptFile.writeAsBytes(encrypted);

    return receiptPath;
  }

  /// Load and decrypt receipt image
  Future<Uint8List> loadReceiptImage(String path) async {
    final key = await _secureStorage.read(key: 'receipt_encryption_key');
    if (key == null) throw ReceiptDecryptionError('No encryption key found');

    final file = File(path);
    final encrypted = await file.readAsBytes();
    return _decrypt(encrypted, key);
  }

  /// Delete receipt image
  Future<void> deleteReceiptImage(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
```

### 8.3 OCR Text Indexing

```dart
/// OCR text storage for search
class ReceiptSearchIndex {
  final AppDatabase _database;

  /// Index OCR text for full-text search
  Future<void> indexReceipt(String transactionId, String ocrText) async {
    // Store OCR text in a searchable format
    await _database.into(_database.receiptTextEntries).insert(
      ReceiptTextEntriesCompanion.insert(
        transactionId: transactionId,
        fullText: ocrText,
        keywords: _extractKeywords(ocrText),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Search receipts by text content
  Future<List<String>> searchReceipts(String query) async {
    final results = await (_database.select(_database.receiptTextEntries)
      ..where((t) => t.fullText.contains(query.toLowerCase()) |
                     t.keywords.contains(query.toLowerCase())))
      .get();

    return results.map((r) => r.transactionId).toList();
  }

  String _extractKeywords(String text) {
    // Extract significant words for keyword search
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final keywords = words
        .where((w) => w.length > 3)
        .where((w) => !_stopWords.contains(w))
        .toSet()
        .join(' ');
    return keywords;
  }

  static const _stopWords = ['the', 'and', 'for', 'are', 'but', 'not', 'you'];
}
```

---

## 9. Performance Requirements

| Metric | Target | Measurement |
|--------|--------|-------------|
| Image preprocessing | < 500ms | P95 |
| ML Kit OCR | < 1s | P95 |
| Gemma parsing | < 1.5s | P95 |
| Total pipeline | < 3s | P95 |
| Memory footprint | < 100MB | Peak during processing |
| Image encryption | < 200ms | For average receipt |

---

## 10. Testing Strategy

### 10.1 Test Receipt Dataset

| Category | Sample Size | Sources |
|----------|-------------|---------|
| Restaurant receipts | 50 | Various restaurants, cafes |
| Shopping receipts | 50 | Retail stores, online orders |
| Transport receipts | 30 | Uber, Ola, fuel stations |
| Utility bills | 20 | Electricity, phone, internet |
| Poor quality images | 30 | Blurry, dark, partial |

### 10.2 Accuracy Benchmarks

| Test | Target | Measurement |
|------|--------|-------------|
| Total amount extraction | ≥ 95% | Exact match |
| Vendor detection | ≥ 85% | Fuzzy match |
| Date parsing | ≥ 90% | Correct date |
| Line item extraction | ≥ 80% | Items found |
| Category classification | ≥ 85% | Correct category |
| Overall receipt parsing | ≥ 85% | All required fields |

### 10.3 Test Scenarios

```dart
void main() {
  group('ReceiptProcessingPipeline', () {
    test('processes clear restaurant receipt', () async {
      final result = await pipeline.process(testImages.clearRestaurant);
      expect(result.isOk, isTrue);
      expect(result.value.totalPaise, equals(125000)); // ₹1,250.00
      expect(result.value.vendor, contains('Restaurant'));
    });

    test('handles blurry image with fallback', () async {
      final result = await pipeline.process(testImages.blurryReceipt);
      expect(result.isOk, isTrue);
      expect(result.value.confidence, lessThan(0.7));
      expect(result.value.missingFields, isNotEmpty);
    });

    test('extracts line items correctly', () async {
      final result = await pipeline.process(testImages.itemizedBill);
      expect(result.value.lineItems.length, greaterThan(2));
    });
  });
}
```

---

## 11. Error Handling

### 11.1 Error Types

```dart
/// Receipt processing errors
sealed class ReceiptProcessingError {
  final String message;
  final String? userMessage;

  const ReceiptProcessingError(this.message, {this.userMessage});
}

class ImageCaptureError extends ReceiptProcessingError {
  const ImageCaptureError() : super(
    'Failed to capture image',
    userMessage: 'Could not access camera. Check permissions.',
  );
}

class ImageQualityError extends ReceiptProcessingError {
  final List<QualityIssue> issues;

  const ImageQualityError(this.issues) : super(
    'Image quality insufficient',
    userMessage: 'Please take a clearer photo.',
  );
}

class OcrFailedError extends ReceiptProcessingError {
  const OcrFailedError(String details) : super(
    'OCR extraction failed: $details',
    userMessage: 'Could not read the receipt. Try again.',
  );
}

class ParseFailedError extends ReceiptProcessingError {
  const ParseFailedError(String details) : super(
    'Receipt parsing failed: $details',
    userMessage: 'Could not understand the receipt format.',
  );
}

class StorageError extends ReceiptProcessingError {
  const StorageError(String details) : super(
    'Storage operation failed: $details',
    userMessage: 'Could not save receipt.',
  );
}
```

---

## 12. File Structure

```
app/lib/features/coins/
├── receipt/
│   ├── domain/
│   │   ├── models/
│   │   │   ├── parsed_receipt.dart
│   │   │   ├── line_item.dart
│   │   │   ├── image_quality_result.dart
│   │   │   └── receipt_processing_result.dart
│   │   └── services/
│   │       ├── receipt_image_preprocessor.dart
│   │       ├── receipt_text_recognizer.dart
│   │       ├── gemma_receipt_parser.dart
│   │       ├── receipt_category_classifier.dart
│   │       └── receipt_storage_service.dart
│   ├── application/
│   │   ├── providers/
│   │   │   └── receipt_providers.dart
│   │   └── use_cases/
│   │       ├── process_receipt_use_case.dart
│   │       └── search_receipts_use_case.dart
│   └── presentation/
│       ├── screens/
│       │   ├── receipt_capture_screen.dart
│       │   └── receipt_review_screen.dart
│       └── widgets/
│           ├── camera_overlay_widget.dart
│           ├── receipt_preview_card.dart
│           └── editable_receipt_form.dart
```

---

## 13. Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `google_mlkit_text_recognition` | ^0.11.0 | On-device OCR |
| `image_picker` | ^1.0.4 | Camera/gallery access |
| `image` | ^4.1.3 | Image preprocessing |
| `flutter_secure_storage` | ^9.0.0 | Encryption key storage |
| `core_ai` | local | Gemma model access |
| `path_provider` | ^2.1.1 | File system access |

---

## 14. Security Considerations

1. **On-device only**: All OCR and parsing runs locally
2. **Encrypted storage**: Receipt images encrypted at rest (AES-256)
3. **No cloud upload**: Receipt images never leave device
4. **Secure deletion**: Shred receipt files on transaction deletion
5. **Permission handling**: Request camera permission only when needed

---

## 15. Open Questions

1. Should we support scanning from gallery in addition to camera?
2. Multi-receipt batch scanning for end-of-day logging?
3. Should extracted vendor names be normalized/mapped to known merchants?
4. Integration with SMS/email receipt parsers (future)?

---

**Document History**

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-02-15 | 1.0 | Airo Team | Initial draft |
```

