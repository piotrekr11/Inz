import 'dart:io';
import 'package:aplikacja_notatki/constants/category_constants.dart';
import 'package:flutter/material.dart';
import 'package:aplikacja_notatki/data/notes_repository.dart';
import 'package:aplikacja_notatki/models/note.dart';

class NotesController extends ChangeNotifier {
  NotesController({
    NotesRepository? notesRepository,
    bool treatAllAsExclusive = true,
  })  : _notesRepository = notesRepository ?? const NotesRepository(),
        _treatAllAsExclusive = treatAllAsExclusive;

  final NotesRepository _notesRepository;
  final bool _treatAllAsExclusive;

  List<Note> _notes = [];
  List<File> _files = [];
  List<String> _availableCategories = [defaultCategory];
  List<String> _selectedCategories = [defaultCategory];

  List<Note> get notes => List.unmodifiable(_notes);
  List<File> get files => List.unmodifiable(_files);
  List<String> get availableCategories => List.unmodifiable(_availableCategories);
  List<String> get selectedCategories => List.unmodifiable(_selectedCategories);

  List<Note> get filteredNotes {
    if (_selectedCategories.contains(defaultCategory)) {
      return _notes;
    }
    return _notes
        .where(
          (note) => note.categories
          .any((category) => _selectedCategories.contains(category)),
    )
        .toList();
  }

  Future<void> loadNotes() async {
    final paired = await _notesRepository.loadNotes();
    _notes = paired.map((pair) => pair.note).toList();
    _files = paired.map((pair) => pair.file).toList();
    await _loadStoredCategories();
    notifyListeners();
  }

  Future<void> deleteNoteAt(int index) async {
    await _notesRepository.deleteNote(_notes[index], _files[index]);
    _notes.removeAt(index);
    _files.removeAt(index);
    notifyListeners();
  }

  Future<void> loadAvailableCategories({Note? existingNote}) async {
    await _loadStoredCategories(existingNote: existingNote);
    notifyListeners();
  }

  Future<void> rewriteCategory(
      String oldCategory, {
        String? newCategory,
      }) async {
    await _notesRepository.rewriteCategory(
      old: oldCategory,
      renamed: newCategory,
    );
  }

  Future<void> saveNote(Note note, {File? noteFile}) async {
    await _notesRepository.saveNote(note, noteFile: noteFile);
  }

  void setSelectedCategories(List<String> categories) {
    _selectedCategories = _normalizeSelected(categories);
    notifyListeners();
  }

  Future<void> addAvailableCategory(String category) async {
    if (_availableCategories.contains(category)) return;
    _availableCategories.add(category);
    _availableCategories.sort();
    await _notesRepository.saveCategories(_availableCategories);
    notifyListeners();
  }

  Future<void> renameCategory(String oldCategory, String renamed) async {
    _availableCategories.remove(oldCategory);
    if (!_availableCategories.contains(renamed)) {
      _availableCategories.add(renamed);
    }
    _availableCategories.sort();
    _selectedCategories = _selectedCategories
        .map((category) => category == oldCategory ? renamed : category)
        .toList();
    await _notesRepository.saveCategories(_availableCategories);
    notifyListeners();
  }

  Future<void> removeCategory(String category) async {
    _availableCategories.remove(category);
    _selectedCategories.remove(category);
    _selectedCategories = _normalizeSelected(_selectedCategories);
    await _notesRepository.saveCategories(_availableCategories);
    notifyListeners();
  }

  Future<void> _loadStoredCategories({Note? existingNote}) async {
    final stored = await _notesRepository.loadCategories();
    final categorySet = <String>{...stored};
    for (final note in _notes) {
      categorySet.addAll(note.categories);
    }
    if (existingNote != null) {
      categorySet.addAll(existingNote.categories);
    }
    categorySet.add(defaultCategory);
    final merged = categorySet.toList()..sort();
    _availableCategories = merged;
    _selectedCategories = _normalizeSelected(_selectedCategories);
    if (merged.toSet().length != stored.toSet().length ||
        !merged.toSet().containsAll(stored)) {
      await _notesRepository.saveCategories(merged);
    }
  }

  List<String> _normalizeSelected(List<String> categories) {
    if (categories.isEmpty) {
      return [defaultCategory];
    }
    if (_treatAllAsExclusive && categories.contains(defaultCategory)) {
      return [defaultCategory];
    }
    if (!_treatAllAsExclusive) {
      return categories;
    }
    final available = _availableCategories.toSet();
    final filtered = categories.where(available.contains).toList();
    return filtered.isEmpty ? [defaultCategory] : filtered;
  }
}