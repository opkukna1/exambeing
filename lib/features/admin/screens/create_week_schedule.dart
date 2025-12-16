import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CreateWeekSchedule extends StatefulWidget {
  final String examId; // Exam ID pass hogi (e.g. RAS 2025 ki ID)
  const CreateWeekSchedule({super.key, required this.examId});

  @override
  State<CreateWeekSchedule> createState() => _CreateWeekScheduleState();
}

class _CreateWeekScheduleState extends State<CreateWeekSchedule> {
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  
  // Selection Logic
  String? selectedSubject;
  List<String> selectedTopics = []; // Yahan topics save honge
  bool _isLoading = false;

  Future<void> _saveWeek() async {
    if (_titleController.text.isEmpty || selectedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title aur kam se kam 1 Topic select karein")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.examId)
          .collection('weeks')
          .add({
        'weekTitle': _titleController.text.trim(),
        'unlockTime': Timestamp.fromDate(_selectedDate),
        'linkedTopics': selectedTopics, // ✅ MAIN: Topics ki list save ho rahi hai
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context); // Save hone ke bad wapis jao
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Week Schedule")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Title Input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Week Title (Ex: Ancient History)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),

            // 2. Date Picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Unlock Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}"),
              trailing: const Icon(Icons.calendar_today, color: Colors.deepPurple),
              onTap: () async {
                DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            const Divider(thickness: 2),
            
            // 3. Subject Selector (Dropdown)
            const Text("Select Topics for this Week", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('NoteSubjects').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                
                // Dropdown Items
                var subjects = snapshot.data!.docs.map((d) => d['name'].toString()).toList();
                
                return DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text("Select Subject First"),
                  value: selectedSubject,
                  items: subjects.map((sub) => DropdownMenuItem(value: sub, child: Text(sub))).toList(),
                  onChanged: (val) {
                    setState(() { selectedSubject = val; }); // Topic list refresh hogi
                  },
                );
              },
            ),

            // 4. Topics List (Checkboxes)
            Expanded(
              child: selectedSubject == null 
                  ? const Center(child: Text("Subject select karein topics dekhne ke liye"))
                  : StreamBuilder<QuerySnapshot>(
                      // Sirf us subject ke topics lao
                      stream: FirebaseFirestore.instance.collection('topics').where('subjectName', isEqualTo: selectedSubject).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        var topicsDocs = snapshot.data!.docs;

                        if (topicsDocs.isEmpty) return const Center(child: Text("No topics found in this subject"));

                        return ListView.builder(
                          itemCount: topicsDocs.length,
                          itemBuilder: (context, index) {
                            String topicName = topicsDocs[index]['name'];
                            bool isSelected = selectedTopics.contains(topicName);

                            return CheckboxListTile(
                              title: Text(topicName),
                              value: isSelected,
                              activeColor: Colors.deepPurple,
                              onChanged: (bool? val) {
                                setState(() {
                                  if (val == true) {
                                    selectedTopics.add(topicName);
                                  } else {
                                    selectedTopics.remove(topicName);
                                  }
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
            ),

            // 5. Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveWeek,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE SCHEDULE"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
