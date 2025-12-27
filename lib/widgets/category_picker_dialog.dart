import 'package:flutter/material.dart';
import 'package:aplikacja_notatki/constants/category_constants.dart';

class CategoryPickerDialog extends StatefulWidget {
  final List<String> availableCategories;
  final List<String> selectedCategories;
  final ValueChanged<String> onAddCategory;
  final Future<void> Function(String oldCategory, String renamed)
  onRenameCategory;
  final Future<void> Function(String category) onDeleteCategory;

  const CategoryPickerDialog({
    required this.availableCategories,
    required this.selectedCategories,
    required this.onAddCategory,
    required this.onRenameCategory,
    required this.onDeleteCategory,
    Key? key,
  }) : super(key: key);

  @override
  State<CategoryPickerDialog> createState() => _CategoryPickerDialogState();
}

class _CategoryPickerDialogState extends State<CategoryPickerDialog> {
  final TextEditingController _newCategoryController =
  TextEditingController();
  final TextEditingController _renameCategoryController =
  TextEditingController();

  late List<String> _tempSelected;
  late List<String> _availableCategories;

  @override
  void initState() {
    super.initState();
    _tempSelected = [...widget.selectedCategories];
    _availableCategories = [...widget.availableCategories];
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    _renameCategoryController.dispose();
    super.dispose();
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

  Future<void> _handleRenameCategory(String category) async {
    final renamed = await _promptRenameCategory(context, category);
    if (renamed == null || renamed.isEmpty) {
      return;
    }

    final alreadyExists = _availableCategories.contains(renamed);
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Taka kategoria już istnieje.'),
        ),
      );
      return;
    }

    setState(() {
      _availableCategories.remove(category);
      _availableCategories.add(renamed);
      _availableCategories.sort();
      if (_tempSelected.contains(category)) {
        _tempSelected.remove(category);
        _tempSelected.add(renamed);
      }
    });

    await widget.onRenameCategory(category, renamed);
  }

  Future<void> _handleDeleteCategory(String category) async {
    setState(() {
      _availableCategories.remove(category);
      _tempSelected.remove(category);
    });

    await widget.onDeleteCategory(category);
  }

  void _handleAddCategory() {
    final newCategory = _newCategoryController.text.trim();
    if (newCategory.isEmpty) return;

    final customCount =
        _availableCategories.where((c) => c != defaultCategory).length;
    final alreadyExists = _availableCategories.contains(newCategory);

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
      if (!_availableCategories.contains(newCategory)) {
        _availableCategories.add(newCategory);
        _availableCategories.sort();
      }
      if (!_tempSelected.contains(newCategory)) {
        _tempSelected.add(newCategory);
      }
    });

    widget.onAddCategory(newCategory);
    _newCategoryController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wybierz kategorie'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._availableCategories.map((category) {
              final isAll = category == defaultCategory;
              return CheckboxListTile(
                title: Text(category),
                value: _tempSelected.contains(category),
                onChanged: isAll
                    ? null
                    : (value) {
                  setState(() {
                    if (value == true) {
                      _tempSelected.add(category);
                    } else {
                      _tempSelected.remove(category);
                    }
                  });
                },
                secondary: isAll
                    ? null
                    : PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'rename') {
                      await _handleRenameCategory(category);
                    } else if (action == 'delete') {
                      await _handleDeleteCategory(category);
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
                onPressed: _handleAddCategory,
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
            Navigator.pop(context, _tempSelected);
          },
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}