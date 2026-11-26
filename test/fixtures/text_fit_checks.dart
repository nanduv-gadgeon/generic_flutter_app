import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Texts on screen that are cut off ("…") or have a word broken across lines, e.g. "BATTE / RY".
/// Large text must wrap between words or move things around instead.
List<String> cutOrBrokenTexts(WidgetTester tester, {Finder? within}) {
  final texts = within == null
      ? find.byType(RichText)
      : find.descendant(of: within, matching: find.byType(RichText));
  final found = <String>[];
  for (final element in texts.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    if (!paragraph.hasSize) continue;
    final text = paragraph.text.toPlainText();
    if (paragraph.didExceedMaxLines) {
      found.add('cut off: "$text" (${_owner(element)})');
      continue;
    }
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: paragraph.text.style),
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
      )..layout();
      if (painter.width > paragraph.size.width + 0.5) {
        found.add('word broken: "$word" in "$text" (${_owner(element)})');
      }
      painter.dispose();
    }
  }
  return found;
}

/// Loads the app's real font (Nunito) under the test theme's font name, so text is measured as on
/// a phone. The test font draws every letter as a square, about twice as wide as real text.
Future<void> loadRealFont() async {
  final font = FontLoader('TestFont');
  for (final weight in ['Regular', 'SemiBold', 'Bold', 'ExtraBold']) {
    font.addFont(rootBundle.load('assets/fonts/Nunito/Nunito-$weight.ttf'));
  }
  await font.load();
}

/// The nearest widget from this app's own code above [element], to say where a text is.
String _owner(Element element) {
  String? owner;
  element.visitAncestorElements((e) {
    final type = e.widget.runtimeType.toString();
    if (!type.startsWith('_') && !_framework.contains(type)) {
      owner = type;
      return false;
    }
    return true;
  });
  return owner ?? '?';
}

const _framework = {
  'Text',
  'RichText',
  'Padding',
  'Row',
  'Column',
  'Expanded',
  'Flexible',
  'SizedBox',
  'Container',
  'Semantics',
  'DefaultTextStyle',
  'Center',
  'Align',
  'Wrap',
  'ConstrainedBox',
  'DecoratedBox',
  'MergeSemantics',
  'ExcludeSemantics',
  'IntrinsicHeight',
  'LayoutBuilder',
  'FittedBox',
  'Builder',
  'Stack',
  'Positioned',
  'Material',
  'InkWell',
  'GestureDetector',
  'AnimatedContainer',
  'Listener',
  'MouseRegion',
  'Ink',
  'ClipRRect',
  'ColoredBox',
  'Opacity',
  'KeyedSubtree',
  'RepaintBoundary',
  'IconTheme',
  'Theme',
  'Focus',
  'Actions',
  'Shortcuts',
  'InkResponse',
  'CustomPaint',
};
