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
  
  // 🔥 Controllers for Fields
  final TextEditingController _subjController = TextEditingController();
  final TextEditingController _subSubjController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _subTopController = TextEditingController();

  DateTime? _examDate;

  // --- Data Variables ---
  List<dynamic> combinedHierarchy = []; // Main Data Source
  bool isLoading = true; 
  String? loadingMessage = "Checking permissions...";

  // --- Current Selections (For filtering child lists) ---
  Map<String, dynamic>? _selectedSubjectMap;
  Map<String, dynamic>? _selectedSubSubjectMap;
  Map<String, dynamic>? _selectedTopicMap;

  final List<Map<String, dynamic>> _addedTopics = [];

  @override
  void initState() {
    super.initState();
    _checkHostPermissions(); 
  }

  // 🔒 1. SECURITY CHECK
  Future<void> _checkHostPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _showErrorAndExit("Please login first."); return; }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      String isHost = (userData['host'] ?? 'no').toString().toLowerCase();
      
      if (isHost != 'yes') {
        _showErrorAndExit("Access Denied: Only Teachers can create schedules.");
        return;
      }
      
      setState(() => loadingMessage = "Loading your topics...");
      await _fetchCombinedHierarchy(user.uid);

    } catch (e) {
      _showErrorAndExit("Error: $e");
    }
  }

  void _showErrorAndExit(String message) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    Navigator.pop(context); 
  }

  // 🧠 2. SMART FETCH
  Future<void> _fetchCombinedHierarchy(String userId) async {
    try {
      List<dynamic> globalList = [];
      List<dynamic> teacherList = [];

      // Global
      DocumentSnapshot globalDoc = await FirebaseFirestore.instance.collection('app_metadata').doc('notes_index').get();
      if (globalDoc.exists) globalList = globalDoc['hierarchy'] as List<dynamic>;

      // Personal
      DocumentSnapshot teacherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('my_custom_topics')
          .doc('hierarchy_doc')
          .get();
      
      if (teacherDoc.exists && teacherDoc.data() != null) {
        Map<String, dynamic> data = teacherDoc.data() as Map<String, dynamic>;
        if (data.containsKey('hierarchy')) teacherList = data['hierarchy'] as List<dynamic>;
      }

      setState(() {
        // Merge lists (Teacher first for priority)
        combinedHierarchy = [...teacherList, ...globalList]; 
        isLoading = false; 
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // 🧠 3. SMART SAVE (Logic to insert New Data into Tree)
  Future<void> _saveTopicToTeacherDictionary(Map<String, dynamic> newEntry) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('my_custom_topics')
          .doc('hierarchy_doc');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        List<dynamic> currentHierarchy = [];

        if (snapshot.exists && snapshot.data() != null) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          if (data.containsKey('hierarchy')) currentHierarchy = List.from(data['hierarchy']);
        }

        // --- Recursive Check & Insert Logic ---
        // 1. Find or Create Subject
        var subjIndex = currentHierarchy.indexWhere((e) => e['name'].toString().toLowerCase() == newEntry['subject'].toString().toLowerCase());
        if (subjIndex == -1) {
          currentHierarchy.add({'id': DateTime.now().millisecondsSinceEpoch.toString(), 'name': newEntry['subject'], 'subSubjects': []});
          subjIndex = currentHierarchy.length - 1;
        }

        // 2. Find or Create SubSubject
        List subSubjects = currentHierarchy[subjIndex]['subSubjects'] ?? [];
        var subSubjIndex = subSubjects.indexWhere((e) => e['name'].toString().toLowerCase() == newEntry['subSubject'].toString().toLowerCase());
        if (subSubjIndex == -1) {
          subSubjects.add({'id': 'auto', 'name': newEntry['subSubject'], 'topics': []});
          subSubjIndex = subSubjects.length - 1;
        }

        // 3. Find or Create Topic
        List topics = subSubjects[subSubjIndex]['topics'] ?? [];
        var topicIndex = topics.indexWhere((e) => e['name'].toString().toLowerCase() == newEntry['topic'].toString().toLowerCase());
        if (topicIndex == -1) {
          topics.add({'id': 'auto', 'name': newEntry['topic'], 'subTopics': []});
          topicIndex = topics.length - 1;
        }

        // 4. Find or Create SubTopic (if exists)
        if (newEntry['subTopic'].toString().isNotEmpty) {
          List subTopics = topics[topicIndex]['subTopics'] ?? [];
          var subTopIndex = subTopics.indexWhere((e) => e['name'].toString().toLowerCase() == newEntry['subTopic'].toString().toLowerCase());
          if (subTopIndex == -1) {
            subTopics.add({'id': 'auto', 'name': newEntry['subTopic']});
          }
          topics[topicIndex]['subTopics'] = subTopics;
        }

        // Re-assign lists back to parents (Reference update)
        subSubjects[subSubjIndex]['topics'] = topics;
        currentHierarchy[subjIndex]['subSubjects'] = subSubjects;

        transaction.set(docRef, {'hierarchy': currentHierarchy}, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint("Auto-Save Error: $e");
    }
  }

  void _pickDate() async {
    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (time != null) setState(() => _examDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
    }
  }

  // 🔥 ADD BUTTON LOGIC
  void _addTopicToList() {
    // Basic Validation
    if (_subjController.text.trim().isEmpty || _topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subject and Topic are required!")));
      return;
    }

    Map<String, dynamic> newItem = {
      'subject': _subjController.text.trim(),
      'subSubject': _subSubjController.text.trim(),
      'topic': _topicController.text.trim(),
      'subTopic': _subTopController.text.trim(),
      'isCustom': true 
    };

    // Save to DB in background (Auto-Learn)
    _saveTopicToTeacherDictionary(newItem);

    setState(() {
      _addedTopics.add(newItem);
      // Clear specific fields to allow adding next topic easily
      _topicController.clear();
      _subTopController.clear();
      // NOTE: We keep Subject/SubSubject filled so teacher can add multiple topics to same subject easily
    });
  }

  void _saveSchedule() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_weekTitleController.text.isEmpty || _examDate == null || _addedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title, Date and at least 1 Topic required!")));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('study_schedules').doc(widget.examId).collection('weeks').add({
        'weekTitle': _weekTitleController.text.trim(),
        'unlockTime': Timestamp.fromDate(_examDate!),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid, 
        'linkedTopics': _addedTopics.map((e) => "${e['topic']} (${e['subTopic']})").toList(),
        'scheduleData': _addedTopics, 
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule Created! ✅")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 🎨 SMART AUTOCOMPLETE WIDGET
  Widget _buildSmartAutocomplete({
    required String label,
    required TextEditingController controller,
    required List<dynamic> dataList,
    required Function(Map<String, dynamic>) onSelected,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<Map<String, dynamic>>(
        optionsBuilder: (TextEditingValue textValue) {
          if (textValue.text.isEmpty) return dataList.map((e) => e as Map<String, dynamic>); // Show all if empty
          return dataList.where((option) {
            return option['name'].toString().toLowerCase().contains(textValue.text.toLowerCase());
          }).map((e) => e as Map<String, dynamic>);
        },
        displayStringForOption: (option) => option['name'],
        onSelected: (selection) {
          controller.text = selection['name'];
          onSelected(selection);
        },
        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
          // Sync controllers: If parent clears, this should reflect
          if (textController.text != controller.text) {
            textController.text = controller.text;
            textController.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
          }
          
          return TextField(
            controller: textController,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  textController.clear();
                  onClear();
                },
              )
            ),
            onChanged: (val) {
              controller.text = val; // Manual typing updates main controller
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🛠️ Prepare Lists based on Selections
    List subSubjectsList = _selectedSubjectMap?['subSubjects'] ?? [];
    List topicsList = _selectedSubSubjectMap?['topics'] ?? [];
    List subTopicsList = _selectedTopicMap?['subTopics'] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text("Create Schedule")),
      body: isLoading ? Center(child: Text(loadingMessage ?? "")) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _weekTitleController, decoration: const InputDecoration(labelText: "Schedule Title", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            ListTile(
              title: Text(_examDate == null ? "Select Unlock Date" : DateFormat('dd MMM - hh:mm a').format(_examDate!)), 
              trailing: const Icon(Icons.calendar_today, color: Colors.deepPurple), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
              onTap: _pickDate
            ),
            const Divider(height: 30),
            
            // 1. SUBJECT
            _buildSmartAutocomplete(
              label: "Subject",
              controller: _subjController,
              dataList: combinedHierarchy,
              onSelected: (val) {
                setState(() {
                  _selectedSubjectMap = val;
                  // Clear children
                  _subSubjController.clear(); _selectedSubSubjectMap = null;
                  _topicController.clear(); _selectedTopicMap = null;
                  _subTopController.clear();
                });
              },
              onClear: () => setState(() { _selectedSubjectMap = null; }),
            ),

            // 2. SUB-SUBJECT
            _buildSmartAutocomplete(
              label: "Sub-Subject",
              controller: _subSubjController,
              dataList: subSubjectsList,
              onSelected: (val) {
                setState(() {
                  _selectedSubSubjectMap = val;
                  // Clear children
                  _topicController.clear(); _selectedTopicMap = null;
                  _subTopController.clear();
                });
              },
              onClear: () => setState(() { _selectedSubSubjectMap = null; }),
            ),

            // 3. TOPIC
            _buildSmartAutocomplete(
              label: "Topic",
              controller: _topicController,
              dataList: topicsList,
              onSelected: (val) {
                setState(() {
                  _selectedTopicMap = val;
                  // Clear children
                  _subTopController.clear();
                });
              },
              onClear: () => setState(() { _selectedTopicMap = null; }),
            ),

            // 4. SUB-TOPIC
            _buildSmartAutocomplete(
              label: "Sub-Topic (Optional)",
              controller: _subTopController,
              dataList: subTopicsList,
              onSelected: (val) {}, // No children
              onClear: () {},
            ),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addTopicToList, 
                icon: const Icon(Icons.add),
                label: const Text("ADD TOPIC"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50, 
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 12)
                )
              ),
            ),
            const SizedBox(height: 20),
            
            // LIST OF ADDED TOPICS
            if (_addedTopics.isNotEmpty) ...[
               const Align(alignment: Alignment.centerLeft, child: Text("Selected Topics:", style: TextStyle(fontWeight: FontWeight.bold))),
               ListView.builder(
                 shrinkWrap: true, 
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: _addedTopics.length, 
                 itemBuilder: (c, i) => Card(
                   margin: const EdgeInsets.symmetric(vertical: 4),
                   child: ListTile(
                     title: Text("${_addedTopics[i]['topic']}"), 
                     subtitle: Text("${_addedTopics[i]['subject']} > ${_addedTopics[i]['subSubject']} > ${_addedTopics[i]['subTopic']}"),
                     trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _addedTopics.removeAt(i)))
                   ),
                 )
               ),
            ],
            
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveSchedule, 
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple, 
                foregroundColor: Colors.white, 
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ), 
              child: const Text("SAVE SCHEDULE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
            )
          ],
        ),
      ),
    );
  }
}
