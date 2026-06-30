
import '../models/document_models.dart';
import 'package:platform_content/platform_content.dart';

class DocumentFormat {
  final String extension;
  final String mimeType;
  const DocumentFormat({required this.extension, required this.mimeType});
  
  static const markdown = DocumentFormat(extension: 'md', mimeType: 'text/markdown');
}

abstract class DocumentParser {
  DocumentFormat get format;
  Future<ContentDocument> parse(DocumentSource source, DocumentId id);
}

abstract class DocumentParserFactory {
  void registerParser(DocumentParser parser);
  DocumentParser? getParserForFormat(DocumentFormat format);
}

abstract class DocumentImporter {
  Future<Document> importDocument(String pathOrUri);
}

abstract class DocumentRepository {
  Future<void> save(Document document);
  Future<Document?> findById(String id);
}
