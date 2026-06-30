
abstract class ContentDocument {
  String get id;
  List<ContentBlock> get blocks;
}

abstract class ContentBlock {
  String get type;
}

class Paragraph implements ContentBlock {
  @override
  String get type => 'paragraph';
  final String text;
  Paragraph(this.text);
}

class Heading implements ContentBlock {
  @override
  String get type => 'heading';
  final int level;
  final String text;
  Heading(this.level, this.text);
}

class Table implements ContentBlock {
  @override
  String get type => 'table';
  // Simplified for now
}

class ListBlock implements ContentBlock {
  @override
  String get type => 'list';
}

class ImageBlock implements ContentBlock {
  @override
  String get type => 'image';
  final String url;
  ImageBlock(this.url);
}

class CodeBlock implements ContentBlock {
  @override
  String get type => 'code';
  final String language;
  final String code;
  CodeBlock(this.language, this.code);
}
