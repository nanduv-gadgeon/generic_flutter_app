import 'package:image_picker/image_picker.dart';

import '../../domain/services/photo_picker.dart';

/// Camera or photo library through the phone's own picker. Pictures are scaled down, since a
/// profile photo is only ever shown small.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    return file?.path;
  }
}
