import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  String id;
  String questionText;
  List<String> options; // ✅ Hum yahan List hi rakhenge, par data alag tarah se bharenge
  int correctIndex;     
  String explanation;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  // App se Database bhejne ke liye (Agar naya test bana rahe ho)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctIndex,
      'explanation': explanation,
    };
  }

  // 🔥 MAIN FIX: Database se Data Padhne ka Logic
  factory Question.fromMap(Map<String, dynamic> map) {
    List<String> parsedOptions = [];
    
    // CASE 1: Agar database me 'options' naam ki List pehle se hai (New Format)
    if (map['options'] != null && map['options'] is List) {
      parsedOptions = List<String>.from(map['options']);
    } 
    // CASE 2: Agar database me 'option0', 'option1' alag-alag hain (Old Format) 🔥
    else {
      int i = 0;
      // Jab tak option0, option1, option2... milte rahenge, loop chalta rahega
      while (map.containsKey('option$i')) {
        String optVal = map['option$i'].toString();
        // Null ya Empty check
        if (optVal.isNotEmpty && optVal != "null") {
          parsedOptions.add(optVal);
        }
        i++;
      }
    }

    return Question(
      id: map['id'] ?? '',
      
      // Question Text (Dono naam check karega)
      questionText: map['questionText'] ?? map['question'] ?? 'No Question', 
      
      options: parsedOptions, 
      
      // Correct Index (Dono naam check karega)
      correctIndex: map['correctAnswerIndex'] ?? map['correctIndex'] ?? 0,
      
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
      
      // Date handling
      scheduledAt: (map['scheduledAt'] ?? map['unlockTime'] ?? Timestamp.now()).toDate(),
      
      // Question List Parsing
      questions: map['questions'] != null
          ? List<Question>.from(
              (map['questions'] as List<dynamic>).map((x) => Question.fromMap(x)))
          : [],
          
      settings: map['settings'] ?? {}, 
    );
  }
}
