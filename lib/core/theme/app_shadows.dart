import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Soft elevation tokens — low opacity, large blur for a modern floating feel.
/// Three levels only, matching the design-system elevation scale.
class AppShadows {
  AppShadows._();

  /// Level 1 — resting cards, list tiles.
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x0F000000), // black @ ~6%
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Level 2 — sticky bars, raised cards, popovers.
  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x14000000), // black @ ~8%
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  /// Level 3 — menus, dialogs, things floating well above content.
  static const List<BoxShadow> level3 = [
    BoxShadow(
      color: Color(0x1A000000), // black @ ~10%
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  /// Branded glow used under primary CTAs / hero surfaces.
  static List<BoxShadow> brand = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.28),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
