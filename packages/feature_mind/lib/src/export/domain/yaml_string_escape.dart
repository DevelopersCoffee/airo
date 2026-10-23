/// Escapes a string for use inside YAML double-quoted scalars in frontmatter.
String escapeYamlDoubleQuoted(String value) =>
    value.replaceAll('\\', r'\\').replaceAll('"', r'\"');
