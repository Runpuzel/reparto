import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../providers/admin_providers.dart';

class AdminPlatformSettingsScreen extends ConsumerStatefulWidget {
  const AdminPlatformSettingsScreen({super.key});

  @override
  ConsumerState<AdminPlatformSettingsScreen> createState() =>
      _AdminPlatformSettingsScreenState();
}

class _AdminPlatformSettingsScreenState
    extends ConsumerState<AdminPlatformSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authFee = TextEditingController();
  final _authDays = TextEditingController();
  final _freeDays = TextEditingController();
  final _sellerFee = TextEditingController();
  final _serviceFee = TextEditingController();
  final _policyVersion = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  bool _dirty = false;
  bool _verificationRequired = true;
  final Set<String> _kycTypes = {};

  static const _documents = <String, String>{
    'ghana_card': 'Ghana Card',
    'student_id': 'Student ID',
    'passport': 'Passport',
    'drivers_license': "Driver's licence",
  };

  @override
  void dispose() {
    _authFee.dispose();
    _authDays.dispose();
    _freeDays.dispose();
    _sellerFee.dispose();
    _serviceFee.dispose();
    _policyVersion.dispose();
    super.dispose();
  }

  void _populate(PlatformSetting settings) {
    if (_initialized) return;
    _initialized = true;
    _authFee.text = _number(settings.serviceAuthFee);
    _authDays.text = '${settings.serviceAuthDurationDays}';
    _freeDays.text = '${settings.serviceFreeListingDays}';
    _sellerFee.text = _number(settings.platformFeeSellerPercent);
    _serviceFee.text = _number(settings.platformFeeServicePercent);
    _policyVersion.text = settings.currentPolicyVersion;
    _verificationRequired = settings.verificationRequiredForPrepayment;
    _kycTypes.addAll(settings.kycAllowedTypes);
  }

  String _number(double value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  void _changed([String? _]) {
    if (_initialized) setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(platformSettingsProvider);
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty) return;
        final leave = await ConfirmActions.confirm(
          context,
          title: 'Discard changes?',
          message: 'Your unsaved platform settings will be lost.',
          confirmLabel: 'Discard',
          destructive: true,
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Platform settings'),
          actions: [
            if (_dirty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text('Unsaved',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.warning)),
                ),
              ),
          ],
        ),
        body: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorState(
            message: '$error',
            onRetry: () => ref.invalidate(platformSettingsProvider),
          ),
          data: (value) {
            _populate(value);
            return _buildForm(context, value);
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, PlatformSetting settings) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final padding = constraints.maxWidth < 420 ? 12.0 : 20.0;
        final listing = _SettingsSection(
          icon: Icons.design_services_outlined,
          title: 'Service listings',
          subtitle: 'Control listing access, duration, and launch pricing.',
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Free listing mode'),
              subtitle: const Text('Vendors can authorize services at no cost.'),
              value: _parseDouble(_authFee.text) == 0,
              onChanged: (enabled) {
                setState(() {
                  _authFee.text = enabled ? '0' : '30';
                  _dirty = true;
                });
              },
            ),
            const SizedBox(height: 12),
            _fieldRow([
              _decimalField(_authFee, 'Authorization fee', 'GHS', 0, 100000),
              _integerField(_authDays, 'Authorization duration', 'Days', 1, 365),
              _integerField(_freeDays, 'Free listing period', 'Days', 0, 365),
            ]),
          ],
        );
        final fees = _SettingsSection(
          icon: Icons.percent,
          title: 'Marketplace fees',
          subtitle: 'Percentage charged on successful marketplace activity.',
          children: [
            _fieldRow([
              _decimalField(_sellerFee, 'Product seller fee', '%', 0, 100),
              _decimalField(_serviceFee, 'Service provider fee', '%', 0, 100),
            ]),
            const SizedBox(height: 12),
            _InfoBanner(
              text:
                  'Fee changes affect future transactions only. Existing orders retain their recorded totals.',
            ),
          ],
        );
        final verification = _SettingsSection(
          icon: Icons.verified_user_outlined,
          title: 'Verification and KYC',
          subtitle: 'Set the identity requirements for prepaid transactions.',
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require verification for prepayment'),
              subtitle: const Text(
                  'Only verified vendors may receive prepaid orders.'),
              value: _verificationRequired,
              onChanged: (value) => setState(() {
                _verificationRequired = value;
                _dirty = true;
              }),
            ),
            const SizedBox(height: 12),
            Text('Accepted identity documents',
                style: AppTextStyles.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _documents.entries
                  .map((entry) => FilterChip(
                        label: Text(entry.value),
                        selected: _kycTypes.contains(entry.key),
                        onSelected: (selected) => setState(() {
                          selected
                              ? _kycTypes.add(entry.key)
                              : _kycTypes.remove(entry.key);
                          _dirty = true;
                        }),
                      ))
                  .toList(),
            ),
          ],
        );
        final governance = _SettingsSection(
          icon: Icons.policy_outlined,
          title: 'Policy governance',
          subtitle: 'Identify the policy version currently shown to users.',
          children: [
            TextFormField(
              controller: _policyVersion,
              onChanged: _changed,
              decoration: const InputDecoration(
                labelText: 'Current policy version',
                hintText: 'Example: v1.1-2026-07',
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Policy version is required'
                  : null,
            ),
            const SizedBox(height: 10),
            Text('Last updated ${Formatters.dateTime(settings.updatedAt)}',
                style: AppTextStyles.bodySmall),
          ],
        );

        return Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
            children: [
              Text('Platform controls', style: AppTextStyles.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Changes apply across Reparto. Review values carefully before saving.',
                style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              if (wide) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: [listing, const SizedBox(height: 16), fees])),
                    const SizedBox(width: 16),
                    Expanded(child: Column(children: [verification, const SizedBox(height: 16), governance])),
                  ],
                ),
              ] else ...[
                listing,
                const SizedBox(height: 12),
                fees,
                const SizedBox(height: 12),
                verification,
                const SizedBox(height: 12),
                governance,
              ],
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: AppButton(
                    label: 'Save platform settings',
                    icon: Icons.save_outlined,
                    loading: _saving,
                    onPressed: _dirty ? _save : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _fieldRow(List<Widget> fields) => LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 560
            ? Column(
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    fields[i],
                    if (i < fields.length - 1) const SizedBox(height: 12),
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < fields.length; i++) ...[
                    Expanded(child: fields[i]),
                    if (i < fields.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
      );

  Widget _decimalField(TextEditingController controller, String label,
      String suffix, double min, double max) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: _changed,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (value) {
        final number = double.tryParse((value ?? '').trim());
        if (number == null) return 'Enter a valid number';
        if (number < min || number > max) return 'Use $min to $max';
        return null;
      },
    );
  }

  Widget _integerField(TextEditingController controller, String label,
      String suffix, int min, int max) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: _changed,
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: (value) {
        final number = int.tryParse((value ?? '').trim());
        if (number == null) return 'Enter a whole number';
        if (number < min || number > max) return 'Use $min to $max';
        return null;
      },
    );
  }

  double _parseDouble(String value) => double.tryParse(value) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_verificationRequired && _kycTypes.isEmpty) {
      ConfirmActions.showError(
          context, 'Select at least one accepted identity document.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).updatePlatformSettings({
        'service_auth_fee': _parseDouble(_authFee.text),
        'service_auth_duration_days': int.parse(_authDays.text.trim()),
        'service_free_listing_days': int.parse(_freeDays.text.trim()),
        'platform_fee_seller_percent': _parseDouble(_sellerFee.text),
        'platform_fee_service_percent': _parseDouble(_serviceFee.text),
        'verification_required_for_prepayment': _verificationRequired,
        'kyc_allowed_types': _kycTypes.toList()..sort(),
        'current_policy_version': _policyVersion.text.trim(),
      });
      ref.invalidate(platformSettingsProvider);
      if (mounted) {
        setState(() => _dirty = false);
        ConfirmActions.toast(context, 'Platform settings saved', success: true);
      }
    } catch (error) {
      if (mounted) ConfirmActions.showError(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            ...children,
          ],
        ),
      );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
          ],
        ),
      );
}
