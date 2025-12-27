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
        scaffoldBackgroundColor: const Color(0xFFF6F5F9),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.note_alt_outlined,
                size: 72,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Stwórz notatkę',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Wykonaj zdjęcie lub wybierz je z galerii, a aplikacja '
                    'zamieni je w gotową notatkę.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _HomeActionButton(
                        icon: Icons.camera_alt,
                        title: 'Zrób zdjęcie',
                        subtitle: 'Użyj aparatu, aby uchwycić interesujący Cię obraz.',
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                      const SizedBox(height: 12),
                      _HomeActionButton(
                        icon: Icons.photo,
                        title: 'Wybierz z galerii',
                        subtitle: 'Skorzystaj z istniejącego obrazu.',
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: colorScheme.primary.withOpacity(0.2)),
        backgroundColor: Colors.white,
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
