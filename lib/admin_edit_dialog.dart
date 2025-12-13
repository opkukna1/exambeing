import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exambeing/models/question_model.dart'; // Apka Question Model ka path sahi karein

class AdminEditDialog extends StatefulWidget {
  final Question question;
  final VoidCallback onUpdateSuccess; // Screen refresh karne ke liye callback

  const AdminEditDialog({
    super.key, 
    required this.question, 
    required this.onUpdateSuccess
  });

  @override
  State<AdminEditDialog> createState() => _AdminEditDialogState();
}

class _AdminEditDialogState extends State<AdminEditDialog> {
  // Controllers text edit karne ke liye
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
    // 1. Purana data controllers mein bharna
    _qController = TextEditingController(text: widget.question.questionText);
    
    // Explanation ya Solution check kar lena model mein kya naam hai
    _expController = TextEditingController(text: widget.question.explanation); 
    
    // Options ko safely handle karna
    var opts = widget.question.options;
    _optAController = TextEditingController(text: opts.isNotEmpty ? opts[0] : "");
    _optBController = TextEditingController(text: opts.length > 1 ? opts[1] : "");
    _optCController = TextEditingController(text: opts.length > 2 ? opts[2] : "");
    _optDController = TextEditingController(text: opts.length > 3 ? opts[3] : "");
    
    _correctIndex = widget.question.correctAnswerIndex;
  }

  // 🔥 UPDATE FUNCTION
  Future<void> _updateQuestion() async {
    setState(() => _isUpdating = true);

    try {
      // 2. Updated Data ka Map banana
      Map<String, dynamic> updatedData = {
        'question': _qController.text.trim(), // Field name DB jesa same hona chahiye
        'options': [
          _optAController.text.trim(),
          _optBController.text.trim(),
          _optCController.text.trim(),
          _optDController.text.trim(),
        ],
        'correctAnswerIndex': _correctIndex,
        'explanation': _expController.text.trim(), 
      };

      // 3. Firebase par update karna
      await FirebaseFirestore.instance
          .collection('questions')
          .doc(widget.question.id)
          .update(updatedData);

      if (!mounted) return;
      Navigator.pop(context); // Dialog band karo
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Question Updated Successfully!"), backgroundColor: Colors.green)
      );
      
      widget.onUpdateSuccess(); // Screen refresh trigger

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
            _buildTextField("Question Text", _qController, maxLines: 3),
            const SizedBox(height: 15),
            _buildTextField("Option A", _optAController),
            _buildTextField("Option B", _optBController),
            _buildTextField("Option C", _optCController),
            _buildTextField("Option D", _optDController),
            const SizedBox(height: 10),
            
            // Correct Answer Dropdown
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
