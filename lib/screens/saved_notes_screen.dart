import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'note_editor_screen.dart';
import '../models/note.dart';
import '../data/notes_repository.dart';

class SavedNotesScreen extends StatefulWidget {
  const SavedNotesScreen({Key? key}) : super(key: key);

  @override
  State<SavedNotesScreen> createState() => SavedNotesScreenState();
}

class SavedNotesScreenState extends State<SavedNotesScreen> {
  List<Note> notes = [];
  List<File> files = [];
  List<String> availableCategories = ['All'];
  List<String> selectedCategories = ['All'];
  final NotesRepository _notesRepository = const NotesRepository();

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  Future<void> loadNotes() async {
    final paired = await _notesRepository.loadNotes();
    setState(() {
      notes = paired.map((pair) => pair.note).toList();
      files = paired.map((pair) => pair.file).toList();
    });
    _updateAvailableCategories();
  }

  void deleteNote(int index) async {
    await _notesRepository.deleteNote(notes[index], files[index]);
    setState(() {
      notes.removeAt(index);
      files.removeAt(index);
    });
    _updateAvailableCategories();
  }

  Future<void> _shareNote(Note note) async {
    final text = note.text.trim();
    if (text.isEmpty) return;
    await Share.share(text);
  }

  Future<void> _confirmDelete(int index) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Usunąć notatkę?'),
          content: const Text(
            'To działanie trwale usunie notatkę wraz z jej zawartością.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                deleteNote(index);
              },
              child: const Text('Usuń'),
            ),
          ],
        );
      },
    );
  }

  void openNote(Note note, File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          imageFile: File(note.imagePath),
          existingNote: note,
          noteFile: file,
        ),
      ),
    ).then((_) => loadNotes()); // Reload list after edits
  }
  void _updateAvailableCategories() {
    final categorySet = <String>{'All'};
    for (final note in notes) {
      categorySet.addAll(note.categories);
    }
    setState(() {
      availableCategories = categorySet.toList()..sort();
      if (selectedCategories.isEmpty) {
        selectedCategories = ['All'];
      } else if (selectedCategories.contains('All')) {
        selectedCategories = ['All'];
      } else {
        selectedCategories = selectedCategories
            .where((c) => categorySet.contains(c))
            .toList();
        if (selectedCategories.isEmpty) {
          selectedCategories = ['All'];
        }
      }
    });
  }

  void _openFilterDialog() {
    final tempSelected = [...selectedCategories];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Filtruj według kategorii'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...availableCategories.map((category) {
                      return CheckboxListTile(
                        title: Text(category),
                        value: tempSelected.contains(category),
                        onChanged: (value) {
                          setStateDialog(() {
                            if (category == 'All') {
                              if (value == true) {
                                tempSelected
                                  ..clear()
                                  ..add('All');
                              }
                            } else {
                              if (value == true) {
                                tempSelected.add(category);
                                tempSelected.remove('All');
                              } else {
                                tempSelected.remove(category);
                                if (tempSelected.isEmpty) {
                                  tempSelected.add('All');
                                }
                              }
                            }
                          });
                        },
                      );
                    })
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anuluj'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedCategories = tempSelected;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Zastosuj'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Note> _filteredNotes() {
    if (selectedCategories.contains('All')) {
      return notes;
    }

    return notes
        .where(
          (note) => note.categories
          .any((category) => selectedCategories.contains(category)),
    )
        .toList();
  }




  @override
  Widget build(BuildContext context) {
    final filteredNotes = _filteredNotes();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zapisane notatki'),
        actions: [
          IconButton(
            onPressed: _openFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtruj',
          )
        ],
      ),
      body: notes.isEmpty
          ? const Center(child: Text('Brak zapisanych notatek.'))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: selectedCategories
                    .map((c) => Chip(
                  label: Text(c),
                ))
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: filteredNotes.isEmpty
                ? const Center(
              child: Text('Brak notatek w wybranych kategoriach.'),
            )
                : ListView.builder(
              itemCount: filteredNotes.length,
              itemBuilder: (context, index) {
                final note = filteredNotes[index];
                final fileIndex = notes.indexOf(note);
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
                        children: note.categories
                            .map((cat) => Chip(label: Text(cat)))
                            .toList(),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          openNote(note, files[fileIndex]);
                          break;
                        case 'share':
                          _shareNote(note);
                          break;
                        case 'delete':
                          _confirmDelete(fileIndex);
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
                  onTap: () => openNote(note, files[fileIndex]),
                );
              },
            ),
          ),
        ],

      ),
    );
  }
}