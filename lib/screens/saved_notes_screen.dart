import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aplikacja_notatki/models/note.dart';
import 'package:aplikacja_notatki/screens/note_editor_screen.dart';
import 'package:aplikacja_notatki/state/notes_controller.dart';
import 'package:aplikacja_notatki/widgets/saved_note_tile.dart';

class SavedNotesScreen extends StatefulWidget {
  const SavedNotesScreen({Key? key}) : super(key: key);

  @override
  State<SavedNotesScreen> createState() => SavedNotesScreenState();
}

class SavedNotesScreenState extends State<SavedNotesScreen> {
  late final NotesController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NotesController();
    _controller.addListener(_handleControllerChanged);
    _controller.loadNotes();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> loadNotes() async {
    await _controller.loadNotes();
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
                _controller.deleteNoteAt(index);
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
    ).then((_) => _controller.loadNotes()); // Reload list after edit
  }

  void _openFilterDialog() {
    final tempSelected = [..._controller.selectedCategories];

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
                    ..._controller.availableCategories.map((category) {
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
                    _controller.setSelectedCategories(tempSelected);
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
    return _controller.filteredNotes;
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
      body: _controller.notes.isEmpty
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
                children: _controller.selectedCategories
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
                final fileIndex = _controller.notes.indexOf(note);;
                return SavedNoteTile(
                  note: note,
                  onEdit: (note) => openNote(note, _controller.files[fileIndex]),
                  onShare: _shareNote,
                  onDelete: () => _confirmDelete(fileIndex),
                  onTap: () => openNote(note, _controller.files[fileIndex]),
                );
              },
            ),
          ),
        ],

      ),
    );
  }
}