class Note {
  final String title;
  final String text;
  final String imagePath;
  final DateTime timestamp;

  Note({
    required this.title,
    required this.text,
    required this.imagePath,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'text': text,
    'imagePath': imagePath,
    'timestamp': timestamp.toIso8601String(),
  };

  static Note fromJson(Map<String, dynamic> json) => Note(
    title: json['title'] ?? '', // fallback
    text: json['text'],
    imagePath: json['imagePath'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}
