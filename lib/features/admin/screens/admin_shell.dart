import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/theme_mode_tile.dart';
import '../../auth/providers/auth_providers.dart';
import 'admin_campuses_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_commission_screen.dart';
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
    final pages = <Widget>[
      const AdminReportsScreen(),
      const AdminVendorsScreen(),
      const AdminServicesScreen(),
      _AdminMoreScreen(
        openPage: _openPage,
        openPlatformSettings: () => context.push('/admin/settings/platform'),
        openDeveloper: () => context.push('/profile/developer'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin - ${_titles[index]}'),
        actions: [
          const ThemeToggleButton(),
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (value) {
              if (value == 'developer') {
                context.push('/profile/developer');
              } else if (value == 'sign_out') {
                ref.read(authRepositoryProvider).signOut();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'developer',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.code_outlined),
                  title: Text('Developer'),
                ),
              ),
              PopupMenuItem(
                value: 'sign_out',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(AppIcons.logout),
                  title: const Text('Sign out'),
                ),
              ),
            ],
          ),
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

class _AdminMoreScreen extends StatelessWidget {
  const _AdminMoreScreen({
    required this.openPage,
    required this.openPlatformSettings,
    required this.openDeveloper,
  });

  final void Function(String title, Widget page) openPage;
  final VoidCallback openPlatformSettings;
  final VoidCallback openDeveloper;

  @override
  Widget build(BuildContext context) {
    final tools = <_AdminTool>[
      _AdminTool('Categories', 'Organize marketplace listings',
          Icons.category_outlined,
          () => openPage('Categories', const AdminCategoriesScreen())),
      _AdminTool('Commission', 'Manage pricing and fee tiers',
          Icons.payments_outlined,
          () => openPage('Commission', const AdminCommissionScreen())),
      _AdminTool('Campuses', 'Manage supported locations',
          Icons.school_outlined,
          () => openPage('Campuses', const AdminCampusesScreen())),
      _AdminTool('Disputes', 'Review and resolve order disputes',
          Icons.gavel_outlined,
          () => openPage('Disputes', const AdminDisputesScreen())),
      _AdminTool('Users', 'Manage access and account status',
          Icons.people_outline,
          () => openPage('User management', const AdminUsersScreen())),
      _AdminTool('Platform settings', 'Configure fees and policies',
          Icons.tune_outlined, openPlatformSettings),
      _AdminTool('Developer', 'Open developer tools', Icons.code_outlined,
          openDeveloper),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        final horizontalPadding = constraints.maxWidth < 400 ? 12.0 : 20.0;

        return GridView.builder(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 20,
              horizontalPadding, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 88,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: tools.length,
          itemBuilder: (context, i) => _AdminToolTile(tool: tools[i]),
        );
      },
    );
  }
}

class _AdminTool {
  const _AdminTool(this.title, this.subtitle, this.icon, this.onTap);

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _AdminToolTile extends StatelessWidget {
  const _AdminToolTile({required this.tool});

  final _AdminTool tool;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tool.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(tool.icon, color: scheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tool.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      tool.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
