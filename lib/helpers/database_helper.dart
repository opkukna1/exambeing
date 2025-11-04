import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambeing/models/mcq_bookmark_model.dart';
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/models/public_note_model.dart'; // List ke liye
import 'package:exambeing/models/schedule_model.dart';
import 'package:intl/intl.dart';

// ⬇️===== NAYE IMPORTS (Bookmark aur Content Models) =====⬇️
import 'package:exambeing/models/bookmarked_note_model.dart';
import 'package:exambeing/models/note_content_model.dart';
// ⬆️==================================================⬆️


// --- Note Model ---
class MyNote {
  final int? id;
  final String content;
  final String createdAt;
  MyNote({this.id, required this.content, required this.createdAt});
  Map<String, dynamic> toMap() {
    return {'id': id, 'content': content, 'createdAt': createdAt};
  }
}

// --- Task (To-Do) Model ---
class Task {
  final int? id;
  final String title;
  final bool isDone;
  final DateTime date;
  Task({this.id, required this.title, this.isDone = false, required this.date});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone ? 1 : 0,
      'date': DateFormat('yyyy-MM-dd').format(date),
    };
  }

  static Task fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int,
      title: map['title'] as String,
      isDone: map['isDone'] == 1,
      date: DateTime.parse(map['date'] as String),
    );
  }
}

// --- Timetable Model ---
class TimetableEntry {
  final int? id;
  final String subjectName;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int dayOfWeek;
  final int notificationId;

  TimetableEntry({
    this.id,
    required this.subjectName,
    required this.startTime,
    required this.endTime,
    required this.dayOfWeek,
    required this.notificationId,
  });

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectName': subjectName,
      'startTime': _formatTime(startTime),
      'endTime': _formatTime(endTime),
      'dayOfWeek': dayOfWeek,
      'notificationId': notificationId,
    };
  }

  static TimetableEntry fromMap(Map<String, dynamic> map) {
    return TimetableEntry(
      id: map['id'] as int,
      subjectName: map['subjectName'] as String,
      startTime: _parseTime(map['startTime'] as String),
      endTime: _parseTime(map['endTime'] as String),
      dayOfWeek: map['dayOfWeek'] as int,
      notificationId: map['notificationId'] as int,
    );
  }
}

// --- User Note Edit Model (v6) ---
class UserNoteEdit {
  final int? id;
  final String firebaseNoteId;
  final String? userContent;
  final String? userHighlightsJson;

  UserNoteEdit({
    this.id,
    required this.firebaseNoteId,
    this.userContent,
    this.userHighlightsJson,
  });

  factory UserNoteEdit.create({
    required String firebaseNoteId,
    String? userContent,
    List<String>? highlights,
  }) {
    return UserNoteEdit(
      firebaseNoteId: firebaseNoteId,
      userContent: userContent,
      userHighlightsJson: highlights != null ? jsonEncode(highlights) : null,
    );
  }

  List<String> get highlights {
    if (userHighlightsJson == null) return [];
    try {
      return List<String>.from(jsonDecode(userHighlightsJson!));
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firebaseNoteId': firebaseNoteId,
      'userContent': userContent,
      'userHighlightsJson': userHighlightsJson,
    };
  }

  static UserNoteEdit fromMap(Map<String, dynamic> map) {
    return UserNoteEdit(
      id: map['id'] as int?,
      firebaseNoteId: map['firebaseNoteId'] as String,
      userContent: map['userContent'] as String?,
      userHighlightsJson: map['userHighlightsJson'] as String?,
    );
  }
}


// --- Database Helper Class ---
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    // ⬇️===== VERSION 7 se 8 KIYA GAYA =====⬇️
    return await openDatabase(path, version: 8, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    await _upgradeDB(db, 0, version);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const uniqueTextType = 'TEXT NOT NULL UNIQUE';
    const integerType = 'INTEGER NOT NULL';
    const nullableTextType = 'TEXT';

    if (oldVersion < 1) {
      // ... (my_notes)
    }
    if (oldVersion < 2) {
      // ... (bookmarked_questions, bookmarked_notes v1)
    }
    if (oldVersion < 3) {
       // ... (bookmarked_schedules)
    }
    if (oldVersion < 4) {
      // ... (tasks)
    }
    if (oldVersion < 5) {
      // ... (timetable_entries)
    }
    if (oldVersion < 6) {
      // ... (user_note_edits)
    }
    if (oldVersion < 7) {
      // ... (bookmarked_notes v2 - content nullable)
    }

    // ⬇️===== BOOKMARKED NOTES TABLE UPDATE (v8) - Content ko NOT NULL kiya =====⬇️
    // Hum naye model (BookmarkedNote) ke liye table ko dobara define kar rahe hain
    if (oldVersion < 8) {
      await db.execute('DROP TABLE IF EXISTS bookmarked_notes');
      await db.execute('''
        CREATE TABLE bookmarked_notes (
          id $idType,
          noteId $uniqueTextType,
          title $textType,
          content $textType, -- ✅ Content ab NOT NULL hai
          subjectId $textType,
          subSubjectId $textType,
          subSubjectName $textType,
          timestamp $textType
        )
      ''');
    }
    // ⬆️==================================================================⬆️
  }

  // --- "My Notes" Functions ---
  Future<MyNote> create(MyNote note) async {
    final db = await instance.database;
    final id = await db.insert('my_notes', note.toMap());
    return MyNote(id: id, content: note.content, createdAt: note.createdAt);
  }
  Future<List<MyNote>> readAllNotes() async {
    final db = await instance.database;
    final orderBy = 'createdAt DESC';
    final result = await db.query('my_notes', orderBy: orderBy);
    return result.map((json) => MyNote(
      id: json['id'] as int,
      content: json['content'] as String,
      createdAt: json['createdAt'] as String,
    )).toList();
  }
  Future<int> update(MyNote note) async {
    final db = await instance.database;
    return db.update('my_notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }
  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('my_notes', where: 'id = ?', whereArgs: [id]);
  }

  // --- Bookmarked Questions Functions ---
  Future<void> bookmarkQuestion(Question question) async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM bookmarked_questions'));
    if (count != null && count >= 100) {
      throw Exception('You can only save a maximum of 100 questions.');
    }
    final Map<String, dynamic> row = {
      'questionText': question.questionText,
      'options': jsonEncode(question.options),
      'correctAnswerIndex': question.correctAnswerIndex,
      'explanation': question.explanation,
      'topicId': question.topicId,
    };
    await db.insert('bookmarked_questions', row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  Future<void> unbookmarkQuestion(String questionText) async {
    final db = await instance.database;
    await db.delete('bookmarked_questions', where: 'questionText = ?', whereArgs: [questionText]);
  }
  Future<bool> isQuestionBookmarked(String questionText) async {
    final db = await instance.database;
    final maps = await db.query('bookmarked_questions', where: 'questionText = ?', whereArgs: [questionText]);
    return maps.isNotEmpty;
  }
  Future<List<McqBookmark>> getAllMcqBookmarks() async {
    final db = await instance.database;
    final maps = await db.query('bookmarked_questions');
    return maps.map((json) {
      final options = List<String>.from(jsonDecode(json['options'] as String));
      final correctIndex = json['correctAnswerIndex'] as int;
      final correctOption = options[correctIndex];
      return McqBookmark(
        id: json['id'] as int,
        questionText: json['questionText'] as String,
        options: options,
        correctOption: correctOption,
        explanation: json['explanation'] as String,
        topic: json['topicId'] as String,
        subject: 'Placeholder Subject',
      );
    }).toList();
  }
  Future<List<Question>> getAllBookmarkedQuestions() async {
    final db = await instance.database;
    final maps = await db.query('bookmarked_questions');
    return maps.map((json) {
      return Question(
        id: json['id'].toString(),
        questionText: json['questionText'] as String,
        options: List<String>.from(jsonDecode(json['options'] as String)),
        correctAnswerIndex: json['correctAnswerIndex'] as int,
        explanation: json['explanation'] as String,
        topicId: json['topicId'] as String,
      );
    }).toList();
  }

  // --- Bookmarked Public Notes Functions (v8) ---
  // ⬇️===== FUNCTION UPDATED (v8) - Poora content save karne ke liye =====⬇️
  Future<void> bookmarkNote(PublicNote note, NoteContent noteContent) async {
    final db = await instance.database;
    final row = {
      'noteId': note.id,
      'title': note.title,
      'content': noteContent.content, // ✅ Poora content save kiya
      'subjectId': note.subjectId,
      'subSubjectId': note.subSubjectId,
      'subSubjectName': note.subSubjectName,
      'timestamp': note.timestamp.toDate().toIso8601String(),
    };
    await db.insert('bookmarked_notes', row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  
  Future<void> unbookmarkNote(String noteId) async {
    final db = await instance.database;
    await db.delete('bookmarked_notes', where: 'noteId = ?', whereArgs: [noteId]);
  }
  
  // ⬇️===== FUNCTION UPDATED (v8) - Naya BookmarkedNote model return karega =====⬇️
  Future<List<BookmarkedNote>> getAllBookmarkedNotes() async {
    final db = await instance.database;
    final maps = await db.query('bookmarked_notes');
    
    // DB se data vaapas naye BookmarkedNote model mein badlo
    return maps.map((json) => BookmarkedNote.fromDbMap(json)).toList();
  }
  // ⬆️===================================================================⬆️


  // --- Bookmarked Schedules Functions ---
  Future<void> bookmarkSchedule(Schedule schedule) async {
    final db = await instance.database;
    final row = {
      'scheduleId': schedule.id,
      'title': schedule.title,
      'content': schedule.content,
      'subjectId': schedule.subjectId,
    };
    await db.insert('bookmarked_schedules', row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  Future<void> unbookmarkSchedule(String scheduleId) async {
    final db = await instance.database;
    await db.delete('bookmarked_schedules', where: 'scheduleId = ?', whereArgs: [scheduleId]);
  }
  Future<List<Schedule>> getAllBookmarkedSchedules() async {
    final db = await instance.database;
    final maps = await db.query('bookmarked_schedules');
    return maps.map((json) {
      return Schedule(
        id: json['scheduleId'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        subjectId: json['subjectId'] as String,
        timestamp: Timestamp.now(),
      );
    }).toList();
  }

  // --- Task (To-Do) Functions ---
  Future<Task> createTask(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    return Task(id: id, title: task.title, isDone: task.isDone, date: task.date);
  }
  Future<List<Task>> getTasksByDate(DateTime date) async {
    final db = await instance.database;
    final String dateString = DateFormat('yyyy-MM-dd').format(date);
    final result = await db.query('tasks', where: 'date = ?', whereArgs: [dateString], orderBy: 'id DESC');
    return result.map((json) => Task.fromMap(json)).toList();
  }
  Future<int> updateTaskStatus(int id, bool isDone) async {
    final db = await instance.database;
    return db.update('tasks', {'isDone': isDone ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }
  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
  
  // --- Timetable (Scheduler) Functions ---
  Future<TimetableEntry> createTimetableEntry(TimetableEntry entry) async {
    final db = await instance.database;
    final id = await db.insert('timetable_entries', entry.toMap());
    return TimetableEntry(
      id: id,
      subjectName: entry.subjectName,
      startTime: entry.startTime,
      endTime: entry.endTime,
      dayOfWeek: entry.dayOfWeek,
      notificationId: entry.notificationId,
    );
  }
  Future<List<TimetableEntry>> getAllTimetableEntries() async {
    final db = await instance.database;
    final result = await db.query('timetable_entries', orderBy: 'dayOfWeek ASC, startTime ASC');
    return result.map((json) => TimetableEntry.fromMap(json)).toList();
  }
  Future<int> deleteTimetableEntry(int id) async {
    final db = await instance.database;
    return await db.delete('timetable_entries', where: 'id = ?', whereArgs: [id]);
  }

  // --- User Note Edits Functions (v6) ---
  Future<int> saveUserEdit(UserNoteEdit edit) async {
    final db = await instance.database;
    return await db.insert(
      'user_note_edits',
      edit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  Future<UserNoteEdit?> getUserEdit(String firebaseNoteId) async {
    final db = await instance.database;
    final maps = await db.query(
      'user_note_edits',
      where: 'firebaseNoteId = ?',
      whereArgs: [firebaseNoteId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserNoteEdit.fromMap(maps.first);
    }
    return null;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
