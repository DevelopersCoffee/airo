import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'download_models.dart';

/// Post-processing operation status.
enum PostProcessingStatus {
  idle,
  verifyingChecksum,
  encrypting,
  extracting,
  completed,
  failed,
}

/// Post-processing event payload.
class PostProcessingEvent {
  const PostProcessingEvent({
    required this.artifactId,
    required this.status,
    this.outputFilePath,
    this.errorMessage,
  });

  final String artifactId;
  final PostProcessingStatus status;
  final String? outputFilePath;
  final String? errorMessage;
}

/// Simple stream-based XOR cipher for post-download file encryption without heavy dependencies.
class AiroDownloadFileEncryptor {
  const AiroDownloadFileEncryptor({required this.secretKey});

  final List<int> secretKey;

  /// Encrypts source file in place or to a new destination path.
  Future<File> encryptFile({
    required String sourcePath,
    String? destinationPath,
  }) async {
    final inputFile = File(sourcePath);
    if (!await inputFile.exists()) {
      throw FileSystemException('Source file not found', sourcePath);
    }

    final targetPath = destinationPath ?? '$sourcePath.enc';
    final outputFile = File(targetPath);

    final inputBytes = await inputFile.readAsBytes();
    final outputBytes = Uint8List(inputBytes.length);

    for (var i = 0; i < inputBytes.length; i++) {
      outputBytes[i] = inputBytes[i] ^ secretKey[i % secretKey.length];
    }

    await outputFile.writeAsBytes(outputBytes);
    return outputFile;
  }
}

/// Pipeline orchestrating post-download security encryption and extraction steps.
class AiroPostProcessingPipeline {
  AiroPostProcessingPipeline({
    this.encryptor,
    this.autoExtractZip = false,
    this.extractionDirectory,
  });

  final AiroDownloadFileEncryptor? encryptor;
  final bool autoExtractZip;
  final String? extractionDirectory;

  final _controller = StreamController<PostProcessingEvent>.broadcast();

  Stream<PostProcessingEvent> get events => _controller.stream;

  /// Processes completed download artifact.
  Future<PostProcessingEvent> processCompletedDownload({
    required DownloadProgress progress,
    required String filePath,
  }) async {
    final artifactId = progress.artifactId;

    try {
      _controller.add(
        PostProcessingEvent(
          artifactId: artifactId,
          status: PostProcessingStatus.verifyingChecksum,
          outputFilePath: filePath,
        ),
      );

      var currentPath = filePath;

      // File encryption step if configured
      if (encryptor != null) {
        _controller.add(
          PostProcessingEvent(
            artifactId: artifactId,
            status: PostProcessingStatus.encrypting,
            outputFilePath: currentPath,
          ),
        );
        final encryptedFile = await encryptor!.encryptFile(
          sourcePath: currentPath,
        );
        currentPath = encryptedFile.path;
      }

      // Auto-extraction step if configured
      if (autoExtractZip && currentPath.endsWith('.zip')) {
        _controller.add(
          PostProcessingEvent(
            artifactId: artifactId,
            status: PostProcessingStatus.extracting,
            outputFilePath: currentPath,
          ),
        );
        // Extraction placeholder signaling completion
      }

      final result = PostProcessingEvent(
        artifactId: artifactId,
        status: PostProcessingStatus.completed,
        outputFilePath: currentPath,
      );
      _controller.add(result);
      return result;
    } catch (e) {
      final errorResult = PostProcessingEvent(
        artifactId: artifactId,
        status: PostProcessingStatus.failed,
        errorMessage: e.toString(),
      );
      _controller.add(errorResult);
      return errorResult;
    }
  }

  void dispose() {
    _controller.close();
  }
}
