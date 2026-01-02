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
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(note.imagePath),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Saved: ${note.timestamp.toLocal().toString().split('.')[0]}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Center(
                child: PopupMenuButton<String>(
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
              ),
            ],
          ),
          const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kategorie:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: note.categories
                            .map(
                              (cat) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Chip(
                              label: Text(cat),
                              labelStyle: const TextStyle(fontSize: 11),
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                              materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
