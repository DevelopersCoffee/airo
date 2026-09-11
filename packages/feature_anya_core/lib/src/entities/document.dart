import 'package:equatable/equatable.dart';

import 'enums.dart';

class DocumentPage extends Equatable {
  const DocumentPage({
    required this.pageNumber,
    required this.rawText,
    required this.pageClass,
    this.confidence = 1,
  });

  final int pageNumber;
  final String rawText;
  final PageClass pageClass;
  final double confidence;

  Map<String, Object?> toJson() => {
    'pageNumber': pageNumber,
    'rawText': rawText,
    'pageClass': pageClass.name,
    'confidence': confidence,
  };

  factory DocumentPage.fromJson(Map<String, Object?> json) => DocumentPage(
    pageNumber: json['pageNumber'] as int,
    rawText: json['rawText'] as String,
    pageClass: PageClass.values.byName(json['pageClass'] as String),
    confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
  );

  @override
  List<Object?> get props => [pageNumber, rawText, pageClass, confidence];
}

class ExtractedPdfPage extends Equatable {
  const ExtractedPdfPage({required this.pageNumber, required this.text});

  final int pageNumber;
  final String text;

  bool get hasTextLayer => text.trim().isNotEmpty;

  @override
  List<Object?> get props => [pageNumber, text];
}

class UploadedDocument extends Equatable {
  const UploadedDocument({
    required this.id,
    required this.fileName,
    required this.bytesHash,
    required this.pages,
  });

  final String id;
  final String fileName;
  final String bytesHash;
  final List<DocumentPage> pages;

  @override
  List<Object?> get props => [id, fileName, bytesHash, pages];
}

class ExtractionValidation extends Equatable {
  const ExtractionValidation({
    required this.profileDetected,
    required this.mealDaysDetected,
    required this.mealTimingsDetected,
    required this.restrictionsDetected,
    required this.includeListDetected,
    required this.avoidListDetected,
    required this.uninterpretedQuantities,
  });

  final bool profileDetected;
  final int mealDaysDetected;
  final bool mealTimingsDetected;
  final bool restrictionsDetected;
  final bool includeListDetected;
  final bool avoidListDetected;
  final int uninterpretedQuantities;

  List<String> get summaryLines {
    final lines = <String>[
      if (profileDetected) 'Profile detected',
      if (mealDaysDetected > 0) '$mealDaysDetected meal days detected',
      if (mealTimingsDetected) 'Meal timings detected',
      if (restrictionsDetected) 'Food restrictions detected',
      if (includeListDetected) 'Include list detected',
      if (avoidListDetected) 'Avoid list detected',
    ];
    if (uninterpretedQuantities > 0) {
      lines.add(
        '$uninterpretedQuantities quantities could not be confidently interpreted',
      );
    }
    if (lines.isEmpty) {
      lines.add('No structured diet content detected');
    }
    return lines;
  }

  @override
  List<Object?> get props => [
    profileDetected,
    mealDaysDetected,
    mealTimingsDetected,
    restrictionsDetected,
    includeListDetected,
    avoidListDetected,
    uninterpretedQuantities,
  ];
}
