import 'package:flutter/material.dart';

/// Radar rings that spread out from [child] and fade while a scan is [active]. Still when not
/// active or when the phone asks for reduced motion. Decorative only: the text next to it says
/// that a scan is running.
class ScanPulse extends StatefulWidget {
  const ScanPulse({
    super.key,
    required this.active,
    required this.color,
    required this.child,
    this.from = 76,
    this.to = 150,
  });

  final bool active;
  final Color color;
  final Widget child;

  /// Ring diameter when it starts (the circle's size) and when it has faded out.
  final double from;
  final double to;

  /// One ring's life; a second ring follows half a period behind.
  static const period = Duration(milliseconds: 1600);

  @override
  State<ScanPulse> createState() => _ScanPulseState();
}

class _ScanPulseState extends State<ScanPulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: ScanPulse.period);

  bool get _running => widget.active && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ScanPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_running) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (_running)
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _RingsPainter(_controller, widget.color, widget.from, widget.to),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.progress, this.color, this.from, this.to) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final double from;
  final double to;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final offset in const [0.0, 0.5]) {
      final t = Curves.easeOut.transform((progress.value + offset) % 1);
      final paint = Paint()..color = color.withValues(alpha: 0.35 * (1 - t));
      canvas.drawCircle(center, (from + (to - from) * t) / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.color != color || old.from != from || old.to != to || old.progress != progress;
}
