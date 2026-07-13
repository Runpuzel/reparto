import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/app_install_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_install_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/theme_mode_tile.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/providers/shared_providers.dart';
import '../../shared/screens/chat_inbox_screen.dart';
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
          _VendorMoreScreen(unread: unread, openPage: _openPage),
        ];
        final titles = ['Dashboard', 'Catalog', 'Orders', 'More'];

        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_index]),
            actions: [
              const AppInstallButton(),
              const ThemeToggleButton(),
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

class _VendorMoreScreen extends ConsumerWidget {
  const _VendorMoreScreen({required this.unread, required this.openPage});
  final int unread;
  final void Function(String title, Widget page) openPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerTools = [
      _VendorMoreItem(
        title: 'Chats',
        subtitle: 'Continue customer conversations',
        icon: AppIcons.chat,
        onTap: () => openPage('Chats', const ChatInboxScreen()),
      ),
      _VendorMoreItem(
        title: 'COD marketplace fee wallet',
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
    ];
    final account = [
      _VendorMoreItem(
        title: 'Store profile',
        subtitle: 'Store details, hours, identity, and payouts',
        icon: AppIcons.person,
        onTap: () => openPage('Profile', const VendorProfileScreen()),
      ),
      _VendorMoreItem(
        title: 'Notifications',
        subtitle: unread == 0
            ? 'You are all caught up'
            : '$unread unread update${unread == 1 ? '' : 's'}',
        icon: AppIcons.notification,
        onTap: () => context.push('/notifications'),
      ),
      _VendorMoreItem(
        title: 'Referral rewards',
        subtitle: 'Invite friends and manage your tokens',
        icon: AppIcons.tag,
        onTap: () => context.push('/referrals'),
      ),
      _VendorMoreItem(
        title: 'Shop on UjustBUY',
        subtitle: 'Browse and buy from other student sellers',
        icon: AppIcons.storefront,
        onTap: () => context.go('/student'),
      ),
      if (kIsWeb)
        _VendorMoreItem(
          title: 'Install app',
          subtitle: 'Download UjustBUY to this device',
          icon: AppIcons.download,
          onTap: () => _showVendorInstallPrompt(context),
        ),
    ];
    final support = [
      _VendorMoreItem(
        title: 'About UjustBUY',
        subtitle: 'Policies, support, and platform information',
        icon: AppIcons.info,
        onTap: () => context.push('/about'),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final padding = constraints.maxWidth < 400 ? 12.0 : 20.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(padding, 16, padding, 24),
          children: [
            _VendorMoreSection(
              title: 'Seller tools',
              items: sellerTools,
              columns: columns,
            ),
            const SizedBox(height: 24),
            _VendorMoreSection(
              title: 'Account',
              items: account,
              columns: columns,
            ),
            const SizedBox(height: 24),
            Text('PREFERENCES', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            const ThemeModeTile(),
            const SizedBox(height: 24),
            _VendorMoreSection(
              title: 'Support',
              items: support,
              columns: columns,
            ),
            const SizedBox(height: 24),
            _VendorMoreItem(
              title: 'Sign out',
              subtitle: 'Leave this account on this device',
              icon: AppIcons.logout,
              destructive: true,
              onTap: () => _signOut(context, ref),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmActions.confirm(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to manage your store.',
      confirmLabel: 'Sign out',
      icon: AppIcons.logout,
    );
    if (confirmed) await ref.read(authRepositoryProvider).signOut();
  }
}

class _VendorMoreSection extends StatelessWidget {
  const _VendorMoreSection({
    required this.title,
    required this.items,
    required this.columns,
  });
  final String title;
  final List<_VendorMoreItem> items;
  final int columns;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 88,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (_, index) => items[index],
          ),
        ],
      );
}

class _VendorMoreItem extends StatelessWidget {
  const _VendorMoreItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = destructive ? scheme.error : scheme.primary;
    return Material(
      color: destructive
          ? scheme.errorContainer.withValues(alpha: 0.7)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: accent),
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
}

Future<void> _showVendorInstallPrompt(BuildContext context) async {
  final status = await promptAppInstall();
  if (!context.mounted) return;
  final message = switch (status) {
    AppInstallStatus.accepted => 'Installing UjustBUY...',
    AppInstallStatus.installed => 'UjustBUY is already installed.',
    _ => null,
  };
  if (message != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
          label: 'Browse Marketplace',
          icon: AppIcons.storefront,
          expand: false,
          onPressed: () => context.go('/student'),
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
              onPressed: () => context.go('/student'),
              child: const Text('Browse Marketplace'),
            ),
          ],
        ),
      ),
    );
  }
}
