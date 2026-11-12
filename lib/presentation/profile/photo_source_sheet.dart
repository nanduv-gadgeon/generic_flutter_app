import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

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
            option(PhotoAction.camera, Icons.photo_camera_outlined, context.l10n.profileTakePhoto),
            option(
              PhotoAction.gallery,
              Icons.photo_library_outlined,
              context.l10n.profileChoosePhoto,
            ),
            if (hasPhoto)
              option(PhotoAction.remove, Icons.delete_outline, context.l10n.profileRemovePhoto),
            const SizedBox(height: 8),
          ],
        );
      },
    );
