// ImageEditScreen with constrained cropping and accurate selection
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_editor/image_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aplikacja_notatki/screens/edit_controls_screen.dart';


class ImageEditScreen extends StatefulWidget {
  final File imageFile;
  const ImageEditScreen({required this.imageFile, Key? key}) : super(key: key);

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  final GlobalKey imageKey = GlobalKey();
  late File originalFile;
  int imageWidth = 0;
  int imageHeight = 0;

  Rect selectionRect = Rect.zero;
  bool selectionInitialized = false;
  bool isDragging = false;
  Offset? dragStart;
  String dragEdge = '';

  Size displaySize = Size.zero;
  Offset imageOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    originalFile = widget.imageFile;
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    final bytes = await originalFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      setState(() {
        imageWidth = decoded.width;
        imageHeight = decoded.height;
      });
    }
  }

  void _updateImageDisplaySize(BoxConstraints constraints) {
    if (imageWidth == 0 || imageHeight == 0) return;

    final containerSize = Size(constraints.maxWidth, constraints.maxHeight - 150);
    final containerAspect = containerSize.width / containerSize.height;
    final imageAspect = imageWidth / imageHeight;

    double displayWidth, displayHeight;
    if (imageAspect > containerAspect) {
      displayWidth = containerSize.width;
      displayHeight = displayWidth / imageAspect;
    } else {
      displayHeight = containerSize.height;
      displayWidth = displayHeight * imageAspect;
    }

    final offsetX = (containerSize.width - displayWidth) / 2;
    final offsetY = (containerSize.height - displayHeight) / 2;

    displaySize = Size(displayWidth, displayHeight);
    imageOffset = Offset(offsetX, offsetY);
    _initializeSelectionRectIfNeeded();
  }

  void _initializeSelectionRectIfNeeded() {
    if (selectionInitialized || displaySize == Size.zero) return;

    final rectWidth = displaySize.width * 0.6;
    final rectHeight = displaySize.height * 0.6;
    final left = imageOffset.dx + (displaySize.width - rectWidth) / 2;
    final top = imageOffset.dy + (displaySize.height - rectHeight) / 2;

    selectionRect = Rect.fromLTWH(left, top, rectWidth, rectHeight);
    selectionInitialized = true;
  }

  void _onPanStart(DragStartDetails details, String edge) {
    dragStart = details.localPosition;
    dragEdge = edge;
    isDragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!isDragging || dragStart == null) return;
    final delta = details.localPosition - dragStart!;
    Rect newRect = selectionRect;

    switch (dragEdge) {
      case 'left':
        newRect = Rect.fromLTRB(
          (selectionRect.left + delta.dx).clamp(imageOffset.dx, selectionRect.right - 20),
          selectionRect.top,
          selectionRect.right,
          selectionRect.bottom,
        );
        break;
      case 'right':
        newRect = Rect.fromLTRB(
          selectionRect.left,
          selectionRect.top,
          (selectionRect.right + delta.dx).clamp(selectionRect.left + 20, imageOffset.dx + displaySize.width),
          selectionRect.bottom,
        );
        break;
      case 'top':
        newRect = Rect.fromLTRB(
          selectionRect.left,
          (selectionRect.top + delta.dy).clamp(imageOffset.dy, selectionRect.bottom - 20),
          selectionRect.right,
          selectionRect.bottom,
        );
        break;
      case 'bottom':
        newRect = Rect.fromLTRB(
          selectionRect.left,
          selectionRect.top,
          selectionRect.right,
          (selectionRect.bottom + delta.dy).clamp(selectionRect.top + 20, imageOffset.dy + displaySize.height),
        );
        break;
    }

    setState(() {
      selectionRect = newRect;
      dragStart = details.localPosition;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    isDragging = false;
    dragStart = null;
    dragEdge = '';
  }

  Future<File> cropSelectedArea() async {
    final scaleX = imageWidth / displaySize.width;
    final scaleY = imageHeight / displaySize.height;

    final cropRect = Rect.fromLTWH(
      (selectionRect.left - imageOffset.dx) * scaleX,
      (selectionRect.top - imageOffset.dy) * scaleY,
      selectionRect.width * scaleX,
      selectionRect.height * scaleY,
    );

    final option = ImageEditorOption()..addOption(ClipOption.fromRect(cropRect));
    final result = await ImageEditor.editImage(
      image: await originalFile.readAsBytes(),
      imageEditorOption: option,
    );

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/selected_crop_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    return file.writeAsBytes(result!);
  }

  void onContinue() async {
    final cropped = await cropSelectedArea();
    if (mounted) {
      final saved = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditControlsScreen(imageFile: cropped),
        ),
      );
      if (saved == true && mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  Widget _buildEdgeHandle(String edge) {
    Rect edgeRect;
    switch (edge) {
      case 'left':
        edgeRect = Rect.fromLTWH(selectionRect.left - 10, selectionRect.top, 20, selectionRect.height);
        break;
      case 'right':
        edgeRect = Rect.fromLTWH(selectionRect.right - 10, selectionRect.top, 20, selectionRect.height);
        break;
      case 'top':
        edgeRect = Rect.fromLTWH(selectionRect.left, selectionRect.top - 10, selectionRect.width, 20);
        break;
      case 'bottom':
        edgeRect = Rect.fromLTWH(selectionRect.left, selectionRect.bottom - 10, selectionRect.width, 20);
        break;
      default:
        edgeRect = Rect.zero;
    }

    return Positioned(
      left: edgeRect.left,
      top: edgeRect.top,
      width: edgeRect.width,
      height: edgeRect.height,
      child: GestureDetector(
        onPanStart: (details) => _onPanStart(details, edge),
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zaznacz wybrany obszar')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _updateImageDisplaySize(constraints);
          return Column(
            children: [
              SizedBox(
                height: constraints.maxHeight - 150,
                width: constraints.maxWidth,
                child: Stack(
                  children: [
                    Positioned(
                      left: imageOffset.dx,
                      top: imageOffset.dy,
                      width: displaySize.width,
                      height: displaySize.height,
                      child: Image.file(
                        widget.imageFile,
                        key: imageKey,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned.fromRect(
                      rect: selectionRect,
                      child: CustomPaint(
                        painter: _SelectionBorderPainter(),
                      ),
                    ),
                    _buildEdgeHandle('left'),
                    _buildEdgeHandle('right'),
                    _buildEdgeHandle('top'),
                    _buildEdgeHandle('bottom'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: onContinue,
                child: const Text('Kontynuuj do edycji'),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
class _SelectionBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Slight deflate keeps strokes within bounds and ensures the outline is visible.
    canvas.drawRect(rect.deflate(0.5), outlinePaint);
    canvas.drawRect(rect.deflate(0.5), innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
