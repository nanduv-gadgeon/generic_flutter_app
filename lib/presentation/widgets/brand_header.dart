import 'package:flutter/material.dart';

import '../../core/config/config_sections.dart';
import '../../core/theme/app_tokens.dart';

/// Brand tile with initials, and the app name below it (login, register, forgot password).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, required this.brand});

  final BrandConfig brand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppTokens>();
    return Semantics(
      header: true,
      label: brand.appName,
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular((tokens?.radius ?? 16) * 1.3),
            ),
            child: Text(
              brand.initials,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 34,
                fontWeight: FontWeight.w800,
              ),
            ),
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
