/// User preferences for quotes feature
class QuotePreferences {
  final bool showQuotes;
  final String
  quoteSource; // 'fake', 'zenquotes', 'fortuneCookie', 'lifeHacks', 'uselessFacts'

  const QuotePreferences({this.showQuotes = true, this.quoteSource = 'fake'});

  QuotePreferences copyWith({bool? showQuotes, String? quoteSource}) {
    return QuotePreferences(
      showQuotes: showQuotes ?? this.showQuotes,
      quoteSource: quoteSource ?? this.quoteSource,
    );
  }

  Map<String, dynamic> toJson() {
    return {'showQuotes': showQuotes, 'quoteSource': quoteSource};
  }

  factory QuotePreferences.fromJson(Map<String, dynamic> json) {
    return QuotePreferences(
      showQuotes: json['showQuotes'] as bool? ?? true,
      quoteSource: json['quoteSource'] as String? ?? 'fake',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuotePreferences &&
          runtimeType == other.runtimeType &&
          showQuotes == other.showQuotes &&
          quoteSource == other.quoteSource;

  @override
  int get hashCode => showQuotes.hashCode ^ quoteSource.hashCode;
}
