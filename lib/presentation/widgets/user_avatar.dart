import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/l10n.dart';

/// The user's photo in a circle, or their initials when there is no photo (or its file is gone).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.photoPath, required this.size});

  final String name;
  final String? photoPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    final path = photoPath;
    final initials = Text(
      initialsFor(name),
      style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800, color: tokens?.accent),
    );
    return Semantics(
      image: true,
      label: path == null ? null : context.l10n.profileProfilePhoto,
      excludeSemantics: path != null,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: tokens?.soft, shape: BoxShape.circle),
        child: path == null
            ? initials
            : Image.file(
                File(path),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initials,
              ),
      ),
    );
  }
}

/// Up to two initials: first letters of the first and last words ("Test User" -> "TU").
String initialsFor(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '';
  final first = words.first[0];
  final last = words.length > 1 ? words.last[0] : '';
  return (first + last).toUpperCase();
}
