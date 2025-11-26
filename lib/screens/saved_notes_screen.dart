import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'note_editor_screen.dart';
import '../notes_model.dart';

class SavedNotesScreen extends StatefulWidget {
  const SavedNotesScreen({Key? key}) : super(key: key);

  @override
  State<SavedNotesScreen> createState() => _SavedNotesScreenState();
}

class _SavedNotesScreenState extends State<SavedNotesScreen> {
  List<Note> notes = [];
  List<File> files = [];

  @override
  void initState() {
    super.initState();
    loadNotes();
  }

  Future<void> loadNotes() async {
    final dir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${dir.path}/notes');

    if (!(await notesDir.exists())) return;

    final jsonFiles = notesDir
        .listSync()
        .where((f) => f.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final loadedNotes = <Note>[];
    for (var file in jsonFiles) {
      final content = await file.readAsString();
      final json = jsonDecode(content);
      loadedNotes.add(Note.fromJson(json));
    }

    setState(() {
      notes = loadedNotes;
      files = jsonFiles;
    });
  }

  void deleteNote(int index) async {
    await files[index].delete();
    setState(() {
      notes.removeAt(index);
      files.removeAt(index);
    });
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zapisane notatki')),
      body: notes.isEmpty
          ? const Center(child: Text('Brak zapisanych notatek.'))
          : ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return Dismissible(
            key: Key(note.timestamp.toIso8601String()),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => deleteNote(index),
            child: ListTile(
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

              subtitle: Text(
                'Saved: ${note.timestamp.toLocal().toString().split('.')[0]}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => openNote(note, files[index]),

            ),
          );
        },
      ),
    );
  }
}