import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CreateWeekSchedule extends StatefulWidget {
  final String examId;
  const CreateWeekSchedule({super.key, required this.examId});

  @override
  State<CreateWeekSchedule> createState() => _CreateWeekScheduleState();
}

class _CreateWeekScheduleState extends State<CreateWeekSchedule> {
  // --- Controllers for Basic Info ---
  final _weekTitleController = TextEditingController();
  DateTime? _examDate;

  // --- Data Variables for Hierarchy ---
  List<dynamic> fullHierarchy = [];
  bool isLoading = true;

  // --- Selections (Stores Full Object from Firebase) ---
  Map<String, dynamic>? selectedSubject;
  Map<String, dynamic>? selectedSubSubject;
  Map<String, dynamic>? selectedTopic;
  Map<String, dynamic>? selectedSubTopic;

  // --- List to store added topics locally ---
  final List<Map<String, dynamic>> _addedTopics = [];

  @override
  void initState() {
    super.initState();
    _fetchHierarchy();
  }

  // 1️⃣ Fetch Hierarchy from Firebase (Same as NotesSelectionScreen)
  Future<void> _fetchHierarchy() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('app_metadata')
          .doc('notes_index')
          .get();

      if (doc.exists) {
        setState(() {
          fullHierarchy = doc['hierarchy'] as List<dynamic>;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching hierarchy: $e");
      setState(() => isLoading = false);
    }
  }

  // --- Helper Getters for Dropdown Lists ---
  List<dynamic> getSubSubjects() => selectedSubject?['subSubjects'] ?? [];
  List<dynamic> getTopics() => selectedSubSubject?['topics'] ?? [];
  List<dynamic> getSubTopics() => selectedTopic?['subTopics'] ?? [];

  // 2️⃣ Date Picker
  void _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) {
        setState(() {
          _examDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  // 3️⃣ Add Selected Topic to List
  void _addTopicToList() {
    if (selectedSubTopic != null) {
      setState(() {
        _addedTopics.add({
          // Hum names store kar rahe hain taaki user ko dikha sakein
          'subject': selectedSubject!['name'],
          'subSubject': selectedSubSubject!['name'],
          'topic': selectedTopic!['name'],
          'subTopic': selectedSubTopic!['name'],
          
          // IDs bhi store kar rahe hain (Future safety ke liye)
          'subjId': selectedSubject!['id'],
          'subSubjId': selectedSubSubject!['id'],
          'topicId': selectedTopic!['id'],
          'subTopId': selectedSubTopic!['id'],
        });

        // Add karne ke baad last selection reset kar dete hain taaki agla add kar sakein
        selectedSubTopic = null; 
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select up to Sub-Topic")));
    }
  }

  // 4️⃣ Save Entire Schedule to Firebase
  void _saveSchedule() async {
    if (_weekTitleController.text.isEmpty || _examDate == null || _addedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title, Date aur kam se kam 1 Topic zaroori hai!")));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.examId)
          .collection('weeks')
          .add({
        'weekTitle': _weekTitleController.text.trim(),
        'unlockTime': Timestamp.fromDate(_examDate!),
        'createdAt': FieldValue.serverTimestamp(),
        'linkedTopics': _addedTopics.map((e) => "${e['topic']} (${e['subTopic']})").toList(), // For simple display
        'scheduleData': _addedTopics, // Full Data for linking
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Schedule 📅")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1: BASIC DETAILS ---
                  const Text("Week Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _weekTitleController,
                    decoration: const InputDecoration(
                      labelText: "Schedule Title (e.g. Week 1 - Basics)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                    title: Text(_examDate == null ? "Select Unlock Date & Time" : "Unlock: ${DateFormat('dd MMM - hh:mm a').format(_examDate!)}"),
                    trailing: const Icon(Icons.calendar_today, color: Colors.deepPurple),
                    onTap: _pickDate,
                  ),

                  const Divider(height: 40, thickness: 2),

                  // --- SECTION 2: HIERARCHY SELECTION ---
                  const Text("Select Topics from Database", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),

                  // 1. SUBJECT
                  _buildDropdown("Subject", fullHierarchy, selectedSubject, (val) {
                    setState(() {
                      selectedSubject = val;
                      selectedSubSubject = null;
                      selectedTopic = null;
                      selectedSubTopic = null;
                    });
                  }),

                  // 2. SUB-SUBJECT
                  _buildDropdown("Sub-Subject", getSubSubjects(), selectedSubSubject, (val) {
                    setState(() {
                      selectedSubSubject = val;
                      selectedTopic = null;
                      selectedSubTopic = null;
                    });
                  }),

                  // 3. TOPIC
                  _buildDropdown("Topic", getTopics(), selectedTopic, (val) {
                    setState(() {
                      selectedTopic = val;
                      selectedSubTopic = null;
                    });
                  }),

                  // 4. SUB-TOPIC
                  _buildDropdown("Sub-Topic", getSubTopics(), selectedSubTopic, (val) {
                    setState(() => selectedSubTopic = val);
                  }),

                  const SizedBox(height: 10),
                  
                  // ADD BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: selectedSubTopic == null ? null : _addTopicToList,
                      icon: const Icon(Icons.add_circle),
                      label: const Text("ADD TOPIC TO SCHEDULE"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  // --- SECTION 3: PREVIEW LIST ---
                  const SizedBox(height: 20),
                  if (_addedTopics.isNotEmpty) ...[
                    const Text("Selected Topics:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _addedTopics.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          var item = _addedTopics[i];
                          return ListTile(
                            title: Text(item['topic'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${item['subject']} > ${item['subTopic']}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => setState(() => _addedTopics.removeAt(i)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                  
                  // SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSchedule,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("SAVE FULL SCHEDULE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
    );
  }

  // --- Helper Widget for Dropdowns ---
  Widget _buildDropdown(String hint, List<dynamic> items, Map<String, dynamic>? value, Function(Map<String, dynamic>?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<Map<String, dynamic>>(
        value: value,
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          filled: true,
          fillColor: Colors.white,
        ),
        isExpanded: true,
        hint: Text("Select $hint"),
        items: items.map((item) {
          return DropdownMenuItem<Map<String, dynamic>>(
            value: item,
            child: Text(item['name'], overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
