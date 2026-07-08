import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';

final weeklySettlementsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final rows = await supabase.from('order_settlements')
      .select('gross_pesewas,platform_fee_pesewas,seller_net_pesewas,created_at')
      .order('created_at', ascending: false);
  return (rows as List).map((e) => Map<String, dynamic>.from(e)).toList();
});

class WeeklyRevenueScreen extends ConsumerWidget {
  const WeeklyRevenueScreen({super.key, required this.admin});
  final bool admin;
  @override Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(weeklySettlementsProvider);
    return Scaffold(appBar: AppBar(title: Text(admin ? 'Marketplace Revenue' : 'My Earnings')),
      body: data.when(loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load revenue: $e')),
        data: (rows) {
          final weeks = <DateTime, _Week>{};
          for (final row in rows) {
            final date = DateTime.parse(row['created_at'] as String).toLocal();
            final day = DateTime(date.year, date.month, date.day);
            final start = day.subtract(Duration(days: day.weekday - 1));
            final w = weeks.putIfAbsent(start, _Week.new);
            w.gross += (row['gross_pesewas'] as num).toInt();
            w.fee += (row['platform_fee_pesewas'] as num).toInt();
            w.net += (row['seller_net_pesewas'] as num).toInt(); w.orders++;
          }
          final entries = weeks.entries.toList()..sort((a,b) => b.key.compareTo(a.key));
          final total = rows.fold<int>(0, (s,r) => s + (r[admin ? 'platform_fee_pesewas' : 'seller_net_pesewas'] as num).toInt());
          return RefreshIndicator(onRefresh: () async => ref.invalidate(weeklySettlementsProvider),
            child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(admin ? 'Total marketplace revenue' : 'Total released earnings', style: AppTextStyles.bodySmall),
                const SizedBox(height: 6), Text(Formatters.money(total / 100), style: AppTextStyles.headlineMedium),
                Text('${rows.length} settled orders', style: AppTextStyles.bodySmall),
              ])), const SizedBox(height: AppSpacing.lg),
              Text('Weekly history', style: AppTextStyles.titleMedium), const SizedBox(height: AppSpacing.sm),
              if (entries.isEmpty) const AppCard(child: Text('No released payments yet.')),
              ...entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${Formatters.dateTime(e.key)} – ${Formatters.dateTime(e.key.add(const Duration(days: 6)))}', style: AppTextStyles.titleSmall),
                  const Divider(), _row('Gross sales', e.value.gross),
                  _row(admin ? 'Developer revenue' : 'Marketplace fee', e.value.fee),
                  _row(admin ? 'Paid to sellers' : 'Seller received', e.value.net, strong: true),
                  Text('${e.value.orders} settled orders', style: AppTextStyles.bodySmall),
                ]),
              ))),
            ]),
          );
        }));
  }
  static Widget _row(String label, int value, {bool strong=false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [Text(label), Text(Formatters.money(value / 100), style: strong ? AppTextStyles.titleSmall : null)]));
}
class _Week { int gross=0, fee=0, net=0, orders=0; }
