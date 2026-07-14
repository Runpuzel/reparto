import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_brand_mark.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const _minimumDisplayTime = Duration(milliseconds: 950);

  @override
  void initState() {
    super.initState();
    _continueToApp();
  }

  Future<void> _continueToApp() async {
    final userFuture = ref.read(currentUserProvider.future);
    final startedAt = DateTime.now();
    final user = await userFuture.catchError((_) => null);
    final remaining = _minimumDisplayTime - DateTime.now().difference(startedAt);

    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted) return;

    if (user == null) {
      context.go('/student');
      return;
    }
    if (user.needsCampus && user.role != UserRole.admin) {
      context.go('/select-campus');
      return;
    }
    switch (user.role) {
      case UserRole.student:
        context.go('/student');
        return;
      case UserRole.vendor:
        context.go('/vendor');
        return;
      case UserRole.admin:
        context.go('/admin');
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              dark ? AppColors.backgroundDark : AppColors.primary50,
              scheme.surface,
              dark
                  ? AppColors.surfaceDark
                  : AppColors.secondary.withValues(alpha: 0.07),
            ],
            stops: const [0, 0.56, 1],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -120,
              top: -180,
              child: _AmbientOrb(
                size: 460,
                color: scheme.primary.withValues(alpha: dark ? 0.14 : 0.09),
              ),
            ),
            Positioned(
              left: -320,
              bottom: -260,
              child: _AmbientOrb(
                size: 520,
                color: scheme.secondary.withValues(alpha: dark ? 0.13 : 0.07),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final shortestSide = constraints.biggest.shortestSide;
                  final compact = constraints.maxHeight <= 560;
                  final logoSize = kIsWeb
                      ? (compact ? 90.0 : 124.0)
                      : (shortestSide * 0.27)
                          .clamp(112.0, 154.0)
                          .toDouble();
                  final skipEntrance = reduceMotion || kIsWeb;

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.xl,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _AnimatedBrandMark(
                                  size: logoSize,
                                  reduceMotion: reduceMotion,
                                  showImmediately: kIsWeb,
                                ),
                                SizedBox(
                                  height: compact
                                      ? AppSpacing.md
                                      : AppSpacing.lg,
                                ),
                                _Entrance(
                                  reduceMotion: skipEntrance,
                                  delay: 130.ms,
                                  child: Text(
                                    AppConstants.appName,
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.displayLarge.copyWith(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _Entrance(
                                  reduceMotion: skipEntrance,
                                  delay: 210.ms,
                                  child: Text(
                                    'Your campus. Your marketplace.',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 22 : 34),
                                _Entrance(
                                  reduceMotion: skipEntrance,
                                  delay: 300.ms,
                                  child: Text(
                                    'Opening your marketplace…',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _Entrance(
                                  reduceMotion: skipEntrance,
                                  delay: 350.ms,
                                  child: _OpeningIndicator(
                                    reduceMotion: reduceMotion,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _AnimatedBrandMark extends StatelessWidget {
  final double size;
  final bool reduceMotion;
  final bool showImmediately;

  const _AnimatedBrandMark({
    required this.size,
    required this.reduceMotion,
    required this.showImmediately,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final halo = Container(
      width: size + 38,
      height: size + 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.19),
            scheme.primary.withValues(alpha: 0),
          ],
          stops: const [0.42, 1],
        ),
      ),
    );

    final animatedHalo = reduceMotion
        ? halo
        : halo
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(
              begin: const Offset(0.96, 0.96),
              end: const Offset(1.05, 1.05),
              duration: 1300.ms,
              curve: Curves.easeInOut,
            );

    final mark = AppBrandMark(size: size);
    final animatedMark = reduceMotion || showImmediately
        ? mark
        : mark.animate().fadeIn(duration: 420.ms).scale(
              begin: const Offset(0.86, 0.86),
              end: const Offset(1, 1),
              duration: 680.ms,
              curve: Curves.easeOutBack,
            );

    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [animatedHalo, animatedMark],
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final bool reduceMotion;

  const _Entrance({
    required this.child,
    required this.delay,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return child
        .animate()
        .fadeIn(delay: delay, duration: 320.ms)
        .slideY(
          begin: 0.09,
          end: 0,
          delay: delay,
          duration: 320.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _OpeningIndicator extends StatelessWidget {
  final bool reduceMotion;

  const _OpeningIndicator({required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Loading',
      child: ClipRRect(
        borderRadius: AppRadius.brFull,
        child: SizedBox(
          width: 156,
          height: 5,
          child: reduceMotion
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: scheme.primary.withValues(alpha: 0.13),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.44,
                        heightFactor: 1,
                        child: ClipRRect(
                          borderRadius: AppRadius.brFull,
                          child: ColoredBox(color: scheme.primary),
                        ),
                      ),
                    ),
                  ],
                )
              : LinearProgressIndicator(
                  color: scheme.primary,
                  backgroundColor: scheme.primary.withValues(alpha: 0.13),
                ),
        ),
      ),
    );
  }
}
