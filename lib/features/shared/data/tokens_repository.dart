import '../../../core/config/supabase_client.dart';
import '../../../models/models.dart';

/// Data access for the referral-token system (spec F7).
/// All mutations go through SECURITY DEFINER RPCs that enforce the rules.
class TokensRepository {
  Future<int> balance() async {
    final res = await supabase.rpc('token_balance');
    return (res as num?)?.toInt() ?? 0;
  }

  Future<List<TokenTransaction>> history() async {
    final rows = await supabase
        .from('token_transactions')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => TokenTransaction.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Claim a referral code (after sign-up). Returns true if tokens were awarded.
  Future<bool> claimReferral(String code) async {
    final res = await supabase.rpc('claim_referral', params: {'p_code': code});
    return res == true;
  }

  Future<void> redeemBoost(String productId) async {
    await supabase
        .rpc('redeem_listing_boost', params: {'p_product': productId});
  }

  Future<void> redeemCommissionDiscount(String productId) async {
    await supabase
        .rpc('redeem_commission_discount', params: {'p_product': productId});
  }
}
