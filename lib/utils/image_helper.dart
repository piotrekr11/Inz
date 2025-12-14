import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ImageHelper {
  static final picker = ImagePicker();

  static Future<File?> pickImageFromGallery() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    return pickedFile != null ? File(pickedFile.path) : null;
  }

  static Future<File?> takePhoto() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    return pickedFile != null ? File(pickedFile.path) : null;
  }
}
