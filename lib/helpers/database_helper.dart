import 'dart:convert';
import 'package:flutter/material.dart'; // ⬇️ Naya import (TimeOfDay ke liye)
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

// ⬇️===== NAYI TIMETABLE CLASS =====⬇️
class TimetableEntry {
  final int? id;
  final String subjectName;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int dayOfWeek; // 1=Monday, 7=Sunday (DateTime.monday, etc.)
  final int notificationId; // Notification ko cancel karne ke liye zaroori

  TimetableEntry({
    this.id,
    required this.subjectName,
    required this.startTime,
    required this.endTime,
    required this.dayOfWeek,
    required this.notificationId,
  });

  // Helper function: TimeOfDay ko 'HH:mm' string mein badalna
  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  // Helper function: 'HH:mm' string ko TimeOfDay mein badalna
  static TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // Database mein save karne ke liye map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectName': subjectName,
      'startTime': _formatTime(startTime), // '09:00'
      'endTime': _formatTime(endTime), // '10:00'
      'dayOfWeek': dayOfWeek, // 1
      'notificationId': notificationId, // 12345
    };
  }

  // Database se vaapas laane ke liye map
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
// ⬆️==============================⬆️

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
      // ... (my_notes table code)
      await db.execute('''
        CREATE TABLE my_notes ( 
          id $idType, 
          content $textType,
          createdAt $textType
        )
      ''');
    }
    if (oldVersion < 2) {
      // ... (bookmarked_questions, bookmarked_notes tables code)
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
      // ... (bookmarked_schedules table code)
       await db.execute('''
        CREATE TABLE bookmarked_schedules (
          id $idType, scheduleId $uniqueTextType, title $textType,
          content $textType, subjectId $textType
        )
      ''');
    }
    if (oldVersion < 4) {
      // ... (tasks table code)
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
  Future<MyNote> create(MyNote note) async { /* ... */ }
  Future<List<MyNote>> readAllNotes() async { /* ... */ }
  Future<int> update(MyNote note) async { /* ... */ }
  Future<int> delete(int id) async { /* ... */ }
  // (Yahaan aapke note functions hain)
  
  // --- Bookmarked Questions Functions ---
  Future<void> bookmarkQuestion(Question question) async { /* ... */ }
  Future<void> unbookmarkQuestion(String questionText) async { /* ... */ }
  Future<bool> isQuestionBookmarked(String questionText) async { /* ... */ }
  Future<List<McqBookmark>> getAllMcqBookmarks() async { /* ... */ }
  Future<List<Question>> getAllBookmarkedQuestions() async { /* ... */ }
  // (Yahaan aapke question bookmark functions hain)

  // --- Bookmarked Public Notes Functions ---
  Future<void> bookmarkNote(PublicNote note) async { /* ... */ }
  Future<void> unbookmarkNote(String noteId) async { /* ... */ }
  Future<List<PublicNote>> getAllBookmarkedNotes() async { /* ... */ }
  // (Yahaan aapke note bookmark functions hain)

  // --- Bookmarked Schedules Functions ---
  Future<void> bookmarkSchedule(Schedule schedule) async { /* ... */ }
  Future<void> unbookmarkSchedule(String scheduleId) async { /* ... */ }
  Future<List<Schedule>> getAllBookmarkedSchedules() async { /* ... */ }
  // (Yahaan aapke schedule bookmark functions hain)

  // --- Task (To-Do) Functions ---
  Future<Task> createTask(Task task) async { /* ... */ }
  Future<List<Task>> getTasksByDate(DateTime date) async { /* ... */ }
  Future<int> updateTaskStatus(int id, bool isDone) async { /* ... */ }
  Future<int> deleteTask(int id) async { /* ... */ }
  // (Yahaan aapke task functions hain)

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
    // Pehle Din (1=Monday) se, phir Start Time se sort karo
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
