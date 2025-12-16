import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditWeekSchedule extends StatefulWidget {
  final String examId;
  final String weekId;
  final Map<String, dynamic> currentData;

  const EditWeekSchedule({
    super.key, 
    required this.examId, 
    required this.weekId, 
    required this.currentData
  });

  @override
  State<EditWeekSchedule> createState() => _EditWeekScheduleState();
}

class _EditWeekScheduleState extends State<EditWeekSchedule> {
  late TextEditingController _titleController;
  late List<dynamic> _topicsList;
  bool _isLoading = false;

  // Dropdown Selections for Adding New Topic
  List<dynamic> fullHierarchy = [];
  Map<String, dynamic>? selectedSubject;
  Map<String, dynamic>? selectedSubSubject;
  Map<String, dynamic>? selectedTopic;
  Map<String, dynamic>? selectedSubTopic;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentData['weekTitle']);
    _topicsList = List.from(widget.currentData['scheduleData'] ?? []);
    _fetchHierarchy();
  }

  // 1️⃣ Fetch Dropdown Data (Same as Create Screen)
  Future<void> _fetchHierarchy() async {
    var doc = await FirebaseFirestore.instance.collection('app_metadata').doc('notes_index').get();
    if (doc.exists) {
      setState(() => fullHierarchy = doc['hierarchy'] as List<dynamic>);
    }
  }

  // 2️⃣ Delete Specific Topic
  void _deleteTopic(int index) {
    setState(() {
      _topicsList.removeAt(index);
    });
  }

  // 3️⃣ Add New Topic Logic
  void _addTopic() {
    if (selectedSubTopic == null) return;
    
    setState(() {
      _topicsList.add({
        'subject': selectedSubject!['name'],
        'subSubject': selectedSubSubject!['name'],
        'topic': selectedTopic!['name'],
        'subTopic': selectedSubTopic!['name'],
        // IDs
        'subjId': selectedSubject!['id'],
        'subSubjId': selectedSubSubject!['id'],
        'topicId': selectedTopic!['id'],
        'subTopId': selectedSubTopic!['id'],
      });
      // Reset Selection
      selectedSubTopic = null;
    });
    Navigator.pop(context); // Close Bottom Sheet
  }

  // 4️⃣ Show Add Dialog
  void _showAddTopicSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Add New Topic", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                _buildDropdown("Subject", fullHierarchy, selectedSubject, (val) => setSheetState(() { selectedSubject = val; selectedSubSubject = null; })),
                _buildDropdown("Sub-Subject", selectedSubject?['subSubjects'] ?? [], selectedSubSubject, (val) => setSheetState(() { selectedSubSubject = val; selectedTopic = null; })),
                _buildDropdown("Topic", selectedSubSubject?['topics'] ?? [], selectedTopic, (val) => setSheetState(() { selectedTopic = val; selectedSubTopic = null; })),
                _buildDropdown("Sub-Topic", selectedTopic?['subTopics'] ?? [], selectedSubTopic, (val) => setSheetState(() => selectedSubTopic = val)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: selectedSubTopic == null ? null : _addTopic,
                  child: const Text("ADD TOPIC"),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // 5️⃣ Save Changes to Firebase
  void _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.examId)
          .collection('weeks')
          .doc(widget.weekId)
          .update({
        'weekTitle': _titleController.text.trim(),
        'scheduleData': _topicsList,
        'linkedTopics': _topicsList.map((e) => "${e['topic']} (${e['subTopic']})").toList(),
      });
      if(mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule Updated! ✅")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 6️⃣ Delete Entire Week (Danger Zone)
  void _deleteWeek() async {
    bool confirm = await showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("Delete Week?"),
        content: const Text("This will delete this week and all its tests."),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: ()=> Navigator.pop(c, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if(confirm) {
      await FirebaseFirestore.instance.collection('study_schedules').doc(widget.examId).collection('weeks').doc(widget.weekId).delete();
      if(mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Schedule ✏️"),
        actions: [
          IconButton(onPressed: _deleteWeek, icon: const Icon(Icons.delete_forever, color: Colors.red))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Week Title", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Topics List", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(onPressed: _showAddTopicSheet, icon: const Icon(Icons.add_circle, color: Colors.deepPurple))
                ],
              ),
              const Divider(),

              // List of Topics
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topicsList.length,
                itemBuilder: (ctx, i) {
                  var item = _topicsList[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item['topic']),
                      subtitle: Text(item['subTopic']),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        onPressed: () => _deleteTopic(i),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
                  child: const Text("SAVE CHANGES"),
                ),
              )
            ],
          ),
        ),
    );
  }

  Widget _buildDropdown(String hint, List<dynamic> items, Map<String, dynamic>? value, Function(Map<String, dynamic>?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<Map<String, dynamic>>(
        value: value,
        hint: Text("Select $hint"),
        isExpanded: true,
        items: items.map((item) => DropdownMenuItem<Map<String, dynamic>>(value: item, child: Text(item['name']))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
