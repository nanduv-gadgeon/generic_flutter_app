import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// A floating green snack bar with a check mark, for something the user did that worked (e.g.
/// "Name changed"). The check and the text mean colour is never the only signal.
SnackBar successSnackBar(BuildContext context, String text) {
  final tokens = Theme.of(context).extension<AppTokens>()!;
  // `surface` is light on the light theme's green and dark on the dark theme's, so it reads on both.
  final onOk = tokens.surface;
  return SnackBar(
    duration: successSnackBarDuration,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    backgroundColor: tokens.ok,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusSmall)),
    content: Row(
      children: [
        ExcludeSemantics(child: Icon(Icons.check_circle_rounded, size: 22, color: onOk)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: onOk),
          ),
        ),
      ],
    ),
  );
}

/// How long a [successSnackBar] stays.
const successSnackBarDuration = Duration(seconds: 2);
