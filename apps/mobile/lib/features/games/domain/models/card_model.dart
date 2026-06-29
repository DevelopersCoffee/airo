/// Represents a playing card from the Deck of Cards API
class CardModel {
  final String code;
  final String image;
  final CardImages images;
  final String value;
  final String suit;

  const CardModel({
    required this.code,
    required this.image,
    required this.images,
    required this.value,
    required this.suit,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      code: json['code'] as String,
      image: json['image'] as String,
      images: CardImages.fromJson(json['images'] as Map<String, dynamic>),
      value: json['value'] as String,
      suit: json['suit'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'image': image,
      'images': images.toJson(),
      'value': value,
      'suit': suit,
    };
  }
}

/// Card image URLs (PNG and SVG)
class CardImages {
  final String svg;
  final String png;

  const CardImages({required this.svg, required this.png});

  factory CardImages.fromJson(Map<String, dynamic> json) {
    return CardImages(svg: json['svg'] as String, png: json['png'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'svg': svg, 'png': png};
  }
}

/// Response from shuffling/creating a new deck
class DeckResponse {
  final bool success;
  final String deckId;
  final bool shuffled;
  final int remaining;

  const DeckResponse({
    required this.success,
    required this.deckId,
    required this.shuffled,
    required this.remaining,
  });

  factory DeckResponse.fromJson(Map<String, dynamic> json) {
    return DeckResponse(
      success: json['success'] as bool,
      deckId: json['deck_id'] as String,
      shuffled: json['shuffled'] as bool,
      remaining: json['remaining'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'deck_id': deckId,
      'shuffled': shuffled,
      'remaining': remaining,
    };
  }
}

/// Response from drawing cards
class DrawResponse {
  final bool success;
  final String deckId;
  final List<CardModel> cards;
  final int remaining;

  const DrawResponse({
    required this.success,
    required this.deckId,
    required this.cards,
    required this.remaining,
  });

  factory DrawResponse.fromJson(Map<String, dynamic> json) {
    return DrawResponse(
      success: json['success'] as bool,
      deckId: json['deck_id'] as String,
      cards: (json['cards'] as List<dynamic>)
          .map((e) => CardModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      remaining: json['remaining'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'deck_id': deckId,
      'cards': cards.map((e) => e.toJson()).toList(),
      'remaining': remaining,
    };
  }
}

/// Response for pile operations
class PileResponse {
  final bool success;
  final String deckId;
  final int remaining;
  final Map<String, PileInfo> piles;

  const PileResponse({
    required this.success,
    required this.deckId,
    required this.remaining,
    required this.piles,
  });

  factory PileResponse.fromJson(Map<String, dynamic> json) {
    return PileResponse(
      success: json['success'] as bool,
      deckId: json['deck_id'] as String,
      remaining: json['remaining'] as int,
      piles: (json['piles'] as Map<String, dynamic>).map(
        (key, value) =>
            MapEntry(key, PileInfo.fromJson(value as Map<String, dynamic>)),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'deck_id': deckId,
      'remaining': remaining,
      'piles': piles.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

/// Information about a pile
class PileInfo {
  final int remaining;
  final List<CardModel>? cards;

  const PileInfo({required this.remaining, this.cards});

  factory PileInfo.fromJson(Map<String, dynamic> json) {
    return PileInfo(
      remaining: json['remaining'] as int,
      cards: json['cards'] != null
          ? (json['cards'] as List<dynamic>)
                .map((e) => CardModel.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'remaining': remaining,
      if (cards != null) 'cards': cards!.map((e) => e.toJson()).toList(),
    };
  }
}

/// Card suit enum
enum CardSuit { spades, hearts, diamonds, clubs }

/// Card value enum
enum CardValue {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
}
