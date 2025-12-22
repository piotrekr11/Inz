import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aplikacja_notatki/screens/image_edit_screen.dart';
import 'package:aplikacja_notatki/screens/saved_notes_screen.dart';
import 'dart:io';


void main() {
  runApp(const NotesOCRApp());
}

class NotesOCRApp extends StatelessWidget {
  const NotesOCRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikacja do automatycznego tworzenia notatek ze zdjęć',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const HomeNavigation(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeNavigation extends StatefulWidget {
  const HomeNavigation({super.key});

  @override
  State<HomeNavigation> createState() => _HomeNavigationState();
}

class _HomeNavigationState extends State<HomeNavigation> {
  int currentIndex = 0;
  final savedNotesKey = GlobalKey<SavedNotesScreenState>();

  final picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final saved = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ImageEditScreen(imageFile: file)),
      );

      if (saved == true) {
        setState(() {
          currentIndex = 1;
        });
        savedNotesKey.currentState?.loadNotes();
      }
    }
  }

  Widget buildHomeTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Stwórz notatkę',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Zrób zdjęcie'),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.photo),
              label: const Text('Wybierz obraz z galerii'),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      buildHomeTab(),
      SavedNotesScreen(key: savedNotesKey),
    ];

    return Scaffold(
      body: tabs[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (idx) => setState(() {
          currentIndex = idx;
          if (idx == 1) {
            savedNotesKey.currentState?.loadNotes();
          }
        }),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Strona główna',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note),
            label: 'Zapisane notatki',
          ),
        ],
      ),
    );
  }
}
