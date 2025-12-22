import 'dart:io';
import 'package:flutter/material.dart';
import 'package:aplikacja_notatki/models/note.dart';

typedef NoteShareCallback = void Function(Note note);

typedef NoteEditCallback = void Function(Note note);

typedef NoteDeleteCallback = void Function();

class SavedNoteTile extends StatelessWidget {
  const SavedNoteTile({
    Key? key,
    required this.note,
    required this.onEdit,
    required this.onShare,
    required this.onDelete,
    required this.onTap,
  }) : super(key: key);

  final Note note;
  final NoteEditCallback onEdit;
  final NoteShareCallback onShare;
  final NoteDeleteCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Image.file(
        File(note.imagePath),
        width: 60,
        height: 60,
        fit: BoxFit.cover,
      ),
      title: Text(
        note.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saved: ${note.timestamp.toLocal().toString().split('.')[0]}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: note.categories.map((cat) => Chip(label: Text(cat))).toList(),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEdit(note);
              break;
            case 'share':
              onShare(note);
              break;
            case 'delete':
              onDelete();
              break;
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'edit',
            child: Text('Edytuj'),
          ),
          PopupMenuItem(
            value: 'share',
            child: Text('Udostępnij'),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text('Usuń'),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}