import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/providers/shared_providers.dart';
import 'vendor_dashboard_screen.dart';
import 'vendor_products_screen.dart';
import 'vendor_orders_screen.dart';
import 'vendor_reports_screen.dart';
import 'vendor_profile_screen.dart';

class VendorShell extends ConsumerStatefulWidget {
  const VendorShell({super.key});

  @override
  ConsumerState<VendorShell> createState() => _VendorShellState();
}

class _VendorShellState extends ConsumerState<VendorShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final vendorAsync = ref.watch(currentVendorProvider);
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;

    return AsyncView<Vendor?>(
      value: vendorAsync,
      onRetry: () => ref.invalidate(currentVendorProvider),
      data: (vendor) {
        if (vendor == null) {
          return _VendorMissingRecord(ref: ref);
        }
        if (!vendor.isApproved) {
          return _ApprovalPending(vendor: vendor, ref: ref);
        }

        final pages = const [
          VendorDashboardScreen(),
          VendorProductsScreen(),
          VendorOrdersScreen(),
          VendorReportsScreen(),
          VendorProfileScreen(),
        ];
        final titles = ['Dashboard', 'Products', 'Orders', 'Reports', 'Profile'];

        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_index]),
            actions: [
              IconButton(
                onPressed: () => context.push('/notifications'),
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: IndexedStack(index: _index, children: pages),
          floatingActionButton: _index == 1
              ? FloatingActionButton.extended(
            onPressed: () => context.push('/vendor/product-form'),
            icon: const Icon(Icons.add),
            label: const Text('Add Product'),
          )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard'),
              NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Products'),
              NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Orders'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Reports'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}

class _ApprovalPending extends StatelessWidget {
  final Vendor vendor;
  final WidgetRef ref;
  const _ApprovalPending({required this.vendor, required this.ref});

  @override
  Widget build(BuildContext context) {
    final suspended = vendor.approvalStatus == ApprovalStatus.suspended;
    final rejected = vendor.approvalStatus == ApprovalStatus.rejected;
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor')),
      body: EmptyState(
        icon: suspended
            ? Icons.block
            : rejected
            ? Icons.cancel_outlined
            : Icons.hourglass_top,
        title: suspended
            ? 'Account Suspended'
            : rejected
            ? 'Application Rejected'
            : 'Awaiting Approval',
        subtitle: suspended
            ? 'Your vendor account has been suspended. Contact the administrator.'
            : rejected
            ? 'Your application was not approved. Contact the administrator.'
            : 'An administrator is reviewing your business application. '
            'You will be notified once approved.',
        action: OutlinedButton.icon(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
        ),
      ),
    );
  }
}

/// Vendor account exists but no business record (e.g. signed up with Google
/// or email confirmation delayed the record creation).
class _VendorMissingRecord extends StatelessWidget {
  final WidgetRef ref;
  const _VendorMissingRecord({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor')),
      body: EmptyState(
        icon: Icons.store_mall_directory_outlined,
        title: 'Complete your business profile',
        subtitle:
        'We could not find your business details. Please register as a vendor.',
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => context.go('/register/vendor'),
              child: const Text('Register Business'),
            ),
            TextButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
