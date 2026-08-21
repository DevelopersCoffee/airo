import 'source_manager.dart';

enum ClaimSupport { supported, unverified }

class ResearchClaim {
  const ResearchClaim({
    required this.id,
    required this.text,
    required this.sourceUrl,
    required this.excerpt,
    required this.status,
  });

  final String id;
  final String text;
  final String sourceUrl;
  final String excerpt;
  final ClaimSupport status;

  ResearchClaim copyWith({ClaimSupport? status}) {
    return ResearchClaim(
      id: id,
      text: text,
      sourceUrl: sourceUrl,
      excerpt: excerpt,
      status: status ?? this.status,
    );
  }
}

/// Paragraphs of acquired documents become claims. Search snippets never do.
List<ResearchClaim> extractClaims(List<SourceDocument> documents) {
  final claims = <ResearchClaim>[];
  var index = 0;
  for (final document in documents) {
    for (final paragraph in document.paragraphs) {
      final text = paragraph.trim();
      if (text.length < 12) {
        continue;
      }
      claims.add(
        ResearchClaim(
          id: 'c$index',
          text: text,
          sourceUrl: document.url,
          excerpt: text,
          status: ClaimSupport.supported,
        ),
      );
      index += 1;
    }
  }
  return claims;
}

/// A citation is valid only if the source was acquired and the excerpt
/// actually appears in that document.
List<ResearchClaim> validateCitations(
  List<ResearchClaim> claims,
  List<SourceDocument> documents,
) {
  final byUrl = {for (final document in documents) document.url: document};
  return [
    for (final claim in claims) _validateOne(claim, byUrl[claim.sourceUrl]),
  ];
}

ResearchClaim _validateOne(ResearchClaim claim, SourceDocument? document) {
  if (document == null) {
    return claim.copyWith(status: ClaimSupport.unverified);
  }
  final body = document.evidenceText.toLowerCase();
  final excerpt = claim.excerpt.trim().toLowerCase();
  if (excerpt.isEmpty || !body.contains(excerpt)) {
    return claim.copyWith(status: ClaimSupport.unverified);
  }
  return claim.copyWith(status: ClaimSupport.supported);
}
