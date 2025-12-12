import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class RevisionDB {
  static final RevisionDB instance = RevisionDB._init();
  static Database? _database;

  RevisionDB._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('revision_questions.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    // ID (Text), Question Data (JSON String), Attempt Count (Integer)
    await db.execute('''
      CREATE TABLE wrong_questions (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        subject TEXT NOT NULL,
        topic TEXT NOT NULL,
        attemptCount INTEGER NOT NULL
      )
    ''');
  }

  // 1. Galat Jawab Save Karo
  Future<void> addWrongQuestion(Map<String, dynamic> questionData, String subject, String topic) async {
    final db = await instance.database;
    final String id = questionData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Check karo agar pehle se hai to add mat karo
    final existing = await db.query('wrong_questions', where: 'id = ?', whereArgs: [id]);
    if (existing.isNotEmpty) return;

    await db.insert('wrong_questions', {
      'id': id,
      'data': jsonEncode(questionData),
      'subject': subject,
      'topic': topic,
      'attemptCount': 0, // Shuru mein 0 attempts
    });
  }

  // 2. Revision Set Nikalo (Limit 25)
  Future<List<Map<String, dynamic>>> getRevisionSet() async {
    final db = await instance.database;
    
    // Sirf wahi sawal lo jo 2 baar se kam attempt hue hain
    final result = await db.query(
      'wrong_questions',
      where: 'attemptCount < 2',
      limit: 25, 
    );

    return result.map((json) => {
      ...json,
      'parsedData': jsonDecode(json['data'] as String),
    }).toList();
  }

  // 3. Attempt Count Badhao (Revision dene ke baad)
  Future<void> incrementAttempt(String id) async {
    final db = await instance.database;
    
    // Pehle current count nikalo
    final result = await db.query('wrong_questions', columns: ['attemptCount'], where: 'id = ?', whereArgs: [id]);
    
    if (result.isNotEmpty) {
      int currentCount = result.first['attemptCount'] as int;
      int newCount = currentCount + 1;

      if (newCount >= 2) {
        // Agar 2 baar ho gaya, to delete kar do
        await db.delete('wrong_questions', where: 'id = ?', whereArgs: [id]);
      } else {
        // Nahi to count update karo
        await db.update('wrong_questions', {'attemptCount': newCount}, where: 'id = ?', whereArgs: [id]);
      }
    }
  }
}
