import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // User Auth ke liye
import 'package:intl/intl.dart';

class CreateWeekSchedule extends StatefulWidget {
  final String examId;
  const CreateWeekSchedule({super.key, required this.examId});

  @override
  State<CreateWeekSchedule> createState() => _CreateWeekScheduleState();
}

class _CreateWeekScheduleState extends State<CreateWeekSchedule> {
  // --- Controllers & Basic Info ---
  final _weekTitleController = TextEditingController();
  DateTime? _examDate;

  // --- Data Variables ---
  List<dynamic> fullHierarchy = [];
  bool isLoading = true; // Overall loading state
  String? loadingMessage = "Checking permissions..."; // Loading status text

  // --- Selections ---
  Map<String, dynamic>? selectedSubject;
  Map<String, dynamic>? selectedSubSubject;
  Map<String, dynamic>? selectedTopic;
  Map<String, dynamic>? selectedSubTopic;

  final List<Map<String, dynamic>> _addedTopics = [];

  @override
  void initState() {
    super.initState();
    _checkHostPermissions(); // 🔥 Step 1: Sabse pehle permission check karo
  }

  // 🔥 1️⃣ Permission & Limit Check Function
  Future<void> _checkHostPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please login first!")));
        Navigator.pop(context);
      }
      return;
    }

    try {
      // A. User ka data fetch karo (users collection se)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        _showErrorAndExit("User data not found!");
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;

      // B. Check 'host' field
      String isHost = (userData['host'] ?? 'no').toString();
      if (isHost.toLowerCase() != 'yes') {
        _showErrorAndExit("Access Denied: You are not authorized as a Host.");
        return;
      }

      // C. Check 'hostnumber' (Max limit)
      // Parse int safely (agar string "5" hai ya number 5 hai dono handle honge)
      int allowedLimit = int.tryParse(userData['hostnumber'].toString()) ?? 0;

      // D. Count current schedules created for this Exam
      // Note: Hum count() query use kar rahe hain jo fast aur sasti hai
      AggregateQuerySnapshot query = await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.examId)
          .collection('weeks')
          .count()
          .get();
      
      int existingSchedules = query.count ?? 0;

      // E. Compare Limit
      if (existingSchedules >= allowedLimit) {
        _showErrorAndExit("Limit Reached! You can only create $allowedLimit schedules.");
        return;
      }

      // ✅ Sab sahi hai -> Ab Hierarchy fetch karo
      setState(() {
        loadingMessage = "Loading topics...";
      });
      _fetchHierarchy();

    } catch (e) {
      _showErrorAndExit("Error checking permissions: $e");
    }
  }

  // Helper to show error and go back
  void _showErrorAndExit(String message) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      )
    );
    Navigator.pop(context); // Screen band kar do
  }

  // 2️⃣ Fetch Hierarchy (Existing Logic)
  Future<void> _fetchHierarchy() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('app_metadata')
          .doc('notes_index')
          .get();

      if (doc.exists) {
        setState(() {
          fullHierarchy = doc['hierarchy'] as List<dynamic>;
          isLoading = false; // Loading khatam
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching hierarchy: $e");
      setState(() => isLoading = false);
    }
  }

  // --- Helper Getters ---
  List<dynamic> getSubSubjects() => selectedSubject?['subSubjects'] ?? [];
  List<dynamic> getTopics() => selectedSubSubject?['topics'] ?? [];
  List<dynamic> getSubTopics() => selectedTopic?['subTopics'] ?? [];

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

  void _addTopicToList() {
    if (selectedSubTopic != null) {
      setState(() {
        _addedTopics.add({
          'subject': selectedSubject!['name'],
          'subSubject': selectedSubSubject!['name'],
          'topic': selectedTopic!['name'],
          'subTopic': selectedSubTopic!['name'],
          'subjId': selectedSubject!['id'],
          'subSubjId': selectedSubSubject!['id'],
          'topicId': selectedTopic!['id'],
          'subTopId': selectedSubTopic!['id'],
        });
        selectedSubTopic = null; 
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select up to Sub-Topic")));
    }
  }

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
        'linkedTopics': _addedTopics.map((e) => "${e['topic']} (${e['subTopic']})").toList(),
        'scheduleData': _addedTopics,
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(loadingMessage ?? "Loading..."), // Loading message dikhayega
                ],
              ),
            )
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
                      labelText: "Schedule Title",
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

                  // --- SECTION 2: HIERARCHY ---
                  const Text("Select Topics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),

                  _buildDropdown("Subject", fullHierarchy, selectedSubject, (val) {
                    setState(() {
                      selectedSubject = val;
                      selectedSubSubject = null;
                      selectedTopic = null;
                      selectedSubTopic = null;
                    });
                  }),

                  _buildDropdown("Sub-Subject", getSubSubjects(), selectedSubSubject, (val) {
                    setState(() {
                      selectedSubSubject = val;
                      selectedTopic = null;
                      selectedSubTopic = null;
                    });
                  }),

                  _buildDropdown("Topic", getTopics(), selectedTopic, (val) {
                    setState(() {
                      selectedTopic = val;
                      selectedSubTopic = null;
                    });
                  }),

                  _buildDropdown("Sub-Topic", getSubTopics(), selectedSubTopic, (val) {
                    setState(() => selectedSubTopic = val);
                  }),

                  const SizedBox(height: 10),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: selectedSubTopic == null ? null : _addTopicToList,
                      icon: const Icon(Icons.add_circle),
                      label: const Text("ADD TOPIC"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    ),
                  ),

                  // --- SECTION 3: LIST ---
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
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSchedule,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("SAVE SCHEDULE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
    );
  }

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
