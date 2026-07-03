// lib/features/shared/data/consent_repository.dart
// v1.0-2025-07 – Consent audit trail – Ghana DPA 2012

import '../../../core/config/supabase_client.dart';

class ConsentRepository {
  /// Record a consent event.
  /// type: 'seller_agreement' | 'service_post' | 'payment_auth' | 'verification_submit' | 'checkout_policy' | 'terms_update'
  Future<String> record({
    required String type,
    required String policyVersion,
    Map<String, dynamic>? metadata,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      // Preferred: server-side RPC with signature_hash
      final res = await supabase.rpc('record_consent', params: {
        'p_consent_type': type,
        'p_policy_version': policyVersion,
        'p_metadata': metadata ?? {},
      });
      return res as String;
    } catch (_) {
      // Fallback: direct insert (RLS: user_id = auth.uid())
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw Exception('Not authenticated');
      final insert = await supabase
          .from('consent_records')
          .insert({
        'user_id': uid,
        'consent_type': type,
        'policy_version': policyVersion,
        'metadata': metadata ?? {},
        'ip_address': ipAddress,
        'user_agent': userAgent,
      })
          .select('id')
          .single();
      return insert['id'] as String;
    }
  }

  Future<bool> hasConsented(String type, String policyVersion) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return false;
    final rows = await supabase
        .from('consent_records')
        .select('id')
        .eq('user_id', uid)
        .eq('consent_type', type)
        .eq('policy_version', policyVersion)
        .isFilter('revoked_at', null)
        .limit(1);
    return (rows as List).isNotEmpty;
  }
}
