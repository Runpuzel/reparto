import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/sign_in_prompt.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/providers/shared_providers.dart';
import '../../shared/screens/chat_inbox_screen.dart';
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
    CartScreen(),
    ChatInboxScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    final cartCount = ref.watch(cartCountProvider);
    final isGuest = ref.watch(isGuestProvider);
    final titles = ['Browse', 'Shops', 'My Cart', 'Chats'];

    // Tabs that require an account (Favorites, Cart, Orders).
    const guarded = {2: 'use your cart', 3: 'view chats'};

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          if (!isGuest) ...[
            IconButton(
              tooltip: 'Favorites',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Favorites')),
                      body: const FavoritesScreen()))),
              icon: Icon(AppIcons.heart),
            ),
            IconButton(
              tooltip: 'Orders',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('My Orders')),
                      body: const OrdersScreen()))),
              icon: Icon(AppIcons.receipt),
            ),
          ],
          IconButton(
            tooltip: 'Services',
            onPressed: () => context.push('/student/services'),
            icon: Icon(AppIcons.services),
          ),
          if (isGuest)
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Sign In'),
            )
          else ...[
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => context.push('/notifications'),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: Icon(AppIcons.notification),
              ),
            ),
            IconButton(
              tooltip: 'Profile',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _ProfilePage()),
              ),
              icon: Icon(AppIcons.account),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (isGuest && guarded.containsKey(i)) {
            SignInPrompt.show(context, action: guarded[i]!);
            return;
          }
          setState(() => _index = i);
        },
        destinations: [
          NavigationDestination(
              icon: Icon(AppIcons.grid),
              selectedIcon: Icon(AppIcons.gridFill),
              label: 'Browse'),
          NavigationDestination(
              icon: Icon(AppIcons.storefront),
              selectedIcon: Icon(AppIcons.storefrontFill),
              label: 'Shops'),
          NavigationDestination(
              icon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: Icon(AppIcons.cart),
              ),
              selectedIcon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                child: Icon(AppIcons.cartFill),
              ),
              label: 'Cart'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Chat'),
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
