import 'package:platform_identity/platform_identity.dart';

enum AstKind {
  document,
  frontMatter,
  heading,
  paragraph,
  sentence,
  inlineCode,
  codeFence,
  table,
  tableRow,
  tableCell,
  orderedList,
  unorderedList,
  listItem,
  quote,
  link,
  image,
  footnote,
  reference,
  math,
  html,
  metadata,
  callout,
  taskItem
}

abstract class AstNode {
  AstNode({
    required this.kind,
    this.attributes = const {},
    this.children = const [],
  });

  final AstKind kind;
  final Map<String, dynamic> attributes;
  final List<AstNode> children;
}

// Concrete AST Nodes
class DocumentNode extends AstNode { DocumentNode(List<AstNode> children) : super(kind: AstKind.document, children: children); }
class FrontMatterNode extends AstNode { FrontMatterNode(Map<String, dynamic> data) : super(kind: AstKind.frontMatter, attributes: data); }
class HeadingNode extends AstNode { HeadingNode(int level, List<AstNode> children) : super(kind: AstKind.heading, attributes: {'level': level}, children: children); }
class ParagraphNode extends AstNode { ParagraphNode(List<AstNode> children) : super(kind: AstKind.paragraph, children: children); }
class SentenceNode extends AstNode { SentenceNode(String text) : super(kind: AstKind.sentence, attributes: {'text': text}); }
class InlineCodeNode extends AstNode { InlineCodeNode(String code) : super(kind: AstKind.inlineCode, attributes: {'code': code}); }
class CodeFenceNode extends AstNode { CodeFenceNode(String language, String code) : super(kind: AstKind.codeFence, attributes: {'language': language, 'code': code}); }
class TableNode extends AstNode { TableNode(List<AstNode> rows) : super(kind: AstKind.table, children: rows); }
class TableRowNode extends AstNode { TableRowNode(List<AstNode> cells) : super(kind: AstKind.tableRow, children: cells); }
class TableCellNode extends AstNode { TableCellNode(List<AstNode> content) : super(kind: AstKind.tableCell, children: content); }
class OrderedListNode extends AstNode { OrderedListNode(List<AstNode> items) : super(kind: AstKind.orderedList, children: items); }
class UnorderedListNode extends AstNode { UnorderedListNode(List<AstNode> items) : super(kind: AstKind.unorderedList, children: items); }
class ListItemNode extends AstNode { ListItemNode(List<AstNode> content) : super(kind: AstKind.listItem, children: content); }
class QuoteNode extends AstNode { QuoteNode(List<AstNode> content) : super(kind: AstKind.quote, children: content); }
class LinkNode extends AstNode { LinkNode(String url, List<AstNode> children) : super(kind: AstKind.link, attributes: {'url': url}, children: children); }
class ImageNode extends AstNode { ImageNode(String url, String alt) : super(kind: AstKind.image, attributes: {'url': url, 'alt': alt}); }
class FootnoteNode extends AstNode { FootnoteNode(String id, List<AstNode> content) : super(kind: AstKind.footnote, attributes: {'id': id}, children: content); }
class ReferenceNode extends AstNode { ReferenceNode(String id) : super(kind: AstKind.reference, attributes: {'id': id}); }
class MathNode extends AstNode { MathNode(String formula, bool block) : super(kind: AstKind.math, attributes: {'formula': formula, 'block': block}); }
class HtmlNode extends AstNode { HtmlNode(String content) : super(kind: AstKind.html, attributes: {'content': content}); }
class MetadataNode extends AstNode { MetadataNode(Map<String, dynamic> data) : super(kind: AstKind.metadata, attributes: data); }
class CalloutNode extends AstNode { CalloutNode(String type, List<AstNode> children) : super(kind: AstKind.callout, attributes: {'type': type}, children: children); }
class TaskItemNode extends AstNode { TaskItemNode(bool checked, List<AstNode> content) : super(kind: AstKind.taskItem, attributes: {'checked': checked}, children: content); }

class AstEvent {
  AstEvent(this.type, this.node);
  final String type; // e.g. "open", "close", "leaf"
  final AstNode node;
}
