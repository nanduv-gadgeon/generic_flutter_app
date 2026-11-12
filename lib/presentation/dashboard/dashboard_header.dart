import 'package:flutter/material.dart';

import '../widgets/form_widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleBackButton(onPressed: onBack),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                type,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: context.tokens.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        action,
      ],
    );
  }
}
