import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageUsersScreen extends StatefulWidget {
  final String testId;
  final String testName;
  final String examId;
  final String weekId;

  const ManageUsersScreen({
    super.key,
    required this.testId,
    required this.testName,
    required this.examId,
    required this.weekId,
  });

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  // 🔥 GRANT ACCESS (Add User to Test)
  Future<void> _grantAccess() async {
    if (_emailController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    String emailKey = _emailController.text.trim().toLowerCase();

    try {
      // Save to specific path: study_schedules -> exam -> weeks -> week -> tests -> test -> allowed_users
      await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.examId)
          .collection('weeks')
          .doc(widget.weekId)
          .collection('tests')
          .doc(widget.testId)
          .collection('allowed_users')
          .doc(emailKey) // 🔥 Document ID is the Email itself (Duplicate nahi hoga)
          .set({
        'email': emailKey,
        'grantedAt': FieldValue.serverTimestamp(),
        // Default 1 Year Validity
        'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365))), 
      });

      _emailController.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Granted!")));

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🚫 REVOKE ACCESS (Delete User from Test)
  Future<void> _revokeAccess(String emailDocId) async {
    try {
      await FirebaseFirestore.instance
          .collection('study_schedules')
          .doc(widget.examId)
          .collection('weeks')
          .doc(widget.weekId)
          .collection('tests')
          .doc(widget.testId)
          .collection('allowed_users')
          .doc(emailDocId)
          .delete();
          
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Revoked.")));
    } catch (e) {
      // Error handling
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 🔥 FIX: AppBar doesn't support subtitle, so we use a Column inside title
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Test Permissions 🔐"),
            Text(widget.testName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ➕ ADD USER SECTION
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Grant Access to Student", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          hintText: "Enter Student Email",
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _grantAccess,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                      child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Allow"),
                    )
                  ],
                ),
                const SizedBox(height: 5),
                const Text("Note: Email must match user's login email exactly.", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),

          const Divider(height: 1),

          // 📋 LIST OF ALLOWED USERS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('study_schedules')
                  .doc(widget.examId)
                  .collection('weeks')
                  .doc(widget.weekId)
                  .collection('tests')
                  .doc(widget.testId)
                  .collection('allowed_users')
                  .orderBy('grantedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open, size: 50, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("No students added yet.\nEveryone else will see 'Locked'.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                var docs = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String email = data['email'] ?? docs[index].id;
                    DateTime? expiry;
                    if (data['expiryDate'] != null) {
                      expiry = (data['expiryDate'] as Timestamp).toDate();
                    }

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green, 
                        child: Icon(Icons.check, color: Colors.white, size: 16)
                      ),
                      title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(expiry != null 
                        ? "Valid till: ${DateFormat('dd MMM yyyy').format(expiry)}" 
                        : "No Expiry"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _revokeAccess(docs[index].id),
                        tooltip: "Revoke Access",
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
