import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../models/models.dart';
import '../../shared/providers/shared_providers.dart';
import '../data/admin_repository.dart';
import '../providers/admin_providers.dart';

class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  String _audience = 'all';
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  int _audienceCount(List<AppUser> users) => users.where((user) {
        if (user.isSuspended || user.role == UserRole.admin) return false;
        if (_audience == 'students') return user.role == UserRole.student;
        if (_audience == 'sellers') return user.role == UserRole.vendor;
        return user.role == UserRole.student || user.role == UserRole.vendor;
      }).length;

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final users = ref.read(allUsersProvider).valueOrNull ?? const <AppUser>[];
    final estimate = _audienceCount(users);
    final audienceLabel = switch (_audience) {
      'students' => 'students',
      'sellers' => 'student sellers',
      _ => 'all users',
    };
    final confirmed = await ConfirmActions.confirm(
      context,
      title: 'Send announcement?',
      message: estimate > 0
          ? 'This will notify approximately $estimate $audienceLabel.'
          : 'This will notify $audienceLabel.',
      confirmLabel: 'Send now',
      icon: Icons.campaign_outlined,
    );
    if (!confirmed) return;

    setState(() => _sending = true);
    try {
      final count = await ref.read(adminRepositoryProvider).sendBroadcast(
            title: _title.text,
            body: _message.text,
            audience: _audience,
          );
      _title.clear();
      _message.clear();
      ref.invalidate(adminBroadcastsProvider);
      ref.invalidate(unreadNotificationsProvider);
      if (mounted) {
        ConfirmActions.toast(
          context,
          'Announcement sent to $count user${count == 1 ? '' : 's'}',
          success: true,
        );
      }
    } catch (error) {
      if (mounted) ConfirmActions.showError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(allUsersProvider).valueOrNull ?? const <AppUser>[];
    final history = ref.watch(adminBroadcastsProvider);
    final count = _audienceCount(users);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allUsersProvider);
        ref.invalidate(adminBroadcastsProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Send announcement', style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Recipients receive an in-app notification and a push alert when push is enabled.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Audience', style: AppTextStyles.titleSmall),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'all',
                                  icon: Icon(Icons.groups_outlined),
                                  label: Text('Everyone'),
                                ),
                                ButtonSegment(
                                  value: 'students',
                                  icon: Icon(Icons.school_outlined),
                                  label: Text('Students'),
                                ),
                                ButtonSegment(
                                  value: 'sellers',
                                  icon: Icon(Icons.storefront_outlined),
                                  label: Text('Sellers'),
                                ),
                              ],
                              selected: {_audience},
                              onSelectionChanged: (selection) => setState(
                                () => _audience = selection.first,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$count estimated recipient${count == 1 ? '' : 's'}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _title,
                            label: 'Title',
                            hint: 'Weekend sale starts today',
                            prefixIcon: Icons.title,
                            maxLength: 60,
                            validator: (value) {
                              final length = value?.trim().length ?? 0;
                              if (length < 3) {
                                return 'Enter at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _message,
                            label: 'Message',
                            hint: 'Share the update users should know...',
                            prefixIcon: Icons.message_outlined,
                            minLines: 4,
                            maxLines: 6,
                            maxLength: 280,
                            validator: (value) {
                              final length = value?.trim().length ?? 0;
                              if (length < 3) {
                                return 'Enter at least 3 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppButton(
                            label:
                                _sending ? 'Sending...' : 'Send announcement',
                            icon: _sending ? null : Icons.send_outlined,
                            loading: _sending,
                            onPressed: _sending ? null : _send,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Recent announcements',
                      style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  history.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => ErrorState(
                      message: '$error',
                      onRetry: () => ref.invalidate(adminBroadcastsProvider),
                    ),
                    data: (items) => items.isEmpty
                        ? const EmptyState(
                            icon: Icons.campaign_outlined,
                            title: 'No announcements yet',
                            subtitle: 'Sent announcements will appear here.',
                          )
                        : Column(
                            children: items
                                .map(
                                    (item) => _BroadcastHistoryItem(item: item))
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BroadcastHistoryItem extends StatelessWidget {
  const _BroadcastHistoryItem({required this.item});
  final AdminBroadcast item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.campaign_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppTextStyles.titleSmall),
                  const SizedBox(height: 4),
                  Text(item.body, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    '${_audienceLabel(item.audience)} • ${item.recipientCount} recipients • ${_dateLabel(item.createdAt)}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _audienceLabel(String value) => switch (value) {
        'students' => 'Students',
        'sellers' => 'Sellers',
        _ => 'Everyone',
      };

  static String _dateLabel(DateTime value) {
    final local = value.toLocal();
    final date = '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
