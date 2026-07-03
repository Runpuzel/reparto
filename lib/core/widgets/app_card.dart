import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// A single, reusable surface container.
///
/// White (surface) background, [AppRadius.lg] corners, soft [AppShadows.level1]
/// elevation and consistent internal padding of [AppSpacing.md]. When [onTap]
/// is provided it becomes tappable with a ripple and a subtle press-scale.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.borderRadius,
    this.color,
    this.shadows,
    this.border,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? color;
  final List<BoxShadow>? shadows;
  final BoxBorder? border;
  final bool clip;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = widget.borderRadius ?? AppRadius.brLg;
    final bg = widget.color ?? scheme.surfaceContainerLowest;

    Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        boxShadow: widget.shadows ?? AppShadows.level1,
        border: widget.border ??
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );

    if (widget.onTap == null) {
      return widget.clip
          ? ClipRRect(borderRadius: radius, child: surface)
          : surface;
    }

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: bg,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              boxShadow: widget.shadows ?? AppShadows.level1,
              border: widget.border ??
                  Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.8)),
            ),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
