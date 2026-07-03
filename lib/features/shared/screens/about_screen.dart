// lib/features/shared/screens/about_screen.dart
// v1.0-2025-07 – Refactored – focused About (Developer split out)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: AppSpacing.sm + 4),
          // Brand header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: AppRadius.brXl,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Image.asset(
                    'assets/ujustbuy_logo.jpeg',
                    height: 64,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      AppIcons.storefrontFill,
                      size: 48,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                Text(
                  'Campus Marketplace',
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 4, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: AppRadius.brFull,
                  ),
                  child: Text(
                    'Version ${AppConstants.appVersion} (${AppConstants.buildNumber})',
                    style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 12.5, color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Mission
          Text('Our Mission',
              style: AppTextStyles.titleMedium
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Campus Marketplace connects Ghanaian student sellers with student buyers – '
                'right on campus. Built in Kumasi for students, by students.\n\n'
                'We believe every student side-hustle deserves trust, discoverability, '
                'and safe payments.',
            style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Safety promise
          AppCard(
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_user_outlined,
                        color: scheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Safety Promise',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Verified Student Seller badge – Ghana Card or Student ID checked\n'
                      '• Unverified sellers = Cash on Delivery only\n'
                      '• Escrow – 48hr buyer confirmation\n'
                      '• 24hr content takedown SLA\n'
                      '• Ghana Data Protection Act 2012 compliant',
                  style: TextStyle(height: 1.6, fontSize: 13.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Quick links
          Text('Legal & Support',
              style: AppTextStyles.titleSmall
                  .copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _linkTile(
                  context,
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () => _openUrl(
                      context, 'https://campusmarketplace.gh/terms'),
                ),
                const Divider(height: 1),
                _linkTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  subtitle: 'DPA 2012 compliant',
                  onTap: () => _openUrl(
                      context, 'https://campusmarketplace.gh/privacy'),
                ),
                const Divider(height: 1),
                _linkTile(
                  context,
                  icon: Icons.gavel_outlined,
                  label: 'Seller Agreement v1.0',
                  onTap: () => context.push('/vendor/agreement'),
                ),
                const Divider(height: 1),
                _linkTile(
                  context,
                  icon: Icons.support_agent_outlined,
                  label: 'Help & Support',
                  subtitle: 'help@campusmarketplace.gh',
                  onTap: () => _openUrl(
                      context, 'mailto:help@campusmarketplace.gh'),
                ),
                const Divider(height: 1),
                _linkTile(
                  context,
                  icon: Icons.code,
                  label: 'Developer Info',
                  subtitle: 'Build info, API, open source →',
                  onTap: () => context.push('/profile/developer'),
                  emphasized: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Campuses
          Text('Campuses',
              style: AppTextStyles.titleSmall
                  .copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: const [
              Chip(label: Text('KNUST', style: TextStyle(fontSize: 12))),
              Chip(label: Text('UG', style: TextStyle(fontSize: 12))),
              Chip(label: Text('UCC', style: TextStyle(fontSize: 12))),
              Chip(label: Text('UDS', style: TextStyle(fontSize: 12))),
              Chip(label: Text('+ more', style: TextStyle(fontSize: 12))),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Column(
              children: [
                Text(
                  'Made with ♥ in Kumasi, Ghana',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '© ${2025} ${AppConstants.devBusinessName}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.push('/profile/developer'),
                  child: const Text(
                    'Technical details → Developer screen',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _linkTile(
      BuildContext context, {
        required IconData icon,
        required String label,
        String? subtitle,
        required VoidCallback onTap,
        bool emphasized = false,
      }) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon,
          color: emphasized ? scheme.primary : null),
      title: Text(
        label,
        style: emphasized
            ? AppTextStyles.bodyMedium
            .copyWith(fontWeight: FontWeight.w700, color: scheme.primary)
            : null,
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (_) {}
  }
}
