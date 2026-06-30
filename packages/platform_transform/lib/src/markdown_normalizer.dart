
import 'transformer.dart';
import 'package:platform_content/platform_content.dart';

class MarkdownNormalizer implements AstTransformer {
  @override
  ContentDocument transform(ContentDocument document) {
    return document;
  }
}
