import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationForm extends StatefulWidget {
  final String? docId; // Edit ke liye ID
  final Map<String, dynamic>? existingData; // Edit ke liye purana data

  const AdminNotificationForm({super.key, this.docId, this.existingData});

  @override
  State<AdminNotificationForm> createState() => _AdminNotificationFormState();
}

class _AdminNotificationFormState extends State<AdminNotificationForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _btnNameController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Edit mode check
    if (widget.existingData != null) {
      _titleController.text = widget.existingData!['title'] ?? '';
      _bodyController.text = widget.existingData!['body'] ?? '';
      _btnNameController.text = widget.existingData!['buttonText'] ?? '';
      _linkController.text = widget.existingData!['link'] ?? '';
    }
  }

  Future<void> _saveNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final data = {
      'title': _titleController.text.trim(),
      'body': _bodyController.text.trim(),
      'buttonText': _btnNameController.text.trim(),
      'link': _linkController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.docId == null) {
        // Create New
        await FirebaseFirestore.instance.collection('notifications').add(data);
      } else {
        // Update
        await FirebaseFirestore.instance.collection('notifications').doc(widget.docId).update(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.docId == null ? "Create Notification" : "Edit Notification")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title (e.g., New Quiz Added)", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(labelText: "Body (Details)", border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _btnNameController,
                decoration: const InputDecoration(labelText: "Button Name (e.g., Join Telegram)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(labelText: "Link URL (e.g., https://t.me/...)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 25),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: _isLoading ? null : _saveNotification,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("SAVE & SEND", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
