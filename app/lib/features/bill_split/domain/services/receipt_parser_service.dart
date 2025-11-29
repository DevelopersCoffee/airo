import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/gemini_nano_service.dart';
import '../../../../core/services/gemini_api_service.dart';
import '../models/receipt_item.dart';

/// Service for parsing receipts from images using OCR
abstract class ReceiptParserService {
  /// Parse a receipt image and extract items
  Future<ParsedReceipt> parseReceipt(File imageFile);

  /// Parse receipt from image bytes (for web)
  Future<ParsedReceipt> parseReceiptFromBytes(List<int> bytes);
}

/// Hybrid ML Kit + AI implementation for intelligent receipt parsing
///
/// Parsing Strategy (with TODO for optimization):
/// 1. Try Gemini API Vision (managed, accurate) - TODO: Replace with on-device
/// 2. Try ML Kit OCR + Gemini Nano (on-device, private)
/// 3. Fallback to regex parsing (fast, works offline)
///
/// TODO: OPTIMIZATION - Preferred on-device flow:
/// 1. ML Kit OCR (on-device, fast)
/// 2. Gemini Nano parsing (on-device, private)
/// 3. Cloud API only for complex/failed receipts (user consent required)
class MLKitReceiptParserService implements ReceiptParserService {
  final _uuid = const Uuid();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _geminiNano = GeminiNanoService();

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
  Future<ParsedReceipt> parseReceipt(File imageFile) async {
    // Strategy 1: Try Gemini API Vision for best accuracy
    // TODO: OPTIMIZATION - Make this opt-in for cloud processing
    // Only use cloud when user explicitly enables it or on-device fails
    if (geminiApiService.isAvailable) {
      try {
        final result = await _parseWithGeminiApi(imageFile);
        if (result != null && result.items.isNotEmpty) {
          debugPrint('Parsed with Gemini API: ${result.items.length} items');
          return result;
        }
      } catch (e) {
        debugPrint('Gemini API failed, trying on-device: $e');
      }
    }

    // Strategy 2: ML Kit OCR + Gemini Nano (on-device)
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    debugPrint(
      '=== OCR Raw Text ===\n${recognizedText.text}\n===================',
    );

    // Try Gemini Nano for on-device intelligent parsing
    if (await _geminiNano.isSupported()) {
      try {
        return await _parseWithGeminiNano(recognizedText.text, imageFile.path);
      } catch (e) {
        debugPrint('Gemini Nano parsing failed, falling back to regex: $e');
      }
    }

    // Strategy 3: Fallback to regex parsing (works offline)
    return _parseTextWithRegex(recognizedText.text, imageFile.path);
  }

  /// Parse receipt using Gemini API Vision (cloud-based)
  /// TODO: OPTIMIZATION - Replace with on-device processing:
  /// - ML Kit OCR for text extraction
  /// - Gemini Nano for intelligent parsing
  /// - Only use cloud API for complex receipts with user consent
  Future<ParsedReceipt?> _parseWithGeminiApi(File imageFile) async {
    final result = await geminiApiService.parseReceiptImage(imageFile);
    if (result == null) return null;

    final items = <ReceiptItem>[];
    int itemTotal = 0;

    final itemsList = result['items'] as List<dynamic>?;
    if (itemsList != null) {
      for (final item in itemsList) {
        final name = item['name']?.toString() ?? '';
        final price = (item['price'] is num)
            ? (item['price'] as num).toDouble()
            : double.tryParse(item['price']?.toString() ?? '0') ?? 0;
        final qty = item['quantity'] ?? 1;

        if (name.isNotEmpty && price > 0) {
          final paise = (price * 100).round();
          items.add(
            ReceiptItem(
              id: _uuid.v4(),
              name: name,
              quantity: qty is int ? qty : 1,
              unitPricePaise: paise,
              totalPricePaise: paise * (qty is int ? qty : 1),
            ),
          );
          itemTotal += paise * (qty is int ? qty : 1);
        }
      }
    }

    if (items.isEmpty) return null;

    final total = result['total'] is num
        ? ((result['total'] as num) * 100).round()
        : itemTotal;

    return ParsedReceipt(
      id: _uuid.v4(),
      vendor: result['vendor']?.toString(),
      orderId: null,
      orderDate: DateTime.now(),
      items: items,
      fees: const [],
      itemTotalPaise: itemTotal,
      grandTotalPaise: total,
      imagePath: imageFile.path,
      parsedAt: DateTime.now(),
    );
  }

  @override
  Future<ParsedReceipt> parseReceiptFromBytes(List<int> bytes) async {
    await Future.delayed(const Duration(seconds: 1));
    return _createMockReceipt(null);
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
    String? orderId;
    final orderIdMatch = RegExp(r'#?\s*(\d{10,})').firstMatch(rawText);
    if (orderIdMatch != null) {
      orderId = orderIdMatch.group(1);
    }

    // Strategy: Try Instamart-style parsing first (items & prices on separate lines)
    var result = _parseInstamartStyle(lines, vendor, orderId, imagePath);
    if (result.items.isNotEmpty) {
      return result;
    }

    // Fallback: Try inline parsing (item and price on same line)
    return _parseInlineStyle(lines, vendor, orderId, imagePath);
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
  List<int> _correctPrices(
    List<int> rawPrices,
    int? itemBillTotal,
    int itemCount,
  ) {
    if (rawPrices.isEmpty) return [];

    // If no reference total, try to detect and fix common OCR errors
    final corrected = <int>[];

    for (final price in rawPrices) {
      var correctedPrice = price;

      // Check if price starts with 7 and is suspiciously large
      // ₹45.00 (4500 paise) often becomes 745.00 (74500 paise)
      final priceStr = (price / 100).toStringAsFixed(0);
      if (priceStr.startsWith('7') && price > 10000) {
        // Try removing the leading 7 (OCR artifact from ₹)
        final withoutSeven = priceStr.substring(1);
        final fixed = int.tryParse(withoutSeven);
        if (fixed != null && fixed > 0 && fixed < 1000) {
          correctedPrice = fixed * 100;
          debugPrint(
            'Price correction: ₹${price / 100} -> ₹${correctedPrice / 100}',
          );
        }
      }

      // Skip prices that are way too high (likely OCR errors or totals)
      if (correctedPrice < 50000) {
        // < ₹500 per item is reasonable
        corrected.add(correctedPrice);
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
  }
}
