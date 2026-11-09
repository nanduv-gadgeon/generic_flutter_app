import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// A rounded card holding Profile rows, with a line between each row.
class ProfileCard extends StatelessWidget {
  const ProfileCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens?.surface,
        border: tokens == null ? null : Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(tokens?.radius ?? 16),
      ),
      child: Column(
        children: [
          for (final (i, row) in children.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: tokens?.border),
            row,
          ],
        ],
      ),
    );
  }
}

/// Icon, label and an optional value or control on the right. Tappable when [onTap] is set.
class ProfileRow extends StatelessWidget {
  const ProfileRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.minHeight = 52,
  });

  final IconData icon;
  final String label;

  /// Small muted line under the label.
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<AppTokens>()?.muted;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Icon(icon, size: 20, color: muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ],
                ),
              ),
              // The label takes the rest, so the value sits at the card's edge; capped at half the
              // row so with large text a long value (the app version) wraps instead of overflowing.
              if (trailing != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
                  child: trailing,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// A [ProfileRow] with an on/off switch. The whole row toggles, and is read as one switch.
class ProfileSwitchRow extends StatelessWidget {
  const ProfileSwitchRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ProfileRow(
        icon: icon,
        label: label,
        minHeight: 56,
        onTap: () => onChanged(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// A tappable row ending in the mockup's chevron (›), with an optional [value] before it.
/// Read as one button: label, subtitle and value.
class ProfileNavRow extends StatelessWidget {
  const ProfileNavRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<AppTokens>()?.muted;
    return Semantics(
      button: true,
      label: [label, ?subtitle, ?value].join(', '),
      excludeSemantics: true,
      child: ProfileRow(
        icon: icon,
        label: label,
        subtitle: subtitle,
        minHeight: subtitle == null ? 52 : 60,
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 14, color: muted),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: muted),
          ],
        ),
      ),
    );
  }
}
