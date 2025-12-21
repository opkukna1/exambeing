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

  // 🔒 1. SECURITY CHECK (Is Host?)
  Future<void> _checkHostPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorAndExit("Please login first.");
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      String isHost = (userData['host'] ?? 'no').toString().toLowerCase();
      
      // 🔥 Only Host can enter
      if (isHost != 'yes') {
        _showErrorAndExit("Access Denied: Only Teachers can create schedules.");
        return;
      }

      // 🔢 Limit Check (Optional Logic from your code)
      int allowedLimit = int.tryParse(userData['hostnumber'].toString()) ?? 0;
      AggregateQuerySnapshot query = await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.examId)
          .collection('weeks')
          .where('createdBy', isEqualTo: user.uid)
          .count()
          .get();
      
      if ((query.count ?? 0) >= allowedLimit) {
        _showErrorAndExit("Limit Reached! You can only create $allowedLimit schedules.");
        return;
      }

      setState(() => loadingMessage = "Loading your topics...");
      _fetchCombinedHierarchy(user.uid);

    } catch (e) {
      _showErrorAndExit("Error checking permissions: $e");
    }
  }

  void _showErrorAndExit(String message) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    Navigator.pop(context); 
  }

  // 2. FETCH DATA
  Future<void> _fetchCombinedHierarchy(String userId) async {
    try {
      List<dynamic> globalList = [];
      List<dynamic> privateList = [];

      DocumentSnapshot globalDoc = await FirebaseFirestore.instance.collection('app_metadata').doc('notes_index').get();
      if (globalDoc.exists) globalList = globalDoc['hierarchy'] as List<dynamic>;

      DocumentSnapshot privateDoc = await FirebaseFirestore.instance.collection('users').doc(userId).collection('my_custom_topics').doc('hierarchy_doc').get();
      if (privateDoc.exists) privateList = privateDoc['data'] as List<dynamic>;

      setState(() {
        combinedHierarchy = [...privateList, ...globalList]; 
        isLoading = false; 
      });
    } catch (e) {
      setState(() => isLoading = false);
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
      setState(() {
        _addedTopics.add({
          'subject': _subjController.text.trim(),
          'subSubject': _subSubjController.text.trim(),
          'topic': _topicController.text.trim(),
          'subTopic': _subTopController.text.trim(),
          'isCustom': selectedSubject == null 
        });
        _topicController.clear();
        _subTopController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subject and Topic are required")));
    }
  }

  // 🔥 3. SAVE LOGIC (Stamp CreatedBy)
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
        
        // 🔥 CRITICAL: Yahan Teacher ki ID save ho rahi hai
        'createdBy': user.uid, 
        
        'linkedTopics': _addedTopics.map((e) => "${e['topic']} (${e['subTopic']})").toList(),
        'scheduleData': _addedTopics, 
      });

      _savePrivateMetadata(user.uid); // Save custom topics

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule Created! ✅")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _savePrivateMetadata(String uid) async {
     // (Same logic as provided before to save custom topics)
     // Skipping code for brevity, assumes logic is same as previous
  }

  Widget _buildAutocomplete(String label, TextEditingController controller, List<dynamic> options, Function(Map<String, dynamic>) onSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<Map<String, dynamic>>(
        optionsBuilder: (v) => v.text.isEmpty ? const Iterable.empty() : options.where((o) => o['name'].toString().toLowerCase().contains(v.text.toLowerCase())).map((e) => e as Map<String, dynamic>),
        displayStringForOption: (o) => o['name'],
        onSelected: (s) { controller.text = s['name']; onSelected(s); },
        fieldViewBuilder: (ctx, tCtrl, fNode, _) {
          if (tCtrl.text != controller.text) tCtrl.text = controller.text;
          return TextField(controller: tCtrl, focusNode: fNode, decoration: InputDecoration(labelText: label, border: OutlineInputBorder(), suffixIcon: const Icon(Icons.arrow_drop_down)), onChanged: (v) => controller.text = v);
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
            TextField(controller: _weekTitleController, decoration: const InputDecoration(labelText: "Schedule Title", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            ListTile(title: Text(_examDate == null ? "Select Date" : DateFormat('dd MMM - hh:mm a').format(_examDate!)), trailing: const Icon(Icons.calendar_today), onTap: _pickDate),
            const Divider(),
            _buildAutocomplete("Subject", _subjController, combinedHierarchy, (v) => setState(() => selectedSubject = v)),
            _buildAutocomplete("Sub-Subject", _subSubjController, selectedSubject?['subSubjects'] ?? [], (v) => setState(() => selectedSubSubject = v)),
            _buildAutocomplete("Topic", _topicController, selectedSubSubject?['topics'] ?? [], (v) => setState(() => selectedTopic = v)),
            _buildAutocomplete("Sub-Topic", _subTopController, selectedTopic?['subTopics'] ?? [], (v) => setState(() => selectedSubTopic = v)),
            ElevatedButton(onPressed: _addTopicToList, child: const Text("ADD TOPIC")),
            const SizedBox(height: 20),
            ListView.builder(shrinkWrap: true, itemCount: _addedTopics.length, itemBuilder: (c, i) => ListTile(title: Text(_addedTopics[i]['topic']), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _addedTopics.removeAt(i))))),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _saveSchedule, style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, minWidth: double.infinity), child: const Text("SAVE"))
          ],
        ),
      ),
    );
  }
}
