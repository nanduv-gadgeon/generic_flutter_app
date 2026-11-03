import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/config/config_sections.dart';
import '../../core/theme/app_tokens.dart';

/// The customer's logo with the app name below it (login, register, forgot password).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.brand});

  final BrandConfig brand;

  static const _logoSize = 76.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      label: brand.appName,
      excludeSemantics: true,
      child: Column(
        children: [
          SvgPicture.asset(
            brand.logoMark,
            width: _logoSize,
            height: _logoSize,
            // If the logo file is missing, show the initials tile so the screen still works.
            errorBuilder: (_, _, _) => _InitialsTile(initials: brand.initials),
          ),
          const SizedBox(height: 10),
          Text(
            brand.appName,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _InitialsTile extends StatelessWidget {
  const _InitialsTile({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = theme.extension<AppTokens>()?.radius ?? 16;
    return Container(
      width: BrandHeader._logoSize,
      height: BrandHeader._logoSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(radius * 1.3),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontSize: 34,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
