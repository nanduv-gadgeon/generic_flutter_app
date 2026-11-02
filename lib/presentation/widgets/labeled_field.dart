import 'package:flutter/material.dart';

/// A bold label above a form field, as in the mockup.
///
/// Screen readers read [label] as the field's name; the visible label is not read twice.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        Semantics(label: label, child: child),
      ],
    );
  }
}
