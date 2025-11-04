import 'dart:convert';
import 'package:flutter/material.dart'; // TimeOfDay ke liye
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambeing/models/mcq_bookmark_model.dart';
import 'package:exambeing/models/question_model.dart';
import 'package:exambeing/models/public_note_model.dart';
import 'package:exambeing/models/schedule_model.dart';
import 'package:intl/intl.dart';

// --- Note Model ---
class MyNote {
  final int? id;
  final String content;
  final String createdAt;

  MyNote({this.id, required this.content, required this.createdAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'createdAt': createdAt,
    };
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
  final int dayOfWeek; // 1=Monday, 7=Sunday
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
    // ⬇️===== VERSION 4 se 5 KIYA GAYA =====⬇️
    return await openDatabase(path, version: 5, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    await _upgradeDB(db, 0, version);
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const uniqueTextType = 'TEXT NOT NULL UNIQUE';
    const integerType = 'INTEGER NOT NULL';

    if (oldVersion < 1) {
      await db.execute('''
        CREATE TABLE my_notes ( 
          id $idType, 
          content $textType,
          createdAt $textType
        )
      ''');
    }
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE bookmarked_questions (
          id $idType, questionText $uniqueTextType, options $textType,
          correctAnswerIndex $integerType, explanation $textType, topicId $textType
        )
      ''');
      await db.execute('''
        CREATE TABLE bookmarked_notes (
          id $idType, noteId $uniqueTextType, title $textType,
          content $textType, subjectId $textType
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE bookmarked_schedules (
          id $idType, scheduleId $uniqueTextType, title $textType,
          content $textType, subjectId $textType
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE tasks (
          id $idType, title $textType, isDone $integerType, date $textType
        )
      ''');
    }
    // ⬇️===== NAYA TIMETABLE TABLE (v5) =====⬇️
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE timetable_entries (
          id $idType,
          subjectName $textType,
          startTime $textType,
          endTime $textType,
          dayOfWeek $integerType,
          notificationId $integerType UNIQUE
        )
      ''');
    }
    // ⬆️====================================⬆️
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
    return db.update(
      'my_notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'my_notes',
      where: 'id = ?',
      whereArgs: [id],
    );
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

  // --- Bookmarked Public Notes Functions ---
  Future<void> bookmarkNote(PublicNote note) async {
    final db = await instance.database;
    final row = {
      'noteId': note.id,
      'title': note.title,
      'content': note.content,
      'subjectId': note.subjectId,
    };
    await db.insert('bookmarked_notes', row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  
  Future<void> unbookmarkNote(String noteId) async {
    final db = await instance.database;
    await db.delete('bookmarked_notes', where: 'noteId = ?', whereArgs: [noteId]);
  }
  
  Future<List<PublicNote>> getAllBookmarkedNotes() async {
    final db = await instance.database;
    final maps = await db.query('bookmarked_notes');
    
    return maps.map((json) {
      return PublicNote(
        id: json['noteId'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        subjectId: json['subjectId'] as String,
      );
    }).toList();
  }

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
    return Task(
      id: id,
      title: task.title,
      isDone: task.isDone,
      date: task.date,
    );
  }

  Future<List<Task>> getTasksByDate(DateTime date) async {
    final db = await instance.database;
    final String dateString = DateFormat('yyyy-MM-dd').format(date);
    
    final result = await db.query(
      'tasks',
      where: 'date = ?',
      whereArgs: [dateString],
      orderBy: 'id DESC',
    );

    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> updateTaskStatus(int id, bool isDone) async {
    final db = await instance.database;
    return db.update(
      'tasks',
      {'isDone': isDone ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // ⬇️===== NAYE TIMETABLE (SCHEDULER) FUNCTIONS =====⬇️

  // Nayi timetable entry banana
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

  // Saari timetable entries padhna (Din ke hisaab se sort karke)
  Future<List<TimetableEntry>> getAllTimetableEntries() async {
    final db = await instance.database;
    final result = await db.query('timetable_entries', orderBy: 'dayOfWeek ASC, startTime ASC');
    return result.map((json) => TimetableEntry.fromMap(json)).toList();
  }

  // Timetable entry ko delete karna (ID se)
  Future<int> deleteTimetableEntry(int id) async {
    final db = await instance.database;
    return await db.delete(
      'timetable_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  // ⬆️================================================⬆️

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
