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
  final TextEditingController _renameCategoryController = TextEditingController();

  List<String> availableCategories = ['All'];
  List<String> selectedCategories = ['All'];

  @override
  void dispose() {
    controller.dispose();
    _titleController.dispose();
    _newCategoryController.dispose();
    _renameCategoryController.dispose();
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
  Future<String> _getImagesDirectoryPath() async {
    final notesDirPath = await _getNotesDirectoryPath();
    final imagesDir = Directory(p.join(notesDirPath, 'images'));
    if (!(await imagesDir.exists())) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir.path;
  }

  String _generateNoteId() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<String> _saveImageToPermanentStorage(String noteId) async {
    final imagesDir = await _getImagesDirectoryPath();
    final extension = p.extension(widget.imageFile.path).isNotEmpty
        ? p.extension(widget.imageFile.path)
        : '.jpg';
    final targetPath = p.join(imagesDir, '$noteId$extension');
    final targetFile = File(targetPath);

    if (widget.imageFile.path != targetPath) {
      await widget.imageFile.copy(targetPath);
    } else if (!(await targetFile.exists())) {
      await widget.imageFile.copy(targetPath);
    }

    return targetPath;
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

  Future<void> _rewriteCategoryInStoredNotes(
      String oldCategory, {
        String? newCategory,
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
          if (category == oldCategory) {
            if (newCategory != null && newCategory.isNotEmpty) {
              if (!updatedCategories.contains(newCategory)) {
                updatedCategories.add(newCategory);
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
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> _saveNoteWithCategories(List<String> categories) async {
    final title = _titleController.text.trim();
    final text = controller.text.trim();

    final noteId = widget.existingNote?.id ?? _generateNoteId();
    final savedImagePath = await _saveImageToPermanentStorage(noteId);

    final uniqueCategories = {
      'All',
      ...categories.where((c) => c.trim().isNotEmpty).map((c) => c.trim()),
    }.toList();

    final note = Note(
      title: title,
      id: noteId,
      text: text,
      imagePath: savedImagePath,
      timestamp: DateTime.now(),
      categories: uniqueCategories,
    );



    if (widget.noteFile != null) {
      // Overwrite existing file
      await widget.noteFile!.writeAsString(jsonEncode(note.toJson()));
    } else {
      // Save as new file
      final path = await _getNotesDirectoryPath();
      final fileName = 'note_$noteId.json';
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
    final rootContext = context;

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
                        secondary: isAll
                            ? null
                            : PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'rename') {
                              final renamed = await _promptRenameCategory(
                                rootContext,
                                category,
                              );
                              if (renamed == null || renamed.isEmpty) {
                                return;
                              }

                              final alreadyExists = availableCategories
                                  .any((c) => c == renamed);
                              if (alreadyExists) {
                                ScaffoldMessenger.of(rootContext)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Taka kategoria już istnieje.'),
                                  ),
                                );
                                return;
                              }

                              setState(() {
                                availableCategories.remove(category);
                                availableCategories.add(renamed);
                                availableCategories.sort();
                                if (selectedCategories.contains(category)) {
                                  selectedCategories.remove(category);
                                  selectedCategories.add(renamed);
                                }
                              });

                              setStateDialog(() {
                                if (tempSelected.contains(category)) {
                                  tempSelected.remove(category);
                                  tempSelected.add(renamed);
                                }
                              });
                              await _rewriteCategoryInStoredNotes(
                                category,
                                newCategory: renamed,
                              );
                            } else if (action == 'delete') {
                              setState(() {
                                availableCategories.remove(category);
                                selectedCategories.remove(category);
                              });
                              setStateDialog(() {
                                tempSelected.remove(category);
                              });
                              await _rewriteCategoryInStoredNotes(
                                category,
                              );
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Zmień nazwę'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Usuń'),
                            ),
                          ],
                        ),
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

                          final customCount =
                              availableCategories.where((c) => c != 'All').length;
                          final alreadyExists =
                          availableCategories.contains(newCategory);

                          if (!alreadyExists && customCount >= 10) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Możesz dodać maksymalnie 10 kategorii.',
                                ),
                              ),
                            );
                            return;
                          }
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
  Future<String?> _promptRenameCategory(
      BuildContext dialogContext,
      String currentName,
      ) async {
    _renameCategoryController.text = currentName;

    return showDialog<String>(
      context: dialogContext,
      builder: (context) {
        return AlertDialog(
          title: const Text('Zmień nazwę kategorii'),
          content: TextField(
            controller: _renameCategoryController,
            decoration: const InputDecoration(
              labelText: 'Nazwa kategorii',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anuluj'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _renameCategoryController.text.trim(),
                );
              },
              child: const Text('Zapisz'),
            ),
          ],
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
