import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
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
  final TextEditingController _newCategoryController = TextEditingController();

  List<String> availableCategories = ['All'];
  List<String> selectedCategories = ['All'];

  @override
  void dispose() {
    controller.dispose();
    _titleController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    if (widget.existingNote != null) {
      _titleController.text = widget.existingNote!.title;
      controller.text = widget.existingNote!.text;
      selectedCategories = [
        ...widget.existingNote!.categories,
        if (!widget.existingNote!.categories.contains('All')) 'All',
      ];
    } else {
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


  Future<String> _getNotesDirectoryPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final notesDir = Directory('${dir.path}/notes');
    if (!(await notesDir.exists())) {
      await notesDir.create(recursive: true);
    }
    return notesDir.path;
  }

  Future<void> _loadAvailableCategories() async {
    final notesDirPath = await _getNotesDirectoryPath();
    final notesDir = Directory(notesDirPath);

    if (!(await notesDir.exists())) {
      setState(() {
        availableCategories = ['All'];
      });
      return;
    }
    final jsonFiles = notesDir
        .listSync()
        .where((f) => f.path.endsWith('.json'))
        .cast<File>()
        .toList();

    final categorySet = <String>{'All'};
    for (var file in jsonFiles) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content);
        final categories = (json['categories'] as List<dynamic>?)
            ?.map((c) => c.toString())
            .toList() ??
            ['All'];
        categorySet.addAll(categories);
      } catch (_) {
        // Ignore malformed files
      }
    }

    if (widget.existingNote != null) {
      categorySet.addAll(widget.existingNote!.categories);
    }

    setState(() {
      availableCategories = categorySet.toList()..sort();
      if (!selectedCategories.contains('All')) {
        selectedCategories = ['All', ...selectedCategories];
      }
    });
  }

  Future<void> _saveNoteWithCategories(List<String> categories) async {
    final title = _titleController.text.trim();
    final text = controller.text.trim();

    final uniqueCategories = {
      'All',
      ...categories.where((c) => c.trim().isNotEmpty).map((c) => c.trim()),
    }.toList();

    final note = Note(
      title: title,
      text: text,
      imagePath: widget.imageFile.path,
      timestamp: DateTime.now(),
      categories: uniqueCategories,
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

  void _showCategoryDialog() {
    final tempSelected = [...selectedCategories];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Wybierz kategorie'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...availableCategories.map((category) {
                      final isAll = category == 'All';
                      return CheckboxListTile(
                        title: Text(category),
                        value: tempSelected.contains(category),
                        onChanged: isAll
                            ? null
                            : (value) {
                          setStateDialog(() {
                            if (value == true) {
                              tempSelected.add(category);
                            } else {
                              tempSelected.remove(category);
                            }
                          });
                        },
                      );
                    }),
                    const Divider(),
                    TextField(
                      controller: _newCategoryController,
                      decoration: const InputDecoration(
                        labelText: 'Nowa kategoria',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          final newCategory =
                          _newCategoryController.text.trim();
                          if (newCategory.isEmpty) return;

                          setState(() {
                            if (!availableCategories.contains(newCategory)) {
                              availableCategories.add(newCategory);
                              availableCategories.sort();
                            }
                          });
                          setStateDialog(() {
                            if (!tempSelected.contains(newCategory)) {
                              tempSelected.add(newCategory);
                            }
                          });
                          _newCategoryController.clear();
                        },
                        child: const Text('Dodaj kategorię'),
                      ),
                    )
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
                    _saveNoteWithCategories(selectedCategories);
                  },
                  child: const Text('Zapisz'),
                ),
              ],
            );
          },
        );
      },
    );
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
