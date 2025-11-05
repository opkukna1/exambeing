import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;

class NoteDetailScreen extends StatefulWidget {
  final String? title;
  final String? content;

  const NoteDetailScreen({
    super.key,
    this.title,
    this.content,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    if (widget.content != null && widget.content!.isNotEmpty) {
      try {
        final doc = Document.fromJson(
          List<Map<String, dynamic>>.from(
            Document.fromDelta(
              Delta()..insert(widget.content!),
            ).toDelta().toJson(),
          ),
        );
        _controller = QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
      } catch (_) {
        _controller = QuillController.basic();
      }
    } else {
      _controller = QuillController.basic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Note Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              // Save functionality here
            },
          ),
        ],
      ),
      body: Column(
        children: [
          QuillSimpleToolbar(
            controller: _controller,
            configurations: const QuillSimpleToolbarConfigurations(
              showAlignmentButtons: true,
              showFontSize: true,
              showColorButton: true,
            ),
          ),
          Expanded(
            child: QuillEditor.basic(
              controller: _controller,
              readOnly: false, // user can edit
            ),
          ),
        ],
      ),
    );
  }
}
