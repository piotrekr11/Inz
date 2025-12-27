import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aplikacja_notatki/models/note.dart';

class NoteWithFile {
  final Note note;
  final File file;

  const NoteWithFile({
    required this.note,
    required this.file,
  });
}

class NotesRepository {
  const NotesRepository();

  Future<String> _getNotesDirectoryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${dir.path}/notes');
    if (!(await notesDir.exists())) {
      await notesDir.create(recursive: true);
    }
    return notesDir.path;
  }

  Future<String> _getImagesDirectoryPath() async {
    final notesDirPath = await _getNotesDirectoryPath();
    final imagesDir = Directory(p.join(notesDirPath, 'images'));
    if (!(await imagesDir.exists())) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir.path;
  }

  Future<String> _saveImageToPermanentStorage({
    required String noteId,
    required File imageFile,
  }) async {
    final imagesDir = await _getImagesDirectoryPath();
    final extension = p.extension(imageFile.path).isNotEmpty
        ? p.extension(imageFile.path)
        : '.jpg';
    final targetPath = p.join(imagesDir, '$noteId$extension');
    final targetFile = File(targetPath);

    if (imageFile.path != targetPath) {
      await imageFile.copy(targetPath);
    } else if (!(await targetFile.exists())) {
      await imageFile.copy(targetPath);
    }

    return targetPath;
  }

  Future<List<NoteWithFile>> loadNotes() async {
    final dir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${dir.path}/notes');

    if (!(await notesDir.exists())) {
      return [];
    }

    final jsonFiles = notesDir
        .listSync()
        .where((f) => f.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final loadedNotes = <Note>[];
    final loadedFiles = <File>[];
    for (var file in jsonFiles) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        loadedNotes.add(Note.fromJson(json));
        loadedFiles.add(file);
      } catch (error) {
        debugPrint(
          'lib/data/notes_repository.dart loadNotes failed for ${file.path}: $error',
        );
        // Skip malformed files instead of breaking the whole list.
        continue;
      }
    }

    final paired = List.generate(
      loadedNotes.length,
          (index) => NoteWithFile(
        note: loadedNotes[index],
        file: loadedFiles[index],
      ),
    )..sort(
          (a, b) => b.note.timestamp.compareTo(a.note.timestamp),
    );

    return paired;
  }

  Future<NoteWithFile> saveNote(Note note, {File? noteFile}) async {
    final savedImagePath = await _saveImageToPermanentStorage(
      noteId: note.id,
      imageFile: File(note.imagePath),
    );

    final updatedNote = Note(
      title: note.title,
      id: note.id,
      text: note.text,
      imagePath: savedImagePath,
      timestamp: note.timestamp,
      categories: note.categories,
    );

    if (noteFile != null) {
      await noteFile.writeAsString(jsonEncode(updatedNote.toJson()));
      return NoteWithFile(note: updatedNote, file: noteFile);
    }

    final path = await _getNotesDirectoryPath();
    final fileName = 'note_${note.id}.json';
    final file = File('$path/$fileName');
    await file.writeAsString(jsonEncode(updatedNote.toJson()));

    return NoteWithFile(note: updatedNote, file: file);
  }

  Future<void> deleteNote(Note note, File noteFile) async {
    final imageFile = File(note.imagePath);
    if (await imageFile.exists()) {
      await imageFile.delete();
    }
    await noteFile.delete();
  }

  Future<void> rewriteCategory({
    required String old,
    String? renamed,
  }) async {
    final notesDirPath = await _getNotesDirectoryPath();
    final notesDir = Directory(notesDirPath);

    if (!(await notesDir.exists())) return;

    final jsonFiles = notesDir
        .listSync()
        .where((f) => f.path.endsWith('.json'))
        .cast<File>()
        .toList();

    for (final file in jsonFiles) {
      try {
        final content = await file.readAsString();
        final jsonMap = jsonDecode(content) as Map<String, dynamic>;
        final note = Note.fromJson(jsonMap);

        final updatedCategories = <String>[];
        for (final category in note.categories) {
          if (category == old) {
            if (renamed != null && renamed.isNotEmpty) {
              if (!updatedCategories.contains(renamed)) {
                updatedCategories.add(renamed);
              }
            }
            continue;
          }
          if (!updatedCategories.contains(category)) {
            updatedCategories.add(category);
          }
        }

        if (!updatedCategories.contains('All')) {
          updatedCategories.add('All');
        }

        final oldSet = note.categories.toSet();
        final newSet = updatedCategories.toSet();
        final changed =
            oldSet.length != newSet.length || !newSet.containsAll(oldSet);

        if (!changed) continue;

        final updatedNote = Note(
          id: note.id,
          title: note.title,
          text: note.text,
          imagePath: note.imagePath,
          timestamp: note.timestamp,
          categories: updatedCategories,
        );

        await file.writeAsString(jsonEncode(updatedNote.toJson()));
      } catch (error) {
        debugPrint(
          'lib/data/notes_repository.dart rewriteCategory failed for ${file.path}: $error',
        );
        continue;
      }
    }
  }
}