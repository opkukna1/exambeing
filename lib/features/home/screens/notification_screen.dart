import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ IMPORT: Upar banayi gayi file ko import karein
import 'package:exambeing/features/admin/screens/admin_notification_form.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // 🔒 ADMIN ID HARDCODED
  final String adminEmail = "opsiddh42@gmail.com"; 
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _markNotificationsAsRead();
  }

  void _checkAdmin() {
    final user = FirebaseAuth.instance.currentUser;
    // Lowercase convert karke check kar rahe hain taaki galti na ho
    if (user != null && user.email?.toLowerCase() == adminEmail.toLowerCase()) {
      setState(() => isAdmin = true);
    }
  }

  Future<void> _markNotificationsAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_notification_check', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _deleteNotification(String id) async {
    // Delete confirm dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Notification?"),
        content: const Text("Are you sure you want to remove this?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('notifications').doc(id).delete();
            }, 
            child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Could not launch $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Notifications"), elevation: 0),
      
      // 🔥 FAB: Sirf Admin (opisiddh42@gmail.com) ko dikhega
      floatingActionButton: isAdmin 
        ? FloatingActionButton.extended(
            backgroundColor: Colors.deepPurple,
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminNotificationForm()));
            },
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Create New", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ) 
        : null,

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notifications').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("No notifications yet", style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final String title = data['title'] ?? "Notice";
              final String body = data['body'] ?? "";
              final String btnText = data['buttonText'] ?? "";
              final String link = data['link'] ?? "";
              final Timestamp? ts = data['timestamp'];
              final String time = ts != null ? DateFormat('dd MMM, hh:mm a').format(ts.toDate()) : "";

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          
                          // 🔒 ADMIN ONLY: Edit & Delete Buttons
                          if (isAdmin)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (c) => AdminNotificationForm(docId: doc.id, existingData: data)
                                    ));
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                  onPressed: () => _deleteNotification(doc.id),
                                ),
                              ],
                            )
                          else
                            Text(time, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      Text(body, style: TextStyle(color: Colors.grey[700], fontSize: 14)),

                      if (btnText.isNotEmpty && link.isNotEmpty) ...[
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade800,
                              elevation: 0
                            ),
                            icon: const Icon(Icons.link),
                            onPressed: () => _launchURL(link),
                            label: Text(btnText),
                          ),
                        )
                      ]
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
