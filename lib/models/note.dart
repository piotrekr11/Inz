import 'package:aplikacja_notatki/constants/category_constants.dart';

class Note {
  final String title;
  final String id;
  final String text;
  final String imagePath;
  final DateTime timestamp;
  final List<String> categories;

  Note({
    required this.title,
    required this.text,
    required this.id,
    required this.imagePath,
    required this.timestamp,
    required this.categories,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'text': text,
    'imagePath': imagePath,
    'timestamp': timestamp.toIso8601String(),
    'categories': categories,
  };

  static Note fromJson(Map<String, dynamic> json) {
    final timestampString = json['timestamp']?.toString();
    final parsedTimestamp = timestampString != null
        ? DateTime.tryParse(timestampString)
        : null;
    return Note(
      id: json['id']?.toString() ??
          (parsedTimestamp?.millisecondsSinceEpoch.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString()),
      title: json['title'] ?? '', // fallback
      text: json['text'],
      imagePath: json['imagePath'],
      timestamp: parsedTimestamp ?? DateTime.now(),
      categories: (json['categories'] as List<dynamic>?)
          ?.map((c) => c.toString())
          .toList()
          .toSet()
          .toList() ??
          [defaultCategory],
    );
  }
}
