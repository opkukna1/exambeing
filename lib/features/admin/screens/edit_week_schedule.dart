import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

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
  bool _isLoading = true; 

  // Dropdown Selections Data
  List<dynamic> fullHierarchy = [];
  
  // 🔥 Controllers for Add Topic Sheet
  final TextEditingController _subjController = TextEditingController();
  final TextEditingController _subSubjController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _subTopController = TextEditingController();

  // Selection Tracking for Hierarchy
  Map<String, dynamic>? selectedSubject;
  Map<String, dynamic>? selectedSubSubject;
  Map<String, dynamic>? selectedTopic;
  Map<String, dynamic>? selectedSubTopic;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentData['weekTitle']);
    _topicsList = List.from(widget.currentData['scheduleData'] ?? []);
    
    // 🔥 Security Check
    _checkPermissions();
  }

  // 🔒 0. SECURITY CHECK
  Future<void> _checkPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if(mounted) Navigator.pop(context);
      return;
    }

    try {
      // 1. OWNERSHIP CHECK
      String creatorId = widget.currentData['createdBy'] ?? '';
      
      // Agar currentData me nahi mila, DB se fetch karo
      if (creatorId.isEmpty) {
        DocumentSnapshot weekDoc = await FirebaseFirestore.instance
            .collection('study_schedules')
            .doc(widget.examId)
            .collection('weeks')
            .doc(widget.weekId)
            .get();
        if (weekDoc.exists) creatorId = weekDoc['createdBy'] ?? '';
      }

      if (creatorId != user.uid) {
        _showErrorAndExit("Access Denied: You can only edit schedules created by YOU.");
        return;
      }

      // 2. HOST CHECK
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        String isHost = (userDoc['host'] ?? 'no').toString().toLowerCase();
        if (isHost == 'yes') {
          _fetchHierarchy();
        } else {
          _showErrorAndExit("Access Denied: You are not a Host.");
        }
      } else {
        _showErrorAndExit("User not found.");
      }
    } catch (e) {
      _showErrorAndExit("Error checking permissions.");
    }
  }

  void _showErrorAndExit(String message) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    Navigator.pop(context); 
  }

  // 1️⃣ Fetch Hierarchy
  Future<void> _fetchHierarchy() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('app_metadata').doc('notes_index').get();
      if (doc.exists) {
        if(mounted) {
          setState(() {
            fullHierarchy = doc['hierarchy'] as List<dynamic>;
            _isLoading = false; 
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 2️⃣ Delete Specific Topic
  void _deleteTopic(int index) {
    setState(() {
      _topicsList.removeAt(index);
    });
  }

  // 3️⃣ Add New Topic Logic (From Text Controllers)
  void _addTopic() {
    String subj = _subjController.text.trim();
    String subSubj = _subSubjController.text.trim();
    String topic = _topicController.text.trim();
    String subTop = _subTopController.text.trim();

    if (subj.isEmpty || subSubj.isEmpty || topic.isEmpty || subTop.isEmpty) return;
    
    setState(() {
      _topicsList.add({
        'subject': subj,
        'subSubject': subSubj,
        'topic': topic,
        'subTopic': subTop,
        // IDs: Agar select kiya to ID, warna custom ID
        'subjId': selectedSubject?['id'] ?? 'custom',
        'subSubjId': selectedSubSubject?['id'] ?? 'custom',
        'topicId': selectedTopic?['id'] ?? 'custom',
        'subTopId': selectedSubTopic?['id'] ?? 'custom',
      });
      
      // Reset
      _topicController.clear();
      _subTopController.clear();
      selectedTopic = null;
      selectedSubTopic = null;
    });
    Navigator.pop(context); 
  }

  // 🔥 4️⃣ Show Add Dialog (Autocomplete Enabled)
  void _showAddTopicSheet() {
    // Reset controllers before opening
    _subjController.clear();
    _subSubjController.clear();
    _topicController.clear();
    _subTopController.clear();
    selectedSubject = null;
    selectedSubSubject = null;
    selectedTopic = null;
    selectedSubTopic = null;

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

                // 1. Subject
                _buildAutocomplete("Subject", _subjController, fullHierarchy, (val) {
                  setSheetState(() {
                    selectedSubject = val;
                    // Reset children
                    _subSubjController.clear(); _topicController.clear(); _subTopController.clear();
                    selectedSubSubject = null; selectedTopic = null; selectedSubTopic = null;
                  });
                }),

                // 2. Sub-Subject
                _buildAutocomplete("Sub-Subject", _subSubjController, selectedSubject?['subSubjects'] ?? [], (val) {
                  setSheetState(() {
                    selectedSubSubject = val;
                    // Reset children
                    _topicController.clear(); _subTopController.clear();
                    selectedTopic = null; selectedSubTopic = null;
                  });
                }),

                // 3. Topic
                _buildAutocomplete("Topic", _topicController, selectedSubSubject?['topics'] ?? [], (val) {
                  setSheetState(() {
                    selectedTopic = val;
                    // Reset children
                    _subTopController.clear();
                    selectedSubTopic = null;
                  });
                }),

                // 4. Sub-Topic
                _buildAutocomplete("Sub-Topic", _subTopController, selectedTopic?['subTopics'] ?? [], (val) {
                  setSheetState(() => selectedSubTopic = val);
                }),

                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _addTopic,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: const Text("ADD TOPIC"),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // 5️⃣ Save Changes
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
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // 6️⃣ Delete Week
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

  // 🔥 AUTOCOMPLETE WIDGET
  Widget _buildAutocomplete(
    String label, 
    TextEditingController controller, 
    List<dynamic> options, 
    Function(Map<String, dynamic>) onSelected
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<Map<String, dynamic>>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
          return options.where((option) {
            return option['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
          }).map((e) => e as Map<String, dynamic>);
        },
        displayStringForOption: (option) => option['name'],
        onSelected: (selection) {
          controller.text = selection['name'];
          onSelected(selection);
        },
        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
          // Sync check
          if (textController.text != controller.text) textController.text = controller.text;
          
          return TextField(
            controller: textController,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: label,
              hintText: "Select or Type $label",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            onChanged: (val) => controller.text = val,
          );
        },
      ),
    );
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
}
