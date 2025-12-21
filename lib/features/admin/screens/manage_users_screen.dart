import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 Auth Import
import 'package:intl/intl.dart';

class ManageUsersScreen extends StatefulWidget {
  final String testId;
  final String testName;

  const ManageUsersScreen({
    super.key, 
    required this.testId, 
    required this.testName
  });

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final TextEditingController _emailController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isVerifying = true; // 🔥 Shuru mein verify karega

  @override
  void initState() {
    super.initState();
    _checkOwnership(); // 🔥 Page load hote hi Security Check
  }

  // 🔒 SECURITY CHECK FUNCTION
  Future<void> _checkOwnership() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showErrorAndExit("Please login first.");
      return;
    }

    try {
      // 1. Fetch Test Details
      DocumentSnapshot testDoc = await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .get();

      if (!testDoc.exists) {
        _showErrorAndExit("Test not found.");
        return;
      }

      Map<String, dynamic> testData = testDoc.data() as Map<String, dynamic>;
      String creatorId = testData['createdBy'] ?? '';

      // 2. Check if Current User is the Creator
      if (creatorId != user.uid) {
        _showErrorAndExit("Access Denied: You can only manage users for YOUR own tests.");
        return;
      }

      // 3. Double Check Host Status (Optional but Safe)
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      String isHost = (userDoc['host'] ?? 'no').toString().toLowerCase();
      if (isHost != 'yes') {
        _showErrorAndExit("Access Denied: You are not authorized as a Host.");
        return;
      }

      // ✅ All Good
      if (mounted) {
        setState(() {
          _isVerifying = false; // Loading hata do
        });
      }

    } catch (e) {
      _showErrorAndExit("Error verifying permissions: $e");
    }
  }

  void _showErrorAndExit(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3))
    );
    Navigator.pop(context); // Screen band kar do
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // 📅 1. DATE PICKER FUNCTION
  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      DateTime endOfDay = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      setState(() => _selectedDate = endOfDay);
    }
  }

  // ➕ 2. ADD USER FUNCTION
  Future<void> _addUser() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Student ki Email ID likhein!")));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expiry Date select karein!")));
      return;
    }

    setState(() => _isLoading = true);
    
    String email = _emailController.text.trim().toLowerCase(); 

    try {
      await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .collection('allowed_users')
          .doc(email)
          .set({
        'email': email,
        'expiryDate': Timestamp.fromDate(_selectedDate!),
        'addedAt': FieldValue.serverTimestamp(),
      });

      _emailController.clear();
      setState(() => _selectedDate = null);
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User Successfully Added! ✅"), backgroundColor: Colors.green)
        );
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // 🗑️ 3. REMOVE USER FUNCTION
  Future<void> _removeUser(String email) async {
    try {
      await FirebaseFirestore.instance
          .collection('tests')
          .doc(widget.testId)
          .collection('allowed_users')
          .doc(email)
          .delete();
          
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User removed access."), duration: Duration(seconds: 1))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 Loading Screen Jab tak Permission Check ho rha hai
    if (_isVerifying) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Manage Users 👥", style: TextStyle(fontSize: 18)),
            Text(widget.testName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ---------------------------
          // 🟢 SECTION 1: ADD USER FORM
          // ---------------------------
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300))
            ),
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Student Email",
                    hintText: "example@gmail.com",
                    prefixIcon: const Icon(Icons.email, color: Colors.deepPurple),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                
                // Date Picker Button
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade600),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.deepPurple),
                        const SizedBox(width: 10),
                        Text(
                          _selectedDate == null 
                              ? "Select Expiry Date" 
                              : "Valid Till: ${DateFormat('dd MMM yyyy').format(_selectedDate!)}",
                          style: TextStyle(
                            color: _selectedDate == null ? Colors.grey.shade700 : Colors.black,
                            fontWeight: FontWeight.w500
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Allow Button
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addUser,
                    icon: _isLoading ? const SizedBox() : const Icon(Icons.check_circle),
                    label: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text("ALLOW ACCESS"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                  ),
                )
              ],
            ),
          ),
          
          // ---------------------------
          // 🔵 SECTION 2: USERS LIST
          // ---------------------------
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(
              children: [
                Icon(Icons.list, size: 20, color: Colors.grey),
                SizedBox(width: 5),
                Text("Allowed Students List", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tests')
                  .doc(widget.testId)
                  .collection('allowed_users')
                  .orderBy('addedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                if (snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text("No students added yet.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    
                    DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
                    bool isExpired = DateTime.now().isAfter(expiry);

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isExpired ? Colors.red.shade100 : Colors.green.shade100,
                          child: Icon(
                            isExpired ? Icons.block : Icons.check, 
                            color: isExpired ? Colors.red : Colors.green
                          ),
                        ),
                        title: Text(data['email'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          isExpired 
                              ? "Expired: ${DateFormat('dd MMM yyyy').format(expiry)}" 
                              : "Valid till: ${DateFormat('dd MMM yyyy').format(expiry)}",
                          style: TextStyle(
                            color: isExpired ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w500
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _removeUser(data['email']),
                        ),
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
