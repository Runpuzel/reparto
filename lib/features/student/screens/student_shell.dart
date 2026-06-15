import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/shared_providers.dart';
import '../providers/student_providers.dart';
import 'browse_screen.dart';
import 'shops_screen.dart';
import 'favorites_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'student_profile_screen.dart';

class StudentShell extends ConsumerStatefulWidget {
  const StudentShell({super.key});

  @override
  ConsumerState<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends ConsumerState<StudentShell> {
  int _index = 0;

  static const _pages = [
    BrowseScreen(),
    ShopsScreen(),
    FavoritesScreen(),
    CartScreen(),
    OrdersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    final cartCount = ref.watch(cartCountProvider);
    final titles = ['Browse', 'Shops', 'Favorites', 'My Cart', 'My Orders'];

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
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const _ProfilePage()),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: 'Browse'),
          const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Shops'),
          const NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Favorites'),
          NavigationDestination(
              icon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: const Icon(Icons.shopping_cart),
              ),
              label: 'Cart'),
          const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders'),
        ],
      ),
    );
  }
}

/// Profile opened from the app bar (kept off the bottom nav to reduce clutter).
class _ProfilePage extends StatelessWidget {
  const _ProfilePage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const StudentProfileScreen(),
    );
  }
}
