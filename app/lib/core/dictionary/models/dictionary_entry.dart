/// Dictionary entry model for Free Dictionary API
class DictionaryEntry {
  final String word;
  final String? phonetic;
  final List<Phonetic> phonetics;
  final String? origin;
  final List<Meaning> meanings;

  const DictionaryEntry({
    required this.word,
    this.phonetic,
    required this.phonetics,
    this.origin,
    required this.meanings,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      word: json['word'] as String,
      phonetic: json['phonetic'] as String?,
      phonetics: (json['phonetics'] as List<dynamic>?)
              ?.map((e) => Phonetic.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      origin: json['origin'] as String?,
      meanings: (json['meanings'] as List<dynamic>?)
              ?.map((e) => Meaning.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'phonetic': phonetic,
      'phonetics': phonetics.map((e) => e.toJson()).toList(),
      'origin': origin,
      'meanings': meanings.map((e) => e.toJson()).toList(),
    };
  }
}

/// Phonetic pronunciation
class Phonetic {
  final String? text;
  final String? audio;

  const Phonetic({
    this.text,
    this.audio,
  });

  factory Phonetic.fromJson(Map<String, dynamic> json) {
    return Phonetic(
      text: json['text'] as String?,
      audio: json['audio'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'audio': audio,
    };
  }

  /// Check if audio is available
  bool get hasAudio => audio != null && audio!.isNotEmpty;

  /// Get full audio URL
  String? get audioUrl {
    if (!hasAudio) return null;
    final url = audio!;
    // Add https: if URL starts with //
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    return url;
  }
}

/// Word meaning with definitions
class Meaning {
  final String partOfSpeech;
  final List<Definition> definitions;

  const Meaning({
    required this.partOfSpeech,
    required this.definitions,
  });

  factory Meaning.fromJson(Map<String, dynamic> json) {
    return Meaning(
      partOfSpeech: json['partOfSpeech'] as String,
      definitions: (json['definitions'] as List<dynamic>?)
              ?.map((e) => Definition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'partOfSpeech': partOfSpeech,
      'definitions': definitions.map((e) => e.toJson()).toList(),
    };
  }
}

/// Definition with examples and synonyms
class Definition {
  final String definition;
  final String? example;
  final List<String> synonyms;
  final List<String> antonyms;

  const Definition({
    required this.definition,
    this.example,
    required this.synonyms,
    required this.antonyms,
  });

  factory Definition.fromJson(Map<String, dynamic> json) {
    return Definition(
      definition: json['definition'] as String,
      example: json['example'] as String?,
      synonyms: (json['synonyms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      antonyms: (json['antonyms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'definition': definition,
      'example': example,
      'synonyms': synonyms,
      'antonyms': antonyms,
    };
  }

  bool get hasSynonyms => synonyms.isNotEmpty;
  bool get hasAntonyms => antonyms.isNotEmpty;
  bool get hasExample => example != null && example!.isNotEmpty;
}

