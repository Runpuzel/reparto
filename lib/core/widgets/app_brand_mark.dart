import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_icons.dart';

/// The canonical UjustBUY brand mark.
///
/// Keeping the asset, framing, and semantics here prevents entry screens from
/// drifting back to template or legacy logos.
class AppBrandMark extends StatelessWidget {
  final double size;
  final bool elevated;

  const AppBrandMark({
    super.key,
    this.size = 112,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = size * 0.22;

    return Semantics(
      image: true,
      label: '${AppConstants.appName} logo',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.035),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: scheme.primary.withValues(alpha: dark ? 0.42 : 0.16),
          ),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
                    blurRadius: size * 0.24,
                    offset: Offset(0, size * 0.09),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius * 0.78),
          child: Image.asset(
            AppConstants.appIconAsset,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (_, __, ___) => Icon(
              AppIcons.storefrontFill,
              size: size * 0.54,
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
