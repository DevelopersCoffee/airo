/// Sample receipt OCR text fixtures for deterministic testing
///
/// These fixtures contain real-world OCR output patterns from various
/// grocery delivery apps, including common OCR errors like corrupted
/// rupee symbols and character substitutions.

const String instamartReceiptOcr = '''
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

const String zeptoReceiptOcr = '''
Your Zepto order has been delivered!
Order #ZPT-123456
Delivered to: Home

ITEMS
1x Milk - Amul Taaza 500ml
1x Bread - Harvest Gold
2x Eggs - 6 pack
1x Butter - Amul 100g

Prices:
₹28.00
₹35.00
₹72.00
₹55.00

Subtotal: ₹190.00
Delivery: FREE
Total: ₹190.00
''';

const String bigbasketReceiptOcr = '''
BigBasket - Fresh Groceries Delivered
Order ID: BB-789012

Your Items:
Rice 5kg - India Gate Basmati
Dal 1kg - Toor Premium
Oil 1L - Fortune Refined
Sugar 1kg - Madhur

Price List:
7550.00
7189.00
198.00
745.00

Item Total: ₹1282.00
Delivery Charges: ₹0.00
Grand Total: ₹1282.00

Thank you for shopping!
''';

const String blinkitReceiptOcr = '''
Blinkit | Grocery in 10 minutes
Order #BK987654

Apples 1kg
Bananas 1 dozen
Oranges 500g
Grapes 250g

T120.00
F60.00
Z85.00
R95.00

Total
F360.00
''';

const String corruptedPricesReceipt = '''
Sample Receipt with corrupted prices
Item A: 741.00
Item B: 738.00
Item C: 769.00
Item D: 45.00
Item E: 120.00
''';

/// Expected parsed items for Instamart receipt
const List<Map<String, dynamic>> expectedInstamartItems = [
  {'name': 'Potato (Batate)', 'price': 41.0},
  {'name': 'Lady Red Papaya (Kappalanga (Omakka)', 'price': 69.0},
  {'name': 'Coriander Leaves without root', 'price': 20.0},
  {'name': 'Onion (Kanda)', 'price': 29.0},
  {'name': 'White Cucumber (Pandhri Kakdi)', 'price': 30.0},
  {'name': 'Spring Onion (Kanda Patta)', 'price': 29.0},
  {'name': '[Combo] Amul Taaza Milky Milk', 'price': 58.0},
];

