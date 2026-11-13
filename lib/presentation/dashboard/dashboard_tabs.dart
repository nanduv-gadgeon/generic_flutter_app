import 'package:flutter/material.dart';

import '../widgets/segment_tabs.dart';
import 'dashboard_format.dart';

/// The Live / History switch under the status strip.
class DashboardTabs extends StatelessWidget {
  const DashboardTabs({super.key, required this.history, required this.onChanged});

  /// Whether History is selected.
  final bool history;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SegmentTabs(
    labels: [context.l10n.dashboardLive, context.l10n.dashboardHistory],
    selected: history ? 1 : 0,
    onChanged: (i) => onChanged(i == 1),
  );
}
