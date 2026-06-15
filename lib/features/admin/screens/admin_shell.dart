import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/theme_mode_tile.dart';
import '../../auth/providers/auth_providers.dart';
import 'admin_reports_screen.dart';
import 'admin_campuses_screen.dart';
import 'admin_categories_screen.dart';
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
    AdminCampusesScreen(),
    AdminUsersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final titles = ['Reports', 'Vendors', 'Categories', 'Campuses', 'Users'];
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin · ${titles[_index]}'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.verified_user_outlined),
              selectedIcon: Icon(Icons.verified_user),
              label: 'Vendors'),
          NavigationDestination(
              icon: Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category),
              label: 'Categories'),
          NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Campuses'),
          NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Users'),
        ],
      ),
    );
  }
}
