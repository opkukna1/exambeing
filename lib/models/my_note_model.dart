class MyNote {
  final int? id;
  final String title;
  final String content;
  final String createdAt;

  MyNote({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  // Convert a MyNote object into a Map object (for SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt,
    };
  }

  // Convert a Map object into a MyNote object
  factory MyNote.fromJson(Map<String, dynamic> json) {
    return MyNote(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: json['createdAt'],
    );
  }

  // Helper to create a copy of MyNote
  MyNote copy({
    int? id,
    String? title,
    String? content,
    String? createdAt,
  }) {
    return MyNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
