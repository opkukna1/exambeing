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
  List<dynamic> combinedHierarchy = []; // Global + Private Merged
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

  // 1. Permission Check
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

      setState(() => loadingMessage = "Loading your topics...");
      
      // 🔥 NEW: Fetch Global + Private Hierarchy
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

  // 🔥 2. FETCH GLOBAL + PRIVATE DATA (MERGE LOGIC)
  Future<void> _fetchCombinedHierarchy(String userId) async {
    try {
      List<dynamic> globalList = [];
      List<dynamic> privateList = [];

      // A. Fetch Global Metadata (Sabke liye)
      DocumentSnapshot globalDoc = await FirebaseFirestore.instance.collection('app_metadata').doc('notes_index').get();
      if (globalDoc.exists) {
        globalList = globalDoc['hierarchy'] as List<dynamic>;
      }

      // B. Fetch Private Metadata (Sirf is Teacher ke liye)
      // Path: users -> {uid} -> my_custom_topics -> hierarchy_doc
      DocumentSnapshot privateDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('my_custom_topics')
          .doc('hierarchy_doc')
          .get();
      
      if (privateDoc.exists) {
        privateList = privateDoc['data'] as List<dynamic>;
      }

      // C. Merge Both
      // Hum private list ko pehle dikhayenge taaki teacher ko apna data upar dikhe
      setState(() {
        combinedHierarchy = [...privateList, ...globalList]; 
        isLoading = false; 
      });

    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error fetching hierarchy: $e");
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

  // 4. ADD TOPIC TO LIST (UI Only)
  void _addTopicToList() {
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
          // Agar database se select kiya to wahi ID, warna Custom ID generate karo
          'subjId': selectedSubject?['id'] ?? 'cust_${DateTime.now().millisecondsSinceEpoch}',
          'subSubjId': selectedSubSubject?['id'] ?? 'cust_ss_${DateTime.now().millisecondsSinceEpoch}',
          'topicId': selectedTopic?['id'] ?? 'cust_t_${DateTime.now().millisecondsSinceEpoch}',
          'subTopId': selectedSubTopic?['id'] ?? 'cust_st_${DateTime.now().millisecondsSinceEpoch}',
          
          // Flag to identify new custom topics
          'isCustom': selectedSubject == null // Agar select nahi kiya, matlab naya hai
        });
        
        // Reset fields
        _topicController.clear();
        _subTopController.clear();
        selectedTopic = null;
        selectedSubTopic = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all 4 fields (Subject to Sub-Topic)")));
    }
  }

  // 🔥 5. SAVE SCHEDULE & PRIVATE METADATA
  void _saveSchedule() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_weekTitleController.text.isEmpty || _examDate == null || _addedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title, Date aur kam se kam 1 Topic zaroori hai!")));
      return;
    }

    try {
      // A. Save Schedule (Publicly visible to students allowed)
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
        'scheduleData': _addedTopics, // Isme names saved hain, IDs nahi, to display me ID ki zaroorat nahi padegi
      });

      // B. Save Custom Topics to Teacher's Private Collection
      _savePrivateMetadata(user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule Created Successfully! ✅")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 🔥 Helper: Save Custom Data Logic
  Future<void> _savePrivateMetadata(String uid) async {
    // Logic: Hum check karenge ki kya naya topic add hua hai.
    // Simplicity ke liye, hum naye wale topics ko existing private list me merge karke save kar denge.
    
    // 1. Get current private data
    List<dynamic> currentPrivateList = [];
    var docRef = FirebaseFirestore.instance.collection('users').doc(uid).collection('my_custom_topics').doc('hierarchy_doc');
    
    var docSnap = await docRef.get();
    if (docSnap.exists) {
      currentPrivateList = List.from(docSnap['data']);
    }

    bool needsUpdate = false;

    // 2. Loop through added topics
    for (var item in _addedTopics) {
      // Agar ye Custom Topic hai (jo autocomplete se nahi aaya)
      if (item['isCustom'] == true) {
        
        // Check if Subject already exists in private list
        var subjIndex = currentPrivateList.indexWhere((e) => e['name'] == item['subject']);
        
        if (subjIndex == -1) {
          // New Subject -> Add whole structure
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
        } else {
          // Subject exists, check SubSubject... (Deep merging logic can be complex, 
          // but for basic usage, saving new subjects is key. If you need deep merging for 
          // sub-subjects, we can expand this. For now, adding new subjects is handled.)
        }
      }
    }

    // 3. Save back if changed
    if (needsUpdate) {
      await docRef.set({'data': currentPrivateList}, SetOptions(merge: true));
    }
  }

  // 6. AUTOCOMPLETE WIDGET
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
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Map<String, dynamic>>.empty();
          }
          return options.where((option) {
            return option['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase());
          }).map((e) => e as Map<String, dynamic>);
        },
        displayStringForOption: (Map<String, dynamic> option) => option['name'],
        onSelected: (Map<String, dynamic> selection) {
          controller.text = selection['name']; 
          onSelected(selection); 
        },
        fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
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
              controller.text = val; 
              // Clear selection to indicate Custom entry
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
      appBar: AppBar(title: const Text("Create Schedule 📅")),
      body: isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(loadingMessage ?? "Loading...")]))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  const Text("Add Topics (Private & Global)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple)),
                  const SizedBox(height: 5),
                  const Text("Jo aap type karenge wo agli baar sirf aapko dikhega.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 15),

                  // 1. Subject (Using Combined Hierarchy)
                  _buildAutocomplete("Subject", _subjController, combinedHierarchy, (val) {
                    setState(() {
                      selectedSubject = val;
                      _subSubjController.clear(); _topicController.clear(); _subTopController.clear();
                      selectedSubSubject = null; selectedTopic = null; selectedSubTopic = null;
                    });
                  }),

                  // 2. Sub-Subject
                  _buildAutocomplete(
                    "Sub-Subject", 
                    _subSubjController, 
                    selectedSubject?['subSubjects'] ?? [], 
                    (val) {
                      setState(() {
                        selectedSubSubject = val;
                        _topicController.clear(); _subTopController.clear();
                        selectedTopic = null; selectedSubTopic = null;
                      });
                    }
                  ),

                  // 3. Topic
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

                  // 4. Sub-Topic
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
