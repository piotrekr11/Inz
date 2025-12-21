import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';
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
  final NotesRepository _notesRepository = const NotesRepository();

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


  String _generateNoteId() => DateTime.now().millisecondsSinceEpoch.toString();



  Future<void> _loadAvailableCategories() async {
    final categorySet = <String>{'All'};
    final notesWithFiles = await _notesRepository.loadNotes();
    for (var noteWithFile in notesWithFiles) {
      categorySet.addAll(noteWithFile.note.categories);
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
    await _notesRepository.rewriteCategory(
      old: oldCategory,
      renamed: newCategory,
    );
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



    await _notesRepository.saveNote(note, noteFile: widget.noteFile);

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
