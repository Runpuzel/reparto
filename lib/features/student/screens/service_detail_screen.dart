import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/confirm_actions.dart';
import '../../../core/widgets/sign_in_prompt.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/student_providers.dart';

/// D1 - Service Detail with swipeable image gallery.
class ServiceDetailScreen extends ConsumerStatefulWidget {
  final String serviceId;
  const ServiceDetailScreen({super.key, required this.serviceId});

  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  int _imageIndex = 0;
  final _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ServiceDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceId != widget.serviceId) {
      _imageIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceAsync = ref.watch(serviceProvider(widget.serviceId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Service')),
      body: serviceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(serviceProvider(widget.serviceId)),
        ),
        data: (s) {
          if (s == null) {
            return const EmptyState(
              icon: Icons.handyman_outlined,
              title: 'Service not found',
            );
          }
          final gallery = s.gallery;
          final serviceIcon = AppIcons.serviceCategory(s.category.db);
          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    _ServiceGallery(
                      images: gallery,
                      controller: _pageController,
                      currentIndex: _imageIndex,
                      fallbackIcon: serviceIcon,
                      onChanged: (i) => setState(() => _imageIndex = i),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _tag(context, s.category.label, serviceIcon),
                              const SizedBox(width: AppSpacing.sm),
                              _tag(
                                context,
                                s.priceLabel,
                                AppIcons.price,
                                accent: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            s.title,
                            style: AppTextStyles.headlineSmall.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _section(context, 'About this service'),
                          const SizedBox(height: AppSpacing.xs + 2),
                          Text(
                            (s.description != null && s.description!.isNotEmpty)
                                ? s.description!
                                : 'No description provided.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (s.availability != null &&
                              s.availability!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            _section(context, 'Availability'),
                            const SizedBox(height: AppSpacing.xs + 2),
                            _iconLine(context, AppIcons.clock, s.availability!),
                          ],
                          if (s.location != null && s.location!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            _section(context, 'Location'),
                            const SizedBox(height: AppSpacing.xs + 2),
                            _iconLine(context, AppIcons.mapPin, s.location!),
                          ],
                          if (s.vendorName != null) ...[
                            const SizedBox(height: AppSpacing.lg),
                            AppCard(
                              onTap: () =>
                                  context.push('/student/shop/${s.vendorId}'),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: scheme.primaryContainer,
                                    child: Icon(
                                      AppIcons.storefrontFill,
                                      color: scheme.onPrimaryContainer,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      s.vendorName!,
                                      style: AppTextStyles.titleSmall.copyWith(
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    AppIcons.caretRight,
                                    size: 18,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _ActionBar(service: s),
            ],
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String t) => Text(
    t,
    style: AppTextStyles.titleMedium.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );

  Widget _iconLine(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurface),
          ),
        ),
      ],
    );
  }

  Widget _tag(
    BuildContext context,
    String label,
    IconData icon, {
    bool accent = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bg = accent
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.secondaryContainer.withValues(alpha: 0.6);
    final fg = accent ? scheme.primary : scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 5,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.brFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image gallery with swipe, dot indicators, thumbnail strip, and fullscreen.
// ---------------------------------------------------------------------------

class _ServiceGallery extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int currentIndex;
  final IconData fallbackIcon;
  final ValueChanged<int> onChanged;

  const _ServiceGallery({
    required this.images,
    required this.controller,
    required this.currentIndex,
    required this.fallbackIcon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // No images - show fallback.
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 10,
        child: Container(
          color: scheme.surfaceContainerHighest,
          child: Icon(fallbackIcon, size: 64, color: scheme.onSurfaceVariant),
        ),
      );
    }

    // Single image - no sliding controls.
    if (images.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 10,
        child: GestureDetector(
          onTap: () => _openFullscreen(context, images, 0),
          child: AppNetworkImage(url: images.first, fallbackIcon: fallbackIcon),
        ),
      );
    }

    final safeIndex = currentIndex.clamp(0, images.length - 1).toInt();
    final dotCount = images.length > 8 ? 8 : images.length;
    final activeDot = images.length <= 8
        ? safeIndex
        : (safeIndex * (dotCount - 1) / (images.length - 1)).round();

    // Multiple images - full gallery experience.
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: images.length,
                onPageChanged: onChanged,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _openFullscreen(context, images, i),
                  child: AppNetworkImage(
                    url: images[i],
                    fallbackIcon: fallbackIcon,
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GalleryArrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: safeIndex > 0 ? () => _goTo(safeIndex - 1) : null,
                    ),
                    _GalleryArrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: safeIndex < images.length - 1
                          ? () => _goTo(safeIndex + 1)
                          : null,
                    ),
                  ],
                ),
              ),
              // Page counter badge
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: AppRadius.brFull,
                  ),
                  child: Text(
                    '${safeIndex + 1} / ${images.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              // Dot indicators
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    dotCount,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == activeDot ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == activeDot
                            ? scheme.primary
                            : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Thumbnail strip
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.sm),
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _goTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.brSm,
                  border: Border.all(
                    color: i == safeIndex
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: i == safeIndex ? 2.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: AppNetworkImage(
                  url: images[i],
                  fallbackIcon: fallbackIcon,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _goTo(int index) {
    final target = index.clamp(0, images.length - 1).toInt();
    onChanged(target);
    if (!controller.hasClients) return;
    controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _openFullscreen(BuildContext context, List<String> imgs, int start) {
    showDialog(
      context: context,
      builder: (_) =>
          _FullscreenServiceGallery(images: imgs, initialIndex: start),
    );
  }
}

class _FullscreenServiceGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenServiceGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenServiceGallery> createState() =>
      _FullscreenServiceGalleryState();
}

class _FullscreenServiceGalleryState extends State<_FullscreenServiceGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1).toInt();
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: Image.network(
                  widget.images[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    AppIcons.brokenImage,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GalleryArrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: _index > 0 ? () => _goTo(_index - 1) : null,
                  ),
                  _GalleryArrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: _index < widget.images.length - 1
                        ? () => _goTo(_index + 1)
                        : null,
                  ),
                ],
              ),
            ),
          Positioned(
            top: 40,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.46),
                borderRadius: AppRadius.brFull,
              ),
              child: Text(
                '${_index + 1} / ${widget.images.length}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  void _goTo(int index) {
    final target = index.clamp(0, widget.images.length - 1).toInt();
    setState(() => _index = target);
    if (!_controller.hasClients) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }
}

class _GalleryArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GalleryArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.28 : 1,
        duration: const Duration(milliseconds: 180),
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.42),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.black.withValues(alpha: 0.24),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
          ),
          icon: Icon(icon),
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  final Service service;
  const _ActionBar({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    final isOwnService =
        ref.watch(currentVendorProvider).valueOrNull?.vendorId ==
        service.vendorId;
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: isOwnService ? 'Your Service' : 'Contact on WhatsApp',
                  icon: AppIcons.whatsapp,
                  variant: AppButtonVariant.secondary,
                  onPressed: isOwnService
                      ? null
                      : () async {
                          if (isGuest) {
                            await SignInPrompt.show(
                              context,
                              action: 'contact sellers',
                            );
                            return;
                          }
                          await _whatsapp(context, ref);
                        },
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                // Booking & pay (D3) arrives with the escrow phase (P6).
                child: AppButton(
                  label: 'Booking soon',
                  icon: AppIcons.clock,
                  onPressed: null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _whatsapp(BuildContext context, WidgetRef ref) async {
    final vendor = await ref
        .read(studentRepositoryProvider)
        .fetchVendor(service.vendorId);
    final phone = vendor?.businessPhone ?? vendor?.phoneNumber;
    if (phone == null || phone.isEmpty) {
      if (context.mounted) {
        ConfirmActions.showError(context, 'This seller has no contact number.');
      }
      return;
    }
    final intl = phone.startsWith('0') ? '233${phone.substring(1)}' : phone;
    final msg = Uri.encodeComponent(
      "Hi, I'm interested in ${service.title} on UjustBUY",
    );
    final url = 'https://wa.me/$intl?text=$msg';
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        ConfirmActions.showError(context, 'Could not open WhatsApp.');
      }
    } catch (_) {
      if (context.mounted) {
        ConfirmActions.showError(context, 'Could not open WhatsApp.');
      }
    }
  }
}
