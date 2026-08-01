library;

import 'dart:io';

class InputImage {
  InputImage._(this.filePath);

  final String filePath;

  static InputImage fromFile(File file) => InputImage._(file.path);
}

class ImageLabelerOptions {
  ImageLabelerOptions({this.confidenceThreshold = 0.5});

  final double confidenceThreshold;
}

class ImageLabel {
  ImageLabel({required this.label, required this.confidence, required this.index});

  final String label;
  final double confidence;
  final int index;
}

class ImageLabeler {
  ImageLabeler({required this.options});

  final ImageLabelerOptions options;

  Future<List<ImageLabel>> processImage(InputImage inputImage) async => const [];

  Future<void> close() async {}
}
