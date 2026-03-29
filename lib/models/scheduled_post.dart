class ScheduledPost {
  final String id;
  final String imagePath;
  final DateTime scheduledDate;
  
  // Metadata for re-rendering
  final String? category;
  final String? title;
  final String? body;
  final String? verse;
  final String? reflection;
  final String? question;
  final int? designVariant;

  ScheduledPost({
    required this.id,
    required this.imagePath,
    required this.scheduledDate,
    this.category,
    this.title,
    this.body,
    this.verse,
    this.reflection,
    this.question,
    this.designVariant,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'scheduledDate': scheduledDate.toIso8601String(),
      'category': category,
      'title': title,
      'body': body,
      'verse': verse,
      'reflection': reflection,
      'question': question,
      'designVariant': designVariant,
    };
  }

  factory ScheduledPost.fromJson(Map<String, dynamic> json) {
    return ScheduledPost(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      category: json['category'] as String?,
      title: json['title'] as String?,
      body: json['body'] as String?,
      verse: json['verse'] as String?,
      reflection: json['reflection'] as String?,
      question: json['question'] as String?,
      designVariant: json['designVariant'] as int?,
    );
  }
}
