import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added for Timestamp

// ✅ Models Import
import 'package:exambeing/models/my_note_model.dart'; 
import 'package:exambeing/models/mcq_bookmark_model.dart';
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/models/public_note_model.dart';
import 'package:exambeing/models/schedule_model.dart';
import 'package:exambeing/models/bookmarked_note_model.dart';
import 'package:exambeing/models/note_content_model.dart';

// --- Helper Classes ---
class Task {
  final int? id;
  final String title;
  final bool isDone;
  final DateTime date;
  Task({this.id, required this.title, this.isDone = false, required this.date});
  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'isDone': isDone ? 1 : 0,
    'date': DateFormat('yyyy-MM-dd').format(date),
  };
  static Task fromMap(Map<String, dynamic> map) => Task(
    id: map['id'] as int, title: map['title'] as String,
    isDone: (map['isDone'] as int) == 1,
    date: DateTime.parse(map['date'] as String),
  );
}

class TimetableEntry {
  final int? id;
  final String subjectName;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int dayOfWeek;
  final int notificationId;
  TimetableEntry({this.id, required this.subjectName, required this.startTime, required this.endTime, required this.dayOfWeek, required this.notificationId});
  
  static String _formatTime(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  static TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
  
  Map<String, dynamic> toMap() => {
    'id': id, 'subjectName': subjectName, 'startTime': _formatTime(startTime),
    'endTime': _formatTime(endTime), 'dayOfWeek': dayOfWeek, 'notificationId': notificationId,
  };
  
  static TimetableEntry fromMap(Map<String, dynamic> map) => TimetableEntry(
    id: map['id'] as int,
    subjectName: map['subjectName'] as String,
    startTime: _parseTime(map['startTime'] as String),
    endTime: _parseTime(map['endTime'] as String),
    dayOfWeek: map['dayOfWeek'] as int,
    notificationId: map['notificationId'] as int,
  );
}

class UserNoteEdit {
  final int? id;
  final String firebaseNoteId;
  final String? userContent;
  final String? userHighlightsJson;
  UserNoteEdit({this.id, required this.firebaseNoteId, this.userContent, this.userHighlightsJson});
  
  factory UserNoteEdit.create({required String firebaseNoteId, String? userContent, List<String>? highlights}) {
    return UserNoteEdit(firebaseNoteId: firebaseNoteId, userContent: userContent, userHighlightsJson: highlights != null ? jsonEncode(highlights) : null);
  }
  
  Map<String, dynamic> toMap() => {
    'id': id, 'firebaseNoteId': firebaseNoteId,
    'userContent': userContent, 'userHighlightsJson': userHighlightsJson,
  };
  
  static UserNoteEdit fromMap(Map<String, dynamic> map) => UserNoteEdit(
    id: map['id'] as int?, firebaseNoteId: map['firebaseNoteId'] as String,
    userContent: map['userContent'] as String?,
    userHighlightsJson: map['userHighlightsJson'] as String?,
  );
}

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
    return await openDatabase(path, version: 11, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async => await _upgradeDB(db, 0, version);

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 11) await db.execute('DROP TABLE IF EXISTS my_notes');
    
    await db.execute('''CREATE TABLE IF NOT EXISTS my_notes (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, content TEXT NOT NULL, createdAt TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS bookmarked_questions (id INTEGER PRIMARY KEY AUTOINCREMENT, questionText TEXT NOT NULL UNIQUE, options TEXT NOT NULL, correctAnswerIndex INTEGER NOT NULL, explanation TEXT NOT NULL, topicId TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS bookmarked_notes (id INTEGER PRIMARY KEY AUTOINCREMENT, noteId TEXT NOT NULL UNIQUE, title TEXT NOT NULL, content TEXT NOT NULL, subjectId TEXT NOT NULL, subSubjectId TEXT NOT NULL, subSubjectName TEXT NOT NULL, timestamp TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS bookmarked_schedules (id INTEGER PRIMARY KEY AUTOINCREMENT, scheduleId TEXT NOT NULL UNIQUE, title TEXT NOT NULL, content TEXT NOT NULL, subjectId TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, isDone INTEGER NOT NULL, date TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS timetable_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, subjectName TEXT NOT NULL, startTime TEXT NOT NULL, endTime TEXT NOT NULL, dayOfWeek INTEGER NOT NULL, notificationId INTEGER UNIQUE)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS user_note_edits (id INTEGER PRIMARY KEY AUTOINCREMENT, firebaseNoteId TEXT NOT NULL UNIQUE, userContent TEXT, userHighlightsJson TEXT)''');
  }

  // --- My Notes ---
  Future<MyNote> create(MyNote note) async {
    final db = await instance.database;
    final id = await db.insert('my_notes', note.toMap());
    return note.copy(id: id);
  }
  Future<List<MyNote>> readAllNotes() async {
    final db = await instance.database;
    final result = await db.query('my_notes', orderBy: 'id DESC');
    return result.map((json) => MyNote.fromJson(json)).toList();
  }
  Future<MyNote> readNote(int id) async {
    final db = await instance.database;
    final maps = await db.query('my_notes', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return MyNote.fromJson(maps.first);
    throw Exception('ID $id not found');
  }
  Future<int> update(MyNote note) async {
    final db = await instance.database;
    return db.update('my_notes', note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }
  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('my_notes', where: 'id = ?', whereArgs: [id]);
  }

  // --- Bookmarks (Fixed Casting Errors) ---
  Future<void> bookmarkQuestion(Question question) async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM bookmarked_questions'));
    if (count != null && count >= 100) throw Exception('Max 100 questions.');
    await db.insert('bookmarked_questions', {
      'questionText': question.questionText,
      'options': jsonEncode(question.options),
      'correctAnswerIndex': question.correctAnswerIndex,
      'explanation': question.explanation,
      'topicId': question.topicId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
  Future<List<Question>> getAllBookmarkedQuestions() async {
    final db = await instance.database;
    final maps = await db.query('bookmarked_questions');
    // ✅ FIX: Explicit Casting
    return maps.map((json) => Question(
      id: json['id'].toString(),
      questionText: json['questionText'] as String,
      options: List<String>.from(jsonDecode(json['options'] as String)),
      correctAnswerIndex: json['correctAnswerIndex'] as int,
      explanation: json['explanation'] as String,
      topicId: json['topicId'] as String,
    )).toList();
  }
  Future<List<McqBookmark>> getAllMcqBookmarks() async {
    final db = await instance.database;
    final maps = await db.query('bookmarked_questions');
    // ✅ FIX: Explicit Casting
    return maps.map((json) {
      final options = List<String>.from(jsonDecode(json['options'] as String));
      final correctIndex = json['correctAnswerIndex'] as int;
      return McqBookmark(
        id: json['id'] as int,
        questionText: json['questionText'] as String,
        options: options,
        correctOption: options[correctIndex],
        explanation: json['explanation'] as String,
        topic: json['topicId'] as String,
        subject: 'Placeholder',
      );
    }).toList();
  }

  // --- Bookmarked Notes ---
  Future<void> bookmarkNote(PublicNote note, NoteContent noteContent) async {
    final db = await instance.database;
    await db.insert('bookmarked_notes', {
      'noteId': note.id, 'title': note.title, 'content': noteContent.content,
      'subjectId': note.subjectId, 'subSubjectId': note.subSubjectId,
      'subSubjectName': note.subSubjectName, 
      'timestamp': note.timestamp.toDate().toIso8601String(), // ✅ Fixed Timestamp usage
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  Future<void> unbookmarkNote(String noteId) async {
    final db = await instance.database;
    await db.delete('bookmarked_notes', where: 'noteId = ?', whereArgs: [noteId]);
  }
  Future<List<BookmarkedNote>> getAllBookmarkedNotes() async {
    final db = await instance.database;
    final maps = await db.query('bookmarked_notes');
    return maps.map((json) => BookmarkedNote.fromDbMap(json)).toList();
  }

  // --- Schedules ---
  Future<void> bookmarkSchedule(Schedule schedule) async {
    final db = await instance.database;
    await db.insert('bookmarked_schedules', {
      'scheduleId': schedule.id, 'title': schedule.title, 'content': schedule.content, 'subjectId': schedule.subjectId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  Future<void> unbookmarkSchedule(String scheduleId) async {
    final db = await instance.database;
    await db.delete('bookmarked_schedules', where: 'scheduleId = ?', whereArgs: [scheduleId]);
  }
  // ✅ FIX: Explicit Casting
  Future<List<Schedule>> getAllBookmarkedSchedules() async {
    final db = await instance.database;
    final maps = await db.query('bookmarked_schedules');
    return maps.map((json) => Schedule(
      id: json['scheduleId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      subjectId: json['subjectId'] as String,
      timestamp: Timestamp.now(), // Placeholder timestamp for display
    )).toList();
  }

  // --- Tasks ---
  Future<Task> createTask(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    return Task(id: id, title: task.title, isDone: task.isDone, date: task.date);
  }
  Future<List<Task>> getTasksByDate(DateTime date) async {
    final db = await instance.database;
    final result = await db.query('tasks', where: 'date = ?', whereArgs: [DateFormat('yyyy-MM-dd').format(date)], orderBy: 'id DESC');
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

  // --- Timetable ---
  Future<TimetableEntry> createTimetableEntry(TimetableEntry entry) async {
    final db = await instance.database;
    final id = await db.insert('timetable_entries', entry.toMap());
    return TimetableEntry(id: id, subjectName: entry.subjectName, startTime: entry.startTime, endTime: entry.endTime, dayOfWeek: entry.dayOfWeek, notificationId: entry.notificationId);
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

  // --- User Edits ---
  Future<int> saveUserEdit(UserNoteEdit edit) async {
    final db = await instance.database;
    return await db.insert('user_note_edits', edit.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<UserNoteEdit?> getUserEdit(String firebaseNoteId) async {
    final db = await instance.database;
    final maps = await db.query('user_note_edits', where: 'firebaseNoteId = ?', whereArgs: [firebaseNoteId], limit: 1);
    if (maps.isNotEmpty) return UserNoteEdit.fromMap(maps.first);
    return null;
  }
}
