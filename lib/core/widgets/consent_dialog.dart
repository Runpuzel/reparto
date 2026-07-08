// lib/core/widgets/consent_dialog.dart
// v1.0-2025-07 – Reusable consent / policy confirmation dialog
// Ghana Data Protection Act 2012 compliant audit trail

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/shared/data/consent_repository.dart';
import '../../features/shared/providers/consent_providers.dart';
// v1.0 – ConsentType lives in models.dart – single source of truth
import '../../models/models.dart' show ConsentType;

extension ConsentTypeX on ConsentType {
  String get db {
    switch (this) {
      case ConsentType.sellerAgreement:
        return 'seller_agreement';
      case ConsentType.servicePost:
        return 'service_post';
      case ConsentType.paymentAuth:
        return 'payment_auth';
      case ConsentType.verificationSubmit:
        return 'verification_submit';
      case ConsentType.checkoutPolicy:
        return 'checkout_policy';
      case ConsentType.termsUpdate:
        return 'terms_update';
    }
  }
  String get label {
    switch (this) {
      case ConsentType.sellerAgreement: return 'Seller Agreement';
      case ConsentType.servicePost: return 'Service Listing Policy';
      case ConsentType.paymentAuth: return 'Payment Authorization';
      case ConsentType.verificationSubmit: return 'ID Verification Consent';
      case ConsentType.checkoutPolicy: return 'Purchase Policy';
      case ConsentType.termsUpdate: return 'Terms Update';
    }
  }
}

/// showConsentDialog – returns true if accepted, records ConsentRecord automatically
Future<bool> showConsentDialog(
    BuildContext context, {
      required ConsentType type,
      required String policyVersion,
      required String title,
      required String bodyMarkdown,
      List<String> requiredCheckboxes = const [],
      bool scrollToAccept = true,
      WidgetRef? ref,
    }) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ConsentDialog(
      type: type,
      policyVersion: policyVersion,
      title: title,
      bodyMarkdown: bodyMarkdown,
      requiredCheckboxes: requiredCheckboxes,
      scrollToAccept: scrollToAccept,
      ref: ref,
    ),
  ) ??
      false;
}

class _ConsentDialog extends StatefulWidget {
  final ConsentType type;
  final String policyVersion;
  final String title;
  final String bodyMarkdown;
  final List<String> requiredCheckboxes;
  final bool scrollToAccept;
  final WidgetRef? ref;
  const _ConsentDialog({
    required this.type,
    required this.policyVersion,
    required this.title,
    required this.bodyMarkdown,
    required this.requiredCheckboxes,
    required this.scrollToAccept,
    this.ref,
  });
  @override
  State<_ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<_ConsentDialog> {
  final _scrollCtrl = ScrollController();
  double _readPct = 0;
  late List<bool> _checks;
  bool _saving = false;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _checks = List.filled(widget.requiredCheckboxes.length, false);
    if (widget.scrollToAccept) {
      _scrollCtrl.addListener(_updateReadProgress);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateReadProgress());
    } else {
      _readPct = 1.0;
    }
    Stream.periodic(const Duration(seconds: 1)).take(900).listen((i) {
      if (mounted) setState(() => _seconds = i + 1);
    });
  }

  void _updateReadProgress() {
    if (!mounted || !_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    final off = _scrollCtrl.position.pixels;
    final pct = max <= 0 ? 1.0 : (off / max).clamp(0.0, 1.0);
    if ((pct - _readPct).abs() > 0.01) {
      setState(() => _readPct = pct);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _allChecked => _checks.isEmpty || _checks.every((e) => e);
  bool get _canAccept =>
      !_saving &&
          _allChecked &&
          (!widget.scrollToAccept || _readPct >= 0.95);

  Future<void> _accept() async {
    setState(() => _saving = true);
    try {
      if (widget.ref != null) {
        try {
          final repo = widget.ref!.read(consentRepositoryProvider);
          await repo.record(
            type: widget.type.db,
            policyVersion: widget.policyVersion,
            metadata: {
              'checkboxes_accepted': widget.requiredCheckboxes,
              'scroll_pct': (_readPct * 100).round(),
              'time_on_page_sec': _seconds,
            },
          );
        } catch (_) {}
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Consent save failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (_readPct * 100).toInt();
    return AlertDialog(
      insetPadding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      title: Row(children: [
        Expanded(child: Text(widget.title)),
        IconButton(
            onPressed: _saving
                ? null
                : () => Navigator.pop(context, false),
            icon: const Icon(Icons.close, size: 20))
      ]),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.scrollToAccept) ...[
              LinearProgressIndicator(
                  value: _readPct, minHeight: 3,
                  backgroundColor:
                  scheme.surfaceContainerHighest),
              const SizedBox(height: 6),
              Text('Read $pct% – scroll to enable',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
            ],
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 340),
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Scrollbar(
                  controller: _scrollCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(14),
                    child: SelectableText(
                      widget.bodyMarkdown,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.requiredCheckboxes.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...List.generate(widget.requiredCheckboxes.length,
                      (i) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity:
                    ListTileControlAffinity.leading,
                    value: _checks[i],
                    onChanged: (v) =>
                        setState(() => _checks[i] = v ?? false),
                    title: Text(
                      widget.requiredCheckboxes[i],
                      style: const TextStyle(
                          fontSize: 13.5, height: 1.35),
                    ),
                  )),
            ],
            const SizedBox(height: 6),
            Text(
              'Policy ${widget.policyVersion} • v1.0 DPA 2012 • ${DateTime.now().toLocal().toString().substring(0,16)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11),
            ),
          ],
        ),
      ),
      actionsPadding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      actions: [
        TextButton(
            onPressed: _saving
                ? null
                : () => Navigator.pop(context, false),
            child: const Text('Decline')),
        FilledButton.icon(
          onPressed: _canAccept ? _accept : null,
          icon: _saving
              ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline,
              size: 18),
          label: Text(_saving
              ? 'Saving…'
              : _canAccept
              ? 'I Agree – Continue'
              : widget.scrollToAccept && _readPct < 0.95
              ? 'Read ${95 - pct}% more'
              : 'Check all boxes'),
        ),
      ],
    );
  }
}
