import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSmartUploadScreen extends StatefulWidget {
  const AdminSmartUploadScreen({super.key});

  @override
  State<AdminSmartUploadScreen> createState() => _AdminSmartUploadScreenState();
}

class _AdminSmartUploadScreenState extends State<AdminSmartUploadScreen> {
  // --- MASTER DATA ---
  List<dynamic> fullHierarchy = [];
  bool isLoading = true;

  // --- SELECTIONS ---
  Map<String, dynamic>? selectedSubject;
  Map<String, dynamic>? selectedSubSubject;
  Map<String, dynamic>? selectedTopic;
  Map<String, dynamic>? selectedSubTopic;

  // --- ADD NEW MODES ---
  bool isAddingSubject = false;
  bool isAddingSubSubject = false;
  bool isAddingTopic = false;
  bool isAddingSubTopic = false;

  // --- TEXT CONTROLLERS (For New Items) ---
  final _newSubjId = TextEditingController();
  final _newSubjName = TextEditingController();
  
  final _newSubSubjId = TextEditingController();
  final _newSubSubjName = TextEditingController();
  
  final _newTopicId = TextEditingController();
  final _newTopicName = TextEditingController();
  
  final _newSubTopId = TextEditingController();
  final _newSubTopName = TextEditingController();

  // --- CONTENT & SETTINGS ---
  final _contentController = TextEditingController();
  String selectedLang = 'Hindi';
  String selectedMode = 'Detailed';
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchHierarchy();
  }

  // 1. Load Data from Firebase
  Future<void> _fetchHierarchy() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('app_metadata').doc('notes_index').get();
      if (doc.exists) {
        setState(() {
          fullHierarchy = doc['hierarchy'] as List<dynamic>;
          isLoading = false;
        });
      } else {
        setState(() {
          fullHierarchy = []; // Empty DB handling
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // --- UPLOAD LOGIC ---
  Future<void> _uploadNote() async {
    setState(() => isUploading = true);
    try {
      // Step 1: IDs aur Names extract karna
      String subjId = isAddingSubject ? _newSubjId.text.trim() : (selectedSubject?['id'] ?? '');
      String subjName = isAddingSubject ? _newSubjName.text.trim() : (selectedSubject?['name'] ?? '');

      String subSubjId = isAddingSubSubject ? _newSubSubjId.text.trim() : (selectedSubSubject?['id'] ?? '');
      String subSubjName = isAddingSubSubject ? _newSubSubjName.text.trim() : (selectedSubSubject?['name'] ?? '');

      String topicId = isAddingTopic ? _newTopicId.text.trim() : (selectedTopic?['id'] ?? '');
      String topicName = isAddingTopic ? _newTopicName.text.trim() : (selectedTopic?['name'] ?? '');

      String subTopId = isAddingSubTopic ? _newSubTopId.text.trim() : (selectedSubTopic?['id'] ?? '');
      String subTopName = isAddingSubTopic ? _newSubTopName.text.trim() : (selectedSubTopic?['name'] ?? '');

      // Validation
      if (subjId.isEmpty || subSubjId.isEmpty || topicId.isEmpty || subTopId.isEmpty) {
        throw "All IDs must be filled! Check your selection.";
      }

      // Step 2: Hierarchy Update (Local Logic)
      List<dynamic> updatedHierarchy = List.from(fullHierarchy);

      // A. Subject
      Map<String, dynamic> subjectMap;
      if (isAddingSubject) {
        subjectMap = {'id': subjId, 'name': subjName, 'subSubjects': []};
        updatedHierarchy.add(subjectMap);
      } else {
        subjectMap = updatedHierarchy.firstWhere((e) => e['id'] == subjId, orElse: () => {});
      }

      // B. Sub-Subject
      List<dynamic> subList = subjectMap['subSubjects'] ?? [];
      Map<String, dynamic> subSubjectMap;
      if (isAddingSubSubject) {
        subSubjectMap = {'id': subSubjId, 'name': subSubjName, 'topics': []};
        subList.add(subSubjectMap);
      } else {
        subSubjectMap = subList.firstWhere((e) => e['id'] == subSubjId, orElse: () => {});
      }

      // C. Topic
      List<dynamic> topicList = subSubjectMap['topics'] ?? [];
      Map<String, dynamic> topicMap;
      if (isAddingTopic) {
        topicMap = {'id': topicId, 'name': topicName, 'subTopics': []};
        topicList.add(topicMap);
      } else {
        topicMap = topicList.firstWhere((e) => e['id'] == topicId, orElse: () => {});
      }

      // D. Sub-Topic (Leaf)
      List<dynamic> leafList = topicMap['subTopics'] ?? [];
      if (isAddingSubTopic) {
        bool exists = leafList.any((e) => e['id'] == subTopId);
        if (!exists) {
          leafList.add({'id': subTopId, 'name': subTopName});
        }
      }

      // Ensure lists are linked back (Reference safety)
      topicMap['subTopics'] = leafList;
      subSubjectMap['topics'] = topicList;
      subjectMap['subSubjects'] = subList;

      // Step 3: Firebase Save (Metadata)
      await FirebaseFirestore.instance.collection('app_metadata').doc('notes_index').set({
        'hierarchy': updatedHierarchy
      });

      // Step 4: Content Save
      String contentDocId = "${subjId}_${subSubjId}_${topicId}_${subTopId}".toLowerCase();
      String fieldName = "${selectedMode.toLowerCase().split(' ')[0]}_${selectedLang == 'Hindi' ? 'hi' : 'en'}";

      await FirebaseFirestore.instance.collection('notes_content').doc(contentDocId).set({
        'subject': subjName,
        'subTopic': subTopName,
        fieldName: _contentController.text,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Success
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Saved Successfully!"), backgroundColor: Colors.green));
      _contentController.clear();
      
      // Update local state to reflect additions
      setState(() {
        fullHierarchy = updatedHierarchy;
        // Logic to keep selection valid is complex, simpler to reset adding flags
        if(isAddingSubject) { isAddingSubject = false; selectedSubject = subjectMap; }
        if(isAddingSubSubject) { isAddingSubSubject = false; selectedSubSubject = subSubjectMap; }
        if(isAddingTopic) { isAddingTopic = false; selectedTopic = topicMap; }
        if(isAddingSubTopic) { isAddingSubTopic = false; }
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Smart Upload 🧠"), backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // 1. SUBJECT
            _buildSmartRow(
              label: "Subject",
              isAdding: isAddingSubject,
              items: fullHierarchy,
              selectedItem: selectedSubject,
              idController: _newSubjId,
              nameController: _newSubjName,
              onChanged: (val) {
                setState(() {
                  selectedSubject = val;
                  selectedSubSubject = null; isAddingSubSubject = false;
                  selectedTopic = null; isAddingTopic = false;
                  selectedSubTopic = null; isAddingSubTopic = false;
                });
              },
              onAddToggle: () => setState(() => isAddingSubject = !isAddingSubject),
            ),

            // 2. SUB-SUBJECT
            if (selectedSubject != null || isAddingSubject)
              _buildSmartRow(
                label: "Sub-Subject",
                isAdding: isAddingSubSubject,
                items: isAddingSubject ? [] : (selectedSubject!['subSubjects'] as List<dynamic>? ?? []),
                selectedItem: selectedSubSubject,
                idController: _newSubSubjId,
                nameController: _newSubSubjName,
                onChanged: (val) {
                  setState(() {
                    selectedSubSubject = val;
                    selectedTopic = null; isAddingTopic = false;
                    selectedSubTopic = null; isAddingSubTopic = false;
                  });
                },
                onAddToggle: () => setState(() => isAddingSubSubject = !isAddingSubSubject),
              ),

            // 3. TOPIC
            if (selectedSubSubject != null || isAddingSubSubject)
              _buildSmartRow(
                label: "Topic",
                isAdding: isAddingTopic,
                items: isAddingSubSubject ? [] : (selectedSubSubject!['topics'] as List<dynamic>? ?? []),
                selectedItem: selectedTopic,
                idController: _newTopicId,
                nameController: _newTopicName,
                onChanged: (val) {
                  setState(() {
                    selectedTopic = val;
                    selectedSubTopic = null; isAddingSubTopic = false;
                  });
                },
                onAddToggle: () => setState(() => isAddingTopic = !isAddingTopic),
              ),

            // 4. SUB-TOPIC
            if (selectedTopic != null || isAddingTopic)
              _buildSmartRow(
                label: "Sub-Topic",
                isAdding: isAddingSubTopic,
                items: isAddingTopic ? [] : (selectedTopic!['subTopics'] as List<dynamic>? ?? []),
                selectedItem: selectedSubTopic,
                idController: _newSubTopId,
                nameController: _newSubTopName,
                onChanged: (val) => setState(() => selectedSubTopic = val),
                onAddToggle: () => setState(() => isAddingSubTopic = !isAddingSubTopic),
              ),

            const Divider(thickness: 2, height: 40),

            // 5. SETTINGS
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedLang,
                    decoration: const InputDecoration(labelText: "Language", border: OutlineInputBorder()),
                    items: const [DropdownMenuItem(value: "Hindi", child: Text("Hindi 🇮🇳")), DropdownMenuItem(value: "English", child: Text("English 🇬🇧"))],
                    onChanged: (v) => setState(() => selectedLang = v!),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedMode,
                    decoration: const InputDecoration(labelText: "Mode", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: "Detailed", child: Text("Detailed 📖")),
                      DropdownMenuItem(value: "Revision", child: Text("Revision 🧠")),
                      DropdownMenuItem(value: "Short", child: Text("Short ⚡")),
                    ],
                    onChanged: (v) => setState(() => selectedMode = v!),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            TextField(
              controller: _contentController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: "Notes Content (HTML)",
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
                hintText: "<h1>Title</h1><p>Description...</p>",
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: isUploading ? null : _uploadNote,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                icon: isUploading ? const SizedBox() : const Icon(Icons.cloud_upload),
                label: isUploading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("UPLOAD & SAVE", style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartRow({
    required String label,
    required bool isAdding,
    required List<dynamic> items,
    required Map<String, dynamic>? selectedItem,
    required TextEditingController idController,
    required TextEditingController nameController,
    required Function(Map<String, dynamic>?) onChanged,
    required VoidCallback onAddToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              TextButton.icon(
                onPressed: onAddToggle,
                icon: Icon(isAdding ? Icons.close : Icons.add, size: 18),
                label: Text(isAdding ? "Cancel" : "Add New"),
                style: TextButton.styleFrom(foregroundColor: isAdding ? Colors.red : Colors.blue),
              )
            ],
          ),
          
          if (isAdding)
            Row(
              children: [
                Expanded(flex: 1, child: TextField(controller: idController, decoration: InputDecoration(labelText: "ID (eg. history)", isDense: true, border: const OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: TextField(controller: nameController, decoration: InputDecoration(labelText: "Name (eg. इतिहास)", isDense: true, border: const OutlineInputBorder()))),
              ],
            )
          else
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Map<String, dynamic>>(
                  value: selectedItem,
                  hint: Text("Select $label"),
                  isExpanded: true,
                  items: items.map((item) => DropdownMenuItem<Map<String, dynamic>>(value: item, child: Text(item['name']))).toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
