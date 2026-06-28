import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/gemini_nano_service.dart';
import '../models/receipt_item.dart';
import 'receipt_litert_lm_extraction_service.dart';
import 'receipt_pdf_renderer_service.dart';

/// Service for parsing receipts from images using OCR
abstract class ReceiptParserService {
  /// Parse a receipt image and extract items
  Future<ParsedReceipt> parseReceipt(
    File imageFile, {
    bool allowFallback = false,
  });

  /// Render a PDF locally, OCR pages in order, and extract receipt items.
  Future<ParsedReceipt> parseReceiptPdf(
    File pdfFile, {
    bool allowFallback = false,
  });

  /// Render PDF bytes locally, OCR pages in order, and extract receipt items.
  Future<ParsedReceipt> parseReceiptPdfBytes(
    List<int> bytes, {
    bool allowFallback = false,
  });

  /// Parse receipt from image bytes.
  Future<ParsedReceipt> parseReceiptFromBytes(
    List<int> bytes, {
    String mimeType = 'image/jpeg',
    bool allowFallback = false,
  });
}

/// Extension point for a later non-local parser.
///
/// The production default is intentionally disabled. This keeps receipt parsing
/// local-first today while preserving a single hook for a future server/API path.
abstract class ReceiptParsingFallback {
  Future<ParsedReceipt?> parseImageFile(File imageFile);

  Future<ParsedReceipt?> parseBytes(
    List<int> bytes, {
    required String mimeType,
  });
}

class DisabledReceiptParsingFallback implements ReceiptParsingFallback {
  const DisabledReceiptParsingFallback();

  @override
  Future<ParsedReceipt?> parseImageFile(File imageFile) async => null;

  @override
  Future<ParsedReceipt?> parseBytes(
    List<int> bytes, {
    required String mimeType,
  }) async => null;
}

abstract class RenderedReceiptPageTextExtractor {
  Future<String> extractText(RenderedPdfPage page);
}

class MLKitRenderedReceiptPageTextExtractor
    implements RenderedReceiptPageTextExtractor {
  final TextRecognizer _textRecognizer;

  MLKitRenderedReceiptPageTextExtractor({TextRecognizer? textRecognizer})
    : _textRecognizer =
          textRecognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> extractText(RenderedPdfPage page) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/airo_receipt_pdf_page_${page.pageNumber}.png',
    );
    await tempFile.writeAsBytes(page.bytes, flush: true);
    final recognizedText = await _textRecognizer.processImage(
      InputImage.fromFile(tempFile),
    );
    return recognizedText.text;
  }

  Future<void> close() => _textRecognizer.close();
}

class ReceiptParsingException implements Exception {
  final String message;

  const ReceiptParsingException(this.message);

  @override
  String toString() => message;
}

/// Hybrid ML Kit + AI implementation for intelligent receipt parsing
///
/// Parsing Strategy (with TODO for optimization):
/// 1. ML Kit OCR (on-device, fast)
/// 2. LiteRT-LM receipt extraction where available
/// 3. Gemini Nano parsing where available
/// 4. Regex parsing (fast, works offline)
/// 5. Optional fallback hook, disabled until a future implementation is wired
class MLKitReceiptParserService implements ReceiptParserService {
  final _uuid = const Uuid();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _geminiNano = GeminiNanoService();
  final _liteRtLmReceiptParser = ReceiptLiteRtLmExtractionService();
  final ReceiptParsingFallback _fallback;
  final ReceiptPdfRenderer _pdfRenderer;
  final RenderedReceiptPageTextExtractor _pdfPageTextExtractor;

  MLKitReceiptParserService({
    this._fallback = const DisabledReceiptParsingFallback(),
    this._pdfRenderer = const PdfxReceiptPdfRenderer(),
    RenderedReceiptPageTextExtractor? pdfPageTextExtractor,
  }) : _pdfPageTextExtractor =
           pdfPageTextExtractor ?? MLKitRenderedReceiptPageTextExtractor();

  // Detect vendor names
  static const _knownVendors = [
    'Instamart',
    'Swiggy',
    'Zepto',
    'BigBasket',
    'Blinkit',
    'Amazon Fresh',
    'JioMart',
    'DMart',
    'Dunzo',
    'Zomato',
    'Urban Company',
  ];

  // Words to filter out - these are NOT item names
  static const _excludePatterns = [
    'completed',
    'delivered',
    'order',
    'address',
    'floor',
    'survey',
    'payment',
    'paid',
    'thank',
    'invoice',
    'receipt',
    'bill',
    'customer',
    'phone',
    'mobile',
    'date',
    'time',
    'status',
  ];

  @override
  Future<ParsedReceipt> parseReceipt(
    File imageFile, {
    bool allowFallback = false,
  }) async {
    // Strategy 1: ML Kit OCR, then local LiteRT-LM receipt extraction.
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    debugPrint(
      '=== OCR Raw Text ===\n${recognizedText.text}\n===================',
    );

    try {
      final liteRtLmResult = await _liteRtLmReceiptParser.parseReceiptText(
        recognizedText.text,
        imagePath: imageFile.path,
      );
      if (liteRtLmResult != null && liteRtLmResult.items.isNotEmpty) {
        debugPrint(
          'Parsed with LiteRT-LM: ${liteRtLmResult.items.length} items',
        );
        return liteRtLmResult;
      }
    } catch (e) {
      debugPrint('LiteRT-LM parsing failed, trying Gemini Nano: $e');
    }

    // Strategy 2: Gemini Nano for on-device intelligent parsing
    if (await _geminiNano.isSupported()) {
      try {
        return await _parseWithGeminiNano(recognizedText.text, imageFile.path);
      } catch (e) {
        debugPrint('Gemini Nano parsing failed, falling back to regex: $e');
      }
    }

    // Strategy 3: Optional later fallback hook. Disabled by default.
    if (allowFallback) {
      try {
        final fallbackResult = await _fallback.parseImageFile(imageFile);
        if (fallbackResult != null && fallbackResult.items.isNotEmpty) {
          debugPrint(
            'Parsed with fallback hook: ${fallbackResult.items.length} items',
          );
          return fallbackResult;
        }
      } catch (e) {
        debugPrint('Receipt fallback hook failed, falling back to regex: $e');
      }
    }

    // Strategy 4: Fallback to regex parsing (works offline)
    return _parseTextWithRegex(recognizedText.text, imageFile.path);
  }

  @override
  Future<ParsedReceipt> parseReceiptPdf(
    File pdfFile, {
    bool allowFallback = false,
  }) async {
    try {
      final pages = await _pdfRenderer.renderFile(pdfFile);
      return await _parseRenderedPdfPages(pages, imagePath: pdfFile.path);
    } catch (e) {
      if (allowFallback) {
        final fallbackResult = await _fallback.parseImageFile(pdfFile);
        if (fallbackResult != null && fallbackResult.items.isNotEmpty) {
          return fallbackResult;
        }
      }
      throw ReceiptParsingException(
        "Couldn't parse this PDF locally. Add items manually.",
      );
    }
  }

  @override
  Future<ParsedReceipt> parseReceiptPdfBytes(
    List<int> bytes, {
    bool allowFallback = false,
  }) async {
    try {
      final pages = await _pdfRenderer.renderBytes(bytes);
      return await _parseRenderedPdfPages(pages);
    } catch (e) {
      if (allowFallback) {
        final fallbackResult = await _fallback.parseBytes(
          bytes,
          mimeType: 'application/pdf',
        );
        if (fallbackResult != null && fallbackResult.items.isNotEmpty) {
          return fallbackResult;
        }
      }
      throw ReceiptParsingException(
        "Couldn't parse this PDF locally. Add items manually.",
      );
    }
  }

  @override
  Future<ParsedReceipt> parseReceiptFromBytes(
    List<int> bytes, {
    String mimeType = 'image/jpeg',
    bool allowFallback = false,
  }) async {
    if (mimeType == 'application/pdf') {
      return parseReceiptPdfBytes(bytes, allowFallback: allowFallback);
    }

    if (allowFallback) {
      try {
        final fallbackResult = await _fallback.parseBytes(
          bytes,
          mimeType: mimeType,
        );
        if (fallbackResult != null && fallbackResult.items.isNotEmpty) {
          return fallbackResult;
        }
      } catch (e) {
        debugPrint('Receipt byte fallback hook failed: $e');
      }
    }

    throw UnsupportedError(
      'Local byte receipt parsing is not available yet. Use an image file path.',
    );
  }

  Future<ParsedReceipt> _parseRenderedPdfPages(
    List<RenderedPdfPage> pages, {
    String? imagePath,
  }) async {
    if (pages.isEmpty) {
      throw const ReceiptParsingException(
        "Couldn't parse this PDF locally. Add items manually.",
      );
    }

    final orderedPages = [...pages]
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    final pageTexts = <String>[];
    for (final page in orderedPages) {
      pageTexts.add(await _pdfPageTextExtractor.extractText(page));
    }

    return parseRecognizedPageTextsForTesting(pageTexts, imagePath: imagePath);
  }

  /// Parse receipt using Gemini Nano for intelligent extraction
  Future<ParsedReceipt> _parseWithGeminiNano(
    String rawText,
    String? imagePath,
  ) async {
    if (!_geminiNano.isInitialized) {
      await _geminiNano.initialize();
    }

    final prompt =
        '''Extract grocery/food items from this receipt text.
Return ONLY a JSON array of items. Each item must have: name (string), price (number in rupees).
Ignore addresses, order status, delivery info, and non-item text.
Only include actual purchasable items like food, groceries, or products.

Receipt text:
$rawText

Example output format:
[{"name": "Milk 500ml", "price": 28.00}, {"name": "Bread", "price": 45.00}]

JSON output:''';

    final response = await _geminiNano.generateContent(prompt);
    debugPrint('Gemini Nano response: $response');

    return _parseGeminiResponse(response, rawText, imagePath);
  }

  /// Parse Gemini Nano's JSON response into ParsedReceipt
  ParsedReceipt _parseGeminiResponse(
    String response,
    String rawText,
    String? imagePath,
  ) {
    final items = <ReceiptItem>[];
    int itemTotal = 0;

    try {
      // Extract JSON array from response
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final List<dynamic> parsed = json.decode(jsonStr);

        for (final item in parsed) {
          if (item is Map<String, dynamic>) {
            final name = item['name']?.toString() ?? '';
            final price = (item['price'] is num)
                ? (item['price'] as num).toDouble()
                : double.tryParse(item['price']?.toString() ?? '0') ?? 0;

            if (name.isNotEmpty && price > 0) {
              final paise = (price * 100).round();
              items.add(
                ReceiptItem(
                  id: _uuid.v4(),
                  name: name,
                  quantity: 1,
                  unitPricePaise: paise,
                  totalPricePaise: paise,
                ),
              );
              itemTotal += paise;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing Gemini response: $e');
    }

    // If Gemini parsing failed, fallback to regex
    if (items.isEmpty) {
      return _parseTextWithRegex(rawText, imagePath);
    }

    // Extract vendor and order ID
    String? vendor;
    for (final v in _knownVendors) {
      if (rawText.toLowerCase().contains(v.toLowerCase())) {
        vendor = v;
        break;
      }
    }

    String? orderId;
    final orderIdMatch = RegExp(r'#?\s*(\d{10,})').firstMatch(rawText);
    if (orderIdMatch != null) {
      orderId = orderIdMatch.group(1);
    }

    // Extract grand total
    int? grandTotal;
    final totalMatch = RegExp(
      r'(?:grand\s*total|total|amount)\s*[:\-]?\s*₹?\s*(\d+(?:[.,]\d{2})?)',
      caseSensitive: false,
    ).firstMatch(rawText);
    if (totalMatch != null) {
      grandTotal = _parsePriceToPaise(totalMatch.group(1)!);
    }

    return ParsedReceipt(
      id: _uuid.v4(),
      vendor: vendor,
      orderId: orderId,
      orderDate: DateTime.now(),
      items: items,
      fees: const [],
      itemTotalPaise: itemTotal,
      grandTotalPaise: grandTotal ?? itemTotal,
      imagePath: imagePath,
      parsedAt: DateTime.now(),
    );
  }

  /// Improved regex-based parsing with Instamart-style support
  /// Handles items and prices on separate lines (common in grocery apps)
  ParsedReceipt _parseTextWithRegex(String rawText, String? imagePath) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Detect vendor
    String? vendor;
    for (final v in _knownVendors) {
      if (rawText.toLowerCase().contains(v.toLowerCase())) {
        vendor = v;
        break;
      }
    }

    // Detect order ID (long number)
    final orderId = _detectOrderId(lines, rawText);

    // Strategy: Try Instamart-style parsing first (items & prices on separate lines)
    var result = _parseInstamartStyle(lines, vendor, orderId, imagePath);
    if (result.items.isNotEmpty) {
      return result;
    }

    // Strategy: Try invoice-style parsing where item labels and totals are
    // separated into table regions.
    result = _parseInvoiceStyle(lines, vendor, orderId, imagePath);
    if (result.items.isNotEmpty) {
      return result;
    }

    // Fallback: Try inline parsing (item and price on same line)
    return _parseInlineStyle(lines, vendor, orderId, imagePath);
  }

  @visibleForTesting
  ParsedReceipt parseRecognizedTextForTesting(
    String rawText, {
    String? imagePath,
  }) {
    return _parseTextWithRegex(rawText, imagePath);
  }

  @visibleForTesting
  ParsedReceipt parseRecognizedPageTextsForTesting(
    List<String> pageTexts, {
    String? imagePath,
  }) {
    final mergedText = pageTexts
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n');
    if (mergedText.isEmpty) {
      throw const ReceiptParsingException(
        "Couldn't parse this PDF locally. Add items manually.",
      );
    }

    final receipt = _parseTextWithRegex(mergedText, imagePath);
    if (_isMockReceipt(receipt)) {
      throw const ReceiptParsingException(
        "Couldn't parse this PDF locally. Add items manually.",
      );
    }
    return receipt;
  }

  ParsedReceipt _mergePageReceipts(
    List<ParsedReceipt> receipts, {
    String? imagePath,
  }) {
    if (receipts.length == 1) {
      return receipts.single;
    }

    final items = receipts.expand((receipt) => receipt.items).toList();
    final fees = receipts.expand((receipt) => receipt.fees).toList();
    final itemTotal = receipts.fold<int>(
      0,
      (sum, receipt) => sum + receipt.itemTotalPaise,
    );
    final grandTotal = receipts.fold<int>(
      0,
      (sum, receipt) => sum + receipt.grandTotalPaise,
    );

    return ParsedReceipt(
      id: _uuid.v4(),
      vendor: _firstNonEmptyString(receipts.map((receipt) => receipt.vendor)),
      orderId: _firstNonEmptyString(receipts.map((receipt) => receipt.orderId)),
      orderDate: _firstDate(receipts.map((receipt) => receipt.orderDate)),
      items: items,
      fees: fees,
      itemTotalPaise: itemTotal,
      grandTotalPaise: grandTotal,
      imagePath: imagePath,
      parsedAt: DateTime.now(),
    );
  }

  String? _firstNonEmptyString(Iterable<String?> values) {
    for (final value in values) {
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  DateTime? _firstDate(Iterable<DateTime?> values) {
    for (final value in values) {
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  bool _isMockReceipt(ParsedReceipt receipt) {
    return receipt.vendor == 'Unknown' &&
        receipt.items.length == 1 &&
        receipt.items.single.name.contains('OCR failed');
  }

  String? _detectOrderId(List<String> lines, String rawText) {
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (!lower.contains('invoice no') && !lower.contains('order no')) {
        continue;
      }

      final searchLimit = (i + 4).clamp(0, lines.length);
      for (var j = i; j < searchLimit; j++) {
        final match = RegExp(r'([A-Z]*\d{8,})').firstMatch(lines[j]);
        if (match == null) continue;
        return match.group(1)!.replaceAll(RegExp(r'\D'), '');
      }
    }

    final orderIdMatch = RegExp(r'#?\s*(\d{10,})').firstMatch(rawText);
    return orderIdMatch?.group(1);
  }

  /// Parse Instamart-style receipts where items start with "V 1x" and prices are on separate lines
  ParsedReceipt _parseInstamartStyle(
    List<String> lines,
    String? vendor,
    String? orderId,
    String? imagePath,
  ) {
    // Pattern for item lines: V followed by quantity (1x, lx, etc.)
    final itemPattern = RegExp(
      r'^V\s*[l1]?\s*x?\s*(.+)$',
      caseSensitive: false,
    );

    // Pattern for price lines: optional corrupted prefix + number.decimal
    // OCR often misreads ₹ as F, Z, T, R, I, O, 7 (especially for prices)
    final pricePattern = RegExp(r'^[FZTRIOЩ₹7]?(\d+)[.,](\d+)$');

    final itemNames = <String>[];
    final rawPrices = <int>[];
    int? itemBillTotal; // Reference total from receipt
    int? grandTotal;
    final fees = <ReceiptFee>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      // Check for Item Bill total (this is our reference for validation)
      if (lineLower.contains('item bill') && i + 1 < lines.length) {
        itemBillTotal = _parseCorruptedPrice(lines[i + 1]);
        debugPrint('Found Item Bill total: ₹${itemBillTotal / 100}');
        continue;
      }

      // Check for grand total (next line has the price)
      if (lineLower.contains('grand total') && i + 1 < lines.length) {
        grandTotal = _parseCorruptedPrice(lines[i + 1]);
        continue;
      }

      // Check for delivery fee
      if (lineLower.contains('delivery') && lineLower.contains('free')) {
        fees.add(
          const ReceiptFee(
            type: FeeType.delivery,
            amountPaise: 0,
            isFree: true,
          ),
        );
        continue;
      }

      // Parse item lines
      final itemMatch = itemPattern.firstMatch(line);
      if (itemMatch != null) {
        var name = itemMatch.group(1)!.trim();
        // Remove leading quantity markers like "1x", "lx"
        name = name.replaceAll(
          RegExp(r'^[0-9l]+x\s*', caseSensitive: false),
          '',
        );
        // Remove leading "0" typos (0nion -> Onion)
        name = name.replaceFirst(RegExp(r'^0(?=[a-zA-Z])'), '');
        if (name.length > 2) {
          itemNames.add(name);
        }
        continue;
      }

      // Parse price lines - collect all potential prices
      final priceMatch = pricePattern.firstMatch(line);
      if (priceMatch != null) {
        final paise = _parseCorruptedPrice(line);
        if (paise > 0 && paise < 200000) {
          rawPrices.add(paise);
        }
      }
    }

    // Fix OCR price errors: ₹ is often read as 7, causing 45.0 -> 745.0
    // Use Item Bill total to validate and correct prices
    final correctedPrices = _correctPrices(
      rawPrices,
      itemBillTotal,
      itemNames.length,
    );

    // Match items to corrected prices
    final items = <ReceiptItem>[];
    int itemTotal = 0;

    for (var i = 0; i < itemNames.length && i < correctedPrices.length; i++) {
      items.add(
        ReceiptItem(
          id: _uuid.v4(),
          name: itemNames[i],
          quantity: 1,
          unitPricePaise: correctedPrices[i],
          totalPricePaise: correctedPrices[i],
        ),
      );
      itemTotal += correctedPrices[i];
    }

    debugPrint(
      'Instamart parser: Found ${itemNames.length} items, ${correctedPrices.length} prices, total: ₹${itemTotal / 100}',
    );

    return ParsedReceipt(
      id: _uuid.v4(),
      vendor: vendor,
      orderId: orderId,
      orderDate: DateTime.now(),
      items: items,
      fees: fees,
      itemTotalPaise: itemTotal,
      grandTotalPaise: grandTotal ?? itemBillTotal ?? itemTotal,
      imagePath: imagePath,
      parsedAt: DateTime.now(),
    );
  }

  /// Correct OCR price errors using Item Bill total as reference
  /// Common error: ₹ read as 7, so ₹45.0 becomes 745.0
  /// BUT: Valid prices like ₹745.0 should NOT be corrected
  List<int> _correctPrices(
    List<int> rawPrices,
    int? itemBillTotal,
    int itemCount,
  ) {
    if (rawPrices.isEmpty) return [];

    // If we have a reference total, use it to validate corrections
    // Don't blindly strip leading 7s - many valid prices are in 700s range
    final corrected = <int>[];

    for (final price in rawPrices) {
      // Skip prices that are way too high (likely OCR errors or totals)
      // Keep prices up to ₹1000 per item as reasonable for groceries
      if (price <= 100000) {
        // <= ₹1000 per item
        corrected.add(price);
      }
    }

    // If we have Item Bill total, validate our corrected prices
    if (itemBillTotal != null && corrected.isNotEmpty) {
      final sumCorrected = corrected.fold<int>(0, (sum, p) => sum + p);
      final difference = (sumCorrected - itemBillTotal).abs();
      final tolerance = itemBillTotal * 0.1; // 10% tolerance

      if (difference > tolerance) {
        debugPrint(
          'Warning: Corrected sum ₹${sumCorrected / 100} differs from Item Bill ₹${itemBillTotal / 100}',
        );
      }
    }

    return corrected;
  }

  /// Parse invoice layouts where OCR groups labels and monetary values in
  /// separate table columns rather than keeping item and price on one line.
  ParsedReceipt _parseInvoiceStyle(
    List<String> lines,
    String? vendor,
    String? orderId,
    String? imagePath,
  ) {
    final hasInvoiceMarker = lines.any((line) {
      final lower = line.toLowerCase();
      return lower.contains('tax invoice') ||
          lower.contains('invoice no') ||
          lower.contains('total amount');
    });
    if (!hasInvoiceMarker) {
      return _emptyReceipt(vendor, orderId, imagePath);
    }

    final receipts = _splitInvoiceSections(lines)
        .map(
          (section) => _parseInvoiceSection(
            section,
            vendor,
            _detectOrderId(section, section.join('\n')) ?? orderId,
            imagePath,
          ),
        )
        .where((receipt) => receipt.items.isNotEmpty)
        .toList();

    if (receipts.isEmpty) {
      return _emptyReceipt(vendor, orderId, imagePath);
    }

    return _mergePageReceipts(receipts, imagePath: imagePath);
  }

  List<List<String>> _splitInvoiceSections(List<String> lines) {
    final sections = <List<String>>[];
    var current = <String>[];

    for (final line in lines) {
      final lower = line.toLowerCase();
      final startsNextInvoice =
          lower.contains('tax invoice') || lower.contains('invoice no');
      if (startsNextInvoice &&
          current.isNotEmpty &&
          _invoiceSectionHasItems(current) &&
          _findInvoiceGrandTotal(current) != null) {
        sections.add(current);
        current = <String>[];
      }
      current.add(line);
    }

    if (current.isNotEmpty) {
      sections.add(current);
    }

    return sections;
  }

  bool _invoiceSectionHasItems(List<String> lines) {
    return lines.any((line) => line.toLowerCase() == 'items');
  }

  ParsedReceipt _parseInvoiceSection(
    List<String> lines,
    String? vendor,
    String? orderId,
    String? imagePath,
  ) {
    final itemNames = <String>[];
    var inItemsSection = false;
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower == 'items') {
        inItemsSection = true;
        continue;
      }
      if (!inItemsSection) continue;
      if (lower.contains('total amount') ||
          lower.contains('tax invoice') ||
          lower.contains('gross amount') ||
          lower.contains('taxable value') ||
          lower.contains('delivery service provider')) {
        break;
      }
      if (lower.startsWith('sac:')) continue;
      if (line.length > 2 &&
          !_excludePatterns.any((pattern) => lower.contains(pattern))) {
        itemNames.add(line);
      }
    }

    final totalAmount = _findInvoiceGrandTotal(lines);
    if (itemNames.isEmpty || totalAmount == null || totalAmount <= 0) {
      return _emptyReceipt(vendor, orderId, imagePath);
    }

    final itemAmount = totalAmount ~/ itemNames.length;
    var remainder = totalAmount % itemNames.length;
    final items = <ReceiptItem>[];
    var itemTotal = 0;
    for (final name in itemNames) {
      final paise = itemAmount + (remainder > 0 ? 1 : 0);
      if (remainder > 0) remainder--;
      items.add(
        ReceiptItem(
          id: _uuid.v4(),
          name: name,
          quantity: 1,
          unitPricePaise: paise,
          totalPricePaise: paise,
        ),
      );
      itemTotal += paise;
    }

    return ParsedReceipt(
      id: _uuid.v4(),
      vendor: vendor,
      orderId: orderId,
      orderDate: DateTime.now(),
      items: items,
      fees: const [],
      itemTotalPaise: itemTotal,
      grandTotalPaise: totalAmount,
      imagePath: imagePath,
      parsedAt: DateTime.now(),
    );
  }

  ParsedReceipt _emptyReceipt(
    String? vendor,
    String? orderId,
    String? imagePath,
  ) {
    return ParsedReceipt(
      id: _uuid.v4(),
      vendor: vendor,
      orderId: orderId,
      orderDate: DateTime.now(),
      items: const [],
      fees: const [],
      itemTotalPaise: 0,
      grandTotalPaise: 0,
      imagePath: imagePath,
      parsedAt: DateTime.now(),
    );
  }

  int? _findInvoiceGrandTotal(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].toLowerCase().contains('total amount')) continue;

      final sameLine = _extractMoneyAmount(lines[i]);
      if (sameLine != null) return sameLine;
    }

    final amounts = lines
        .map(_extractMoneyAmount)
        .whereType<int>()
        .where((amount) => amount > 0)
        .toList();
    if (amounts.isEmpty) return null;
    return amounts.last;
  }

  int? _extractMoneyAmount(String line) {
    final match = RegExp(
      r'(?:₹|rs\.?)\s*-?\s*(\d+(?:[.,]\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(line);
    if (match == null) return null;
    return _parsePriceToPaise(match.group(1)!);
  }

  /// Parse inline-style receipts where item and price are on the same line
  ParsedReceipt _parseInlineStyle(
    List<String> lines,
    String? vendor,
    String? orderId,
    String? imagePath,
  ) {
    final items = <ReceiptItem>[];
    int? grandTotal;
    int itemTotal = 0;
    final fees = <ReceiptFee>[];

    // Price pattern: ₹123.45 or Rs.123 or just numbers with decimals
    final pricePattern = RegExp(
      r'₹\s*(\d+(?:[.,]\d{2})?)|Rs\.?\s*(\d+(?:[.,]\d{2})?)|(\d+[.,]\d{2})\s*$',
      caseSensitive: false,
    );

    for (final line in lines) {
      final lineLower = line.toLowerCase();

      // Skip lines with exclude patterns
      if (_excludePatterns.any((p) => lineLower.contains(p))) continue;
      if (line.length < 4 || RegExp(r'^\d+$').hasMatch(line)) continue;

      // Check for total
      if (lineLower.contains('total') || lineLower.contains('grand')) {
        final priceMatch = pricePattern.firstMatch(line);
        if (priceMatch != null) {
          grandTotal = _parsePriceToPaise(
            priceMatch.group(1) ??
                priceMatch.group(2) ??
                priceMatch.group(3) ??
                '0',
          );
        }
        continue;
      }

      // Try to parse as item (inline format)
      final priceMatch = pricePattern.firstMatch(line);
      if (priceMatch != null) {
        final priceStr =
            priceMatch.group(1) ??
            priceMatch.group(2) ??
            priceMatch.group(3) ??
            '0';
        final paise = _parsePriceToPaise(priceStr);

        if (paise > 0 && paise < 200000) {
          var name = line.substring(0, priceMatch.start).trim();
          name = name
              .replaceAll(RegExp(r'[₹Rs\.INR\d,\.\-x×\|]+$'), '')
              .replaceAll(RegExp(r'^\d+\s*[x×]\s*'), '')
              .trim();

          if (name.length > 2 &&
              !_excludePatterns.any((p) => name.toLowerCase().contains(p))) {
            items.add(
              ReceiptItem(
                id: _uuid.v4(),
                name: name,
                quantity: 1,
                unitPricePaise: paise,
                totalPricePaise: paise,
              ),
            );
            itemTotal += paise;
          }
        }
      }
    }

    if (items.isEmpty) {
      return _createMockReceipt(imagePath);
    }

    return ParsedReceipt(
      id: _uuid.v4(),
      vendor: vendor,
      orderId: orderId,
      orderDate: DateTime.now(),
      items: items,
      fees: fees,
      itemTotalPaise: itemTotal,
      grandTotalPaise: grandTotal ?? itemTotal,
      imagePath: imagePath,
      parsedAt: DateTime.now(),
    );
  }

  /// Parse price with corrupted rupee symbol (F, Z, T instead of ₹)
  int _parseCorruptedPrice(String priceStr) {
    // Remove corrupted prefix characters
    final clean = priceStr.replaceAll(RegExp(r'^[FZTRIOЩ₹\s]+'), '');
    final parts = clean.split(RegExp(r'[.,]'));
    if (parts.length >= 2) {
      final rupees = int.tryParse(parts[0]) ?? 0;
      final paise =
          int.tryParse(parts[1].padRight(2, '0').substring(0, 2)) ?? 0;
      return rupees * 100 + paise;
    }
    return (int.tryParse(clean) ?? 0) * 100;
  }

  int _parsePriceToPaise(String priceStr) {
    final clean = priceStr.replaceAll(',', '').replaceAll(' ', '');
    final parts = clean.split(RegExp(r'[.,]'));

    if (parts.length == 2) {
      final rupees = int.tryParse(parts[0]) ?? 0;
      final paise =
          int.tryParse(parts[1].padRight(2, '0').substring(0, 2)) ?? 0;
      return rupees * 100 + paise;
    } else {
      return (int.tryParse(clean) ?? 0) * 100;
    }
  }

  ParsedReceipt _createMockReceipt(String? imagePath) {
    final items = [
      ReceiptItem(
        id: _uuid.v4(),
        name: 'Item 1 (OCR failed - add items manually)',
        quantity: 1,
        unitPricePaise: 10000,
        totalPricePaise: 10000,
      ),
    ];

    return ParsedReceipt(
      id: _uuid.v4(),
      vendor: 'Unknown',
      orderDate: DateTime.now(),
      items: items,
      fees: const [],
      itemTotalPaise: 10000,
      grandTotalPaise: 10000,
      imagePath: imagePath,
      parsedAt: DateTime.now(),
    );
  }

  void dispose() {
    _textRecognizer.close();
    final pdfExtractor = _pdfPageTextExtractor;
    if (pdfExtractor is MLKitRenderedReceiptPageTextExtractor) {
      pdfExtractor.close();
    }
  }
}
