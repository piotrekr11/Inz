import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../notes_model.dart';
import '/utils/ocr_helper.dart';

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

  @override
  void initState() {
    super.initState();

    if (widget.existingNote != null) {
      _titleController.text = widget.existingNote!.title;
      controller.text = widget.existingNote!.text;
    } else {
      performOCR();
    }
  }

  Future<void> performOCR() async {
    final text = await OCRHelper.recognizeTextFromImage(widget.imageFile);
    setState(() {
      controller.text = text;
    });
  }


  Future<String> _getNotesDirectoryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${dir.path}/notes');
    if (!(await notesDir.exists())) {
      await notesDir.create(recursive: true);
    }
    return notesDir.path;
  }

  Future<void> saveNote() async {
    final title = _titleController.text.trim();
    final text = controller.text.trim();

    if (title.isEmpty || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wprowadź tytuł notatki")),
      );
      return;
    }

    final note = Note(
      title: title,
      text: text,
      imagePath: widget.imageFile.path,
      timestamp: DateTime.now(),
    );


    if (widget.noteFile != null) {
      // Overwrite existing file
      await widget.noteFile!.writeAsString(jsonEncode(note.toJson()));
    } else {
      // Save as new file
      final path = await _getNotesDirectoryPath();
      final fileName = 'note_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('$path/$fileName');
      await file.writeAsString(jsonEncode(note.toJson()));
    }

    if (!mounted) return;
    Navigator.pop(context); // Close editor
  }

  Future<void> shareNote() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    await Share.share(text);
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
              onPressed: saveNote,
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
