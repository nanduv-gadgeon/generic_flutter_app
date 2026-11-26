import 'package:flutter/widgets.dart';

/// [children] [columns] to a row, a row's cells sharing its height, or one per row when
/// [fits] says a cell's text would not fit a column (large text, narrow screen), so nothing is cut
/// off or broken mid-word.
class FitGrid extends StatelessWidget {
  const FitGrid({
    super.key,
    required this.children,
    required this.fits,
    this.columns = 2,
    this.gap = 10,
    this.rowGap,
    this.top = 0,
  });

  final List<Widget> children;

  /// Whether every cell's text fits a column this wide.
  final bool Function(BuildContext context, double columnWidth) fits;
  final int columns;

  /// Space between columns, and between rows unless [rowGap] is given.
  final double gap;
  final double? rowGap;

  /// Space above the first row.
  final double top;

  @override
  Widget build(BuildContext context) {
    final rowGap = this.rowGap ?? gap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final perRow = fits(context, width) ? columns : 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i += perRow) ...[
              SizedBox(height: i == 0 ? top : rowGap),
              if (perRow == 1)
                children[i]
              else
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = i; j < i + perRow; j++) ...[
                        if (j > i) SizedBox(width: gap),
                        Expanded(child: j < children.length ? children[j] : const SizedBox()),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}
