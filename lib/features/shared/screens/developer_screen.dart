// lib/features/shared/screens/developer_screen.dart
// Phase 4 – Developer Screen (NEW) – split out of About

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../features/auth/providers/auth_providers.dart';

class DeveloperScreen extends ConsumerWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isAdmin = user?.role.toString().contains('admin') ?? false;
    final isVendor = user?.role.toString().contains('vendor') ?? false;
    final scheme = Theme.of(context).colorScheme;

    Future<void> copyDebug() async {
      final info = {
        'app': AppConstants.appName,
        'version': '${AppConstants.appVersion}+${AppConstants.buildNumber}',
        'env': 'production',
        'flutter': '3.32.x',
        'supabase': 'xxx-****',
        'user_id': user?.userId ?? 'guest',
        'role': user?.role.toString(),
        'policy_version': 'v1.0-2025-07',
        'build_date': '2025-07-01',
      };
      await Clipboard.setData(ClipboardData(text: info.entries.map((e)=>'${e.key}: ${e.value}').join('\n')));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debug info copied')));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Developer')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Developer Info', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),

          _section('Build Info', [
            _kv('App Name', AppConstants.appName),
            _kv('Version', '${AppConstants.appVersion}+${AppConstants.buildNumber}'),
            _kv('Build', '2025-07-01'),
            _kv('Environment', 'Production', chip: true, chipColor: Colors.green),
            _kv('Flutter', '3.32.x'),
            _kv('Supabase Project', 'cmp-••••'),
          ], trailing: TextButton.icon(icon: const Icon(Icons.copy, size:16), label: const Text('Copy Debug Info'), onPressed: copyDebug)),

          _section('Tech Stack', [
            const ListTile(dense:true, leading: Icon(Icons.layers_outlined), title: Text('Flutter • Riverpod • GoRouter')),
            const ListTile(dense:true, leading: Icon(Icons.storage_outlined), title: Text('Supabase (Postgres + Auth + Storage + Realtime)')),
            const ListTile(dense:true, leading: Icon(Icons.payments_outlined), title: Text('Paystack Mobile Money')),
            ListTile(dense:true, leading: const Icon(Icons.article_outlined), title: const Text('View Dependencies'), trailing: const Icon(Icons.chevron_right, size:18), onTap: ()=> showLicensePage(context: context)),
          ]),

          _section('API & Integrations', [
            _kv('API Base', 'https://xxx.supabase.co', mono: true),
            _kv('Realtime', 'wss://xxx.supabase.co', mono: true),
            _kv('Storage buckets', 'kyc_docs (private), service_images, store_logos'),
            const ListTile(dense:true, title: Text('API Docs – Coming Soon'), enabled: false),
          ]),

          _section('Open Source', [
            const ListTile(dense:true, title: Text('Built with open source – thank you')),
            ListTile(dense:true, leading: const Icon(Icons.balance_outlined), title: const Text('View Licenses'), trailing: const Icon(Icons.chevron_right, size:18), onTap: ()=> showLicensePage(context: context)),
            ListTile(dense:true, leading: const Icon(Icons.code), title: const Text('GitHub'), subtitle: const Text('github.com/campus-marketplace'), onTap: ()=> launchUrl(Uri.parse('https://github.com')), trailing: const Icon(Icons.open_in_new, size:16)),
          ]),

          _section('Developer Contact', [
            _kv('Lead Dev', AppConstants.devName),
            _kv('Email', AppConstants.devEmail),
            ListTile(dense:true, leading: const Icon(Icons.bug_report_outlined), title: const Text('Report Bug'), onTap: ()=> launchUrl(Uri.parse('mailto:${AppConstants.devEmail}?subject=Bug Report – ${AppConstants.appVersion}'))),
            ListTile(dense:true, leading: const Icon(Icons.lightbulb_outline), title: const Text('Feature Request'), onTap: (){}),
            ListTile(dense:true, leading: const Icon(Icons.chat_outlined), title: const Text('WhatsApp Dev Channel'), subtitle: Text(AppConstants.devWhatsApp), onTap: ()=> launchUrl(Uri.parse('https://wa.me/${AppConstants.devWhatsApp}'))),
            const ListTile(dense:true, title: Text('Response SLA: 48hr')),
          ]),

          if (isAdmin || isVendor) _section('Role Tools', [
            if (isAdmin) ...[
              const ListTile(dense:true, leading: Icon(Icons.dns_outlined), title: Text('DB Migration Status'), subtitle: Text('0019 applied ✓'), trailing: Icon(Icons.check_circle, color: Colors.green, size:18)),
              const ListTile(dense:true, leading: Icon(Icons.bolt_outlined), title: Text('Edge Function Logs'), subtitle: Text('View in Supabase')),
              ListTile(dense:true, leading: const Icon(Icons.refresh), title: const Text('Force Expiration Cron'), onTap: (){}),
              ListTile(dense:true, leading: const Icon(Icons.cleaning_services_outlined), title: const Text('Clear Cache'), onTap: (){}),
            ],
            if (isVendor && !isAdmin) ...[
              const ListTile(dense:true, enabled:false, title: Text('API Test Console – disabled')),
              const ListTile(dense:true, enabled:false, title: Text('Webhook Test – coming soon')),
            ],
          ]),

          if (!isAdmin && !isVendor)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Interested in building?', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 6),
                  const Text('Join the Campus Marketplace dev team – Flutter + Supabase.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(icon: const Icon(Icons.code), label: const Text('Contribute'), onPressed: (){}),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.lg),
          Center(child: Column(children: [
            const Text('Made with ♥ in Kumasi, Ghana'),
            const SizedBox(height: 4),
            Text('© ${2025} ${AppConstants.devBusinessName}', style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            const Text('DPA Compliance: Data Protection Act 2012', style: TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            Wrap(spacing: 16, alignment: WrapAlignment.center, children: [
              _link('Privacy Policy'),
              _link('Terms'),
              _link('Seller Agreement v1.0'),
            ]),
          ])),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static Widget _section(String title, List<Widget> children, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: Text(title, style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700))), if (trailing != null) trailing]),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  static Widget _kv(String k, String v, {bool chip=false, Color? chipColor, bool mono=false}) {
    return ListTile(
      dense: true,
      title: Text(k, style: AppTextStyles.bodySmall),
      subtitle: chip
          ? Align(alignment: Alignment.centerLeft, child: Chip(label: Text(v, style: const TextStyle(fontSize: 11)), backgroundColor: (chipColor ?? Colors.grey).withValues(alpha:.15), side: BorderSide.none, visualDensity: VisualDensity.compact))
          : Text(v, style: mono ? const TextStyle(fontFamily: 'monospace', fontSize: 13) : AppTextStyles.titleSmall),
      contentPadding: EdgeInsets.zero,
    );
  }

  static Widget _link(String t) => Text(t, style: const TextStyle(fontSize: 12, decoration: TextDecoration.underline));
}
