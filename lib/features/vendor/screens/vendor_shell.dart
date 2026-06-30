import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/providers/shared_providers.dart';
import 'sell_chooser.dart';
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
                  child: Icon(AppIcons.notification),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: IndexedStack(index: _index, children: pages),
          floatingActionButton: _index == 1
              ? FloatingActionButton.extended(
            onPressed: () => showSellChooser(context, ref),
            icon: Icon(AppIcons.add),
            label: const Text('Post'),
          )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              NavigationDestination(
                  icon: Icon(AppIcons.dashboard),
                  selectedIcon: Icon(AppIcons.dashboardFill),
                  label: 'Dashboard'),
              NavigationDestination(
                  icon: Icon(AppIcons.package),
                  selectedIcon: Icon(AppIcons.packageFill),
                  label: 'Products'),
              NavigationDestination(
                  icon: Icon(AppIcons.receipt),
                  selectedIcon: Icon(AppIcons.receiptFill),
                  label: 'Orders'),
              NavigationDestination(
                  icon: Icon(AppIcons.reports),
                  selectedIcon: Icon(AppIcons.reportsFill),
                  label: 'Reports'),
              NavigationDestination(
                  icon: Icon(AppIcons.person),
                  selectedIcon: Icon(AppIcons.personFill),
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
      appBar: AppBar(title: const Text('Student Seller')),
      body: EmptyState(
        icon: suspended
            ? AppIcons.block
            : rejected
            ? AppIcons.cancel
            : AppIcons.pending,
        title: suspended
            ? 'Account Suspended'
            : rejected
            ? 'Application Rejected'
            : 'Awaiting Approval',
        subtitle: suspended
            ? 'Your Student Seller account has been suspended. Contact the administrator.'
            : rejected
            ? 'Your application was not approved. Contact the administrator.'
            : 'An administrator is reviewing your business application. '
            'You will be notified once approved.',
        action: AppButton(
          label: 'Sign Out',
          icon: AppIcons.logout,
          variant: AppButtonVariant.secondary,
          expand: false,
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
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
      appBar: AppBar(title: const Text('Student Seller')),
      body: EmptyState(
        icon: AppIcons.store,
        title: 'Complete your seller profile',
        subtitle:
        'We could not find your seller details. Please apply to become a '
            'Student Seller.',
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Apply as Student Seller',
              icon: AppIcons.storefront,
              expand: false,
              onPressed: () => context.go('/register/vendor'),
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
