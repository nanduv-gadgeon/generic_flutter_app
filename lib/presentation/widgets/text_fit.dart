import 'package:flutter/widgets.dart';

/// Whether each of [texts] fits on one line of [width] in [style], at the user's text size. Lets a
/// row of short labels switch to a stacked layout before a word would be broken or cut off.
bool fitsOnOneLine(BuildContext context, Iterable<String> texts, TextStyle style, double width) {
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  // The theme's font, as the Text widgets get it.
  final full = DefaultTextStyle.of(context).style.merge(style);
  for (final text in texts) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: full),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final fits = painter.width <= width;
    painter.dispose();
    if (!fits) return false;
  }
  return true;
}
