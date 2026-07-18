import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/push_service.dart';
import '../../../models/models.dart';

/// Handles all authentication & profile bootstrap concerns.
class AuthRepository {
  GoogleSignIn? _googleSignInInstance;
  String? _googleSignInClientId;

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
      data: {'full_name': fullName, 'role': 'student', 'campus_id': campusId},
    );
  }

  Future<AuthResponse> signUpVendor({
    required String businessName,
    required String ownerName,
    required String businessPhone,
    required String momoNumber,
    required String momoNetwork,
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
  /// Uses the Google SDK to get an ID token, then exchanges that token with
  /// Supabase. This keeps the visible Google sign-in screen branded by the
  /// Google OAuth app instead of the Supabase project URL.
  Future<void> signInWithGoogle() async {
    final googleSignIn = this.googleSignIn;
    if (kIsWeb) {
      final account =
          googleSignIn.currentUser ??
          await googleSignIn.signInSilently(suppressErrors: true);
      if (account == null) {
        throw const AuthException(
          'Use the Google button to sign in on the web.',
        );
      }
      await signInWithGoogleAccount(account);
      return;
    }

    final GoogleSignInAccount? account;
    try {
      account = await googleSignIn.signIn();
    } on PlatformException catch (e) {
      if (_isGoogleOriginMismatch(e)) {
        throw const AuthException(
          'Google sign-in is not configured for this web address. Add this site origin to Authorized JavaScript origins in Google Cloud Console.',
        );
      }
      rethrow;
    }
    if (account == null) return; // User cancelled.

    await signInWithGoogleAccount(account);
  }

  Future<void> signInWithGoogleAccount(GoogleSignInAccount account) async {
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

    try {
      await _googleSignIn(Env.googleWebClientId.trim()).signOut();
    } catch (_) {}

    await supabase.auth.signOut();
  }

  GoogleSignIn get googleSignIn {
    final webClientId = Env.googleWebClientId.trim();
    if (kIsWeb && webClientId.isEmpty) {
      throw const AuthException(
        'Google sign-in is missing GOOGLE_WEB_CLIENT_ID.',
      );
    }
    return _googleSignIn(webClientId);
  }

  Future<void> resetPassword(String email) =>
      supabase.auth.resetPasswordForEmail(email);

  /// Fetch the extended profile for the signed-in user.
  Future<AppUser?> fetchProfile() async {
    final uid = currentAuthUser?.id;
    if (uid == null) return null;
    final data = await supabase
        .from('users')
        .select()
        .eq('user_id', uid)
        .maybeSingle();
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
        .update({'campus_id': campusId})
        .eq('user_id', uid);
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
    required String campusId,
    String? logoUrl,
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
      'campus_id': campusId,
      if (logoUrl != null) 'logo_url': logoUrl,
    }, onConflict: 'user_id');
  }

  GoogleSignIn _googleSignIn(String webClientId) {
    if (_googleSignInInstance != null && _googleSignInClientId == webClientId) {
      return _googleSignInInstance!;
    }

    _googleSignInClientId = webClientId;
    _googleSignInInstance = GoogleSignIn(
      clientId: kIsWeb && webClientId.isNotEmpty ? webClientId : null,
      serverClientId: !kIsWeb && webClientId.isNotEmpty ? webClientId : null,
      scopes: const ['email', 'profile'],
    );
    return _googleSignInInstance!;
  }

  bool _isGoogleOriginMismatch(PlatformException error) {
    final raw = '${error.code} ${error.message} ${error.details}'.toLowerCase();
    return raw.contains('origin_mismatch') ||
        raw.contains('javascript origin') ||
        raw.contains('not a registered origin');
  }

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
}
