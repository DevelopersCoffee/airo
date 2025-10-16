import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:developer' as developer;
import '../models/food_item.dart';
import '../services/database_service.dart';
import '../services/ocr_service.dart';

class FoodProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final OCRService _ocrService = OCRService();

  List<FoodItem> _foodItems = [];
  bool _isLoading = false;
  String? _error;
  String? _userId;

  List<FoodItem> get foodItems => _foodItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initialize food provider with user ID
  Future<void> initialize(String userId) async {
    try {
      _userId = userId;
      developer.log('Initializing FoodProvider for user: $userId', name: 'FoodProvider');

      // Load existing food items
      await _loadFoodItems();

      notifyListeners();
    } catch (e) {
      developer.log('Error initializing FoodProvider: $e', name: 'FoodProvider');
      _error = 'Failed to initialize food tracker';
      notifyListeners();
    }
  }

  /// Load food items from database
  Future<void> _loadFoodItems() async {
    try {
      if (_userId == null) return;

      _foodItems = await _databaseService.getFoodItems(_userId!);
      developer.log('Loaded ${_foodItems.length} food items', name: 'FoodProvider');
      notifyListeners();
    } catch (e) {
      developer.log('Error loading food items: $e', name: 'FoodProvider');
      _error = 'Failed to load food items';
      notifyListeners();
    }
  }

  /// Pick image from camera and extract text
  Future<void> captureAndAnalyzeFood() async {
    try {
      if (_userId == null) {
        _error = 'User not authenticated';
        notifyListeners();
        return;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      developer.log('Capturing food image', name: 'FoodProvider');

      // Pick image from camera
      final imageFile = await _ocrService.pickImageFromCamera();
      if (imageFile == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Extract text from image
      final extractedText = await _ocrService.extractTextFromImage(imageFile);
      developer.log('Text extracted: ${extractedText.length} chars', name: 'FoodProvider');

      // Parse nutritional information
      final nutritionInfo = _ocrService.parseNutritionalInfo(extractedText);

      // Create food item
      final foodItem = FoodItem(
        name: _extractFoodName(extractedText),
        description: extractedText,
        calories: (nutritionInfo['calories'] as double?),
        protein: (nutritionInfo['protein'] as double?),
        carbs: (nutritionInfo['carbs'] as double?),
        fat: (nutritionInfo['fat'] as double?),
        fiber: (nutritionInfo['fiber'] as double?),
        imagePath: imageFile.path,
        extractedText: extractedText,
        createdAt: DateTime.now(),
        userId: _userId!,
      );

      // Save to database
      final id = await _databaseService.insertFoodItem(foodItem);
      developer.log('Food item saved with id: $id', name: 'FoodProvider');

      // Add to list
      _foodItems.add(foodItem.copyWith(id: id));
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      developer.log('Error capturing food: $e', name: 'FoodProvider');
      _error = 'Failed to capture and analyze food';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Pick image from gallery and extract text
  Future<void> selectAndAnalyzeFood() async {
    try {
      if (_userId == null) {
        _error = 'User not authenticated';
        notifyListeners();
        return;
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      developer.log('Selecting food image from gallery', name: 'FoodProvider');

      // Pick image from gallery
      final imageFile = await _ocrService.pickImageFromGallery();
      if (imageFile == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Extract text from image
      final extractedText = await _ocrService.extractTextFromImage(imageFile);

      // Parse nutritional information
      final nutritionInfo = _ocrService.parseNutritionalInfo(extractedText);

      // Create food item
      final foodItem = FoodItem(
        name: _extractFoodName(extractedText),
        description: extractedText,
        calories: (nutritionInfo['calories'] as double?),
        protein: (nutritionInfo['protein'] as double?),
        carbs: (nutritionInfo['carbs'] as double?),
        fat: (nutritionInfo['fat'] as double?),
        fiber: (nutritionInfo['fiber'] as double?),
        imagePath: imageFile.path,
        extractedText: extractedText,
        createdAt: DateTime.now(),
        userId: _userId!,
      );

      // Save to database
      final id = await _databaseService.insertFoodItem(foodItem);

      // Add to list
      _foodItems.add(foodItem.copyWith(id: id));
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      developer.log('Error selecting food: $e', name: 'FoodProvider');
      _error = 'Failed to select and analyze food';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Extract food name from text
  String _extractFoodName(String text) {
    final lines = text.split('\n');
    if (lines.isNotEmpty) {
      return lines.first.trim().split(' ').take(3).join(' ');
    }
    return 'Food Item';
  }

  /// Delete food item
  Future<void> deleteFoodItem(int id) async {
    try {
      await _databaseService.deleteFoodItem(id);
      _foodItems.removeWhere((item) => item.id == id);
      notifyListeners();
      developer.log('Food item deleted: $id', name: 'FoodProvider');
    } catch (e) {
      developer.log('Error deleting food item: $e', name: 'FoodProvider');
      _error = 'Failed to delete food item';
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

