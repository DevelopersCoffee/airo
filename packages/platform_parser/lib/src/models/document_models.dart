
class DocumentSource {
  final String uri;
  DocumentSource(this.uri);
}

class DocumentMetadata {
  final Map<String, dynamic> attributes;
  DocumentMetadata(this.attributes);
}

class Document {
  final String id;
  final DocumentSource source;
  final DocumentMetadata metadata;
  
  Document({required this.id, required this.source, required this.metadata});
}
