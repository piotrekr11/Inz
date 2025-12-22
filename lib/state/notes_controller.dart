import 'dart:io';

import 'package:flutter/material.dart';

import '../data/notes_repository.dart';
import '../models/note.dart';

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
  List<String> _availableCategories = ['All'];
  List<String> _selectedCategories = ['All'];

  List<Note> get notes => List.unmodifiable(_notes);
  List<File> get files => List.unmodifiable(_files);
  List<String> get availableCategories => List.unmodifiable(_availableCategories);
  List<String> get selectedCategories => List.unmodifiable(_selectedCategories);

  List<Note> get filteredNotes {
    if (_selectedCategories.contains('All')) {
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
    _updateAvailableCategories();
    notifyListeners();
  }

  Future<void> deleteNoteAt(int index) async {
    await _notesRepository.deleteNote(_notes[index], _files[index]);
    _notes.removeAt(index);
    _files.removeAt(index);
    _updateAvailableCategories();
    notifyListeners();
  }

  Future<void> loadAvailableCategories({Note? existingNote}) async {
    final categorySet = <String>{'All'};
    final notesWithFiles = await _notesRepository.loadNotes();
    for (final noteWithFile in notesWithFiles) {
      categorySet.addAll(noteWithFile.note.categories);
    }

    if (existingNote != null) {
      categorySet.addAll(existingNote.categories);
    }

    _availableCategories = categorySet.toList()..sort();
    if (!_selectedCategories.contains('All')) {
      _selectedCategories = ['All', ..._selectedCategories];
    }
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

  void addAvailableCategory(String category) {
    if (_availableCategories.contains(category)) return;
    _availableCategories.add(category);
    _availableCategories.sort();
    notifyListeners();
  }

  void renameCategory(String oldCategory, String renamed) {
    _availableCategories.remove(oldCategory);
    if (!_availableCategories.contains(renamed)) {
      _availableCategories.add(renamed);
    }
    _availableCategories.sort();
    _selectedCategories = _selectedCategories
        .map((category) => category == oldCategory ? renamed : category)
        .toList();
    notifyListeners();
  }

  void removeCategory(String category) {
    _availableCategories.remove(category);
    _selectedCategories.remove(category);
    notifyListeners();
  }

  void _updateAvailableCategories() {
    final categorySet = <String>{'All'};
    for (final note in _notes) {
      categorySet.addAll(note.categories);
    }
    _availableCategories = categorySet.toList()..sort();
    _selectedCategories = _normalizeSelected(_selectedCategories);
  }

  List<String> _normalizeSelected(List<String> categories) {
    if (categories.isEmpty) {
      return ['All'];
    }
    if (_treatAllAsExclusive && categories.contains('All')) {
      return ['All'];
    }
    if (!_treatAllAsExclusive) {
      return categories;
    }
    final available = _availableCategories.toSet();
    final filtered = categories.where(available.contains).toList();
    return filtered.isEmpty ? ['All'] : filtered;
  }
}