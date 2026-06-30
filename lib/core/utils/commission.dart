import 'money.dart';

/// A single commission tier (mirrors `public.commission_tiers`).
/// All money is in integer pesewas; [percentBps] is basis points (500 = 5%).
class CommissionTier {
  final String tierId;
  final String? campusId; // null = global
  final int priceFrom;
  final int? priceTo; // null = open-ended
  final int? flatPesewas; // set when this is a flat tier
  final int? percentBps; // set when this is a percentage tier

  const CommissionTier({
    required this.tierId,
    this.campusId,
    required this.priceFrom,
    this.priceTo,
    this.flatPesewas,
    this.percentBps,
  });

  bool get isPercent => percentBps != null;

  bool matches(int pricePesewas) =>
      priceFrom <= pricePesewas &&
          (priceTo == null || priceTo! >= pricePesewas);

  /// Commission (pesewas) this tier charges for [pricePesewas].
  int commissionFor(int pricePesewas) {
    if (flatPesewas != null) return flatPesewas!;
    return (pricePesewas * (percentBps ?? 0) / 10000).round();
  }

  factory CommissionTier.fromMap(Map<String, dynamic> m) => CommissionTier(
    tierId: m['tier_id'] as String,
    campusId: m['campus_id'] as String?,
    priceFrom: (m['price_from'] as num).toInt(),
    priceTo: m['price_to'] == null ? null : (m['price_to'] as num).toInt(),
    flatPesewas: m['flat_pesewas'] == null
        ? null
        : (m['flat_pesewas'] as num).toInt(),
    percentBps:
    m['percent_bps'] == null ? null : (m['percent_bps'] as num).toInt(),
  );
}

/// Client-side commission calculator that mirrors the SQL
/// `commission_for_price()` so the UI can show the platform fee live. The
/// server remains the source of truth at order time.
class Commission {
  const Commission._();

  /// Spec defaults, used as a fallback if tiers haven't loaded yet.
  static const List<CommissionTier> defaults = [
    CommissionTier(tierId: '_d1', priceFrom: 100, priceTo: 900, flatPesewas: 100),
    CommissionTier(tierId: '_d2', priceFrom: 1000, priceTo: 2000, flatPesewas: 200),
    CommissionTier(tierId: '_d3', priceFrom: 2100, priceTo: 5000, flatPesewas: 350),
    CommissionTier(tierId: '_d4', priceFrom: 5100, priceTo: 10000, flatPesewas: 600),
    CommissionTier(tierId: '_d5', priceFrom: 10100, priceTo: 20000, flatPesewas: 1200),
    CommissionTier(tierId: '_d6', priceFrom: 20100, priceTo: 50000, flatPesewas: 2500),
    CommissionTier(tierId: '_d7', priceFrom: 50100, priceTo: null, percentBps: 500),
  ];

  /// Commission in pesewas for [pricePesewas], preferring a campus-specific
  /// tier over a global one. Free items (price <= 0) cost nothing.
  static int forPrice(
      int pricePesewas, {
        String? campusId,
        List<CommissionTier> tiers = defaults,
      }) {
    if (pricePesewas <= 0) return 0;
    CommissionTier? best;
    bool bestIsCampus = false;
    for (final t in tiers) {
      if (!t.matches(pricePesewas)) continue;
      final isCampus = t.campusId != null && t.campusId == campusId;
      // Prefer campus tier; among same kind, the higher band wins.
      if (best == null ||
          (isCampus && !bestIsCampus) ||
          (isCampus == bestIsCampus && t.priceFrom > best.priceFrom)) {
        best = t;
        bestIsCampus = isCampus;
      }
    }
    return best?.commissionFor(pricePesewas) ?? 0;
  }

  /// Convenience: commission for a cedis price, returned formatted.
  static String formatForCedis(num cedis,
      {String? campusId, List<CommissionTier> tiers = defaults}) {
    final fee = forPrice(Money.fromCedis(cedis), campusId: campusId, tiers: tiers);
    return Money.format(fee);
  }
}
