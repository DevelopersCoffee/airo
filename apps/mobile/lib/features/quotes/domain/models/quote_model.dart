/// Quote model from ZenQuotes API
class Quote {
  final String text;
  final String author;

  const Quote({required this.text, required this.author});

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      text: json['q'] as String? ?? '',
      author: json['a'] as String? ?? 'Unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {'q': text, 'a': author};
  }

  @override
  String toString() => '"$text" - $author';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Quote &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          author == other.author;

  @override
  int get hashCode => text.hashCode ^ author.hashCode;
}
