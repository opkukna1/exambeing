import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/public_note_model.dart';
import '../models/schedule_model.dart';
import '../models/test_series_model.dart';
import '../models/subject_model.dart';
import '../models/topic_model.dart';
import '../models/question_model.dart';
import '../models/offer_model.dart';

class FirebaseDataService {
  
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  //=========== PUBLIC NOTES FETCH LOGIC ===========
  Future<List<PublicNote>> getPublicNotes({String? subjectId}) async {
    try {
      Query query = _db.collection("publicNotes");

      if (subjectId != null && subjectId.isNotEmpty) {
        query = query.where("subjectId", isEqualTo: subjectId);
      }
      
      query = query.orderBy("timestamp", descending: true).limit(20);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) => PublicNote.fromFirestore(doc)).toList();
      
    } catch (e) {
      print("Error fetching public notes: $e");
      throw Exception("Failed to load public notes");
    }
  }

  //=========== SCHEDULES FETCH LOGIC (UPDATED FOR FILTER) ===========
  Future<List<Schedule>> getSchedules({String? subjectId}) async {
    try {
      Query query = _db.collection("schedules");

      // If a subjectId is provided, filter the schedules
      if (subjectId != null && subjectId.isNotEmpty) {
        query = query.where("subjectId", isEqualTo: subjectId);
      }
      
      query = query.orderBy("timestamp", descending: true).limit(10);
          
      QuerySnapshot snapshot = await query.get();

      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) => Schedule.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching schedules: $e");
      throw Exception("Failed to load schedules");
    }
  }

  //=========== TEST SERIES FETCH LOGIC ===========
  Future<List<TestSeries>> getTestSeries() async {
    try {
      QuerySnapshot snapshot = await _db.collection("testSeries").get();
      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) => TestSeries.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching test series: $e");
      throw Exception("Failed to load test series");
    }
  }

  //=========== SUBJECTS FETCH LOGIC (FILTERED BY SERIES) ===========
  Future<List<Subject>> getSubjects(String seriesId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection("subjects")
          .where("testSeriesId", isEqualTo: seriesId)
          .get();
      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching subjects for seriesId $seriesId: $e");
      throw Exception("Failed to load subjects");
    }
  }
  
  //=========== ALL SUBJECTS FETCH LOGIC (FOR FILTER) ===========
  Future<List<Subject>> getAllSubjects() async {
    try {
      QuerySnapshot snapshot = await _db.collection("subjects").get();
      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching all subjects: $e");
      throw Exception("Failed to load subjects for filter");
    }
  }

  //=========== OFFERS FETCH LOGIC ===========
  Future<List<Offer>> getOffers() async {
    try {
      QuerySnapshot snapshot = await _db.collection("offers").get();
      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) => Offer.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching offers: $e");
      throw Exception("Failed to load offers");
    }
  }

  //=========== DAILY QUIZ FETCH LOGIC ===========
  Future<Map<String, dynamic>?> getDailyQuizTopic() async {
    try {
      final now = DateTime.now();
      final String todayDocId = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final docSnapshot = await _db.collection("dailyQuizzes").doc(todayDocId).get();

      if (docSnapshot.exists) {
        return docSnapshot.data();
      } else {
        return null;
      }
    } catch (e) {
      print("Error fetching daily quiz: $e");
      throw Exception("Failed to load daily quiz");
    }
  }

  //=========== TOPICS FETCH LOGIC ===========
  Future<List<Topic>> getTopics(String subjectId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection("topics")
          .where("subjectId", isEqualTo: subjectId)
          .get();
          
      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) => Topic.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching topics for subjectId $subjectId: $e");
      throw Exception("Failed to load topics");
    }
  }

  //=========== QUESTIONS FETCH LOGIC ===========
  Future<List<Question>> getQuestions(String topicId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection("questions")
          .where("topicId", isEqualTo: topicId)
          .get();
          
      if (snapshot.docs.isEmpty) return [];
      return snapshot.docs.map((doc) => Question.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching questions for topicId $topicId: $e");
      throw Exception("Failed to load questions");
    }
  }
}
