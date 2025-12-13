import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambeing/models/question_model.dart'; 

class AdminEditDialog extends StatefulWidget {
  final Question question;
  // Callback: Jab update ho jaye to naya data wapas bhejne ke liye
  final Function(String q, List<String> opts, int ans, String exp) onUpdateSuccess;

  const AdminEditDialog({
    super.key, 
    required this.question, 
    required this.onUpdateSuccess
  });

  @override
  State<AdminEditDialog> createState() => _AdminEditDialogState();
}

class _AdminEditDialogState extends State<AdminEditDialog> {
  late TextEditingController _qController;
  late TextEditingController _optAController;
  late TextEditingController _optBController;
  late TextEditingController _optCController;
  late TextEditingController _optDController;
  late TextEditingController _expController;
  
  int _correctIndex = 0;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    // ✅ Data Initialize
    _qController = TextEditingController(text: widget.question.questionText);
    _expController = TextEditingController(text: widget.question.explanation); 
    
    var opts = widget.question.options;
    _optAController = TextEditingController(text: opts.isNotEmpty ? opts[0] : "");
    _optBController = TextEditingController(text: opts.length > 1 ? opts[1] : "");
    _optCController = TextEditingController(text: opts.length > 2 ? opts[2] : "");
    _optDController = TextEditingController(text: opts.length > 3 ? opts[3] : "");
    
    _correctIndex = widget.question.correctAnswerIndex;
  }

  Future<void> _updateQuestion() async {
    setState(() => _isUpdating = true);

    try {
      final newQuestionText = _qController.text.trim();
      final newExplanation = _expController.text.trim();
      
      final newOptions = [
          _optAController.text.trim(),
          _optBController.text.trim(),
          _optCController.text.trim(),
          _optDController.text.trim(),
      ];

      // 🔥 Database Update
      Map<String, dynamic> updatedData = {
        'questionText': newQuestionText,      
        'options': newOptions,                
        'correctAnswerIndex': _correctIndex,  
        'explanation': newExplanation,        
      };

      await FirebaseFirestore.instance
          .collection('questions')
          .doc(widget.question.id)
          .update(updatedData);

      if (!mounted) return;
      Navigator.pop(context); 
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Question Updated Successfully!"), backgroundColor: Colors.green)
      );
      
      // Pass data back
      widget.onUpdateSuccess(newQuestionText, newOptions, _correctIndex, newExplanation);

    } catch (e) {
      setState(() => _isUpdating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Edit Question ✏️", style: TextStyle(color: Colors.deepPurple)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField("Question Text", _qController, maxLines: 4),
            const SizedBox(height: 15),
            
            _buildTextField("Option A", _optAController),
            _buildTextField("Option B", _optBController),
            _buildTextField("Option C", _optCController),
            _buildTextField("Option D", _optDController),
            const SizedBox(height: 10),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _correctIndex,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text("Correct Answer: A")),
                    DropdownMenuItem(value: 1, child: Text("Correct Answer: B")),
                    DropdownMenuItem(value: 2, child: Text("Correct Answer: C")),
                    DropdownMenuItem(value: 3, child: Text("Correct Answer: D")),
                  ],
                  onChanged: (val) => setState(() => _correctIndex = val!),
                ),
              ),
            ),
            
            const SizedBox(height: 15),
            _buildTextField("Explanation", _expController, maxLines: 4),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateQuestion,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
          child: _isUpdating 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text("UPDATE NOW"),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
