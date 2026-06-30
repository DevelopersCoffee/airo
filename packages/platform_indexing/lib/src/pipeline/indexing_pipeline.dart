
import 'package:platform_documents/platform_documents.dart';

abstract class IndexingPipeline {
  Future<void> indexDocument(DocumentSource source);
}
