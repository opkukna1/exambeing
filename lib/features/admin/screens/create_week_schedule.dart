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
  
  // 🔥 Controllers for Auto-Complete
  final TextEditingController _subjController = TextEditingController();
  final TextEditingController _subSubjController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _subTopController = TextEditingController();

  DateTime? _examDate;

  // --- Data Variables ---
  List<dynamic> combinedHierarchy = []; 
  bool isLoading = true; 
  String? loadingMessage = "Checking permissions...";

  // --- Selections ---
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

  // 🧠 2. SMART FETCH (Global + Personal)
  Future<void> _fetchCombinedHierarchy(String userId) async {
    try {
      List<dynamic> globalList = [];
      List<dynamic> teacherList = [];

      // 1. Fetch Global Hierarchy (Admin wala)
      DocumentSnapshot globalDoc = await FirebaseFirestore.instance.collection('app_metadata').doc('notes_index').get();
      if (globalDoc.exists) globalList = globalDoc['hierarchy'] as List<dynamic>;

      // 2. Fetch Teacher's Personal Hierarchy (Jo usne pehle add kiya tha)
      DocumentSnapshot teacherDoc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(userId)
          .collection('private_data')
          .doc('my_hierarchy')
          .get();
      
      if (teacherDoc.exists) teacherList = teacherDoc['hierarchy'] as List<dynamic>;

      // 3. Merge Lists (Duplicates Handle karne ke liye Set use kar sakte hain, par abhi simple merge)
      // Note: Hum teacher list ko pehle rakhenge taaki uske custom topics upar aayein
      setState(() {
        combinedHierarchy = [...teacherList, ...globalList]; 
        isLoading = false; 
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // 🧠 3. SMART SAVE (Auto-Learn Logic)
  Future<void> _saveTopicToTeacherDictionary(Map<String, dynamic> newEntry) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('teachers')
          .doc(user.uid)
          .collection('private_data')
          .doc('my_hierarchy');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        List<dynamic> currentHierarchy = [];

        if (snapshot.exists) {
          currentHierarchy = snapshot['hierarchy'] as List<dynamic>;
        }

        // Logic: Check karo Subject -> SubSubject -> Topic hierarchy exist karti hai kya
        // Agar nahi karti to add karo. Ye deep nested check hai.
        
        bool subjectFound = false;
        for (var subj in currentHierarchy) {
          if (subj['name'] == newEntry['subject']) {
            subjectFound = true;
            // Subject mil gaya, ab SubSubject check karo
            List subSubjects = subj['subSubjects'] ?? [];
            bool subSubjFound = false;
            
            for (var subSubj in subSubjects) {
              if (subSubj['name'] == newEntry['subSubject']) {
                subSubjFound = true;
                // SubSubject mil gaya, ab Topic check karo
                List topics = subSubj['topics'] ?? [];
                bool topicFound = false;

                for (var topic in topics) {
                  if (topic['name'] == newEntry['topic']) {
                    topicFound = true;
                    // Topic mil gaya, ab SubTopic check karo
                    List subTopics = topic['subTopics'] ?? [];
                    bool subTopicFound = false;
                    for (var subTop in subTopics) {
                      if (subTop['name'] == newEntry['subTopic']) {
                         subTopicFound = true;
                         break;
                      }
                    }
                    if(!subTopicFound && newEntry['subTopic'].toString().isNotEmpty) {
                       subTopics.add({'id': DateTime.now().millisecondsSinceEpoch.toString(), 'name': newEntry['subTopic']});
                       topic['subTopics'] = subTopics; // Update ref
                    }
                    break;
                  }
                }
                if(!topicFound) {
                   topics.add({
                     'id': DateTime.now().millisecondsSinceEpoch.toString(),
                     'name': newEntry['topic'],
                     'subTopics': newEntry['subTopic'].toString().isNotEmpty ? [{'id': 'auto', 'name': newEntry['subTopic']}] : []
                   });
                   subSubj['topics'] = topics;
                }
                break;
              }
            }
            if (!subSubjFound) {
              subSubjects.add({
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'name': newEntry['subSubject'],
                'topics': [{
                    'id': 'auto', 
                    'name': newEntry['topic'],
                    'subTopics': newEntry['subTopic'].toString().isNotEmpty ? [{'id': 'auto', 'name': newEntry['subTopic']}] : []
                }]
              });
              subj['subSubjects'] = subSubjects;
            }
            break;
          }
        }

        if (!subjectFound) {
          currentHierarchy.add({
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'name': newEntry['subject'],
            'subSubjects': [{
                'id': 'auto',
                'name': newEntry['subSubject'],
                'topics': [{
                    'id': 'auto', 
                    'name': newEntry['topic'],
                    'subTopics': newEntry['subTopic'].toString().isNotEmpty ? [{'id': 'auto', 'name': newEntry['subTopic']}] : []
                }]
            }]
          });
        }

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

  void _addTopicToList() {
    if (_subjController.text.isNotEmpty && _topicController.text.isNotEmpty) {
      Map<String, dynamic> newItem = {
        'subject': _subjController.text.trim(),
        'subSubject': _subSubjController.text.trim(),
        'topic': _topicController.text.trim(),
        'subTopic': _subTopController.text.trim(),
        'isCustom': true // Mark as custom initially
      };

      // 🔥 Background mein save karo future use ke liye
      _saveTopicToTeacherDictionary(newItem);

      setState(() {
        _addedTopics.add(newItem);
        _topicController.clear();
        _subTopController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subject and Topic are required")));
    }
  }

  void _saveSchedule() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_weekTitleController.text.isEmpty || _examDate == null || _addedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields required!")));
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

  Widget _buildAutocomplete(String label, TextEditingController controller, List<dynamic> options, Function(Map<String, dynamic>) onSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<Map<String, dynamic>>(
        optionsBuilder: (v) {
          if (v.text.isEmpty) return const Iterable.empty();
          return options.where((o) => o['name'].toString().toLowerCase().contains(v.text.toLowerCase())).map((e) => e as Map<String, dynamic>);
        },
        displayStringForOption: (o) => o['name'],
        onSelected: (s) { 
          controller.text = s['name']; 
          onSelected(s); 
        },
        fieldViewBuilder: (ctx, tCtrl, fNode, _) {
          // Sync internal text field with our controller
          if (tCtrl.text != controller.text) {
             tCtrl.text = controller.text;
             tCtrl.selection = TextSelection.fromPosition(TextPosition(offset: tCtrl.text.length));
          }
          return TextField(
            controller: tCtrl, 
            focusNode: fNode, 
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.arrow_drop_down)), 
            onChanged: (v) {
              controller.text = v;
            }
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Schedule")),
      body: isLoading ? Center(child: Text(loadingMessage ?? "")) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _weekTitleController, decoration: const InputDecoration(labelText: "Schedule Title (e.g., Week 1)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            ListTile(
              title: Text(_examDate == null ? "Select Unlock Date" : DateFormat('dd MMM - hh:mm a').format(_examDate!)), 
              trailing: const Icon(Icons.calendar_today, color: Colors.deepPurple), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
              onTap: _pickDate
            ),
            const Divider(height: 30),
            
            // 🔥 Smart Autocomplete Fields
            _buildAutocomplete("Subject", _subjController, combinedHierarchy, (v) => setState(() => selectedSubject = v)),
            _buildAutocomplete("Sub-Subject", _subSubjController, selectedSubject?['subSubjects'] ?? [], (v) => setState(() => selectedSubSubject = v)),
            _buildAutocomplete("Topic", _topicController, selectedSubSubject?['topics'] ?? [], (v) => setState(() => selectedTopic = v)),
            _buildAutocomplete("Sub-Topic", _subTopController, selectedTopic?['subTopics'] ?? [], (v) => setState(() => selectedSubTopic = v)),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addTopicToList, 
                icon: const Icon(Icons.add),
                label: const Text("ADD TOPIC"),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12))
              ),
            ),
            const SizedBox(height: 20),
            
            // List of Added Topics
            if (_addedTopics.isNotEmpty) ...[
               const Align(alignment: Alignment.centerLeft, child: Text("Selected Topics:", style: TextStyle(fontWeight: FontWeight.bold))),
               ListView.builder(
                 shrinkWrap: true, 
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: _addedTopics.length, 
                 itemBuilder: (c, i) => Card(
                   margin: const EdgeInsets.symmetric(vertical: 4),
                   child: ListTile(
                     title: Text("${_addedTopics[i]['topic']} (${_addedTopics[i]['subTopic']})"), 
                     subtitle: Text("${_addedTopics[i]['subject']} > ${_addedTopics[i]['subSubject']}"),
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
              child: const Text("SAVE & PUBLISH", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
            )
          ],
        ),
      ),
    );
  }
}
