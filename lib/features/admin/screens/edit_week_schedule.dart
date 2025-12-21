import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:intl/intl.dart';

class CreateWeekSchedule extends StatefulWidget {
  final String examId;
  const CreateWeekSchedule({super.key, required this.examId});

  @override
  State<CreateWeekSchedule> createState() => _CreateWeekScheduleState();
}

class _CreateWeekScheduleState extends State<CreateWeekSchedule> {
  // --- Controllers ---
  final _weekTitleController = TextEditingController();
  
  // 🔥 Controllers for Auto-Complete Fields (Taki hum text read kar sakein)
  final TextEditingController _subjController = TextEditingController();
  final TextEditingController _subSubjController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _subTopController = TextEditingController();

  DateTime? _examDate;

  // --- Data Variables ---
  List<dynamic> fullHierarchy = [];
  bool isLoading = true; 
  String? loadingMessage = "Checking permissions...";

  // --- Selections (For Logic) ---
  // Agar user list se chunega to ye bharenge, agar type karega to ye null rahenge
  Map<String, dynamic>? selectedSubject;
  Map<String, dynamic>? selectedSubSubject;
  Map<String, dynamic>? selectedTopic;
  Map<String, dynamic>? selectedSubTopic;

  final List<Map<String, dynamic>> _addedTopics = [];

  @override
  void initState() {
    super.initState();
    _checkHostPermissions(); 
  }

  // 🔥 1. Permission Check
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
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      String isHost = (userData['host'] ?? 'no').toString();
      
      if (isHost.toLowerCase() != 'yes') {
        _showErrorAndExit("Access Denied: You are not authorized as a Host.");
        return;
      }

      int allowedLimit = int.tryParse(userData['hostnumber'].toString()) ?? 0;

      AggregateQuerySnapshot query = await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.examId)
          .collection('weeks')
          .where('createdBy', isEqualTo: user.uid)
          .count()
          .get();
      
      int existingSchedules = query.count ?? 0;

      if (existingSchedules >= allowedLimit) {
        _showErrorAndExit("Limit Reached! You can only create $allowedLimit schedules.");
        return;
      }

      setState(() => loadingMessage = "Loading topics...");
      _fetchHierarchy();

    } catch (e) {
      _showErrorAndExit("Error checking permissions: $e");
    }
  }

  void _showErrorAndExit(String message) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    Navigator.pop(context); 
  }

  // 2. Fetch Hierarchy
  Future<void> _fetchHierarchy() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('app_metadata').doc('notes_index').get();
      if (doc.exists) {
        setState(() {
          fullHierarchy = doc['hierarchy'] as List<dynamic>;
          isLoading = false; 
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // 3. Date Picker
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
        setState(() => _examDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
      }
    }
  }

  // 🔥 4. ADD TOPIC (Updated Logic)
  void _addTopicToList() {
    // Ab hum Controllers se text uthayenge (chahe select kiya ho ya type kiya ho)
    String subj = _subjController.text.trim();
    String subSubj = _subSubjController.text.trim();
    String topic = _topicController.text.trim();
    String subTop = _subTopController.text.trim();

    if (subj.isNotEmpty && subSubj.isNotEmpty && topic.isNotEmpty && subTop.isNotEmpty) {
      setState(() {
        _addedTopics.add({
          'subject': subj,
          'subSubject': subSubj,
          'topic': topic,
          'subTopic': subTop,
          // Agar database se select kiya to ID wahi hogi, warna random ID generate kar lenge
          'subjId': selectedSubject?['id'] ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
          'subSubjId': selectedSubSubject?['id'] ?? 'custom',
          'topicId': selectedTopic?['id'] ?? 'custom',
          'subTopId': selectedSubTopic?['id'] ?? 'custom',
        });
        
        // Clear fields for next entry
        _topicController.clear();
        _subTopController.clear();
        selectedTopic = null;
        selectedSubTopic = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all 4 fields (Subject to Sub-Topic)")));
    }
  }

  // 5. Save Schedule
  void _saveSchedule() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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
        'createdBy': user.uid,
        'linkedTopics': _addedTopics.map((e) => "${e['topic']} (${e['subTopic']})").toList(),
        'scheduleData': _addedTopics,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule Created Successfully! ✅")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 🔥 6. AUTOCOMPLETE WIDGET BUILDER
  Widget _buildAutocomplete(
    String label, 
    TextEditingController controller, 
    List<dynamic> options, 
    Function(Map<String, dynamic>) onSelected
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<Map<String, dynamic>>(
        // A. Options Filter Logic
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Map<String, dynamic>>.empty();
          }
          return options.where((option) {
            return option['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
          }).map((e) => e as Map<String, dynamic>);
        },
        
        // B. Display String
        displayStringForOption: (Map<String, dynamic> option) => option['name'],

        // C. Selection Handler
        onSelected: (Map<String, dynamic> selection) {
          controller.text = selection['name']; // Text field update
          onSelected(selection); // Logic update (Parent update karne ke liye)
        },

        // D. Field UI
        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
          // Sync internal controller with our controller
          if (textController.text != controller.text) {
             textController.text = controller.text;
          }
          
          return TextField(
            controller: textController,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: label,
              hintText: "Select or Type $label",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            onChanged: (val) {
              controller.text = val; // Agar user khud type kare to bhi save ho
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Schedule 📅")),
      body: isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(loadingMessage ?? "Loading...")]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Week Details ---
                  const Text("Week Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(controller: _weekTitleController, decoration: const InputDecoration(labelText: "Schedule Title", border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                    title: Text(_examDate == null ? "Select Unlock Date & Time" : "Unlock: ${DateFormat('dd MMM - hh:mm a').format(_examDate!)}"),
                    trailing: const Icon(Icons.calendar_today, color: Colors.deepPurple),
                    onTap: _pickDate,
                  ),

                  const Divider(height: 40, thickness: 2),

                  // --- 🔥 SEARCH or TYPE TOPICS ---
                  const Text("Add Topics (Select or Type Custom)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)),
                  const SizedBox(height: 15),

                  // 1. Subject
                  _buildAutocomplete("Subject", _subjController, fullHierarchy, (val) {
                    setState(() {
                      selectedSubject = val;
                      _subSubjController.clear();
                      _topicController.clear();
                      _subTopController.clear();
                      selectedSubSubject = null;
                      selectedTopic = null;
                      selectedSubTopic = null;
                    });
                  }),

                  // 2. Sub-Subject (Depends on Subject)
                  _buildAutocomplete(
                    "Sub-Subject", 
                    _subSubjController, 
                    selectedSubject?['subSubjects'] ?? [], 
                    (val) {
                      setState(() {
                        selectedSubSubject = val;
                        _topicController.clear();
                        _subTopController.clear();
                        selectedTopic = null;
                        selectedSubTopic = null;
                      });
                    }
                  ),

                  // 3. Topic (Depends on Sub-Subject)
                  _buildAutocomplete(
                    "Topic", 
                    _topicController, 
                    selectedSubSubject?['topics'] ?? [], 
                    (val) {
                      setState(() {
                        selectedTopic = val;
                        _subTopController.clear();
                        selectedSubTopic = null;
                      });
                    }
                  ),

                  // 4. Sub-Topic (Depends on Topic)
                  _buildAutocomplete(
                    "Sub-Topic", 
                    _subTopController, 
                    selectedTopic?['subTopics'] ?? [], 
                    (val) {
                      setState(() => selectedSubTopic = val);
                    }
                  ),

                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addTopicToList,
                      icon: const Icon(Icons.add_circle),
                      label: const Text("ADD TOPIC"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    ),
                  ),

                  // --- LIST ---
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
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                      child: const Text("SAVE SCHEDULE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
