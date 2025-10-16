import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer' as developer;
import '../models/food_item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'airo_assistant.db');

      developer.log('Initializing database at: $path', name: 'DatabaseService');

      return await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      developer.log('Database initialization failed: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      developer.log('Creating database tables', name: 'DatabaseService');

      // Create food_items table
      await db.execute('''
        CREATE TABLE food_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          calories REAL,
          protein REAL,
          carbs REAL,
          fat REAL,
          fiber REAL,
          imagePath TEXT,
          extractedText TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT,
          userId TEXT NOT NULL
        )
      ''');

      // Create messages table
      await db.execute('''
        CREATE TABLE messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          content TEXT NOT NULL,
          role TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          userId TEXT NOT NULL
        )
      ''');

      // Create reminders table
      await db.execute('''
        CREATE TABLE reminders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT,
          scheduledTime TEXT NOT NULL,
          reminderType TEXT NOT NULL,
          isCompleted INTEGER DEFAULT 0,
          createdAt TEXT NOT NULL,
          userId TEXT NOT NULL
        )
      ''');

      developer.log('Database tables created successfully', name: 'DatabaseService');
    } catch (e) {
      developer.log('Error creating tables: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    developer.log(
      'Upgrading database from $oldVersion to $newVersion',
      name: 'DatabaseService',
    );
    // Handle future migrations here
  }

  // Food Items CRUD Operations

  Future<int> insertFoodItem(FoodItem foodItem) async {
    try {
      final db = await database;
      final id = await db.insert('food_items', foodItem.toJson());
      developer.log('Food item inserted with id: $id', name: 'DatabaseService');
      return id;
    } catch (e) {
      developer.log('Error inserting food item: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  Future<List<FoodItem>> getFoodItems(String userId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'food_items',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'createdAt DESC',
      );
      return List.generate(maps.length, (i) => FoodItem.fromJson(maps[i]));
    } catch (e) {
      developer.log('Error fetching food items: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  Future<FoodItem?> getFoodItem(int id) async {
    try {
      final db = await database;
      final maps = await db.query(
        'food_items',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return FoodItem.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      developer.log('Error fetching food item: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  Future<int> updateFoodItem(FoodItem foodItem) async {
    try {
      final db = await database;
      final updated = await db.update(
        'food_items',
        foodItem.copyWith(updatedAt: DateTime.now()).toJson(),
        where: 'id = ?',
        whereArgs: [foodItem.id],
      );
      developer.log('Food item updated: $updated rows', name: 'DatabaseService');
      return updated;
    } catch (e) {
      developer.log('Error updating food item: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  Future<int> deleteFoodItem(int id) async {
    try {
      final db = await database;
      final deleted = await db.delete(
        'food_items',
        where: 'id = ?',
        whereArgs: [id],
      );
      developer.log('Food item deleted: $deleted rows', name: 'DatabaseService');
      return deleted;
    } catch (e) {
      developer.log('Error deleting food item: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  // Messages CRUD Operations

  Future<int> insertMessage(String userId, String content, String role) async {
    try {
      final db = await database;
      final id = await db.insert('messages', {
        'content': content,
        'role': role,
        'createdAt': DateTime.now().toIso8601String(),
        'userId': userId,
      });
      return id;
    } catch (e) {
      developer.log('Error inserting message: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(String userId) async {
    try {
      final db = await database;
      return await db.query(
        'messages',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'createdAt ASC',
      );
    } catch (e) {
      developer.log('Error fetching messages: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  // Reminders CRUD Operations

  Future<int> insertReminder(
    String userId,
    String title,
    String? description,
    DateTime scheduledTime,
    String reminderType,
  ) async {
    try {
      final db = await database;
      final id = await db.insert('reminders', {
        'title': title,
        'description': description,
        'scheduledTime': scheduledTime.toIso8601String(),
        'reminderType': reminderType,
        'createdAt': DateTime.now().toIso8601String(),
        'userId': userId,
      });
      return id;
    } catch (e) {
      developer.log('Error inserting reminder: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getReminders(String userId) async {
    try {
      final db = await database;
      return await db.query(
        'reminders',
        where: 'userId = ? AND isCompleted = 0',
        whereArgs: [userId],
        orderBy: 'scheduledTime ASC',
      );
    } catch (e) {
      developer.log('Error fetching reminders: $e', name: 'DatabaseService');
      rethrow;
    }
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

