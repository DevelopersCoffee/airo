import 'package:equatable/equatable.dart';

/// Offer model
class Offer extends Equatable {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? link;
  final String source; // 'rss', 'telegram', 'http', etc.
  final DateTime publishedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? metadata;

  const Offer({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.link,
    required this.source,
    required this.publishedAt,
    this.expiresAt,
    this.metadata,
  });

  /// Check if offer is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get time until expiration
  Duration? get timeUntilExpiration {
    if (expiresAt == null) return null;
    final remaining = expiresAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    imageUrl,
    link,
    source,
    publishedAt,
    expiresAt,
    metadata,
  ];
}

/// Offer source interface
abstract interface class OffersSource {
  /// Get source name
  String get name;

  /// Fetch offers
  Future<List<Offer>> fetch({int limit = 20, String? cursor});

  /// Search offers
  Future<List<Offer>> search(String query);
}

/// Fake offers source for development
class FakeOffersSource implements OffersSource {
  @override
  String get name => 'Best Deals in India';

  @override
  Future<List<Offer>> fetch({int limit = 20, String? cursor}) async {
    return [
      Offer(
        id: '1',
        title: 'Tu Casa Lamps - Upto 93% Off 💥',
        description: 'Premium lighting solutions at unbeatable prices',
        imageUrl:
            'https://images-na.ssl-images-amazon.com/images/I/71-qXjTrPyL._SX679_.jpg',
        link: 'https://amzn.to/4omubAz',
        source: 'Amazon',
        publishedAt: DateTime.now(),
        metadata: {'discount': '93%', 'platform': 'amazon'},
      ),
      Offer(
        id: '2',
        title: 'WickedGud Noodles - Apply 50% Off Coupon',
        description: 'Delicious instant noodles with 50% coupon available',
        imageUrl:
            'https://images-na.ssl-images-amazon.com/images/I/81Ym7-ZCBQL._SX679_.jpg',
        link: 'https://amzn.to/4myhd0I',
        source: 'Amazon',
        publishedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        metadata: {'discount': '50%', 'platform': 'amazon'},
      ),
      Offer(
        id: '3',
        title: 'Vivel Soap, 150g - (Pack of 4) at Rs.151 💥',
        description: 'Premium soap pack at incredible price',
        imageUrl:
            'https://images-na.ssl-images-amazon.com/images/I/71Ym7-ZCBQL._SX679_.jpg',
        link: 'https://amzn.to/48HnZOv',
        source: 'Amazon',
        publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
        metadata: {'price': '₹151', 'platform': 'amazon'},
      ),
      Offer(
        id: '4',
        title: 'Orient Electric - Water Geyser 25L at Rs.5,999 💥',
        description: 'High-capacity water heater at best price',
        imageUrl:
            'https://images-na.ssl-images-amazon.com/images/I/71Ym7-ZCBQL._SX679_.jpg',
        link: 'https://amzn.to/4m3ezzN',
        source: 'Amazon',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
        metadata: {'price': '₹5,999', 'platform': 'amazon'},
      ),
      Offer(
        id: '5',
        title: 'Milton Products - Upto 70% Off 💥',
        description: 'Kitchen and home products at massive discounts',
        imageUrl:
            'https://images-na.ssl-images-amazon.com/images/I/71Ym7-ZCBQL._SX679_.jpg',
        link: 'https://amzn.to/4hGpejB',
        source: 'Amazon',
        publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
        metadata: {'discount': '70%', 'platform': 'amazon'},
      ),
      Offer(
        id: '6',
        title: 'Head & Shoulders Shampoos - Upto 70% Off 💥',
        description: 'Premium hair care products on Myntra',
        imageUrl:
            'https://images-na.ssl-images-amazon.com/images/I/71Ym7-ZCBQL._SX679_.jpg',
        link: 'https://mynt.ro/0Bhx7ywP',
        source: 'Myntra',
        publishedAt: DateTime.now().subtract(const Duration(hours: 4)),
        metadata: {'discount': '70%', 'platform': 'myntra'},
      ),
      Offer(
        id: '7',
        title: 'Men\'s Cotton T-Shirt - (Pack of 3) at Rs.400 💥',
        description: 'Apply Rs.399 Off Coupon for extra savings',
        imageUrl:
            'https://images-na.ssl-images-amazon.com/images/I/71Ym7-ZCBQL._SX679_.jpg',
        link: 'https://amzn.to/4058ZVm',
        source: 'Amazon',
        publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
        metadata: {'price': '₹400', 'coupon': '₹399', 'platform': 'amazon'},
      ),
    ];
  }

  @override
  Future<List<Offer>> search(String query) async {
    return [];
  }
}

/// RSS offers source
class RssOffersSource implements OffersSource {
  final String feedUrl;

  RssOffersSource({required this.feedUrl});

  @override
  String get name => 'RSS Feed';

  @override
  Future<List<Offer>> fetch({int limit = 20, String? cursor}) async {
    // TODO: Implement RSS parsing
    return [];
  }

  @override
  Future<List<Offer>> search(String query) async {
    // TODO: Implement search
    return [];
  }
}

/// HTTP scrape offers source
class HttpOffersSource implements OffersSource {
  final String url;
  final String? selector;

  HttpOffersSource({required this.url, this.selector});

  @override
  String get name => 'HTTP Source';

  @override
  Future<List<Offer>> fetch({int limit = 20, String? cursor}) async {
    // TODO: Implement HTTP scraping
    return [];
  }

  @override
  Future<List<Offer>> search(String query) async {
    // TODO: Implement search
    return [];
  }
}
