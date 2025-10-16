import 'dart:io';
import 'dart:developer' as developer;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class OCRService {
  static final OCRService _instance = OCRService._internal();
  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePicker _imagePicker = ImagePicker();

  factory OCRService() {
    return _instance;
  }

  OCRService._internal();

  /// Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        developer.log('Image picked from camera: ${pickedFile.path}', name: 'OCRService');
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      developer.log('Error picking image from camera: $e', name: 'OCRService');
      rethrow;
    }
  }

  /// Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        developer.log('Image picked from gallery: ${pickedFile.path}', name: 'OCRService');
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      developer.log('Error picking image from gallery: $e', name: 'OCRService');
      rethrow;
    }
  }

  /// Extract text from image using ML Kit
  Future<String> extractTextFromImage(File imageFile) async {
    try {
      developer.log('Starting text extraction from: ${imageFile.path}', name: 'OCRService');

      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final extractedText = recognizedText.text;
      developer.log('Text extracted: ${extractedText.length} characters', name: 'OCRService');

      return extractedText;
    } catch (e) {
      developer.log('Error extracting text: $e', name: 'OCRService');
      rethrow;
    }
  }

  /// Parse nutritional information from extracted text
  Map<String, dynamic> parseNutritionalInfo(String text) {
    try {
      developer.log('Parsing nutritional info from text', name: 'OCRService');

      final result = {
        'calories': _extractNumber(text, ['calories', 'kcal', 'cal']),
        'protein': _extractNumber(text, ['protein', 'g protein']),
        'carbs': _extractNumber(text, ['carbs', 'carbohydrates', 'g carbs']),
        'fat': _extractNumber(text, ['fat', 'g fat']),
        'fiber': _extractNumber(text, ['fiber', 'g fiber']),
      };

      developer.log('Parsed nutritional info: $result', name: 'OCRService');
      return result;
    } catch (e) {
      developer.log('Error parsing nutritional info: $e', name: 'OCRService');
      return {};
    }
  }

  /// Extract number from text based on keywords
  double? _extractNumber(String text, List<String> keywords) {
    final lowerText = text.toLowerCase();

    for (final keyword in keywords) {
      final index = lowerText.indexOf(keyword);
      if (index != -1) {
        // Look for numbers before or after the keyword
        final beforeText = text.substring(0, index);
        final afterText = text.substring(index + keyword.length);

        // Try to find number before keyword
        final beforeMatch = RegExp(r'(\d+\.?\d*)').firstMatch(beforeText);
        if (beforeMatch != null) {
          return double.tryParse(beforeMatch.group(1)!);
        }

        // Try to find number after keyword
        final afterMatch = RegExp(r'(\d+\.?\d*)').firstMatch(afterText);
        if (afterMatch != null) {
          return double.tryParse(afterMatch.group(1)!);
        }
      }
    }

    return null;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}

