import 'package:flutter/material.dart';

// ✅ CORRECT IMPORT
import 'package:exambeing/features/notes/screens/notes_online_view_screen.dart'; 

class LinkedNotesScreen extends StatelessWidget {
  final String weekTitle;
  final List<dynamic> scheduleData; 

  const LinkedNotesScreen({
    super.key, 
    required this.weekTitle, 
    required this.scheduleData
  });

  // 🔥 1. POPUP DIALOG LOGIC
  void _showReadingOptions(BuildContext context, Map<String, dynamic> topicData) {
    // Default values
    String selectedMode = 'Detailed';
    String selectedLang = 'Hindi';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Column(
                children: [
                  const Icon(Icons.settings_suggest, size: 40, color: Colors.deepPurple),
                  const SizedBox(height: 10),
                  const Text("Reading Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Topic: ${topicData['topic']}", style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
                  const Divider(height: 20),
                  
                  // --- MODE DROPDOWN ---
                  const Text("Select Mode:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: DropdownButton<String>(
                      value: selectedMode,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: ['Detailed', 'Revision', 'Short'].map((String val) {
                        return DropdownMenuItem(value: val, child: Text(val));
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedMode = val!);
                      },
                    ),
                  ),

                  const SizedBox(height: 15),

                  // --- LANGUAGE DROPDOWN ---
                  const Text("Select Language:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: DropdownButton<String>(
                      value: selectedLang,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: ['Hindi', 'English', 'Hinglish'].map((String val) {
                        return DropdownMenuItem(value: val, child: Text(val));
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedLang = val!);
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  onPressed: () {
                    Navigator.pop(ctx); 

                    // 🔥 UPDATED NAVIGATION LOGIC
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => NotesOnlineViewScreen( 
                          // ✅ FIX: Sara data ab ek 'data' map me jayega
                          data: {
                            'subjId': topicData['subjId'],     
                            'subSubjId': topicData['subSubjId'],
                            'topicId': topicData['topicId'],
                            'subTopId': topicData['subTopId'],
                            'displayName': topicData['subTopic'], 
                            'topicName': topicData['topic'],
                            'mode': selectedMode,
                            'lang': selectedLang, // Note key: 'lang' used in map
                          }
                        ),
                      ),
                    );
                  },
                  child: const Text("OPEN NOTES 🚀"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("$weekTitle Notes"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: scheduleData.isEmpty
          ? const Center(child: Text("No notes linked yet."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scheduleData.length,
              itemBuilder: (context, index) {
                var item = scheduleData[index] as Map<String, dynamic>;

                return Card(
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6)
                          ),
                          child: Text(
                            "${item['subject']}  •  ${item['subSubject']}",
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        Text(
                          item['topic'],
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Focus: ${item['subTopic']}",
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),

                        const SizedBox(height: 15),
                        const Divider(),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showReadingOptions(context, item),
                            icon: const Icon(Icons.menu_book, size: 18),
                            label: const Text("READ NOTES"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
