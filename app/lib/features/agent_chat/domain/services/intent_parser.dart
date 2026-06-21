import 'package:equatable/equatable.dart';

/// Intent classification from user text
enum IntentType {
  playMusic,
  pauseMusic,
  nextTrack,
  openMoney,
  openBudget,
  openExpenses,
  splitBill,
  createDietPlan,
  createRoutine,
  playGames,
  playChess,
  playGame,
  askImage,
  audioScribe,
  mobileActions,
  modelManagement,
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

    // Money and routine intents
    'open money': IntentType.openMoney,
    'show budget': IntentType.openBudget,
    'budget': IntentType.openBudget,
    'expenses': IntentType.openExpenses,
    'show expenses': IntentType.openExpenses,
    'split bill': IntentType.splitBill,
    'bill split': IntentType.splitBill,
    'split expense': IntentType.splitBill,
    'diet plan': IntentType.createDietPlan,
    'meal plan': IntentType.createDietPlan,
    'routine': IntentType.createRoutine,
    'daily routine': IntentType.createRoutine,
    'study routine': IntentType.createRoutine,

    // Games intents
    'play games': IntentType.playGames,
    'open games': IntentType.playGames,
    'open arena': IntentType.playGames,
    'arena': IntentType.playGames,
    'play chess': IntentType.playChess,
    'chess': IntentType.playChess,
    'play blackjack': IntentType.playGame,
    'start blackjack': IntentType.playGame,
    'play poker': IntentType.playGame,
    'play rummy': IntentType.playGame,
    'play solitaire': IntentType.playGame,

    // AI use cases
    'ask image': IntentType.askImage,
    'describe image': IntentType.askImage,
    'audio scribe': IntentType.audioScribe,
    'transcribe audio': IntentType.audioScribe,
    'mobile actions': IntentType.mobileActions,
    'open mobile actions': IntentType.mobileActions,
    'manage models': IntentType.modelManagement,
    'model management': IntentType.modelManagement,
    'offline models': IntentType.modelManagement,

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
    final parameters = _extractParameters(text);

    final structuredType = _classifyStructured(lowerText);
    if (structuredType != null) {
      return Intent(
        type: structuredType,
        originalText: text,
        parameters: parameters,
        confidence: 0.9,
      );
    }

    // Try exact matches first
    if (_phraseMap.containsKey(lowerText)) {
      return Intent(
        type: _phraseMap[lowerText]!,
        originalText: text,
        parameters: parameters,
      );
    }

    // Try partial matches
    for (final entry in _phraseMap.entries) {
      if (lowerText.contains(entry.key)) {
        return Intent(
          type: entry.value,
          originalText: text,
          parameters: parameters,
          confidence: 0.8,
        );
      }
    }

    // Default to unknown
    return Intent(
      type: IntentType.unknown,
      originalText: text,
      parameters: parameters,
      confidence: 0.0,
    );
  }

  static IntentType? _classifyStructured(String text) {
    if (_containsAny(text, ['split', 'divide']) &&
        _containsAny(text, ['bill', 'expense', 'receipt', 'tab'])) {
      return IntentType.splitBill;
    }

    if (_containsAny(text, ['diet', 'meal plan', 'food plan', 'nutrition'])) {
      return IntentType.createDietPlan;
    }

    if (_containsAny(text, ['routine', 'schedule my day', 'study plan'])) {
      return IntentType.createRoutine;
    }

    if (_containsAny(text, ['ask image', 'describe image', 'image about'])) {
      return IntentType.askImage;
    }

    if (_containsAny(text, [
      'audio scribe',
      'transcribe audio',
      'translate audio',
    ])) {
      return IntentType.audioScribe;
    }

    if (_containsAny(text, ['mobile actions', 'device control'])) {
      return IntentType.mobileActions;
    }

    if (_containsAny(text, [
      'manage model',
      'offline model',
      'model management',
    ])) {
      return IntentType.modelManagement;
    }

    final game = _extractGame(text);
    if (game != null &&
        _containsAny(text, ['play', 'start', 'open', 'bored'])) {
      return IntentType.playGame;
    }

    return null;
  }

  static bool _containsAny(String text, List<String> phrases) {
    return phrases.any(text.contains);
  }

  /// Extract parameters from text (e.g., search query, artist name)
  static Map<String, dynamic> _extractParameters(String text) {
    final params = <String, dynamic>{};
    final lowerText = text.toLowerCase().trim();

    // Extract search query for music
    if (lowerText.contains('play') && !_phraseMap.containsKey(lowerText)) {
      final parts = lowerText.split('play');
      if (parts.length > 1) {
        params['query'] = parts[1].trim();
      }
    }

    final amountCents = _extractAmountCents(text);
    if (amountCents != null) {
      params['amountCents'] = amountCents;
      params['currencyCode'] = _extractCurrencyCode(text);
    }

    final participants = _extractParticipants(text);
    if (participants.isNotEmpty) {
      params['participants'] = participants;
    }

    final game = _extractGame(lowerText);
    if (game != null) {
      params['game'] = game;
    }

    if (_containsAny(lowerText, [
      'diet',
      'meal plan',
      'routine',
      'study plan',
    ])) {
      params['prompt'] = text.trim();
    }

    return params;
  }

  static int? _extractAmountCents(String text) {
    final match = RegExp(
      r'(?:₹|rs\.?|inr|\$|usd)?\s*(\d+(?:,\d{3})*(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    final amount = double.tryParse(match.group(1)!.replaceAll(',', ''));
    if (amount == null) return null;
    return (amount * 100).round();
  }

  static String _extractCurrencyCode(String text) {
    final lowerText = text.toLowerCase();
    if (lowerText.contains(r'$') || lowerText.contains('usd')) return 'USD';
    return 'INR';
  }

  static List<String> _extractParticipants(String text) {
    final match = RegExp(
      r'\b(?:with|among|between)\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return const [];

    return match
        .group(1)!
        .split(RegExp(r'\s*(?:,| and | & )\s*', caseSensitive: false))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static String? _extractGame(String text) {
    const games = ['chess', 'blackjack', 'poker', 'rummy', 'solitaire'];
    for (final game in games) {
      if (text.contains(game)) return game;
    }
    return null;
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
      case IntentType.splitBill:
        return 'Splitting a bill';
      case IntentType.createDietPlan:
        return 'Creating a diet plan';
      case IntentType.createRoutine:
        return 'Creating a routine';
      case IntentType.playGames:
        return 'Opening Games';
      case IntentType.playChess:
        return 'Opening Chess';
      case IntentType.playGame:
        return 'Opening Arena game';
      case IntentType.askImage:
        return 'Opening Ask Image';
      case IntentType.audioScribe:
        return 'Opening Audio Scribe';
      case IntentType.mobileActions:
        return 'Opening Mobile Actions';
      case IntentType.modelManagement:
        return 'Opening Model Management';
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
