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
import 'vendor_wallet_screen.dart';

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
        if (vendor.approvalStatus == ApprovalStatus.suspended ||
            vendor.approvalStatus == ApprovalStatus.rejected) {
          return _ApprovalPending(vendor: vendor, ref: ref);
        }

        final pages = [
          const VendorDashboardScreen(),
          const VendorProductsScreen(),
          const VendorOrdersScreen(),
          _VendorMoreScreen(openPage: _openPage),
        ];
        final titles = ['Dashboard', 'Catalog', 'Orders', 'More'];

        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_index]),
            actions: [
              IconButton(
                tooltip: 'Notifications',
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
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view),
                  label: 'More'),
            ],
          ),
        );
      },
    );
  }

  void _openPage(String title, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(child: page),
        ),
      ),
    );
  }
}

class _VendorMoreScreen extends StatelessWidget {
  const _VendorMoreScreen({required this.openPage});
  final void Function(String title, Widget page) openPage;

  @override
  Widget build(BuildContext context) {
    final items = [
      _VendorMoreItem(
        title: 'COD commission wallet',
        subtitle: 'Fund and review Cash on Delivery fees',
        icon: Icons.account_balance_wallet_outlined,
        onTap: () => openPage('COD wallet', const VendorWalletScreen()),
      ),
      _VendorMoreItem(
        title: 'Reports',
        subtitle: 'Sales, products, and customer reviews',
        icon: AppIcons.reports,
        onTap: () => openPage('Reports', const VendorReportsScreen()),
      ),
      _VendorMoreItem(
        title: 'Store profile',
        subtitle: 'Identity, store details, and preferences',
        icon: AppIcons.person,
        onTap: () => openPage('Profile', const VendorProfileScreen()),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth >= 700 ? 2 : 1,
          mainAxisExtent: 88,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: items.length,
        itemBuilder: (_, index) => items[index],
      ),
    );
  }
}

class _VendorMoreItem extends StatelessWidget {
  const _VendorMoreItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
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
