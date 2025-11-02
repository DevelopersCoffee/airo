import 'package:equatable/equatable.dart';

/// Intent classification from user text
enum IntentType {
  playMusic,
  pauseMusic,
  nextTrack,
  openMoney,
  openBudget,
  openExpenses,
  playGames,
  playChess,
  openOffers,
  openReader,
  openChat,
  boredom,
  unknown,
}

/// Parsed intent from user input
class Intent extends Equatable {
  final IntentType type;
  final String originalText;
  final Map<String, dynamic> parameters;
  final double confidence;

  const Intent({
    required this.type,
    required this.originalText,
    this.parameters = const {},
    this.confidence = 1.0,
  });

  @override
  List<Object?> get props => [type, originalText, parameters, confidence];
}

/// Intent parser - converts text to structured intents
class IntentParser {
  static const Map<String, IntentType> _phraseMap = {
    // Music intents
    'play music': IntentType.playMusic,
    'play some music': IntentType.playMusic,
    'start music': IntentType.playMusic,
    'play lofi': IntentType.playMusic,
    'play jazz': IntentType.playMusic,
    'play rock': IntentType.playMusic,
    'pause music': IntentType.pauseMusic,
    'stop music': IntentType.pauseMusic,
    'next track': IntentType.nextTrack,
    'next song': IntentType.nextTrack,
    'skip': IntentType.nextTrack,

    // Money intents
    'open money': IntentType.openMoney,
    'show budget': IntentType.openBudget,
    'budget': IntentType.openBudget,
    'expenses': IntentType.openExpenses,
    'show expenses': IntentType.openExpenses,

    // Games intents
    'play games': IntentType.playGames,
    'open games': IntentType.playGames,
    'play chess': IntentType.playChess,
    'chess': IntentType.playChess,

    // Offers intents
    'open offers': IntentType.openOffers,
    'show offers': IntentType.openOffers,
    'Loot': IntentType.openOffers,

    // Reader intents
    'open reader': IntentType.openReader,
    'read': IntentType.openReader,
    'reading': IntentType.openReader,

    // Chat intents
    'open chat': IntentType.openChat,
    'chat': IntentType.openChat,

    // Boredom intents
    'bored': IntentType.boredom,
    'im bored': IntentType.boredom,
    'i am bored': IntentType.boredom,
    'boring': IntentType.boredom,
  };

  /// Parse user text into an intent
  static Intent parse(String text) {
    final lowerText = text.toLowerCase().trim();

    // Try exact matches first
    if (_phraseMap.containsKey(lowerText)) {
      return Intent(type: _phraseMap[lowerText]!, originalText: text);
    }

    // Try partial matches
    for (final entry in _phraseMap.entries) {
      if (lowerText.contains(entry.key)) {
        return Intent(type: entry.value, originalText: text, confidence: 0.8);
      }
    }

    // Extract parameters from text
    final parameters = _extractParameters(lowerText);

    // Default to unknown
    return Intent(
      type: IntentType.unknown,
      originalText: text,
      parameters: parameters,
      confidence: 0.0,
    );
  }

  /// Extract parameters from text (e.g., search query, artist name)
  static Map<String, dynamic> _extractParameters(String text) {
    final params = <String, dynamic>{};

    // Extract search query for music
    if (text.contains('play') && !_phraseMap.containsKey(text)) {
      final parts = text.split('play');
      if (parts.length > 1) {
        params['query'] = parts[1].trim();
      }
    }

    return params;
  }

  /// Get human-readable description of intent
  static String describe(Intent intent) {
    switch (intent.type) {
      case IntentType.playMusic:
        return 'Playing music';
      case IntentType.pauseMusic:
        return 'Pausing music';
      case IntentType.nextTrack:
        return 'Skipping to next track';
      case IntentType.openMoney:
        return 'Opening Money app';
      case IntentType.openBudget:
        return 'Opening Budget';
      case IntentType.openExpenses:
        return 'Opening Expenses';
      case IntentType.playGames:
        return 'Opening Games';
      case IntentType.playChess:
        return 'Opening Chess';
      case IntentType.openOffers:
        return 'Opening Offers';
      case IntentType.openReader:
        return 'Opening Reader';
      case IntentType.openChat:
        return 'Opening Chat';
      case IntentType.boredom:
        return 'User is bored';
      case IntentType.unknown:
        return 'Unknown command';
    }
  }
}
