
import 'package:platform_identity/platform_identity.dart';
import '../visitors/content_visitor.dart';

class DocumentId extends PlatformIdentifier {
  const DocumentId(super.value);
}

class ContentMetadata {
  final Map<String, dynamic> attributes;
  const ContentMetadata([this.attributes = const {}]);
}

class ContentDocument {
  final DocumentId id;
  final List<ContentNode> nodes;
  final ContentMetadata metadata;

  const ContentDocument({
    required this.id,
    required this.nodes,
    this.metadata = const ContentMetadata(),
  });
  
  T accept<T>(ContentVisitor<T> visitor) {
    return visitor.visitDocument(this);
  }
}

abstract class ContentNode {
  const ContentNode();
  T accept<T>(ContentVisitor<T> visitor);
}

class ParagraphNode extends ContentNode {
  final String text;
  const ParagraphNode(this.text);
  
  @override
  T accept<T>(ContentVisitor<T> visitor) => visitor.visitParagraph(this);
}

class HeadingNode extends ContentNode {
  final int level;
  final String text;
  const HeadingNode(this.level, this.text);

  @override
  T accept<T>(ContentVisitor<T> visitor) => visitor.visitHeading(this);
}

class TableNode extends ContentNode {
  const TableNode();

  @override
  T accept<T>(ContentVisitor<T> visitor) => visitor.visitTable(this);
}

class ListNode extends ContentNode {
  const ListNode();

  @override
  T accept<T>(ContentVisitor<T> visitor) => visitor.visitList(this);
}

class ImageNode extends ContentNode {
  final String url;
  final String altText;
  const ImageNode(this.url, this.altText);

  @override
  T accept<T>(ContentVisitor<T> visitor) => visitor.visitImage(this);
}

class CodeNode extends ContentNode {
  final String language;
  final String code;
  const CodeNode(this.language, this.code);

  @override
  T accept<T>(ContentVisitor<T> visitor) => visitor.visitCode(this);
}
