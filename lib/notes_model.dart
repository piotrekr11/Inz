class Note {
  final String title;
  final String text;
  final String imagePath;
  final DateTime timestamp;
  final List<String> categories;

  Note({
    required this.title,
    required this.text,
    required this.imagePath,
    required this.timestamp,
    required this.categories,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'text': text,
    'imagePath': imagePath,
    'timestamp': timestamp.toIso8601String(),
    'categories': categories,
  };

  static Note fromJson(Map<String, dynamic> json) => Note(
    title: json['title'] ?? '', // fallback
    text: json['text'],
    imagePath: json['imagePath'],
    timestamp: DateTime.parse(json['timestamp']),
    categories: (json['categories'] as List<dynamic>?)
        ?.map((c) => c.toString())
        .toList()
        .toSet()
        .toList() ??
        ['All'],

  );
}
