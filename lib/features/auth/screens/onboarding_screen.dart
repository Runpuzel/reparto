import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_brand_mark.dart';

/// A2 — Welcome / Onboarding. Shown on first launch or after sign-out.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const _cards = [
    (
    AppIcons.bag,
    'Buy & Sell on Campus',
    'Find great deals from students near you, or list your own items in seconds.'
    ),
    (
    AppIcons.services,
    'Hire Student Talent',
    'Book trusted student services — barbering, repairs, tutoring and more.'
    ),
    (
    AppIcons.tag,
    'Earn Token Rewards',
    'Invite friends and earn tokens you can redeem for boosts and discounts.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const Spacer(),
                  const AppBrandMark(size: 104)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(begin: const Offset(0.95, 0.95)),
                  const SizedBox(height: AppSpacing.xl),
                  ..._cards.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                    child: _ValueCard(
                      icon: e.value.$1,
                      title: e.value.$2,
                      body: e.value.$3,
                    )
                        .animate()
                        .fadeIn(delay: (120 * e.key).ms, duration: 350.ms)
                        .slideY(begin: 0.1, end: 0),
                  )),
                  const Spacer(),
                  AppButton(
                    label: 'Get Started',
                    icon: AppIcons.arrowRight,
                    onPressed: () => context.push('/register/student'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Sign In'),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: () => context.go('/student'),
                    child: Text(
                      'Browse without an account',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _ValueCard(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(body, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
