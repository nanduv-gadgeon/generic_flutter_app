import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/config/config_sections.dart';
import '../../core/theme/app_tokens.dart';

/// The customer's logo with the app name below it.
class BrandHeader extends StatelessWidget {
  /// Logo tile and name on the normal background (login, register, forgot password).
  const BrandHeader({super.key, required this.brand}) : _logoSize = 76, _gap = 10, _onColor = null;

  /// Splash logo and white name, drawn on [background] (the config's primary colour).
  const BrandHeader.splash({super.key, required this.brand, required Color background})
    : _logoSize = 96,
      _gap = 14,
      _onColor = background;

  final BrandConfig brand;
  final double _logoSize;
  final double _gap;

  /// The background colour when drawn on it (splash); null for the normal background.
  final Color? _onColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onColor = _onColor;
    final nameStyle = theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800);
    return Semantics(
      header: true,
      label: brand.appName,
      excludeSemantics: true,
      child: Column(
        children: [
          SvgPicture.asset(
            onColor == null ? brand.logoMark : brand.logoSplash,
            width: _logoSize,
            height: _logoSize,
            // If the logo file is missing, show the initials tile so the screen still works.
            errorBuilder: (_, _, _) => _InitialsTile(
              initials: brand.initials,
              size: _logoSize,
              background: onColor == null ? theme.colorScheme.primary : Colors.white,
              foreground: onColor ?? theme.colorScheme.onPrimary,
            ),
          ),
          SizedBox(height: _gap),
          Text(
            brand.appName,
            style: onColor == null
                ? nameStyle
                : nameStyle?.copyWith(color: Colors.white, fontSize: 32, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }
}

class _InitialsTile extends StatelessWidget {
  const _InitialsTile({
    required this.initials,
    required this.size,
    required this.background,
    required this.foreground,
  });

  final String initials;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final radius = Theme.of(context).extension<AppTokens>()?.radius ?? 16;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius * 1.3),
      ),
      child: Text(
        initials,
        style: TextStyle(color: foreground, fontSize: size * 0.45, fontWeight: FontWeight.w800),
      ),
    );
  }
}
