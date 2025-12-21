import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  String id;
  String questionText;
  List<String> options; 
  int correctIndex;     
  String explanation;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctIndex,
      'explanation': explanation,
    };
  }

  // 🔥 YAHAN THI DIKKAT - AB FIX HAI
  factory Question.fromMap(Map<String, dynamic> map) {
    List<String> parsedOptions = [];
    
    // Case 1: Agar pehle se List hai
    if (map['options'] != null && map['options'] is List) {
      parsedOptions = List<String>.from(map['options']);
    } 
    // Case 2: Agar option0, option1, option2... alag hain (Aapka Case)
    else {
      int i = 0;
      while (map.containsKey('option$i')) {
        String optVal = map['option$i'].toString();
        if (optVal.isNotEmpty && optVal != "null") {
          parsedOptions.add(optVal);
        }
        i++;
      }
    }

    // Safety check for Index
    int parseIndex(dynamic val) {
      if (val is int) return val;
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    return Question(
      id: map['id'] ?? '',
      questionText: map['questionText'] ?? map['question'] ?? 'No Question',
      options: parsedOptions, // ✅ Ab ye list kabhi khali nahi hogi
      correctIndex: parseIndex(map['correctAnswerIndex'] ?? map['correctIndex']),
      explanation: map['explanation'] ?? map['solution'] ?? '',
    );
  }
}

class TestModel {
  String id;
  String subject; 
  DateTime scheduledAt;
  List<Question> questions;
  Map<String, dynamic> settings; 

  TestModel({
    required this.id,
    required this.subject,
    required this.scheduledAt,
    required this.questions,
    required this.settings,
  });

  Map<String, dynamic> toMap() {
    return {
      'testTitle': subject,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'questions': questions.map((x) => x.toMap()).toList(),
      'settings': settings,
    };
  }

  factory TestModel.fromMap(Map<String, dynamic> map, String docId) {
    return TestModel(
      id: docId,
      subject: map['testTitle'] ?? map['subject'] ?? 'Untitled Test',
      scheduledAt: (map['scheduledAt'] ?? map['unlockTime'] ?? Timestamp.now()).toDate(),
      questions: map['questions'] != null
          ? List<Question>.from(
              (map['questions'] as List<dynamic>).map((x) => Question.fromMap(x)))
          : [],
      settings: map['settings'] ?? {}, 
    );
  }
}
