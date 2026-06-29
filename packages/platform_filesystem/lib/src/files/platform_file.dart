abstract class PlatformFile {
  final String fileName;
  
  const PlatformFile(this.fileName);
  
  String get relativePath;
}
