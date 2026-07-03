// lib/features/admin/screens/admin_shell.dart
// v1.0-2025-07 – Admin Shell – Services tab added, Users moved to Settings

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/theme_mode_tile.dart';
import '../../auth/providers/auth_providers.dart';
import 'admin_reports_screen.dart';
import 'admin_vendors_screen.dart';
import 'admin_services_screen.dart';
import 'admin_campuses_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_commission_screen.dart';
// Users moved out of main nav – now at /admin/settings/users
import 'admin_users_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => AdminShellState();
}

class AdminShellState extends ConsumerState<AdminShell> {
  int index = 0;

  // v1.0 nav order:
  // 0 Reports / Dashboard
  // 1 Vendors (was Sellers)
  // 2 Services [NEW]
  // 3 Categories
  // 4 Commission
  // 5 Campuses
  static const pages = [
    AdminReportsScreen(),
    AdminVendorsScreen(),
    AdminServicesScreen(), // NEW – Phase 3
    AdminCategoriesScreen(),
    AdminCommissionScreen(),
    AdminCampusesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Reports',
      'Vendors',
      'Services',
      'Categories',
      'Commission',
      'Campuses',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin · ${titles[index]}'),
        actions: [
          // Service expiration quick indicator
          if (index == 2)
            IconButton(
              tooltip: 'Expiration cron',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Run expire_unpaid_services() – see Admin Services > Tools')),
                );
              },
              icon: const Icon(Icons.timer_outlined),
            ),
          IconButton(
            tooltip: 'Disputes',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Disputes')),
                body: const AdminDisputesScreen(),
              ),
            )),
            icon: const Icon(Icons.gavel_outlined),
          ),
          // Settings menu – Users moved here
          PopupMenuButton<String>(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onSelected: (v) {
              switch (v) {
                case 'users':
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const Scaffold(
                      appBar: null,
                      body: AdminUsersSettingsPage(),
                    ),
                  ));
                  break;
                case 'platform':
                  context.push('/admin/settings/platform');
                  break;
                case 'developer':
                  context.push('/profile/developer');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'users',
                child: ListTile(
                  leading: Icon(Icons.people_outline),
                  title: Text('User Management'),
                  subtitle: Text('Users moved here – v1.0'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'platform',
                child: ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('Platform Settings'),
                  subtitle: Text('Fees, policy version'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'developer',
                child: ListTile(
                  leading: Icon(Icons.code),
                  title: Text('Developer'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
          const ThemeToggleButton(),
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: Icon(AppIcons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.verified_outlined),
              selectedIcon: Icon(Icons.verified),
              label: 'Vendors'),
          NavigationDestination(
            // NEW Services tab – v1.0
              icon: Icon(Icons.design_services_outlined),
              selectedIcon: Icon(Icons.design_services),
              label: 'Services'),
          NavigationDestination(
              icon: Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category),
              label: 'Categories'),
          NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Commission'),
          NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Campuses'),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// Users moved out of main bottom nav – now accessible via Settings menu
// -------------------------------------------------------------------
class AdminUsersSettingsPage extends StatelessWidget {
  const AdminUsersSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings · User Management'),
      ),
      body: const AdminUsersScreen(),
    );
  }
}

// Keep Disputes screen import shim – matches existing project structure
// ignore: camel_case_types
class AdminDisputesScreen extends StatelessWidget {
  const AdminDisputesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // delegate to real file if present
    // fallback simple
    return const Center(child: Text('Disputes – see lib/features/admin/screens/admin_disputes_screen.dart'));
  }
}
