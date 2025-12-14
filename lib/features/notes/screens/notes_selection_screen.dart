import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class NotesSelectionScreen extends StatefulWidget {
  const NotesSelectionScreen({super.key});

  @override
  State<NotesSelectionScreen> createState() => _NotesSelectionScreenState();
}

class _NotesSelectionScreenState extends State<NotesSelectionScreen> {
  // --- Admin Logic ---
  final String _adminEmail = "opsiddh42@gmail.com"; // Apna email yahan dalein
  bool _isAdmin = false;

  // --- Data Variables ---
  List<dynamic> fullHierarchy = [];
  bool isLoading = true;

  // --- Selections (Stores Full Object: ID + Name) ---
  Map<String, dynamic>? selectedSubject;
  Map<String, dynamic>? selectedSubSubject;
  Map<String, dynamic>? selectedTopic;
  Map<String, dynamic>? selectedSubTopic;

  // --- Settings ---
  String selectedLang = 'Hindi';
  String selectedMode = 'Detailed';

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _fetchHierarchy();
  }

  void _checkAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email == _adminEmail) {
      setState(() => _isAdmin = true);
    }
  }

  Future<void> _fetchHierarchy() async {
    try {
      // Sirf 1 Read me pura menu load hoga
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('app_metadata')
          .doc('notes_index')
          .get();

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

  // --- Lists Filter Logic ---
  List<dynamic> getSubSubjects() => selectedSubject?['subSubjects'] ?? [];
  List<dynamic> getTopics() => selectedSubSubject?['topics'] ?? [];
  List<dynamic> getSubTopics() => selectedTopic?['subTopics'] ?? [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Select Notes 📚", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      
      // 🔥 SIRF ADMIN KO YEH BUTTON DIKHEGA
      floatingActionButton: _isAdmin 
        ? FloatingActionButton.extended(
            onPressed: () {
              // Admin Upload Screen par jayein
              context.push('/admin-smart-upload');
            },
            label: const Text("Add New Notes"),
            icon: const Icon(Icons.add_circle),
            backgroundColor: Colors.redAccent,
          )
        : null,

      body: isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Filter Topics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // 1. SUBJECT
                  _buildDropdown("विषय (Subject)", fullHierarchy, selectedSubject, (val) {
                    setState(() {
                      selectedSubject = val;
                      selectedSubSubject = null;
                      selectedTopic = null;
                      selectedSubTopic = null;
                    });
                  }),

                  // 2. SUB-SUBJECT
                  _buildDropdown("उप-विषय (Sub-Subject)", getSubSubjects(), selectedSubSubject, (val) {
                    setState(() {
                      selectedSubSubject = val;
                      selectedTopic = null;
                      selectedSubTopic = null;
                    });
                  }),

                  // 3. TOPIC
                  _buildDropdown("टॉपिक (Topic)", getTopics(), selectedTopic, (val) {
                    setState(() {
                      selectedTopic = val;
                      selectedSubTopic = null;
                    });
                  }),

                  // 4. SUB-TOPIC
                  _buildDropdown("उप-टॉपिक (Sub-Topic)", getSubTopics(), selectedSubTopic, (val) {
                    setState(() => selectedSubTopic = val);
                  }),

                  const Divider(height: 40),

                  // 5. SETTINGS (Language & Mode)
                  const Text("Reading Preferences", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedLang,
                          decoration: _inputDeco("Language"),
                          items: const [
                            DropdownMenuItem(value: "Hindi", child: Text("Hindi 🇮🇳")),
                            DropdownMenuItem(value: "English", child: Text("English 🇬🇧")),
                          ],
                          onChanged: (v) => setState(() => selectedLang = v!),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedMode,
                          decoration: _inputDeco("Mode"),
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

                  const SizedBox(height: 40),

                  // 6. GENERATE BUTTON (User ke liye)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (selectedSubTopic != null)
                          ? () {
                              // ✅ UPDATED PATH: Ab ye nayi wali screen par jayega
                              context.push('/notes-online-view', extra: {
                                // IDs for Fetching Content
                                'subjId': selectedSubject!['id'],
                                'subSubjId': selectedSubSubject!['id'],
                                'topicId': selectedTopic!['id'],
                                'subTopId': selectedSubTopic!['id'],
                                
                                // Names for Display (Hindi)
                                'displayName': selectedSubTopic!['name'],
                                'topicName': selectedTopic!['name'],
                                
                                // Settings
                                'lang': selectedLang,
                                'mode': selectedMode,
                              });
                            }
                          : null, // Disable if incomplete
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 4,
                      ),
                      child: const Text("GENERATE NOTES 🚀", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildDropdown(String hint, List<dynamic> items, Map<String, dynamic>? value, Function(Map<String, dynamic>?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<Map<String, dynamic>>(
        value: value,
        decoration: _inputDeco(hint),
        isExpanded: true,
        hint: Text("Select $hint"),
        items: items.map((item) {
          return DropdownMenuItem<Map<String, dynamic>>(
            value: item,
            child: Text(item['name'], overflow: TextOverflow.ellipsis), // Hindi Name show karega
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
