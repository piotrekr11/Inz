import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_editor/image_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aplikacja_notatki/screens/note_editor_screen.dart';


class ImageAdjustmentScreen extends StatefulWidget {
  final File imageFile;

  const ImageAdjustmentScreen({required this.imageFile, Key? key}) : super(key: key);

  @override
  State<ImageAdjustmentScreen> createState() => _ImageAdjustmentScreenState();
}

class _EditSlider extends StatelessWidget {
  const _EditSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.description,
    this.onChangeEnd,
    this.valueFormatter,
  });

  final String label;
  final String? description;
  final double value;
  final double min;
  final double max;
  final double step;
  final void Function(double) onChanged;
  final void Function(double)? onChangeEnd;
  final String Function(double)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final formatter =
        valueFormatter ?? (value) => value.toStringAsFixed(2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${formatter(value)}'),
        if (description != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              description!,
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
          label: formatter(value),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}

class _ImageAdjustmentScreenState extends State<ImageAdjustmentScreen> {
  late File originalFile;
  File? previewFile;
  File? _lastPreviewFile;

  double rotation = 0;
  double brightnessPercent = 0;
  double contrastPercent = 0;

  double get _brightnessValue =>
      (1 + (brightnessPercent / 100)).clamp(0.0, 2.0);
  double get _contrastValue {
    final normalized = contrastPercent / 100;
    final contrastValue =
      normalized < 0 ? 1 + normalized : 1 + normalized;
    return contrastValue.clamp(0.0, 2.0);
  }
  @override
  void initState() {
    super.initState();
    originalFile = widget.imageFile;
    previewFile = originalFile;
    updatePreview();
  }

  @override
  void dispose() {
    _cleanupTempFile(_lastPreviewFile);
    super.dispose();
  }

  Future<void> updatePreview() async {
    final needsProcessing =
        rotation != 0 || brightnessPercent != 0 || contrastPercent != 0;

    if (!needsProcessing) {
      setState(() {
        previewFile = originalFile;
      });
      return;
    }
    final editorOption = ImageEditorOption()

      ..addOption(RotateOption(rotation.toInt()))
      ..addOption(ColorOption.brightness(_brightnessValue))
      ..addOption(ColorOption.contrast(_contrastValue));

    final result = await ImageEditor.editImage(
      image: await originalFile.readAsBytes(),
      imageEditorOption: editorOption,
    );

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/preview_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(result!);
    final previousPreview = _lastPreviewFile;
    setState(() {
      _lastPreviewFile = tempFile;
      previewFile = tempFile;
    });
    _cleanupTempFile(previousPreview);
  }

  void _cleanupTempFile(File? file) {
    if (file == null) return;
    if (file.path == originalFile.path) return;
    if (file.path == previewFile?.path) return;
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
  }

  void resetEdits() {
    setState(() {
      rotation = 0;
      brightnessPercent = 0;
      contrastPercent = 0;
    });
    updatePreview();
  }

  void continueToOCR() async {
    final needsProcessing =
        rotation != 0 || brightnessPercent != 0 || contrastPercent != 0;

    File finalEditedFile = originalFile;

    if (needsProcessing) {
      final finalFile = await ImageEditor.editImage(
        image: await originalFile.readAsBytes(),
        imageEditorOption: ImageEditorOption()
          ..addOption(RotateOption(rotation.toInt()))
          ..addOption(ColorOption.brightness(_brightnessValue))
          ..addOption(ColorOption.contrast(_contrastValue)),
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
            _EditSlider(
              label: 'Obrót',
              value: rotation,
              min: 0,
              max: 360,
              step: 1,
              valueFormatter: (value) => value.toStringAsFixed(0),
              onChanged: (val) => setState(() => rotation = val),
              onChangeEnd: (_) => updatePreview(),
            ),
            _EditSlider(
              label: 'Jasność',
              description:
              '-100% = czarne zdjęcie, 0% = oryginalna jasność, +100% = maksymalnie rozjaśnione',
              value: brightnessPercent,
              min: -100,
              max: 100,
              step: 1,
              valueFormatter: (value) => '${value.toStringAsFixed(0)}%',
              onChanged: (val) => setState(() => brightnessPercent = val),
              onChangeEnd: (_) => updatePreview(),
            ),
            _EditSlider(
              label: 'Kontrast',
              description:
              '-100% = minimalny kontrast, 0% = oryginał, +100% = mocno podbity',
              value: contrastPercent,
              min: -100,
              max: 100,
              step: 1,
              valueFormatter: (value) => '${value.toStringAsFixed(0)}%',
              onChanged: (val) => setState(() => contrastPercent = val),
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
