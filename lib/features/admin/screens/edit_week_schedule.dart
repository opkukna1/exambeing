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

  // Combined Data (Global + Private)
  List<dynamic> combinedHierarchy = [];
  
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
    // Ensure we create a new list so we don't modify the reference directly before saving
    _topicsList = List.from(widget.currentData['scheduleData'] ?? []);
    
    // 🔥 Security Check
    _checkPermissions();
  }

  // 🔒 0. SECURITY CHECK (Ownership & Host)
  Future<void> _checkPermissions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if(mounted) Navigator.pop(context);
      return;
    }

    try {
      // 1. OWNERSHIP CHECK
      String creatorId = widget.currentData['createdBy'] ?? '';
      
      // Agar currentData me nahi mila, DB se fetch karo check karne ke liye
      if (creatorId.isEmpty) {
        DocumentSnapshot weekDoc = await FirebaseFirestore.instance
            .collection('study_schedules')
            .doc(widget.examId)
            .collection('weeks')
            .doc(widget.weekId)
            .get();
        if (weekDoc.exists) creatorId = weekDoc['createdBy'] ?? '';
      }

      // 🔥 CRITICAL: Agar Creator ID match nahi karti
      if (creatorId != user.uid) {
        _showErrorAndExit("Access Denied: You can only edit schedules created by YOU.");
        return;
      }

      // 2. HOST CHECK
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        // Handle boolean or string 'yes'
        String isHostStr = (userData['host'] ?? 'no').toString().toLowerCase();
        bool isHost = isHostStr == 'yes' || isHostStr == 'true';

        if (isHost) {
          // ✅ Sab sahi hai, Data Load karo
          _fetchCombinedHierarchy(user.uid);
        } else {
          _showErrorAndExit("Access Denied: You are not a Host.");
        }
      } else {
        _showErrorAndExit("User profile not found.");
      }
    } catch (e) {
      _showErrorAndExit("Error checking permissions: $e");
    }
  }

  void _showErrorAndExit(String message) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
    Navigator.pop(context); 
  }

  // 🔥 1️⃣ Fetch Combined Hierarchy (Global + Private)
  Future<void> _fetchCombinedHierarchy(String userId) async {
    try {
      List<dynamic> globalList = [];
      List<dynamic> privateList = [];

      // A. Fetch Global Metadata
      DocumentSnapshot globalDoc = await FirebaseFirestore.instance.collection('app_metadata').doc('notes_index').get();
      if (globalDoc.exists) {
        globalList = globalDoc['hierarchy'] as List<dynamic>;
      }

      // B. Fetch Private Metadata (Unique to Teacher)
      DocumentSnapshot privateDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('my_custom_topics')
          .doc('hierarchy_doc')
          .get();
      
      if (privateDoc.exists) {
        privateList = privateDoc['data'] as List<dynamic>;
      }

      // C. Merge (Private first so user sees their custom topics top)
      if(mounted) {
        setState(() {
          combinedHierarchy = [...privateList, ...globalList];
          _isLoading = false; 
        });
      }

    } catch (e) {
      debugPrint("Error loading hierarchy: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // 2️⃣ Delete Specific Topic
  void _deleteTopic(int index) {
    setState(() {
      _topicsList.removeAt(index);
    });
  }

  // 🔥 3️⃣ Add New Topic Logic
  void _addTopic() {
    String subj = _subjController.text.trim();
    String subSubj = _subSubjController.text.trim();
    String topic = _topicController.text.trim();
    String subTop = _subTopController.text.trim();

    if (subj.isEmpty || subSubj.isEmpty || topic.isEmpty || subTop.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are required")));
      return;
    }
    
    setState(() {
      _topicsList.add({
        'subject': subj,
        'subSubject': subSubj,
        'topic': topic,
        'subTopic': subTop,
        // IDs: Database se select kiya to wahi ID, warna Custom ID
        'subjId': selectedSubject?['id'] ?? 'cust_${DateTime.now().millisecondsSinceEpoch}',
        'subSubjId': selectedSubSubject?['id'] ?? 'cust_ss_${DateTime.now().millisecondsSinceEpoch}',
        'topicId': selectedTopic?['id'] ?? 'cust_t_${DateTime.now().millisecondsSinceEpoch}',
        'subTopId': selectedSubTopic?['id'] ?? 'cust_st_${DateTime.now().millisecondsSinceEpoch}',
        
        // Flag to save into private dictionary later
        'isCustom': selectedSubject == null 
      });
      
      // Reset Sheet Controllers
      _topicController.clear();
      _subTopController.clear();
      selectedTopic = null;
      selectedSubTopic = null;
    });
    Navigator.pop(context); 
  }

  // 4️⃣ Show Add Dialog
  void _showAddTopicSheet() {
    // Reset selections before opening
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
                _buildAutocomplete("Subject", _subjController, combinedHierarchy, (val) {
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
                    _topicController.clear(); _subTopController.clear();
                    selectedTopic = null; selectedSubTopic = null;
                  });
                }),

                // 3. Topic
                _buildAutocomplete("Topic", _topicController, selectedSubSubject?['topics'] ?? [], (val) {
                  setSheetState(() {
                    selectedTopic = val;
                    _subTopController.clear();
                    selectedSubTopic = null;
                  });
                }),

                // 4. Sub-Topic
                _buildAutocomplete("Sub-Topic", _subTopController, selectedTopic?['subTopics'] ?? [], (val) {
                  setSheetState(() => selectedSubTopic = val);
                }),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addTopic,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text("ADD TOPIC"),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // 🔥 5️⃣ Save Changes & Private Metadata
  void _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if(user == null) return;

    setState(() => _isLoading = true);
    try {
      // A. Save Public Schedule Update
      await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.examId)
          .collection('weeks')
          .doc(widget.weekId)
          .update({
        'weekTitle': _titleController.text.trim(),
        'scheduleData': _topicsList,
        // Update linked topics string array for quick viewing
        'linkedTopics': _topicsList.map((e) => "${e['topic']} (${e['subTopic']})").toList(),
      });

      // B. Save Custom Topics (Private Dictionary)
      await _savePrivateMetadata(user.uid);

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

  // 🔥 Helper: Save Private Metadata Logic
  Future<void> _savePrivateMetadata(String uid) async {
    List<dynamic> currentPrivateList = [];
    var docRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('my_custom_topics').doc('hierarchy_doc');
    
    var docSnap = await docRef.get();
    if (docSnap.exists) {
      currentPrivateList = List.from(docSnap['data']);
    }

    bool needsUpdate = false;

    for (var item in _topicsList) {
      // Check for Custom Items (added manually, not selected from list)
      if (item['isCustom'] == true) {
        var subjIndex = currentPrivateList.indexWhere((e) => e['name'] == item['subject']);
        
        // Agar Subject naya hai, toh pura structure add kar do
        if (subjIndex == -1) {
          currentPrivateList.add({
            'name': item['subject'],
            'id': item['subjId'],
            'subSubjects': [{
              'name': item['subSubject'],
              'id': item['subSubjId'],
              'topics': [{
                'name': item['topic'],
                'id': item['topicId'],
                'subTopics': [{
                  'name': item['subTopic'],
                  'id': item['subTopId']
                }]
              }]
            }]
          });
          needsUpdate = true;
        }
        // NOTE: Deep merging (Existing Subject me naya Topic add karna)
        // complex hota hai. Abhi ke liye hum sirf bilkul naye Subjects ko save kar rahe hain.
      }
    }

    if (needsUpdate) {
      await docRef.set({'data': currentPrivateList}, SetOptions(merge: true));
    }
  }

  // 6️⃣ Delete Week
  void _deleteWeek() async {
    bool confirm = await showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("Delete Week?"),
        content: const Text("This will delete this week and all its tests/data permanently."),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: ()=> Navigator.pop(c, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if(confirm) {
      // Deleting the document
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
          // Sync text if needed
          if (textController.text != controller.text && controller.text.isNotEmpty) {
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
              controller.text = val;
              // Reset selection if user types manually (implies custom)
              if(label == "Subject") selectedSubject = null;
              if(label == "Sub-Subject") selectedSubSubject = null;
            },
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
                  ElevatedButton.icon(
                    onPressed: _showAddTopicSheet, 
                    icon: const Icon(Icons.add_circle, size: 18),
                    label: const Text("Add Topic"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue),
                  )
                ],
              ),
              const Divider(),

              // List of Topics
              _topicsList.isEmpty 
              ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No topics added yet.")))
              : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topicsList.length,
                itemBuilder: (ctx, i) {
                  var item = _topicsList[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(item['topic'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${item['subject']} > ${item['subTopic']}"),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                  child: const Text("SAVE CHANGES", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
    );
  }
}
