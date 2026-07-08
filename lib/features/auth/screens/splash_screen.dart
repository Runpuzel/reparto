import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../providers/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _continueToApp();
  }

  Future<void> _continueToApp() async {
    final userFuture = ref.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    final user = await userFuture.catchError((_) => null);
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

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primaryContainer.withValues(alpha: dark ? 0.28 : 0.5),
              scheme.surface,
              scheme.surface,
            ],
            stops: const [0, 0.48, 1],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 760) {
                return _buildWebSplash(context, constraints, scheme, dark);
              }
              final shortestSide = constraints.biggest.shortestSide;
              final logoSize = (shortestSide * 0.42).clamp(112.0, 180.0);

              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.lg,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                  Container(
                    width: logoSize,
                    height: logoSize,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: AppRadius.brXl,
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.8),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: dark ? 0.3 : 0.1),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: AppRadius.brLg,
                      child: Image.asset(
                        'assets/ujustbuy_logo.jpeg',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.storefront_rounded,
                          size: 72,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 420.ms)
                      .scale(
                        begin: const Offset(0.88, 0.88),
                        end: const Offset(1, 1),
                        duration: 650.ms,
                        curve: Curves.easeOutBack,
                      ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displayMedium.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.15, end: 0),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Your campus marketplace',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 280.ms),
                  const SizedBox(height: AppSpacing.xl + AppSpacing.md),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                      color: scheme.primary,
                      backgroundColor:
                          scheme.primary.withValues(alpha: dark ? 0.18 : 0.12),
                    ),
                  ).animate().fadeIn(delay: 350.ms),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Connecting your campus…',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ).animate().fadeIn(delay: 420.ms),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWebSplash(BuildContext context, BoxConstraints constraints,
      ColorScheme scheme, bool dark) {
    return Stack(
      children: [
        Positioned(
          right: -120,
          top: -180,
          child: Container(
            width: 560,
            height: 560,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: dark ? 0.16 : 0.09),
            ),
          ),
        ),
        Positioned(
          left: -160,
          bottom: -260,
          child: Container(
            width: 620,
            height: 620,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: dark ? 0.1 : 0.06),
            ),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.brFull,
                          ),
                          child: Text('CAMPUS MARKETPLACE',
                              style: AppTextStyles.labelSmall.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2)),
                        ),
                        const SizedBox(height: 24),
                        Text('Buy, sell, and connect\non your campus.',
                            style: AppTextStyles.displayLarge.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w800,
                                height: 1.08)),
                        const SizedBox(height: 18),
                        Text(
                          'Discover trusted student sellers, local services, and secure order communication—all in one place.',
                          style: AppTextStyles.bodyLarge.copyWith(
                              color: scheme.onSurfaceVariant, height: 1.6),
                        ),
                        const SizedBox(height: 36),
                        Row(children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: scheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Text('Opening UjustBUY…',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: scheme.onSurfaceVariant)),
                        ]),
                      ],
                    ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.04),
                  ),
                  const SizedBox(width: 72),
                  Expanded(
                    flex: 4,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 390),
                      padding: const EdgeInsets.all(34),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: AppRadius.brXl,
                        border: Border.all(color: scheme.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: dark ? 0.3 : 0.1),
                            blurRadius: 46,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: AppRadius.brLg,
                            child: Image.asset('assets/ujustbuy_logo.jpeg',
                                height: 210,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                    Icons.storefront_rounded,
                                    size: 110,
                                    color: scheme.primary)),
                          ),
                          const SizedBox(height: 22),
                          Text(AppConstants.appName,
                              style: AppTextStyles.headlineMedium.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('Your campus. Your marketplace.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ).animate().fadeIn(delay: 120.ms).scale(
                        begin: const Offset(0.96, 0.96),
                        duration: 550.ms,
                        curve: Curves.easeOut),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
