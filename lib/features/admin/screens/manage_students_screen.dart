import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  
  // 🗑️ DELETE STUDENT
  void _deleteStudent(String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete User?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('users').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Deleted")));
    }
  }

  // 📝 EDIT/UPDATE STUDENT
  void _editStudent(String docId, Map<String, dynamic> currentData) {
    TextEditingController nameCtrl = TextEditingController(text: currentData['name']);
    TextEditingController emailCtrl = TextEditingController(text: currentData['email']);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Edit Student"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(docId).update({
                'name': nameCtrl.text,
                'email': emailCtrl.text,
              });
              Navigator.pop(c);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  // ➕ ADD STUDENT (Manually create record)
  void _addStudent() {
    TextEditingController nameCtrl = TextEditingController();
    TextEditingController emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Add New Student"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Note: This only adds a record. User must sign up with this email.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (emailCtrl.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('users').add({
                  'name': nameCtrl.text,
                  'email': emailCtrl.text,
                  'isAllowed': true, // Default allowed
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(c);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Students 👥"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _addStudent,
            tooltip: "Add Student Record",
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').orderBy('email').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var users = snapshot.data!.docs;
          if (users.isEmpty) return const Center(child: Text("No users found."));

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var doc = users[index];
              var data = doc.data() as Map<String, dynamic>;
              bool isAllowed = data['isAllowed'] ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isAllowed ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    child: Icon(Icons.person, color: isAllowed ? Colors.green : Colors.red),
                  ),
                  title: Text(data['name'] ?? 'No Name'),
                  subtitle: Text(data['email'] ?? 'No Email'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Toggle Permission
                      Switch(
                        value: isAllowed,
                        activeColor: Colors.green,
                        onChanged: (val) {
                          FirebaseFirestore.instance.collection('users').doc(doc.id).update({'isAllowed': val});
                        },
                      ),
                      // Edit Button
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editStudent(doc.id, data),
                      ),
                      // Delete Button
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteStudent(doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
