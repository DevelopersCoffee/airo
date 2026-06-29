import 'platform_file.dart';

class ModelFile extends PlatformFile {
  final String modelType;
  const ModelFile(super.fileName, this.modelType);
  
  @override
  String get relativePath => 'models/$modelType/$fileName';
}

class WorkspaceFile extends PlatformFile {
  final String workspaceId;
  const WorkspaceFile(super.fileName, this.workspaceId);
  
  @override
  String get relativePath => 'workspaces/$workspaceId/$fileName';
}

class DocumentFile extends WorkspaceFile {
  const DocumentFile(String fileName, String workspaceId) : super(fileName, workspaceId);
  
  @override
  String get relativePath => 'workspaces/$workspaceId/documents/$fileName';
}

class AudioFile extends WorkspaceFile {
  const AudioFile(String fileName, String workspaceId) : super(fileName, workspaceId);
  
  @override
  String get relativePath => 'workspaces/$workspaceId/audio/$fileName';
}

class ImageFile extends WorkspaceFile {
  const ImageFile(String fileName, String workspaceId) : super(fileName, workspaceId);
  
  @override
  String get relativePath => 'workspaces/$workspaceId/images/$fileName';
}

class ExportFile extends PlatformFile {
  const ExportFile(super.fileName);
  
  @override
  String get relativePath => 'exports/$fileName';
}

class TemporaryFile extends PlatformFile {
  const TemporaryFile(super.fileName);
  
  @override
  String get relativePath => 'temp/$fileName';
}
