import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aplikacja_notatki/models/note.dart';
import 'package:aplikacja_notatki/state/notes_controller.dart';
import 'package:aplikacja_notatki/utils/ocr_helper.dart';
import 'package:aplikacja_notatki/widgets/category_picker_dialog.dart';

class NoteEditorScreen extends StatefulWidget {
  final File imageFile;
  final Note? existingNote;
  final File? noteFile; // Path to the original JSON file (for editing)

  const NoteEditorScreen({
    required this.imageFile,
    this.existingNote,
    this.noteFile,
    Key? key,
  }) : super(key: key);

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final TextEditingController controller = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final NotesController _controller =
  NotesController(treatAllAsExclusive: false);

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);

    if (widget.existingNote != null) {
      _titleController.text = widget.existingNote!.title;
      controller.text = widget.existingNote!.text;
      _controller.setSelectedCategories([
        ...widget.existingNote!.categories,
        if (!widget.existingNote!.categories.contains('All')) 'All',
      ]);
    } else {
      _controller.setSelectedCategories(['All']);
      performOCR();

    }
    _loadAvailableCategories();
  }

  Future<void> performOCR() async {
    final text = await OCRHelper.recognizeTextFromImage(widget.imageFile);
    setState(() {
      controller.text = text;
    });
  }


  String _generateNoteId() => DateTime.now().millisecondsSinceEpoch.toString();



  Future<void> _loadAvailableCategories() async {
    await _controller.loadAvailableCategories(existingNote: widget.existingNote);
  }

  Future<void> _rewriteCategoryInStoredNotes(
      String oldCategory, {
        String? newCategory,
      }) async {
    await _controller.rewriteCategory(oldCategory, newCategory: newCategory);
  }

  Future<void> _saveNoteWithCategories(List<String> categories) async {
    final title = _titleController.text.trim();
    final text = controller.text.trim();

    final noteId = widget.existingNote?.id ?? _generateNoteId();


    final uniqueCategories = {
      'All',
      ...categories.where((c) => c.trim().isNotEmpty).map((c) => c.trim()),
    }.toList();

    final note = Note(
      title: title,
      id: noteId,
      text: text,
      imagePath: widget.imageFile.path,
      timestamp: DateTime.now(),
      categories: uniqueCategories,
    );



    await _controller.saveNote(note, noteFile: widget.noteFile);

    if (!mounted) return;
    Navigator.pop(context); // Close editor
  }

  Future<void> _handleSavePressed() async {
    final title = _titleController.text.trim();
    final text = controller.text.trim();

    if (title.isEmpty || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wprowadź tytuł notatki")),
      );
      return;
    }

    await _loadAvailableCategories();
    if (!mounted) return;

    _showCategoryDialog();
  }

  Future<void> _showCategoryDialog() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return CategoryPickerDialog(
          availableCategories: _controller.availableCategories,
          selectedCategories: _controller.selectedCategories,
          onAddCategory: (newCategory) {
            if (!mounted) return;
            _controller.addAvailableCategory(newCategory);
          },
          onRenameCategory: (oldCategory, renamed) async {
            if (!mounted) return;
            _controller.renameCategory(oldCategory, renamed);
            await _rewriteCategoryInStoredNotes(
              oldCategory,
              newCategory: renamed,
            );
          },
          onDeleteCategory: (category) async {
            if (!mounted) return;
            _controller.removeCategory(category);
            await _rewriteCategoryInStoredNotes(category);
          },
        );
      },
    );
    if (!mounted || result == null) return;
    _controller.setSelectedCategories(result);
    await _saveNoteWithCategories(result);
  }

  Future<void> shareNote() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    await Share.share(text);
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingNote != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edytuj notatkę' : 'Nowa notatka'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Tytuł notatki',
              ),
            ),
            const SizedBox(height: 12),

            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(widget.imageFile, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 200,
                maxHeight: 400,
              ),

              child: TextField(
                controller: controller,
                maxLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Treść notatki',
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleSavePressed,
              child: Text(isEditing ? 'Zapisz zmiany' : 'Zapisz notatkę'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: shareNote,
              child: const Text('Udostępnij'),
            ),
          ],
        ),
      ),
    );

  }
}


