import 'package:flutter/material.dart';

/// Design tokens from the mockup that `ColorScheme` does not cover.
///
/// Status and neutral colours are the same for every customer; `accent`, `soft` and the radii come
/// from the config. Read them in widgets with `Theme.of(context).extension<AppTokens>()!`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.surface,
    required this.muted,
    required this.border,
    required this.chipBg,
    required this.accent,
    required this.soft,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.okBg,
    required this.warnBg,
    required this.dangerBg,
    required this.radius,
    required this.radiusSmall,
  });

  factory AppTokens.light({
    required Color primary,
    required double radius,
    required double radiusSmall,
  }) => AppTokens(
    surface: const Color(0xFFFFFFFF),
    muted: const Color(0xFF5B6472),
    border: const Color(0xFFE2E6EC),
    chipBg: const Color(0xFFEEF1F5),
    accent: primary,
    soft: primary.withAlpha(0x17),
    ok: const Color(0xFF15803D),
    warn: const Color(0xFFB45309),
    danger: const Color(0xFFB91C1C),
    okBg: const Color(0x1715803D),
    warnBg: const Color(0x17B45309),
    dangerBg: const Color(0x14B91C1C),
    radius: radius,
    radiusSmall: radiusSmall,
  );

  factory AppTokens.dark({
    required Color accent,
    required double radius,
    required double radiusSmall,
  }) => AppTokens(
    surface: const Color(0xFF151E2E),
    muted: const Color(0xFF9AA4B2),
    border: const Color(0xFF263044),
    chipBg: const Color(0xFF1E2838),
    accent: accent,
    soft: accent.withAlpha(0x26),
    ok: const Color(0xFF4ADE80),
    warn: const Color(0xFFFBBF24),
    danger: const Color(0xFFF87171),
    okBg: const Color(0x244ADE80),
    warnBg: const Color(0x24FBBF24),
    dangerBg: const Color(0x24F87171),
    radius: radius,
    radiusSmall: radiusSmall,
  );

  final Color surface;
  final Color muted;
  final Color border;
  final Color chipBg;
  final Color accent;
  final Color soft;
  final Color ok;
  final Color warn;
  final Color danger;
  final Color okBg;
  final Color warnBg;
  final Color dangerBg;
  final double radius;
  final double radiusSmall;

  @override
  AppTokens copyWith({
    Color? surface,
    Color? muted,
    Color? border,
    Color? chipBg,
    Color? accent,
    Color? soft,
    Color? ok,
    Color? warn,
    Color? danger,
    Color? okBg,
    Color? warnBg,
    Color? dangerBg,
    double? radius,
    double? radiusSmall,
  }) => AppTokens(
    surface: surface ?? this.surface,
    muted: muted ?? this.muted,
    border: border ?? this.border,
    chipBg: chipBg ?? this.chipBg,
    accent: accent ?? this.accent,
    soft: soft ?? this.soft,
    ok: ok ?? this.ok,
    warn: warn ?? this.warn,
    danger: danger ?? this.danger,
    okBg: okBg ?? this.okBg,
    warnBg: warnBg ?? this.warnBg,
    dangerBg: dangerBg ?? this.dangerBg,
    radius: radius ?? this.radius,
    radiusSmall: radiusSmall ?? this.radiusSmall,
  );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    double d(double a, double b) => a + (b - a) * t;
    return AppTokens(
      surface: c(surface, other.surface),
      muted: c(muted, other.muted),
      border: c(border, other.border),
      chipBg: c(chipBg, other.chipBg),
      accent: c(accent, other.accent),
      soft: c(soft, other.soft),
      ok: c(ok, other.ok),
      warn: c(warn, other.warn),
      danger: c(danger, other.danger),
      okBg: c(okBg, other.okBg),
      warnBg: c(warnBg, other.warnBg),
      dangerBg: c(dangerBg, other.dangerBg),
      radius: d(radius, other.radius),
      radiusSmall: d(radiusSmall, other.radiusSmall),
    );
  }
}
