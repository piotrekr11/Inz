import 'dart:io';

import 'package:flutter/material.dart';

class FullscreenImageScreen extends StatelessWidget {
  const FullscreenImageScreen({
    required this.imageFile,
    Key? key,
  }) : super(key: key);

  final File imageFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.file(imageFile, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Zamknij',
              ),
            ),
          ],
        ),
      ),
    );
  }
}