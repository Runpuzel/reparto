import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/theme_mode_tile.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/providers/shared_providers.dart';
import 'admin_activity_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_campuses_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_disputes_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_services_screen.dart';
import 'admin_users_screen.dart';
import 'admin_vendors_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => AdminShellState();
}

class AdminShellState extends ConsumerState<AdminShell> {
  int index = 0;

  static const _titles = ['Reports', 'Vendors', 'Services', 'More'];

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

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    final pages = <Widget>[
      const AdminReportsScreen(),
      const AdminVendorsScreen(),
      const AdminServicesScreen(),
      _AdminMoreScreen(
        unread: unread,
        openPage: _openPage,
        openPlatformSettings: () => context.push('/admin/settings/platform'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin - ${_titles[index]}'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(AppIcons.notification),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(index: index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified),
            label: 'Vendors',
          ),
          NavigationDestination(
            icon: Icon(Icons.design_services_outlined),
            selectedIcon: Icon(Icons.design_services),
            label: 'Services',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _AdminMoreScreen extends ConsumerWidget {
  const _AdminMoreScreen({
    required this.unread,
    required this.openPage,
    required this.openPlatformSettings,
  });

  final int unread;
  final void Function(String title, Widget page) openPage;
  final VoidCallback openPlatformSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = <_AdminTool>[
      _AdminTool(
        'Announcements',
        'Notify everyone, students, or sellers',
        Icons.campaign_outlined,
        () => openPage('Announcements', const AdminBroadcastScreen()),
      ),
      _AdminTool(
        'Marketplace activity',
        'Sales, cancellations, chats, and product performance',
        Icons.monitor_heart_outlined,
        () => openPage('Marketplace activity', const AdminActivityScreen()),
      ),
      _AdminTool(
        'Categories',
        'Organize marketplace listings',
        Icons.category_outlined,
        () => openPage('Categories', const AdminCategoriesScreen()),
      ),
      _AdminTool(
        'Campuses',
        'Manage supported locations',
        Icons.school_outlined,
        () => openPage('Campuses', const AdminCampusesScreen()),
      ),
      _AdminTool(
        'Disputes',
        'Review and resolve order disputes',
        Icons.gavel_outlined,
        () => openPage('Disputes', const AdminDisputesScreen()),
      ),
      _AdminTool(
        'Users',
        'Manage access and account status',
        Icons.people_outline,
        () => openPage('User management', const AdminUsersScreen()),
      ),
      _AdminTool(
        'Revenue',
        'Weekly fees and seller payouts',
        Icons.trending_up_outlined,
        () => context.push('/admin/revenue'),
      ),
      _AdminTool(
        'Platform settings',
        'Configure fees and marketplace policies',
        Icons.tune_outlined,
        openPlatformSettings,
      ),
    ];
    final account = <_AdminTool>[
      _AdminTool(
        'Notifications',
        unread == 0
            ? 'You are all caught up'
            : '$unread unread update${unread == 1 ? '' : 's'}',
        AppIcons.notification,
        () => context.push('/notifications'),
      ),
      _AdminTool(
        'Reset passcode',
        'Update access to your administrator account',
        Icons.lock_reset_outlined,
        () => context.push('/forgot-passcode'),
      ),
    ];
    final support = <_AdminTool>[
      _AdminTool(
        'About UjustBUY',
        'Policies, support, and platform information',
        AppIcons.info,
        () => context.push('/about'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final horizontalPadding = constraints.maxWidth < 400 ? 12.0 : 20.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            24,
          ),
          children: [
            _AdminMoreSection(
              title: 'Operations',
              tools: operations,
              columns: columns,
            ),
            const SizedBox(height: 24),
            _AdminMoreSection(
              title: 'Account',
              tools: account,
              columns: columns,
            ),
            const SizedBox(height: 24),
            Text('PREFERENCES', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            const ThemeModeTile(),
            const SizedBox(height: 24),
            _AdminMoreSection(
              title: 'Support',
              tools: support,
              columns: columns,
            ),
            const SizedBox(height: 24),
            _AdminToolTile(
              tool: _AdminTool(
                'Sign out',
                'Leave this administrator account on this device',
                AppIcons.logout,
                () => _signOut(context, ref),
                destructive: true,
              ),
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
      message: 'You will need to sign in again to manage UjustBUY.',
      confirmLabel: 'Sign out',
      icon: AppIcons.logout,
      destructive: true,
    );
    if (confirmed) await ref.read(authRepositoryProvider).signOut();
  }
}

class _AdminMoreSection extends StatelessWidget {
  const _AdminMoreSection({
    required this.title,
    required this.tools,
    required this.columns,
  });

  final String title;
  final List<_AdminTool> tools;
  final int columns;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 96,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: tools.length,
            itemBuilder: (context, itemIndex) =>
                _AdminToolTile(tool: tools[itemIndex]),
          ),
        ],
      );
}

class _AdminTool {
  const _AdminTool(
    this.title,
    this.subtitle,
    this.icon,
    this.onTap, {
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
}

class _AdminToolTile extends StatelessWidget {
  const _AdminToolTile({required this.tool});

  final _AdminTool tool;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = tool.destructive ? scheme.error : scheme.primary;
    return Material(
      color: tool.destructive
          ? scheme.errorContainer.withValues(alpha: 0.72)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tool.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(tool.icon, color: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tool.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
