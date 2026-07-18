// lib/features/shared/screens/about_screen.dart
// v1.0-2025-07 – Refactored – focused About (Developer split out)

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_brand_mark.dart';

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
                const AppBrandMark(size: 104),
                const SizedBox(height: AppSpacing.sm + 4),
                Text(
                  'UjustBUY',
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
            'UjustBUY connects Ghanaian student sellers with student buyers – '
                'right on campus. Built for students, by students.\n\n'
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
                  '• Verified Student Seller badge – Student ID checked\n'
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
                  onTap: () => _showLegal(context, 'Terms of Service',
                      'Use UjustBUY lawfully and honestly. Keep orders, payments, and communication inside the app. Sellers must describe items accurately and fulfil accepted orders. Fraud, unsafe items, harassment, and attempts to bypass platform protections may result in suspension.'),
                ),
                const Divider(height: 1),
                _linkTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  subtitle: 'DPA 2012 compliant',
                  onTap: () => _showLegal(context, 'Privacy Policy',
                      'UjustBUY processes account, order, payment, and verification information only to operate and protect the marketplace. Identity documents are restricted to authorised review and handled under Ghana\'s Data Protection Act, 2012 (Act 843).'),
                ),
                _linkTile(
                  context,
                  icon: Icons.support_agent_outlined,
                  label: 'Help & Support',
                  subtitle: AppConstants.devEmail,
                  onTap: () => _showLegal(context, 'Help & Support',
                      'For account, order, payment, or verification assistance, email ${AppConstants.devEmail}. Include your order reference when asking about an order. Please never send passwords or passcodes.'),
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
              Chip(label: Text('USTED-K', style: TextStyle(fontSize: 12))),
              Chip(
                  label:
                      Text('USTED-MAMPONG', style: TextStyle(fontSize: 12))),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Column(
              children: [
                Text(
                  'Made with ♥ in Ghana',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '© ${2025} ${AppConstants.devBusinessName}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: scheme.onSurfaceVariant),
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

  Future<void> _showLegal(
      BuildContext context, String title, String content) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }
}
