
import '../models/content_models.dart';

abstract interface class ContentVisitor<T> {
  T visitDocument(ContentDocument document);
  T visitParagraph(ParagraphNode node);
  T visitHeading(HeadingNode node);
  T visitTable(TableNode node);
  T visitList(ListNode node);
  T visitImage(ImageNode node);
  T visitCode(CodeNode node);
}

abstract interface class ContentTransformer {
  ContentDocument transform(ContentDocument document);
}
