
import '../models/document_models.dart';
import 'package:platform_content/platform_content.dart';

abstract class DocumentParser {
  bool canParse(DocumentSource source);
  Future<ContentDocument> parse(DocumentSource source);
}

abstract class DocumentImporter {
  Future<Document> importDocument(String pathOrUri);
}

abstract class DocumentRepository {
  Future<void> save(Document document);
  Future<Document?> findById(String id);
}
