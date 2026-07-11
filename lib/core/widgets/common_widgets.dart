import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../utils/app_error.dart';

/// A reusable async-value renderer with consistent loading/error states.
class AsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(error: e, onRetry: onRetry),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String? message;
  final Object? error;
  final VoidCallback? onRetry;

  const ErrorState({super.key, this.message, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOffline = AppError.isOffline(error ?? message);

    // Ensure even if a technical string is passed in 'message', we show a friendly one.
    final displayMessage = AppError.friendly(error ?? message);

    final icon = isOffline
        ? Icons.wifi_off_rounded
        : Icons.error_outline_rounded;
    final title = isOffline ? 'No Internet Connection' : 'Something went wrong';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (isOffline ? scheme.primary : scheme.error).withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: isOffline ? scheme.primary : scheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: Icon(
                  isOffline ? Icons.refresh : Icons.replay_rounded,
                  size: 18,
                ),
                label: Text(isOffline ? 'Try Reconnecting' : 'Try again'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 48),
                  backgroundColor: isOffline ? scheme.primary : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  subtitle!,
                  style: TextStyle(color: muted, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// Brand logo lockup used in headers / auth screens.
class UjustBuyLogo extends StatelessWidget {
  final double size;
  final bool showText;
  const UjustBuyLogo({super.key, this.size = 48, this.showText = true});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.35),
                blurRadius: size * 0.3,
                offset: Offset(0, size * 0.12),
              ),
            ],
          ),
          child: Icon(
            Icons.storefront_rounded,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }
}

/// A branded "Continue with Google" button using the multicolor G mark.
class GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  const GoogleButton({
    super.key,
    required this.onPressed,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.58,
      duration: const Duration(milliseconds: 160),
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style:
              OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: scheme.primary,
                side: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.55),
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 0,
              ).copyWith(
                overlayColor: WidgetStatePropertyAll(
                  scheme.primary.withValues(alpha: 0.08),
                ),
              ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _GoogleG(size: 20),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lightweight Google "G" rendered with a custom painter (no asset needed).
class _GoogleG extends StatelessWidget {
  final double size;
  const _GoogleG({this.size = 20});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22;

    // Four arcs in Google brand colors.
    p.color = const Color(0xFF4285F4); // blue
    canvas.drawArc(rect.deflate(w * 0.11), -0.3, 1.2, false, p);
    p.color = const Color(0xFF34A853); // green
    canvas.drawArc(rect.deflate(w * 0.11), 0.9, 1.2, false, p);
    p.color = const Color(0xFFFBBC05); // yellow
    canvas.drawArc(rect.deflate(w * 0.11), 2.1, 1.0, false, p);
    p.color = const Color(0xFFEA4335); // red
    canvas.drawArc(rect.deflate(w * 0.11), 3.1, 1.3, false, p);

    // Horizontal bar of the G.
    final bar = Paint()..color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(w * 0.5, h * 0.42, w * 0.42, h * 0.16), bar);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(color, Colors.white, 0.22)!
        : color;
    return Container(
      padding: EdgeInsets.fromLTRB(icon != null ? 7 : 10, 4, 10, 4),
      decoration: BoxDecoration(
        color: displayColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: displayColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: displayColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: displayColor,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

Color orderStatusColor(OrderStatus s, BuildContext ctx) {
  switch (s) {
    case OrderStatus.pending:
      return AppTheme.warning;
    case OrderStatus.confirmed:
    case OrderStatus.accepted:
      return AppTheme.info;
    case OrderStatus.preparing:
      return const Color(0xFF6D5BD0); // calm violet
    case OrderStatus.dispatched:
    case OrderStatus.readyForPickup:
      return const Color(0xFF0E8A8A); // teal
    case OrderStatus.delivered:
    case OrderStatus.completed:
      return AppTheme.success;
    case OrderStatus.cancelled:
      return AppTheme.danger;
    case OrderStatus.disputed:
      return const Color(0xFFB7791F); // amber — needs attention
  }
}

/// Icon paired with each order status (used in timelines & lists).
IconData orderStatusIcon(OrderStatus s) {
  switch (s) {
    case OrderStatus.pending:
      return Icons.receipt_long_outlined;
    case OrderStatus.confirmed:
    case OrderStatus.accepted:
      return Icons.check_circle_outline;
    case OrderStatus.preparing:
      return Icons.soup_kitchen_outlined;
    case OrderStatus.dispatched:
    case OrderStatus.readyForPickup:
      return Icons.local_shipping_outlined;
    case OrderStatus.delivered:
    case OrderStatus.completed:
      return Icons.inventory_2_outlined;
    case OrderStatus.cancelled:
      return Icons.cancel_outlined;
    case OrderStatus.disputed:
      return Icons.gavel_outlined;
  }
}
