import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/theme_mode_tile.dart';
import '../../auth/providers/auth_providers.dart';
import 'admin_reports_screen.dart';
import 'admin_campuses_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_commission_screen.dart';
import 'admin_disputes_screen.dart';
import 'admin_vendors_screen.dart';
import 'admin_users_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;

  static const _pages = [
    AdminReportsScreen(),
    AdminVendorsScreen(),
    AdminCategoriesScreen(),
    AdminCommissionScreen(),
    AdminCampusesScreen(),
    AdminUsersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Reports',
      'Sellers',
      'Categories',
      'Commission',
      'Campuses',
      'Users'
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin · ${titles[_index]}'),
        actions: [
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
          const ThemeToggleButton(),
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: Icon(AppIcons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: Icon(AppIcons.insightsOutline),
              selectedIcon: Icon(AppIcons.insights),
              label: 'Reports'),
          NavigationDestination(
              icon: Icon(AppIcons.verified),
              selectedIcon: Icon(AppIcons.verifiedFill),
              label: 'Sellers'),
          NavigationDestination(
              icon: Icon(AppIcons.category),
              selectedIcon: Icon(AppIcons.categoryFill),
              label: 'Categories'),
          NavigationDestination(
              icon: Icon(AppIcons.price),
              selectedIcon: Icon(AppIcons.revenue),
              label: 'Commission'),
          NavigationDestination(
              icon: Icon(AppIcons.campus),
              selectedIcon: Icon(AppIcons.campusFill),
              label: 'Campuses'),
          NavigationDestination(
              icon: Icon(AppIcons.users),
              selectedIcon: Icon(AppIcons.usersFill),
              label: 'Users'),
        ],
      ),
    );
  }
}
