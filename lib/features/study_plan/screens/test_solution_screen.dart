import 'package:flutter/material.dart';

class TestSolutionScreen extends StatelessWidget {
  final List<dynamic> questions;
  final Map<String, dynamic> userAnswers;
  final String testTitle;

  const TestSolutionScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
    required this.testTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Solutions & Analysis 🧐"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          var q = questions[index];
          // Use ID if available, else fallback to question text for mapping
          String qKey = q['id'] ?? q['question']; 
          
          // User answer might be stored with String keys in Firestore Map
          int? userSelectedOpt = userAnswers[qKey];
          int correctOpt = q['correctIndex'];

          // Determine Status
          bool isSkipped = userSelectedOpt == null;
          bool isCorrect = userSelectedOpt == correctOpt;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            // ✅ FIX: 'shape' sirf ek baar define kiya hai ab
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSkipped ? Colors.orange 
                     : isCorrect ? Colors.green 
                     : Colors.red,
                width: 1.5
              )
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Number & Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Q.${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSkipped ? Colors.orange.shade50 : isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4)
                        ),
                        child: Text(
                          isSkipped ? "SKIPPED" : isCorrect ? "CORRECT" : "WRONG",
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold,
                            color: isSkipped ? Colors.orange : isCorrect ? Colors.green : Colors.red
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // Question Text
                  Text(
                    q['question'], 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 15),

                  // Options List
                  ...List.generate(q['options'].length, (optIndex) {
                    String optionText = q['options'][optIndex];
                    
                    // Styling Logic
                    Color bgColor = Colors.white;
                    Color textColor = Colors.black;
                    IconData? icon;

                    if (optIndex == correctOpt) {
                      // ✅ Always highlight correct answer Green
                      bgColor = Colors.green.shade100;
                      textColor = Colors.green.shade900;
                      icon = Icons.check_circle;
                    } else if (optIndex == userSelectedOpt) {
                      // ❌ Highlight wrong selection Red
                      bgColor = Colors.red.shade100;
                      textColor = Colors.red.shade900;
                      icon = Icons.cancel;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200)
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${String.fromCharCode(65 + optIndex)}. $optionText",
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                            ),
                          ),
                          if (icon != null) Icon(icon, size: 18, color: textColor)
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
