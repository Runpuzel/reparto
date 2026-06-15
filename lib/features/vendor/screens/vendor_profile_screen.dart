import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/developer_info_card.dart';
import '../../../core/widgets/notifications_diagnostic_tile.dart';
import '../../../core/widgets/theme_mode_tile.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';

class VendorProfileScreen extends ConsumerWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(currentVendorProvider);
    final user = ref.watch(currentUserProvider);

    return AsyncView<Vendor?>(
      value: vendor,
      data: (v) {
        if (v == null) return const SizedBox();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor:
                Theme.of(context).colorScheme.primaryContainer,
                backgroundImage:
                (v.logoUrl != null && v.logoUrl!.isNotEmpty)
                    ? NetworkImage(v.logoUrl!)
                    : null,
                child: (v.logoUrl == null || v.logoUrl!.isEmpty)
                    ? const Icon(Icons.storefront, size: 42)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Center(
                child: Text(v.businessName,
                    style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 6),
            Center(
                child: StatusPill(
                    label: v.approvalStatus.label,
                    color: v.isApproved ? Colors.green : Colors.orange)),
            const SizedBox(height: 24),
            _tile(context, Icons.person_outline, 'Owner', v.ownerName ?? '—'),
            _tile(context, Icons.phone_outlined, 'Personal Phone',
                v.phoneNumber ?? '—'),
            _tile(context, Icons.call_outlined, 'Business Phone',
                v.businessPhone ?? '—'),
            _tile(context, Icons.account_balance_wallet_outlined, 'Mobile Money',
                v.momoNumber == null
                    ? '—'
                    : '${v.momoNumber} (${v.momoNetwork ?? ''})'),
            _tile(context, Icons.badge_outlined, 'Ghana Card',
                v.ghanaCardNumber ?? '—'),
            _tile(context, Icons.mail_outline, 'Email',
                user.valueOrNull?.email ?? '—'),
            const SizedBox(height: 12),
            const ThemeModeTile(),
            const SizedBox(height: 12),
            const NotificationsDiagnosticTile(),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Forgot / Reset passcode'),
                subtitle: const Text('Contact support to reset your passcode'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/forgot-passcode'),
              ),
            ),
            const SizedBox(height: 12),
            const DeveloperInfoCard(),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style:
              OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(
      BuildContext context, IconData icon, String label, String value) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label, style: Theme.of(context).textTheme.bodySmall),
        subtitle: Text(value,
            style:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
