import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_editor/image_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'note_editor_screen.dart';


class EditControlsScreen extends StatefulWidget {
  final File imageFile;

  const EditControlsScreen({required this.imageFile, Key? key}) : super(key: key);

  @override
  State<EditControlsScreen> createState() => _EditControlsScreenState();
}

class _EditControlsScreenState extends State<EditControlsScreen> {
  late File originalFile;
  File? previewFile;

  double rotation = 0;
  double brightness = 1.0;
  double contrast = 1.0;

  @override
  void initState() {
    super.initState();
    originalFile = widget.imageFile;
    previewFile = originalFile;
    updatePreview();
  }

  Future<void> updatePreview() async {
    final needsProcessing =
        rotation != 0 || brightness != 1.0 || contrast != 1.0;

    if (!needsProcessing) {
      setState(() {
        previewFile = originalFile;
      });
      return;
    }
    final editorOption = ImageEditorOption()

      ..addOption(RotateOption(rotation.toInt()))
      ..addOption(ColorOption.brightness(brightness))
      ..addOption(ColorOption.contrast(contrast));

    final result = await ImageEditor.editImage(
      image: await originalFile.readAsBytes(),
      imageEditorOption: editorOption,
    );

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/preview_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(result!);

    setState(() {
      previewFile = tempFile;
    });
  }

  void resetEdits() {
    setState(() {
      rotation = 0;
      brightness = 1.0;
      contrast = 1.0;
    });
    updatePreview();
  }

  void continueToOCR() async {
    final needsProcessing =
        rotation != 0 || brightness != 1.0 || contrast != 1.0;

    File finalEditedFile = originalFile;

    if (needsProcessing) {
      final finalFile = await ImageEditor.editImage(
        image: await originalFile.readAsBytes(),
        imageEditorOption: ImageEditorOption()
          ..addOption(RotateOption(rotation.toInt()))
          ..addOption(ColorOption.brightness(brightness))
          ..addOption(ColorOption.contrast(contrast)),
      );

      final tempDir = await getTemporaryDirectory();
      finalEditedFile = File(
        '${tempDir.path}/final_edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await finalEditedFile.writeAsBytes(finalFile!);
    }

    final saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(imageFile: finalEditedFile),
      ),
    );
    if (saved
        == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Widget buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    String? description,
    required void Function(double) onChanged,
    void Function(double)? onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}'),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              description,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[700]),
            ),
          ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          label: value.toStringAsFixed(2),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edytuj Zdjęcie')),
      body: previewFile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: Colors.white),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(previewFile!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
            buildSlider(
              label: 'Obrót',
              value: rotation,
              min: 0,
              max: 360,
              step: 1,
              onChanged: (val) => setState(() => rotation = val),
              onChangeEnd: (_) => updatePreview(),
            ),
            buildSlider(
              label: 'Jasność',
              description:
              '0 = czarne zdjęcie, 1 = oryginalna jasność, 2 = maksymalnie rozjaśnione',
              value: brightness,
              min: 0.0,
              max: 2.0,
              step: 0.01,
              onChanged: (val) => setState(() => brightness = val),
              onChangeEnd: (_) => updatePreview(),
            ),
            buildSlider(
              label: 'Kontrast',
              description:
              '0.7 = łagodny kontrast, 1 = oryginał, 1.3 = mocno podkreślony',
              value: contrast,
              min: 0.7,
              max: 1.3,
              step: 0.01,
              onChanged: (val) => setState(() => contrast = val),
              onChangeEnd: (_) => updatePreview(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: resetEdits,
              child: const Text('Cofnij wszystkie zmiany'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: continueToOCR,
              child: const Text('Kontynuuj do detekcji tekstu'),
            ),
          ],
        ),
      ),
    );
  }
}
