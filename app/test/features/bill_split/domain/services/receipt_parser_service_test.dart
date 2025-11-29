import 'package:flutter_test/flutter_test.dart';

/// Unit tests for receipt parsing - TDD approach
/// These tests define expected behavior before implementation
void main() {
  group('Receipt Parser - Instamart Format', () {
    test(
      'should parse items with V 1x prefix and prices on separate lines',
      () {
        // This is the actual OCR output from the Pixel 9 test
        const ocrText = '''
9:25 O
ORDER #223354972839240
Completed |7 items, T288
Instamart | Ground Floor,Survey no. 34/8, 44-33-0 HRP, Balewadi...
Home Laxman Nagar, Baner, Pune, Maharashtra 411045, India....
ITEM DETAILS
Delivery
7 items Balewadi
V lx Potato (Batate)
V 1xLady Red Papaya (Kappalanga (Omakka)
V 1xCoriander Leaves without root
V 1x0nion (Kanda)
V 1xWhite Cucumber (Pandhri Kakdi)
V 1x Spring Onion (Kanda Patta)
V 1x[Combo] Amul Taaza Milky Milk
TOTAL ORDER BILL DETAILS
Item BilI
Delivery fee
Handling Fee
HELP
Grand Total
O Delivered
F41.0
Z69,0
T20.0
29.0
Z30.0
T29.0
F58.0
Download Invoice
F276.00
600 Free
11.56
F288.00
''';

        // Expected parsed items (7 items matching 7 prices)
        final expectedItems = [
          {'name': 'Potato (Batate)', 'price': 41.0},
          {'name': 'Lady Red Papaya (Kappalanga (Omakka)', 'price': 69.0},
          {'name': 'Coriander Leaves without root', 'price': 20.0},
          {'name': 'Onion (Kanda)', 'price': 29.0},
          {'name': 'White Cucumber (Pandhri Kakdi)', 'price': 30.0},
          {'name': 'Spring Onion (Kanda Patta)', 'price': 29.0},
          {'name': '[Combo] Amul Taaza Milky Milk', 'price': 58.0},
        ];

        // Test parsing logic
        final items = parseInstamartItems(ocrText);

        expect(items.length, equals(7), reason: 'Should parse all 7 items');
        expect(items[0]['name'], contains('Potato'));
        expect(items[0]['price'], equals(41.0));
        expect(items[6]['name'], contains('Milk'));
        expect(items[6]['price'], equals(58.0));
      },
    );

    test('should extract vendor name as Instamart', () {
      const ocrText = 'Instamart | Ground Floor...';
      expect(extractVendor(ocrText), equals('Instamart'));
    });

    test('should extract grand total of 288', () {
      const ocrText = '''
Grand Total
F288.00
''';
      expect(extractGrandTotal(ocrText), equals(28800)); // in paise
    });

    test('should handle corrupted rupee symbols (F, Z, T instead of ₹)', () {
      // OCR often misreads ₹ as F, Z, T, or other characters
      expect(parseCorruptedPrice('F41.0'), equals(4100));
      expect(parseCorruptedPrice('Z69,0'), equals(6900));
      expect(parseCorruptedPrice('T20.0'), equals(2000));
      expect(parseCorruptedPrice('29.0'), equals(2900));
    });

    test('should correct prices where ₹ is read as 7 (745.0 -> 45.0)', () {
      // OCR often misreads ₹ as 7, causing ₹45.0 to become 745.0
      final rawPrices = [
        74500,
        73800,
        9100,
        12000,
        5800,
        72900,
        76900,
      ]; // in paise
      final corrected = correctPrices(rawPrices, null, 7);

      // Prices starting with 7 and > ₹100 should be corrected
      expect(corrected[0], equals(4500)); // 745.0 -> 45.0
      expect(corrected[1], equals(3800)); // 738.0 -> 38.0
      expect(corrected[2], equals(9100)); // 91.0 stays (doesn't start with 7)
      expect(corrected[3], equals(12000)); // 120.0 stays (doesn't start with 7)
      expect(corrected[4], equals(5800)); // 58.0 stays (< ₹100)
      expect(corrected[5], equals(2900)); // 729.0 -> 29.0
      expect(corrected[6], equals(6900)); // 769.0 -> 69.0
    });

    test('should detect Zepto vendor', () {
      const ocrText = 'Your Zepto order has been delivered!';
      expect(extractVendor(ocrText), equals('Zepto'));
    });

    test('should detect BigBasket vendor', () {
      const ocrText = 'BigBasket - Fresh Groceries Delivered';
      expect(extractVendor(ocrText), equals('BigBasket'));
    });

    test('should detect Blinkit vendor', () {
      const ocrText = 'Blinkit | Grocery in 10 minutes';
      expect(extractVendor(ocrText), equals('Blinkit'));
    });

    test('should return null for unknown vendor', () {
      const ocrText = 'Unknown Store Receipt';
      expect(extractVendor(ocrText), isNull);
    });
  });

  group('WhatsApp Message Generation', () {
    test('should generate formatted message with itemized breakdown', () {
      final participants = [
        const TestItemParticipant(id: 'me', name: 'Me', isMe: true),
        const TestItemParticipant(id: 'roommate', name: 'Roommate'),
      ];

      final items = [
        const TestItemizedSplitItem(
          name: 'Potato',
          pricePaise: 4500,
          participantIds: {'me'},
        ),
        const TestItemizedSplitItem(
          name: 'Milk',
          pricePaise: 5800,
          participantIds: {'roommate'},
        ),
        const TestItemizedSplitItem(
          name: 'Rice',
          pricePaise: 12000,
          participantIds: {'me', 'roommate'},
        ),
      ];

      final summary = {
        'me': 4500 + 6000, // Potato + half of Rice
        'roommate': 5800 + 6000, // Milk + half of Rice
      };

      final message = generateWhatsAppMessage(
        totalAmount: 223.0,
        vendor: 'Instamart',
        orderId: '123456',
        summary: summary,
        items: items,
        participants: participants,
      );

      // Check header
      expect(message, contains('🧾 *Bill Split - Instamart*'));
      expect(message, contains('Order #123456'));
      expect(message, contains('💰 *Total: ₹223.00*'));

      // Check participant breakdown
      expect(message, contains('👤 *You: ₹105.00*'));
      expect(message, contains('👤 *Roommate: ₹118.00*'));

      // Check items
      expect(message, contains('• Potato ₹45.00'));
      expect(message, contains('• Milk ₹58.00'));
      expect(message, contains('• Rice (split ÷2) ₹60.00'));

      // Check footer
      expect(message, contains('_Shared via Airo_'));
    });

    test('should handle single participant (no split)', () {
      final participants = [
        const TestItemParticipant(id: 'me', name: 'Me', isMe: true),
      ];

      final items = [
        const TestItemizedSplitItem(
          name: 'Bread',
          pricePaise: 3500,
          participantIds: {'me'},
        ),
      ];

      final summary = {'me': 3500};

      final message = generateWhatsAppMessage(
        totalAmount: 35.0,
        vendor: null,
        orderId: null,
        summary: summary,
        items: items,
        participants: participants,
      );

      expect(message, contains('🧾 *Bill Split - Receipt*'));
      expect(message, contains('👤 *You: ₹35.00*'));
      expect(message, contains('• Bread ₹35.00'));
    });

    test('should handle 3-way split correctly', () {
      final participants = [
        const TestItemParticipant(id: 'p1', name: 'Alice'),
        const TestItemParticipant(id: 'p2', name: 'Bob'),
        const TestItemParticipant(id: 'p3', name: 'Charlie'),
      ];

      final items = [
        const TestItemizedSplitItem(
          name: 'Pizza',
          pricePaise: 60000, // ₹600
          participantIds: {'p1', 'p2', 'p3'},
        ),
      ];

      // Each person pays ₹200
      final summary = {'p1': 20000, 'p2': 20000, 'p3': 20000};

      final message = generateWhatsAppMessage(
        totalAmount: 600.0,
        vendor: 'Dominos',
        orderId: null,
        summary: summary,
        items: items,
        participants: participants,
      );

      expect(message, contains('• Pizza (split ÷3) ₹200.00'));
      expect(message, contains('👤 *Alice: ₹200.00*'));
      expect(message, contains('👤 *Bob: ₹200.00*'));
      expect(message, contains('👤 *Charlie: ₹200.00*'));
    });
  });

  group('Per-user Total Calculation', () {
    test('should calculate correct totals for assigned items', () {
      // Simulate items with assignments
      final items = [
        {
          'price': 4500,
          'assigned': {'me'},
        },
        {
          'price': 5800,
          'assigned': {'roommate'},
        },
        {
          'price': 12000,
          'assigned': {'me', 'roommate'},
        }, // Split
      ];

      final totals = calculateParticipantTotals(items, ['me', 'roommate']);

      expect(totals['me'], equals(4500 + 6000)); // ₹45 + ₹60
      expect(totals['roommate'], equals(5800 + 6000)); // ₹58 + ₹60
    });

    test('should handle unassigned items (split among all)', () {
      final items = [
        {'price': 10000, 'assigned': <String>{}}, // Unassigned = split all
      ];

      final totals = calculateParticipantTotals(items, ['p1', 'p2']);

      expect(totals['p1'], equals(5000)); // ₹50 each
      expect(totals['p2'], equals(5000));
    });
  });
}

/// Calculate per-participant totals from items
Map<String, int> calculateParticipantTotals(
  List<Map<String, dynamic>> items,
  List<String> participantIds,
) {
  final totals = <String, int>{};
  for (final pid in participantIds) {
    totals[pid] = 0;
  }

  for (final item in items) {
    final price = item['price'] as int;
    final assigned = item['assigned'] as Set<String>;

    // If unassigned, split among all participants
    final recipients = assigned.isEmpty ? participantIds.toSet() : assigned;
    final share = price ~/ recipients.length;

    for (final pid in recipients) {
      totals[pid] = (totals[pid] ?? 0) + share;
    }
  }

  return totals;
}

/// Correct OCR price errors where ₹ is read as 7
List<int> correctPrices(
  List<int> rawPrices,
  int? itemBillTotal,
  int itemCount,
) {
  if (rawPrices.isEmpty) return [];

  final corrected = <int>[];

  for (final price in rawPrices) {
    var correctedPrice = price;

    // Check if price starts with 7 and is suspiciously large (> ₹100)
    final priceStr = (price / 100).toStringAsFixed(0);
    if (priceStr.startsWith('7') && price > 10000) {
      // Try removing the leading 7 (OCR artifact from ₹)
      final withoutSeven = priceStr.substring(1);
      final fixed = int.tryParse(withoutSeven);
      if (fixed != null && fixed > 0 && fixed < 1000) {
        correctedPrice = fixed * 100;
      }
    }

    // Skip prices that are way too high
    if (correctedPrice < 50000) {
      corrected.add(correctedPrice);
    }
  }

  return corrected;
}

/// Parse Instamart-style items where items and prices are on separate lines
List<Map<String, dynamic>> parseInstamartItems(String ocrText) {
  final items = <Map<String, dynamic>>[];
  final lines = ocrText.split('\n').map((l) => l.trim()).toList();

  // Find item lines (start with V followed by quantity)
  final itemPattern = RegExp(r'^V\s*[l1]?\s*x?\s*(.+)$', caseSensitive: false);

  // Find price lines (number with optional corrupted prefix)
  final pricePattern = RegExp(r'^[FZTRIO₹]?(\d+)[.,](\d+)$');

  final itemLines = <String>[];
  final priceLines = <double>[];

  for (final line in lines) {
    final itemMatch = itemPattern.firstMatch(line);
    if (itemMatch != null) {
      var name = itemMatch.group(1)!.trim();
      // Clean up: remove leading "1x", "lx", quantity markers
      name = name.replaceAll(RegExp(r'^[0-9l]+x\s*', caseSensitive: false), '');
      itemLines.add(name);
    }

    final priceMatch = pricePattern.firstMatch(line);
    if (priceMatch != null) {
      final rupees = int.parse(priceMatch.group(1)!);
      final paise = int.parse(
        priceMatch.group(2)!.padRight(2, '0').substring(0, 2),
      );
      priceLines.add(rupees + paise / 100);
    }
  }

  // Match items to prices (assuming same order)
  for (var i = 0; i < itemLines.length && i < priceLines.length; i++) {
    items.add({'name': itemLines[i], 'price': priceLines[i]});
  }

  return items;
}

String? extractVendor(String ocrText) {
  const vendors = ['Instamart', 'Swiggy', 'Zepto', 'BigBasket', 'Blinkit'];
  for (final v in vendors) {
    if (ocrText.toLowerCase().contains(v.toLowerCase())) return v;
  }
  return null;
}

int extractGrandTotal(String ocrText) {
  final lines = ocrText.split('\n').map((l) => l.trim()).toList();
  for (var i = 0; i < lines.length - 1; i++) {
    if (lines[i].toLowerCase().contains('grand total')) {
      return parseCorruptedPrice(lines[i + 1]);
    }
  }
  return 0;
}

int parseCorruptedPrice(String priceStr) {
  // Remove corrupted prefix characters (F, Z, T, R, I, O, ₹)
  final clean = priceStr.replaceAll(RegExp(r'^[FZTRIOЩ₹\s]+'), '');
  final parts = clean.split(RegExp(r'[.,]'));
  if (parts.length >= 2) {
    final rupees = int.tryParse(parts[0]) ?? 0;
    final paise = int.tryParse(parts[1].padRight(2, '0').substring(0, 2)) ?? 0;
    return rupees * 100 + paise;
  }
  return (int.tryParse(clean) ?? 0) * 100;
}

// ============================================================================
// WhatsApp Message Generation Tests
// ============================================================================

/// Test helper class for ItemizedSplitItem
class TestItemizedSplitItem {
  final String name;
  final int pricePaise;
  final Set<String> participantIds;

  const TestItemizedSplitItem({
    required this.name,
    required this.pricePaise,
    required this.participantIds,
  });
}

/// Test helper class for ItemParticipant
class TestItemParticipant {
  final String id;
  final String name;
  final bool isMe;

  const TestItemParticipant({
    required this.id,
    required this.name,
    this.isMe = false,
  });
}

/// Generate WhatsApp message from itemized split
String generateWhatsAppMessage({
  required double totalAmount,
  required String? vendor,
  required String? orderId,
  required Map<String, int> summary,
  required List<TestItemizedSplitItem> items,
  required List<TestItemParticipant> participants,
}) {
  final buffer = StringBuffer();

  buffer.writeln('🧾 *Bill Split - ${vendor ?? "Receipt"}*');
  if (orderId != null) buffer.writeln('Order #$orderId');
  buffer.writeln('');
  buffer.writeln('💰 *Total: ₹${totalAmount.toStringAsFixed(2)}*');
  buffer.writeln('');

  // Group items by participant
  final itemsByParticipant = <String, List<TestItemizedSplitItem>>{};
  for (final item in items) {
    for (final pId in item.participantIds) {
      itemsByParticipant.putIfAbsent(pId, () => []).add(item);
    }
  }

  buffer.writeln('📋 *Breakdown:*');
  for (final p in participants) {
    final amount = summary[p.id] ?? 0;
    final name = p.isMe ? 'You' : p.name;
    buffer.writeln('');
    buffer.writeln('👤 *$name: ₹${(amount / 100).toStringAsFixed(2)}*');

    final pItems = itemsByParticipant[p.id] ?? [];
    for (final item in pItems) {
      final splitCount = item.participantIds.length;
      final itemShare = item.pricePaise ~/ splitCount;
      if (splitCount > 1) {
        buffer.writeln(
          '  • ${item.name} (split ÷$splitCount) ₹${(itemShare / 100).toStringAsFixed(2)}',
        );
      } else {
        buffer.writeln(
          '  • ${item.name} ₹${(item.pricePaise / 100).toStringAsFixed(2)}',
        );
      }
    }
  }

  buffer.writeln('');
  buffer.writeln('---');
  buffer.writeln('_Shared via Airo_');

  return buffer.toString();
}
