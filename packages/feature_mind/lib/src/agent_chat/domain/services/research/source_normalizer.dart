import 'research_search.dart';

String canonicalizeUrl(String raw) {
  var value = raw.trim();
  for (final prefix in ['https://', 'http://']) {
    if (value.startsWith(prefix)) {
      value = value.substring(prefix.length);
      break;
    }
  }
  final parts = value.split('?');
  var hostPath = parts.first.replaceAll(RegExp(r'/+$'), '');
  if (hostPath.toLowerCase().startsWith('www.')) {
    hostPath = hostPath.substring(4);
  }
  final slash = hostPath.indexOf('/');
  if (slash < 0) {
    hostPath = hostPath.toLowerCase();
  } else {
    hostPath =
        '${hostPath.substring(0, slash).toLowerCase()}${hostPath.substring(slash)}';
  }
  if (parts.length == 1) {
    return 'https://$hostPath';
  }
  final kept = parts.last.split('&').where((pair) {
    final key = pair.split('=').first;
    return key.isNotEmpty && !key.startsWith('utm') && key != 'fbclid';
  });
  if (kept.isEmpty) {
    return 'https://$hostPath';
  }
  return 'https://$hostPath?${kept.join('&')}';
}

List<ResearchHit> dedupeHits(List<ResearchHit> hits) {
  final seen = <String>{};
  final out = <ResearchHit>[];
  for (final hit in hits) {
    if (seen.add(canonicalizeUrl(hit.url))) {
      out.add(hit);
    }
  }
  return out;
}

int sourceTier(ResearchHit hit) {
  final url = hit.url.toLowerCase();
  if (url.contains('arxiv.org') || url.contains('doi.org')) {
    return 1;
  }
  if (url.contains('wikipedia.org') || url.contains('.gov')) {
    return 2;
  }
  return 3;
}

List<ResearchHit> rankHits(List<ResearchHit> hits) {
  final copy = [...hits];
  copy.sort((a, b) => sourceTier(a).compareTo(sourceTier(b)));
  return copy;
}
