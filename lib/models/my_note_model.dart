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

  // Database se read karne ke liye
  factory MyNote.fromJson(Map<String, dynamic> json) => MyNote(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        createdAt: json['createdAt'],
      );

  // Database me save karne ke liye
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt,
      };

  // Update karte waqt copy banane ke liye helper
  MyNote copy({
    int? id,
    String? title,
    String? content,
    String? createdAt,
  }) =>
      MyNote(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
      );
}
