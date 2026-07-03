// lib/features/shared/providers/consent_providers.dart
// v1.0

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/consent_repository.dart';

final consentRepositoryProvider =
Provider<ConsentRepository>((ref) => ConsentRepository());

// convenience: has user consented?
final hasConsentedProvider =
FutureProvider.family<bool, ({String type, String version})>((ref, p) async {
  final repo = ref.watch(consentRepositoryProvider);
  return repo.hasConsented(p.type, p.version);
});
