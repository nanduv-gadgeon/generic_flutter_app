import 'package:flutter/material.dart';

import '../widgets/form_widgets.dart';
import '../widgets/text_fit.dart';
import 'dashboard_format.dart';

/// The dashboard's top row: back, the device's name and type, and [action] (Device settings).
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.name,
    required this.type,
    required this.onBack,
    required this.action,
  });

  final String name;
  final String type;
  final VoidCallback onBack;
  final Widget action;

  static const _nameStyle = TextStyle(fontSize: 19, fontWeight: FontWeight.w800);
  static const _typeStyle = TextStyle(fontSize: 13);

  /// The back button and [action] are 44 px; 12 px gaps sit between them and the text.
  static const _sides = 2 * 44 + 2 * 12.0;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          // Wraps, so large text still shows the whole name.
          child: Text(name, style: _nameStyle),
        ),
        Text(type, style: _typeStyle.copyWith(color: context.tokens.muted)),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Between the buttons while every word fits there; with large text the name and type go
        // under them, full width, so no word is broken.
        final middle = constraints.maxWidth - _sides;
        final fits =
            fitsOnOneLine(context, _words(name), _nameStyle, middle) &&
            fitsOnOneLine(context, _words(type), _typeStyle, middle);
        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleBackButton(onPressed: onBack),
                  action,
                ],
              ),
              const SizedBox(height: 10),
              text,
            ],
          );
        }
        return Row(
          children: [
            CircleBackButton(onPressed: onBack),
            const SizedBox(width: 12),
            Expanded(child: text),
            const SizedBox(width: 12),
            action,
          ],
        );
      },
    );
  }

  static List<String> _words(String text) => text.split(RegExp(r'\s+'));
}
