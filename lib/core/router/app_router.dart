// lib/core/routing/app_router.dart
// v1.0-2025-07 – New routes + SellerAgreement blocking guard + admin reorg

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../features/admin/screens/admin_shell.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/screens/forgot_passcode_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/register_student_screen.dart';
import '../../features/auth/screens/register_vendor_screen.dart';
import '../../features/auth/screens/select_campus_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/shared/screens/about_screen.dart';
import '../../features/shared/screens/developer_screen.dart';
import '../../features/shared/screens/notifications_screen.dart';
import '../../features/shared/screens/referral_hub_screen.dart';
import '../../features/student/screens/checkout_screen.dart';
import '../../features/student/screens/order_detail_screen.dart';
import '../../features/student/screens/product_detail_screen.dart';
import '../../features/student/screens/service_detail_screen.dart';
import '../../features/student/screens/services_screen.dart';
import '../../features/student/screens/shop_detail_screen.dart';
import '../../features/student/screens/student_shell.dart';
import '../../features/vendor/screens/product_form_screen.dart';
import '../../features/vendor/screens/service_form_screen.dart';
import '../../features/vendor/screens/service_posted_screen.dart';
import '../../features/vendor/screens/seller_agreement_screen.dart';
import '../../features/vendor/screens/store_details_update_screen.dart';
import '../../features/vendor/screens/identity_verification_screen.dart';
import '../../features/vendor/screens/vendor_shell.dart';
import '../services/push_service.dart';

/// Global navigator key so background services (e.g. push taps) can navigate.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Builds the GoRouter, redirecting based on auth + role + campus + consent state.
final routerProvider = Provider<GoRouter>((ref) {
  PushService.navigatorKey = rootNavigatorKey;
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: AuthChangeNotifier(ref),
    redirect: (context, state) {
      final authAsync = ref.read(currentUserProvider);
      final loc = state.matchedLocation;

      // public routes
      final isForgot = loc == '/forgot-passcode';
      final isAuthRoute = loc.startsWith('/login') ||
          loc.startsWith('/register') ||
          loc == '/welcome' ||
          isForgot ||
          loc == '/splash';

      bool isGuestBrowsable(String l) =>
          l == '/student' ||
              l.startsWith('/student/product/') ||
              l.startsWith('/student/shop/') ||
              l.startsWith('/student/service/') ||
              l == '/student/services' ||
              l == '/about' ||
              l == '/profile/developer'; // developer info is public curious

      // While loading the profile, stay on splash.
      if (authAsync.isLoading) return loc == '/splash' ? null : '/splash';

      final user = authAsync.valueOrNull;

      // Not signed in (GUEST)
      if (user == null) {
        if (loc == '/splash') return '/student';
        if (isAuthRoute || isGuestBrowsable(loc)) return null;
        return '/student';
      }

      // v1.0 – SELLER AGREEMENT GATE
      // Check vendor consent via vendor record
      try {
        final vendor = ref.read(currentVendorProvider).valueOrNull;
        if (user.role == UserRole.vendor &&
            vendor != null &&
            // ignore: avoid_dynamic_calls
            (vendor as dynamic).consentSellerAgreement != true) {
          // allow agreement screen itself + legal view + logout
          final allowed = loc == '/vendor/agreement' ||
              loc == '/about' ||
              loc == '/profile/developer' ||
              loc == '/login';
          if (!allowed) return '/vendor/agreement';
        }
      } catch (_) {}

      // Signed in but missing campus (e.g. Google first login).
      if (user.needsCampus && user.role != UserRole.admin) {
        return loc == '/select-campus' ? null : '/select-campus';
      }

      // Signed in: route to the correct home if on an auth route
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
      GoRoute(path: '/welcome', builder: (_, __) => const OnboardingScreen()),
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
        builder: (_, s) =>
            ProductDetailScreen(productId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/shop/:id',
        builder: (_, s) =>
            ShopDetailScreen(vendorId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/service/:id',
        builder: (_, s) =>
            ServiceDetailScreen(serviceId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/student/services',
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('Student Services')),
          body: const ServicesScreen(),
        ),
      ),
      GoRoute(
        path: '/student/checkout',
        builder: (_, __) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/student/order/:id',
        builder: (_, s) =>
            OrderDetailScreen(orderId: s.pathParameters['id']!),
      ),

      // Vendor – v1.0 new routes
      GoRoute(path: '/vendor', builder: (_, __) => const VendorShell()),
      GoRoute(
        path: '/vendor/agreement',
        builder: (_, __) => const SellerAgreementScreen(),
      ),
      GoRoute(
        path: '/vendor/store/edit',
        builder: (_, __) => const StoreDetailsUpdateScreen(),
      ),
      GoRoute(
        path: '/vendor/settings/verification',
        builder: (_, __) => const IdentityVerificationScreen(),
      ),
      GoRoute(
        path: '/vendor/product-form',
        builder: (_, s) =>
            ProductFormScreen(product: s.extra as dynamic),
      ),
      GoRoute(
        path: '/vendor/service-form',
        builder: (_, s) =>
            ServiceFormScreen(service: s.extra as dynamic),
      ),
      GoRoute(
        path: '/vendor/services/posted/:id',
        builder: (_, s) => ServicePostedScreen(
          serviceId: s.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/vendor/earnings',
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('Earnings & Fees')),
          body: const Center(
              child: Text(
                  'Earnings Dashboard – Phase 5\nPlatform fee: 5% products / 8% services – seller only')),
        ),
      ),
      GoRoute(
        path: '/vendor/store/preview',
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('Store Preview')),
          body: const Center(child: Text('Public store preview – Phase 4')),
        ),
      ),

      // Admin – v1.0 reorganized
      GoRoute(path: '/admin', builder: (_, __) => const AdminShell()),
      // deep links (optional – shell handles tabs internally)
      GoRoute(
        path: '/admin/services',
        redirect: (_, __) => '/admin', // tab 2 inside shell
      ),
      GoRoute(
        path: '/admin/settings/users',
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('Settings · User Management')),
          body: const Center(
              child: Text('AdminUsersScreen – moved from main nav – v1.0')),
        ),
      ),
      GoRoute(
        path: '/admin/settings/platform',
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('Platform Settings')),
          body: const Center(
              child: Text(
                  'service_auth_fee, platform_fee_seller_percent, current_policy_version\nEdit in Admin Services > Fee Settings')),
        ),
      ),

      // Shared – v1.0 split About / Developer
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      // NEW – separate developer routes (all roles)
      GoRoute(
          path: '/profile/about',
          builder: (_, __) => const AboutScreen()),
      GoRoute(
          path: '/profile/developer',
          builder: (_, __) => const DeveloperScreen()),
      GoRoute(
          path: '/developer',
          redirect: (_, __) => '/profile/developer'),
      GoRoute(
          path: '/referrals',
          builder: (_, __) => const ReferralHubScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Route not found:\n${state.matchedLocation}',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/student'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});

/// Bridges Riverpod auth changes to GoRouter's refresh.
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(Ref ref) {
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    // v1.0 – also listen vendor consent changes to trigger redirect guard
    ref.listen(currentVendorProvider, (_, __) => notifyListeners());
  }
}
