import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/app_install_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/app_install_button.dart';
import '../../../core/widgets/sign_in_prompt.dart';
import '../../../core/widgets/theme_mode_tile.dart';
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
    final cartCount = ref.watch(cartCountProvider);
    final isGuest = ref.watch(isGuestProvider);
    final titles = ['Browse', 'Shops', 'My Cart', 'More'];

    final pages = [
      const BrowseScreen(),
      const ShopsScreen(),
      const CartScreen(),
      _StudentMoreScreen(unread: unread, isGuest: isGuest, openPage: _openPage),
    ];

    const guarded = {2: 'use your cart'};

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: const [
          AppInstallButton(),
          ThemeToggleButton(),
          SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        indicatorColor: Colors.transparent,
        onDestinationSelected: (i) {
          if (isGuest && guarded.containsKey(i)) {
            SignInPrompt.show(context, action: guarded[i]!);
            return;
          }
          setState(() => _index = i);
        },
        destinations: [
          const NavigationDestination(
            icon: _ShellNavIcon(icon: AppIcons.grid),
            selectedIcon: _ShellNavIcon(
              icon: AppIcons.gridFill,
              selected: true,
            ),
            label: 'Browse',
          ),
          const NavigationDestination(
            icon: _ShellNavIcon(icon: AppIcons.storefront),
            selectedIcon: _ShellNavIcon(
              icon: AppIcons.storefrontFill,
              selected: true,
            ),
            label: 'Shops',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const _ShellNavIcon(icon: AppIcons.cart),
            ),
            selectedIcon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const _ShellNavIcon(
                icon: AppIcons.cartFill,
                selected: true,
              ),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: _ShellNavIcon(icon: AppIcons.more),
            selectedIcon: _ShellNavIcon(icon: AppIcons.more, selected: true),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _StudentMoreScreen extends ConsumerWidget {
  const _StudentMoreScreen({
    required this.unread,
    required this.isGuest,
    required this.openPage,
  });

  final int unread;
  final bool isGuest;
  final void Function(String title, Widget page) openPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = <_StudentTool>[
      _StudentTool(
        'Student services',
        'Find repairs, tutoring, beauty, laundry, food and more',
        AppIcons.services,
        () => context.push('/student/services'),
      ),
      _StudentTool(
        'About UjustBUY',
        'Policies, support, and platform information',
        AppIcons.info,
        () => context.push('/about'),
      ),
      _StudentTool(
        'Install app',
        'Download UjustBUY to this device',
        AppIcons.download,
        () => _showInstallPrompt(context),
      ),
    ];

    if (isGuest) {
      tools.add(
        _StudentTool(
          'Sign in',
          'Access chats, orders, favorites, and notifications',
          AppIcons.signIn,
          () => context.push('/login'),
        ),
      );
    } else {
      tools.insertAll(1, [
        _StudentTool(
          'Chats',
          'Continue conversations with sellers',
          AppIcons.chat,
          () => openPage('Chats', const ChatInboxScreen()),
        ),
        _StudentTool(
          'Favorites',
          'Saved products you want to revisit',
          AppIcons.heart,
          () => openPage('Favorites', const FavoritesScreen()),
        ),
        _StudentTool(
          'My orders',
          'Track purchases, delivery, and receipts',
          AppIcons.receipt,
          () => openPage('My Orders', const OrdersScreen()),
        ),
        _StudentTool(
          'Notifications',
          unread == 0
              ? 'You are all caught up'
              : '$unread unread update${unread == 1 ? '' : 's'}',
          AppIcons.notification,
          () => context.push('/notifications'),
          badge: unread > 0 ? '$unread' : null,
        ),
        _StudentTool(
          'Profile',
          'Account, seller mode, referrals, and preferences',
          AppIcons.account,
          () => openPage('Profile', const StudentProfileScreen()),
        ),
        _StudentTool(
          'Referral rewards',
          'Invite friends and manage your tokens',
          AppIcons.tag,
          () => context.push('/referrals'),
        ),
        _StudentTool(
          'Sign out',
          'Leave this account on this device',
          AppIcons.logout,
          () => ref.read(authRepositoryProvider).signOut(),
          destructive: true,
        ),
      ]);
    }

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
            const ThemeModeTile(),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 88,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: tools.length,
              itemBuilder: (context, i) => _StudentToolTile(tool: tools[i]),
            ),
          ],
        );
      },
    );
  }
}

class _StudentTool {
  const _StudentTool(
    this.title,
    this.subtitle,
    this.icon,
    this.onTap, {
    this.badge,
    this.destructive = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? badge;
  final bool destructive;
}

class _StudentToolTile extends StatelessWidget {
  const _StudentToolTile({required this.tool});

  final _StudentTool tool;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = tool.destructive ? scheme.error : scheme.primary;
    final bg = tool.destructive
        ? scheme.errorContainer.withValues(alpha: 0.88)
        : scheme.primary.withValues(alpha: 0.12);

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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Center(
                  child: Badge(
                    isLabelVisible: tool.badge != null,
                    label: Text(tool.badge ?? ''),
                    child: Icon(tool.icon, color: accent, size: 23),
                  ),
                ),
              ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.caretRight, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellNavIcon extends StatelessWidget {
  const _ShellNavIcon({required this.icon, this.selected = false});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconSize = icon == AppIcons.more ? 27.0 : 24.0;

    if (!selected) {
      return Icon(icon, color: scheme.onSurface, size: iconSize);
    }

    return Container(
      width: 44,
      height: 34,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(100),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: scheme.onPrimary, size: iconSize),
    );
  }
}

Future<void> _showInstallPrompt(BuildContext context) async {
  final status = await promptAppInstall();
  if (!context.mounted) return;

  final message = switch (status) {
    AppInstallStatus.accepted => 'Installing UjustBUY...',
    AppInstallStatus.installed => 'UjustBUY is already installed.',
    AppInstallStatus.dismissed => 'Install dismissed.',
    AppInstallStatus.unavailable =>
      'Use your browser menu and choose Add to Home screen.',
    AppInstallStatus.failed =>
      'Could not start install. Use your browser menu and choose Add to Home screen.',
  };

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
