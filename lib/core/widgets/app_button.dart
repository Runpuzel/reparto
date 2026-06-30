import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Visual variants for [AppButton].
enum AppButtonVariant { primary, secondary, ghost }

/// A single, reusable button used across the whole app.
///
/// • [primary]   — filled brand background, white label
/// • [secondary] — outlined with brand border, brand label
/// • [ghost]     — no border/background, brand label
///
/// All variants are ≥48px tall, use [AppRadius.md] corners, an Inter 14px
/// medium label, a ripple, a press-scale micro-interaction (0.97) and a
/// built-in [loading] state that swaps the label for a spinner.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;

  /// Whether the button stretches to fill its parent width.
  final bool expand;
  final double height;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPrimary = widget.variant == AppButtonVariant.primary;
    final isSecondary = widget.variant == AppButtonVariant.secondary;

    final Color fg = isPrimary ? AppColors.onPrimary : scheme.primary;
    final Color bg =
    isPrimary ? scheme.primary : Colors.transparent;

    final BorderSide side = isSecondary
        ? BorderSide(color: scheme.primary.withValues(alpha: 0.55), width: 1.4)
        : BorderSide.none;

    final spinner = SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        valueColor: AlwaysStoppedAnimation<Color>(fg),
      ),
    );

    final content = widget.loading
        ? spinner
        : Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.labelLarge.copyWith(color: fg),
          ),
        ),
      ],
    );

    return AnimatedScale(
      scale: _pressed && _enabled ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: Opacity(
        opacity: _enabled ? 1 : 0.55,
        child: Material(
          color: bg,
          borderRadius: AppRadius.brMd,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _enabled ? widget.onPressed : null,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            splashColor: (isPrimary ? Colors.white : scheme.primary)
                .withValues(alpha: 0.12),
            child: Container(
              height: widget.height,
              width: widget.expand ? double.infinity : null,
              padding: EdgeInsets.symmetric(
                  horizontal: widget.expand ? AppSpacing.md : AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: AppRadius.brMd,
                border: Border.fromBorderSide(side),
              ),
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
