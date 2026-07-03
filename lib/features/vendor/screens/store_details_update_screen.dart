// lib/features/vendor/screens/store_details_update_screen.dart
// v1.4 – Fixed compilation errors: logo callback, deprecated Dropdown value, and AppTextField parameters.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/image_upload_field.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/vendor_providers.dart';

class StoreDetailsUpdateScreen extends ConsumerStatefulWidget {
  const StoreDetailsUpdateScreen({super.key});
  @override
  ConsumerState<StoreDetailsUpdateScreen> createState() =>
      _StoreDetailsUpdateScreenState();
}

class _StoreDetailsUpdateScreenState
    extends ConsumerState<StoreDetailsUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = StorageService();

  // Controllers
  final storeNameCtrl = TextEditingController();
  final ownerNameCtrl = TextEditingController();
  final storeDescriptionCtrl = TextEditingController();
  final sellerBioCtrl = TextEditingController();
  final programYearCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final hallCtrl = TextEditingController();
  final whatsappCtrl = TextEditingController();
  final storePhoneCtrl = TextEditingController();
  final personalPhoneCtrl = TextEditingController();
  final momoNumberCtrl = TextEditingController();
  final specialtyInputCtrl = TextEditingController();
  final customNoteCtrl = TextEditingController();

  String? selectedCampusId;
  String momoNetwork = 'MTN';
  List<String> workingDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  TimeOfDay openingTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay closingTime = const TimeOfDay(hour: 20, minute: 0);
  bool isClosedToday = false;
  bool holidayMode = false;
  double deliveryRadiusKm = 2.0;
  List<String> specialties = [];
  
  bool saving = false;
  bool _hydrated = false;
  PickedImage? _newLogo;

  static const allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    for (final c in [
      storeNameCtrl, ownerNameCtrl, storeDescriptionCtrl, sellerBioCtrl,
      programYearCtrl, locationCtrl, hallCtrl, whatsappCtrl, storePhoneCtrl,
      personalPhoneCtrl, momoNumberCtrl, specialtyInputCtrl, customNoteCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onLogoPicked(PickedImage? p) {
    setState(() => _newLogo = p);
  }

  void _hydrate(Vendor v) {
    if (_hydrated) return;
    _hydrated = true;
    storeNameCtrl.text = v.storeName ?? v.businessName;
    ownerNameCtrl.text = v.ownerName ?? '';
    storeDescriptionCtrl.text = v.storeDescription ?? v.description ?? '';
    sellerBioCtrl.text = v.sellerBio ?? '';
    programYearCtrl.text = v.programYear ?? '';
    locationCtrl.text = v.storeLocation ?? '';
    hallCtrl.text = v.hallHostel ?? '';
    whatsappCtrl.text = v.whatsappNumber ?? '';
    storePhoneCtrl.text = v.storePhone ?? '';
    personalPhoneCtrl.text = v.phoneNumber ?? '';
    momoNumberCtrl.text = v.momoNumber ?? '';
    momoNetwork = v.momoNetwork ?? 'MTN';
    customNoteCtrl.text = v.customNote ?? '';
    selectedCampusId = v.campusId;
    isClosedToday = v.isClosedToday;
    holidayMode = v.holidayMode;
    deliveryRadiusKm = v.deliveryRadiusKm.toDouble();
    specialties = List<String>.from(v.specialties);
    
    if (v.workingDays.isNotEmpty) workingDays = List<String>.from(v.workingDays);
    
    // Parse times
    try {
      if (v.openingTime != null && v.openingTime!.length >= 5) {
        final p = v.openingTime!.split(':');
        openingTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      }
      if (v.closingTime != null && v.closingTime!.length >= 5) {
        final p = v.closingTime!.split(':');
        closingTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      }
    } catch (_) {}
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime(bool isOpen) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isOpen ? openingTime : closingTime,
    );
    if (picked != null) {
      setState(() {
        if (isOpen) {
          openingTime = picked;
        } else {
          closingTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (workingDays.isEmpty) {
      ConfirmActions.showError(context, 'Select at least one working day');
      return;
    }

    setState(() => saving = true);
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) throw 'Session expired';

      String? logoUrl;
      if (_newLogo != null) {
        logoUrl = await _storage.upload(
          bucket: StorageService.businessLogos,
          bytes: _newLogo!.bytes,
          fileName: _newLogo!.name,
        );
      }

      final payload = {
        'store_name': storeNameCtrl.text.trim(),
        'business_name': storeNameCtrl.text.trim(),
        'owner_name': ownerNameCtrl.text.trim(),
        'store_description': storeDescriptionCtrl.text.trim(),
        'seller_bio': sellerBioCtrl.text.trim(),
        'program_year': programYearCtrl.text.trim(),
        'store_location': locationCtrl.text.trim(),
        'hall_hostel': hallCtrl.text.trim(),
        'campus_id': selectedCampusId,
        'whatsapp_number': whatsappCtrl.text.trim(),
        'store_phone': storePhoneCtrl.text.trim(),
        'phone_number': personalPhoneCtrl.text.trim(),
        'momo_number': momoNumberCtrl.text.trim(),
        'momo_network': momoNetwork,
        'working_days': workingDays,
        'opening_time': _fmtTime(openingTime),
        'closing_time': _fmtTime(closingTime),
        'is_closed_today': isClosedToday,
        'holiday_mode': holidayMode,
        'delivery_radius_km': deliveryRadiusKm.round(),
        'specialties': specialties,
        'custom_note': customNoteCtrl.text.trim(),
        'profile_completed': true,
        if (logoUrl != null) 'logo_url': logoUrl,
      };

      await ref.read(vendorRepositoryProvider).updateStoreDetails(payload);
      // Sync main account name
      await supabase.from('users').update({'full_name': ownerNameCtrl.text.trim()}).eq('user_id', uid);

      ref.invalidate(currentVendorProvider);
      if (!mounted) return;
      ConfirmActions.toast(context, 'Profile updated successfully', success: true);
      context.pop();
    } catch (e) {
      if (mounted) ConfirmActions.showError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorAsync = ref.watch(currentVendorProvider);
    final campusesAsync = ref.watch(campusesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Store Profile')),
      body: AsyncView<Vendor?>(
        value: vendorAsync,
        onRetry: () => ref.invalidate(currentVendorProvider),
        data: (v) {
          if (v == null) return const Center(child: Text('Vendor not found'));
          _hydrate(v);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Identity
                _sectionHeader('Business Identity'),
                AppCard(
                  child: Column(
                    children: [
                      Center(
                        child: ImageUploadField(
                          label: 'Store Logo',
                          icon: Icons.storefront,
                          height: 100,
                          circle: true,
                          initialUrl: v.logoUrl,
                          onPicked: _onLogoPicked,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: storeNameCtrl,
                        label: 'Store Name *',
                        prefixIcon: AppIcons.storefront,
                        validator: (s) => Validators.required(s, 'Store name'),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: ownerNameCtrl,
                        label: 'Owner Name *',
                        prefixIcon: AppIcons.user,
                        validator: (s) => Validators.required(s, 'Owner name'),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: storeDescriptionCtrl,
                        label: 'Short Tagline *',
                        hint: 'e.g. Best campus braids & fades',
                        maxLength: 100,
                        validator: (s) => Validators.required(s, 'Tagline'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Profile
                _sectionHeader('Seller Profile'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: sellerBioCtrl,
                        label: 'About Me',
                        hint: 'Share your experience or story...',
                        maxLines: 3,
                        maxLength: 300,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: programYearCtrl,
                        label: 'Program / Year',
                        hint: 'e.g. BSc. Computer Science - Year 3',
                        prefixIcon: Icons.school_outlined,
                      ),
                      const SizedBox(height: 16),
                      const Text('Skills & Specialties (Max 5)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: specialties.map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          onDeleted: () => setState(() => specialties.remove(s)),
                        )).toList(),
                      ),
                      if (specialties.length < 5)
                        Row(
                          children: [
                            Expanded(child: AppTextField(controller: specialtyInputCtrl, hint: 'e.g. Graphics Design')),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                final t = specialtyInputCtrl.text.trim();
                                if (t.isNotEmpty && !specialties.contains(t)) {
                                  setState(() { specialties.add(t); specialtyInputCtrl.clear(); });
                                }
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Location
                _sectionHeader('Location'),
                AppCard(
                  child: Column(
                    children: [
                      AsyncView<List<Campus>>(
                        value: campusesAsync,
                        data: (list) => DropdownButtonFormField<String>(
                          initialValue: selectedCampusId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Primary Campus *', prefixIcon: Icon(Icons.apartment)),
                          items: list.map((c) => DropdownMenuItem(value: c.campusId, child: Text(c.campusName))).toList(),
                          onChanged: (x) => setState(() => selectedCampusId = x),
                          validator: (x) => x == null ? 'Select campus' : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppTextField(controller: hallCtrl, label: 'Hall / Hostel', prefixIcon: Icons.home_work_outlined),
                      const SizedBox(height: 16),
                      AppTextField(controller: locationCtrl, label: 'Specific Location *', hint: 'e.g. Room B20 or Near Gate 2', validator: (s) => Validators.required(s, 'Location')),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.delivery_dining, size: 20, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Delivery Radius: ${deliveryRadiusKm.round()} km')),
                        ],
                      ),
                      Slider(
                        value: deliveryRadiusKm, min: 0, max: 10, divisions: 10,
                        label: '${deliveryRadiusKm.round()} km',
                        onChanged: (v) => setState(() => deliveryRadiusKm = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Contact
                _sectionHeader('Contact & Payouts'),
                AppCard(
                  child: Column(
                    children: [
                      AppTextField(controller: whatsappCtrl, label: 'WhatsApp Number *', prefixIcon: AppIcons.whatsapp, keyboardType: TextInputType.phone, validator: Validators.phone),
                      const SizedBox(height: 16),
                      AppTextField(controller: storePhoneCtrl, label: 'Business Call Line', prefixIcon: AppIcons.phoneBusiness, keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: DropdownButtonFormField<String>(
                              initialValue: momoNetwork,
                              decoration: const InputDecoration(labelText: 'Network'),
                              items: ['MTN', 'Vodafone', 'AirtelTigo'].map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                              onChanged: (v) => setState(() => momoNetwork = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: AppTextField(controller: momoNumberCtrl, label: 'MoMo Number *', prefixIcon: AppIcons.wallet, validator: Validators.momo)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Hours
                _sectionHeader('Operating Hours'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Working Days *', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: allDays.map((d) {
                          final sel = workingDays.contains(d);
                          return FilterChip(
                            label: Text(d, style: TextStyle(fontSize: 12, color: sel ? scheme.onPrimary : null)),
                            selected: sel,
                            selectedColor: scheme.primary,
                            onSelected: (v) => setState(() => v ? workingDays.add(d) : workingDays.remove(d)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.access_time, size: 18), label: Text(openingTime.format(context)), onPressed: () => _pickTime(true))),
                          const SizedBox(width: 12),
                          Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.bedtime_outlined, size: 18), label: Text(closingTime.format(context)), onPressed: () => _pickTime(false))),
                        ],
                      ),
                      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Holiday Mode'), subtitle: const Text('Shows "On Break" to students'), value: holidayMode, onChanged: (v) => setState(() => holidayMode = v)),
                      AppTextField(controller: customNoteCtrl, label: 'Custom Status Note', hint: 'e.g. Slower replies during exams', maxLength: 60),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: 'Save Changes', icon: AppIcons.save, loading: saving, onPressed: _save),
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(text.toUpperCase(), style: AppTextStyles.labelMedium.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
  );
}
