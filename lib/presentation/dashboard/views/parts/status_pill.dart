import 'package:flutter/material.dart';

import '../../../../domain/models/reading.dart';
import '../../dashboard_format.dart';

/// A status word on a tinted pill ("Normal", "High", "Fever"). The word is always there, so colour
/// is never the only signal. [kind] null: muted.
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.kind, this.height = 24, this.fontSize = 12});

  final String text;
  final StatusKind? kind;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = kindColors(context.tokens, kind);
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.42),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(height / 2)),
      // Shrinks to the word; a centred child would stretch the pill across its parent.
      child: Center(
        widthFactor: 1,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: fg, height: 1),
        ),
      ),
    );
  }
}
