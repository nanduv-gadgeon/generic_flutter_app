import 'package:flutter/material.dart';

import '../../dashboard_format.dart';

/// A section heading with a short note on the right, e.g. "All readings · 7 values · live"; with
/// large text the note goes under the heading.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 12,
      runSpacing: 2,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        if (trailing case final note?)
          Text(note, style: TextStyle(fontSize: 12, color: context.tokens.muted)),
      ],
    );
  }
}
