import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../widgets/form_widgets.dart';
import '../../l10n/l10n.dart';

/// Pieces shared by the Add device steps (mockup screens 10–12).

AppTokens? tokensOf(BuildContext context) => Theme.of(context).extension<AppTokens>();

/// Back button, "Add device" and "Step n of 4", then the 4-part progress bar.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, required this.onBack});

  final int step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = tokensOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircleBackButton(onPressed: onBack),
            const SizedBox(width: 12),
            // Side by side as in the mockup; the step drops below the title with large text.
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      context.l10n.addDeviceTitle,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    context.l10n.addDeviceStepOf(step),
                    style: TextStyle(fontSize: 13, color: tokens?.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // The step is already read out by the text above.
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 1; i <= 4; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i <= step ? Theme.of(context).colorScheme.primary : tokens?.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A step's heading (18/700) and its muted line below.
class StepHeading extends StatelessWidget {
  const StepHeading(this.heading, this.body, {super.key});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(heading, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Text(body, style: TextStyle(fontSize: 14, color: tokensOf(context)?.muted)),
      ],
    );
  }
}

/// Scrolling content with the step's main button pinned below it.
class StepLayout extends StatelessWidget {
  const StepLayout({super.key, required this.children, this.button});

  final List<Widget> children;
  final Widget? button;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 18, bottom: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
        ?button,
      ],
    );
  }
}

/// A selectable card with an icon tile, a title, a line below and an optional badge. A chosen
/// card has a 2 px accent border and is announced as selected; a disabled one is faded.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? badge;
  final bool selected;

  /// Null disables the card.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = tokensOf(context);
    final radius = BorderRadius.circular(tokens?.radius ?? 16);
    final accent = tokens?.accent ?? Theme.of(context).colorScheme.primary;
    final badgeText = badge == null
        ? null
        : Text(
            badge!,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tokens?.muted),
          );
    // With large text the badge moves under the text, so the title keeps its room.
    final stackBadge = MediaQuery.textScalerOf(context).scale(10) > 13;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
        child: Material(
          color: tokens?.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? accent : (tokens?.border ?? Colors.grey),
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: tokens?.soft,
                      borderRadius: BorderRadius.circular(tokens?.radiusSmall ?? 12),
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(body, style: TextStyle(fontSize: 13, color: tokens?.muted)),
                        if (badgeText != null && stackBadge) ...[
                          const SizedBox(height: 4),
                          badgeText,
                        ],
                      ],
                    ),
                  ),
                  if (badgeText != null && !stackBadge) ...[const SizedBox(width: 8), badgeText],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon of [size] px, optionally on a soft [ring] (the scan step).
class StatusCircle extends StatelessWidget {
  const StatusCircle({
    super.key,
    required this.icon,
    required this.size,
    required this.iconSize,
    this.ring,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  /// Outer soft ring diameter, if any.
  final double? ring;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final tokens = tokensOf(context);
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background ?? tokens?.soft, shape: BoxShape.circle),
      child: Icon(icon, size: iconSize, color: foreground ?? tokens?.accent),
    );
    return ExcludeSemantics(
      child: Center(
        child: ring == null
            ? circle
            : Container(
                width: ring,
                height: ring,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: tokens?.soft, shape: BoxShape.circle),
                child: circle,
              ),
      ),
    );
  }
}

/// A card: surface colour, 1 px border, the config's corner radius.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = tokensOf(context);
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens?.surface,
        border: Border.all(color: tokens?.border ?? Colors.grey),
        borderRadius: BorderRadius.circular(tokens?.radius ?? 16),
      ),
      child: child,
    );
  }
}
