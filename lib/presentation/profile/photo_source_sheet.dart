import 'package:flutter/material.dart';

import '../strings/profile_strings.dart';

enum PhotoAction { camera, gallery, remove }

/// "Change photo" choices. Remove is offered only when there is a photo. Null if dismissed.
Future<PhotoAction?> showPhotoSourceSheet(BuildContext context, {required bool hasPhoto}) =>
    showModalBottomSheet<PhotoAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        Widget option(PhotoAction action, IconData icon, String label) => ListTile(
          leading: Icon(icon),
          title: Text(label),
          onTap: () => Navigator.pop(context, action),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(PhotoAction.camera, Icons.photo_camera_outlined, ProfileStrings.takePhoto),
            option(PhotoAction.gallery, Icons.photo_library_outlined, ProfileStrings.choosePhoto),
            if (hasPhoto)
              option(PhotoAction.remove, Icons.delete_outline, ProfileStrings.removePhoto),
            const SizedBox(height: 8),
          ],
        );
      },
    );
