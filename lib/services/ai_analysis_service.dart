import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AiAnalysisService {
  
  // 1. Quota Logic (Unlimited for local)
  Future<bool> _checkAndIncrementQuota() async {
    return true; 
  }

  // 2. FETCH DATA & ANALYZE LOCALLY
  Future<String> getAnalysis() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return "Error: User not logged in.";

      // Name Format (Ram Kumar -> Ram)
      String userName = user.displayName?.split(' ')[0] ?? "Aspirant";

      // A. Fetch Last 25 Tests
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('test_results')
          .orderBy('timestamp', descending: true)
          .limit(25) 
          .get();

      if (query.docs.isEmpty) return "NO_DATA";

      // B. VARIABLES FOR LOGIC
      Map<String, int> topicCorrect = {};
      Map<String, int> topicTotal = {};
      int totalCorrect = 0;
      int totalQuestions = 0;

      // C. Process Data (Deep Calculation)
      for (var doc in query.docs) {
        final data = doc.data();
        String topic = data['topicName'] ?? "General";
        
        List<dynamic> logs = data['logs'] ?? [];

        if (logs.isNotEmpty) {
          // New Data (Logs Array)
          for (var log in logs) {
            bool isCorrect = log['s'] ?? false;
            
            topicTotal[topic] = (topicTotal[topic] ?? 0) + 1;
            if (isCorrect) {
              topicCorrect[topic] = (topicCorrect[topic] ?? 0) + 1;
              totalCorrect++;
            }
            totalQuestions++;
          }
        } else {
          // Old Data (Fallback)
          int score = data['score'] ?? 0;
          int total = data['totalQuestions'] ?? 0;
          
          topicTotal[topic] = (topicTotal[topic] ?? 0) + total;
          topicCorrect[topic] = (topicCorrect[topic] ?? 0) + score;
          totalCorrect += score;
          totalQuestions += total;
        }
      }

      if (totalQuestions == 0) return "NO_DATA";

      // D. Find Weak & Strong Topics
      String strongTopic = "None";
      String weakTopic = "None";
      double highestPercent = -1;
      double lowestPercent = 101;

      topicTotal.forEach((topic, total) {
        if (total >= 5) { // Kam se kam 5 sawal attempt kiye ho tabhi judge karenge
          int correct = topicCorrect[topic] ?? 0;
          double percent = (correct / total) * 100;

          if (percent > highestPercent) {
            highestPercent = percent;
            strongTopic = topic;
          }
          if (percent < lowestPercent) {
            lowestPercent = percent;
            weakTopic = topic;
          }
        }
      });

      double overallPercentage = (totalCorrect / totalQuestions) * 100;

      // E. GENERATE SMART RESPONSE
      return _generatePersonalizedMessage(
        name: userName,
        percentage: overallPercentage,
        strong: strongTopic,
        weak: weakTopic,
        totalQ: totalQuestions,
      );

    } catch (e) {
      return "Error generating analysis: $e";
    }
  }

  // 3. THE BRAIN 🧠 (6 Smart Levels)
  String _generatePersonalizedMessage({
    required String name,
    required double percentage,
    required String strong,
    required String weak,
    required int totalQ,
  }) {
    
    // LEVEL 1: Danger Zone (0% - 35%) 🔴
    if (percentage < 35) {
      return """
### 🛑 Needs Immediate Attention, $name!
Your accuracy is currently low (${percentage.toStringAsFixed(1)}%). It seems you are rushing through tests without clearing concepts.

### 📊 Summary
- **Questions Analyzed:** $totalQ
- **Weakest Area:** **$weak** (Accuracy is critical here)

### 💡 Smart Strategy (Don't Worry!)
1. **Stop guessing!** Negative marking will hurt you in real exams.
2. Go to the **'Quick Notes'** section right now.
3. Read the theory for **$weak** specifically.
4. Come back and attempt a small topic-wise test. You will definitely score better!
""";
    }

    // LEVEL 2: Struggling (35% - 50%) 🟠
    else if (percentage < 50) {
      return """
### ⚠️ Focus on Basics, $name
You are attempting questions, but many are going wrong. You need to bridge the gap between "Learning" and "Testing".

### 📊 Summary
- **Overall Score:** ${percentage.toStringAsFixed(1)}%
- **Struggling Topic:** **$weak**

### 🟢 Good News
- You have started building momentum in **$strong**. Keep it up!

### 🚀 Action Plan
- Before your next test, spend 15 minutes in **Quick Notes**.
- Revise the key formulas/dates for **$weak**.
- Then attempt the test. Your confidence will skyrocket! 🚀
""";
    }

    // LEVEL 3: Average / Inconsistent (50% - 65%) 🟡
    else if (percentage < 65) {
      return """
### 📈 You are Improving, $name!
You have crossed the passing mark, but consistency is missing. Some topics are good, some need polish.

### 📊 Summary
- **Current Score:** ${percentage.toStringAsFixed(1)}% (Average)
- **Strong Hold:** $strong

### 🔍 Analysis
- The topic **$weak** is pulling your average down.
- It seems you get confused in tricky options.

### 💡 Expert Tip
- Don't just give tests blindly.
- Open **Quick Notes** > Read **$weak** Summary > Then retake the test.
- Accuracy > Speed right now.
""";
    }

    // LEVEL 4: Good Performance (65% - 80%) 🟢
    else if (percentage < 80) {
      return """
### 👏 Great Going, $name!
You are performing well! You have a good grasp of most topics. Now we aim for excellence.

### 📊 Summary
- **Overall Score:** ${percentage.toStringAsFixed(1)}% (Good)
- **Questions Attempted:** $totalQ

### 🌟 Star Performer
- Your performance in **$strong** is solid.

### 🎯 Next Goal
- To cross 85%, you need to fix **$weak**.
- A quick revision from **Notes** will turn this weak topic into a strong one.
- Keep practicing, you are on the right track!
""";
    }

    // LEVEL 5: Excellent (80% - 90%) 🟣
    else if (percentage < 90) {
      return """
### 🏆 Outstanding, $name!
You are in the top tier of students! Your consistency is impressive.

### 📊 Summary
- **Score:** ${percentage.toStringAsFixed(1)}% (Excellent)
- **Mastery:** You are dominating in **$strong**.

### 🚀 Final Polish
- Even at this level, **$weak** has slight scope for improvement.
- Just a 5-minute glance at **Quick Notes** for $weak will make you unstoppable.
- Try increasing your speed now.
""";
    }

    // LEVEL 6: Topper Level (90%+) 🔥
    else {
      return """
### 👑 Unstoppable! Take a Bow, $name!
Your performance is phenomenal. You are exam-ready!

### 📊 Summary
- **Score:** ${percentage.toStringAsFixed(1)}% (Legendary)
- **Accuracy:** Pin-point perfect.

### 💡 Challenge for You
- Since you have mastered **$strong** and **$weak**, try "Full Length Mock Tests".
- Focus on time management now.
- Teach concepts to others or revise **Quick Notes** just to stay sharp.
""";
    }
  }
}
