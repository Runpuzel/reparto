import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/push_service.dart';
import '../../../models/models.dart';

/// Handles all authentication & profile bootstrap concerns.
class AuthRepository {
  /// Email + password sign-up. Profile row is created server-side by the
  /// `handle_new_user` trigger using the metadata supplied here.
  Future<AuthResponse> signUpStudent({
    required String fullName,
    required String email,
    required String password,
    required String campusId,
  }) {
    return supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: kIsWeb ? null : AppConstants.oauthRedirect,
      data: {
        'full_name': fullName,
        'role': 'student',
        'campus_id': campusId,
      },
    );
  }

  Future<AuthResponse> signUpVendor({
    required String businessName,
    required String ownerName,
    required String businessPhone,
    required String momoNumber,
    required String momoNetwork,
    required String ghanaCardNumber,
    required String email,
    required String password,
    required String campusId,
  }) {
    return supabase.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: kIsWeb ? null : AppConstants.oauthRedirect,
      data: {
        'full_name': ownerName,
        'role': 'vendor',
        'campus_id': campusId,
        'business_name': businessName,
        // Keep the legacy contact column aligned without asking applicants for
        // a second, personal number.
        'phone_number': businessPhone,
        'business_phone': businessPhone,
        'momo_number': momoNumber,
        'momo_network': momoNetwork,
        'ghana_card_number': ghanaCardNumber,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// Google sign-in.
  ///
  /// • Mobile (Android/iOS): native `google_sign_in` → exchange the id token
  ///   with Supabase via `signInWithIdToken` (no browser round-trip, reliable).
  /// • Web: Supabase OAuth redirect flow.
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
      return;
    }

    // Native flow. serverClientId must be the *Web* OAuth client id.
    final googleSignIn = GoogleSignIn(
      serverClientId:
      Env.googleWebClientId.isEmpty ? null : Env.googleWebClientId,
      scopes: const ['email', 'profile'],
    );

    final account = await googleSignIn.signIn();
    if (account == null) return; // user cancelled
    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in failed: missing id token');
    }

    await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    if (Env.pushEnabled) {
      try {
        await PushService.clearToken();
      } catch (_) {}
    }
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await supabase.auth.signOut();
  }

  Future<void> resetPassword(String email) =>
      supabase.auth.resetPasswordForEmail(email);

  /// Fetch the extended profile for the signed-in user.
  Future<AppUser?> fetchProfile() async {
    final uid = currentAuthUser?.id;
    if (uid == null) return null;
    final data =
    await supabase.from('users').select().eq('user_id', uid).maybeSingle();
    if (data == null) return null;
    return AppUser.fromMap(data);
  }

  /// Fetch vendor record for the current user (if any).
  Future<Vendor?> fetchVendor() async {
    final uid = currentAuthUser?.id;
    if (uid == null) return null;
    final data = await supabase
        .from('vendors')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (data == null) return null;
    return Vendor.fromMap(data);
  }

  /// Set the campus for a user who registered without one (e.g. Google).
  Future<void> setCampus(String campusId) async {
    final uid = currentAuthUser?.id;
    if (uid == null) return;
    await supabase
        .from('users')
        .update({'campus_id': campusId}).eq('user_id', uid);
  }

  /// Upgrade the signed-in student account to a Student Seller while keeping
  /// the same buyer identity, cart, favorites, and order history.
  Future<void> becomeStudentSeller() async {
    await supabase.rpc('become_student_seller');
  }

  /// Create / update the vendor business record (after the user account exists).
  Future<void> createVendorRecord({
    required String businessName,
    required String ownerName,
    required String businessPhone,
    required String momoNumber,
    required String momoNetwork,
    required String ghanaCardNumber,
    required String campusId,
    String? logoUrl,
    String? ghanaCardImageUrl,
  }) async {
    final uid = currentAuthUser?.id;
    if (uid == null) return;
    await supabase.from('vendors').upsert({
      'user_id': uid,
      'business_name': businessName,
      'owner_name': ownerName,
      'phone_number': businessPhone,
      'business_phone': businessPhone,
      'momo_number': momoNumber,
      'momo_network': momoNetwork,
      'ghana_card_number': ghanaCardNumber.isEmpty ? null : ghanaCardNumber,
      'campus_id': campusId,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (ghanaCardImageUrl != null) 'ghana_card_image_url': ghanaCardImageUrl,
    }, onConflict: 'user_id');
  }

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
}
