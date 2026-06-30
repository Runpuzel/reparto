import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../providers/student_providers.dart';

/// C5 — Dispute Form.
class DisputeFormScreen extends ConsumerStatefulWidget {
  final String orderId;
  const DisputeFormScreen({super.key, required this.orderId});

  @override
  ConsumerState<DisputeFormScreen> createState() => _DisputeFormScreenState();
}

class _DisputeFormScreenState extends ConsumerState<DisputeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  String _category = 'Item not received';
  bool _loading = false;

  static const _categories = [
    'Item not received',
    'Item does not match description',
    'Item is damaged',
    'Seller is unresponsive',
    'Other',
  ];

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(studentRepositoryProvider).raiseDispute(
        orderId: widget.orderId,
        category: _category,
        description: _description.text.trim(),
      );
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(myOrdersProvider);
      if (mounted) {
        Navigator.pop(context);
        ConfirmActions.toast(
            context, 'Dispute submitted. An admin will review it.',
            success: true);
      }
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Raise a Dispute')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.warningContainer,
                        borderRadius: AppRadius.brMd,
                      ),
                      child: Row(
                        children: [
                          Icon(AppIcons.info,
                              size: 20, color: AppColors.onWarningContainer),
                          const SizedBox(width: AppSpacing.sm + 2),
                          Expanded(
                            child: Text(
                              'A Campus Admin will review your case and contact '
                                  'both parties. Only raise a dispute if there is a '
                                  'genuine issue with your order.',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.onWarningContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('What is the issue?',
                        style: AppTextStyles.titleSmall
                            .copyWith(color: scheme.onSurface)),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      value: _category,
                      isExpanded: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(AppIcons.info, size: 20),
                      ),
                      items: _categories
                          .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? _categories.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _description,
                      label: 'Describe the issue',
                      hint:
                      'What went wrong? Include any details that help us '
                          'resolve it fairly.',
                      maxLines: 5,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.length < 30) {
                          return 'Please write at least 30 characters';
                        }
                        if (t.length > 1000) {
                          return 'Keep it under 1000 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tip: you can share screenshots of your WhatsApp '
                          'conversation with the seller when the admin reaches out.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Submit Dispute',
                      icon: AppIcons.info,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
