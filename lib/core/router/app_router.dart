import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../features/admin/screens/notifications_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_student_screen.dart';
import '../../features/auth/screens/register_vendor_screen.dart';
import '../../features/auth/screens/select_campus_screen.dart';
import '../../features/auth/screens/forgot_passcode_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/student/screens/student_shell.dart';
import '../../features/student/screens/product_detail_screen.dart';
import '../../features/student/screens/shop_detail_screen.dart';
import '../../features/student/screens/checkout_screen.dart';
import '../../features/student/screens/order_detail_screen.dart';
import '../../features/vendor/screens/vendor_shell.dart';
import '../../features/vendor/screens/product_form_screen.dart';
import '../../features/admin/screens/admin_shell.dart';
import '../../features/shared/screens/about_screen.dart';
import '../services/push_service.dart';

/// Global navigator key so background services (e.g. push taps) can navigate.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Builds the GoRouter, redirecting based on auth + role + campus state.
final routerProvider = Provider<GoRouter>((ref) {
  PushService.navigatorKey = rootNavigatorKey;
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final authAsync = ref.read(currentUserProvider);
      final loc = state.matchedLocation;
      // Forgot-passcode is reachable by anyone (signed in or not).
      final isForgot = loc == '/forgot-passcode';
      final isAuthRoute = loc.startsWith('/login') ||
          loc.startsWith('/register') ||
          isForgot ||
          loc == '/splash';

      // While loading the profile, stay on splash.
      if (authAsync.isLoading) return loc == '/splash' ? null : '/splash';

      final user = authAsync.valueOrNull;

      // Not signed in -> must be on an auth route.
      if (user == null) {
        return isAuthRoute && loc != '/splash' ? null : '/login';
      }

      // Signed in but missing campus (e.g. Google first login).
      if (user.needsCampus && user.role != UserRole.admin) {
        return loc == '/select-campus' ? null : '/select-campus';
      }

      // Signed in: route to the correct home if on an auth route (but allow
      // the forgot-passcode screen to stay open).
      if ((isAuthRoute && !isForgot) || loc == '/select-campus') {
        switch (user.role) {
          case UserRole.student:
            return '/student';
          case UserRole.vendor:
            return '/vendor';
          case UserRole.admin:
            return '/admin';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/register/student',
          builder: (_, __) => const RegisterStudentScreen()),
      GoRoute(
          path: '/register/vendor',
          builder: (_, __) => const RegisterVendorScreen()),
      GoRoute(
          path: '/select-campus',
          builder: (_, __) => const SelectCampusScreen()),
      GoRoute(
          path: '/forgot-passcode',
          builder: (_, __) => const ForgotPasscodeScreen()),

      // Student
      GoRoute(path: '/student', builder: (_, __) => const StudentShell()),
      GoRoute(
        path: '/student/product/:id',
        builder: (_, s) => ProductDetailScreen(productId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/shop/:id',
        builder: (_, s) => ShopDetailScreen(vendorId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/checkout',
        builder: (_, __) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/student/order/:id',
        builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!),
      ),

      // Vendor
      GoRoute(path: '/vendor', builder: (_, __) => const VendorShell()),
      GoRoute(
        path: '/vendor/product-form',
        builder: (_, s) =>
            ProductFormScreen(product: s.extra as dynamic),
      ),

      // Admin
      GoRoute(path: '/admin', builder: (_, __) => const AdminShell()),

      // Shared
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
    ],
  );
});

/// Bridges Riverpod auth changes to GoRouter's refresh.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
