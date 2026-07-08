import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';
import 'app_text_styles.dart';

/// UjustBUY design system — a refined, production-grade Material 3 theme.
///
/// This file is the *assembly* layer: it reads the token files
/// ([AppColors], [AppTextStyles], [AppSpacing], [AppRadius], [AppShadows])
/// and wires them into a single [ThemeData] for light and dark mode.
/// Screens should reference the tokens (or `Theme.of(context)`), never raw
/// hex values.
class AppTheme {
  AppTheme._();

  // ---- Re-exported brand colours (kept for backward compatibility) ----------
  static const Color primary = AppColors.primary;
  static const Color primaryDark = AppColors.primary700;
  static const Color primaryLight = AppColors.primary300;
  static const Color secondary = AppColors.secondary;
  static const Color tertiary = AppColors.tertiary;

  static const Color primaryContainerLight = AppColors.primary50;
  static const Color onPrimaryContainerLight = AppColors.primary800;

  // ---- Semantic re-exports --------------------------------------------------
  static const Color success = AppColors.success;
  static const Color successContainer = AppColors.successContainer;
  static const Color onSuccessContainer = AppColors.onSuccessContainer;
  static const Color warning = AppColors.warning;
  static const Color warningContainer = AppColors.warningContainer;
  static const Color onWarningContainer = AppColors.onWarningContainer;
  static const Color danger = AppColors.error;
  static const Color dangerContainer = AppColors.errorContainer;
  static const Color onDangerContainer = AppColors.onErrorContainer;
  static const Color info = AppColors.info;
  static const Color infoContainer = AppColors.infoContainer;
  static const Color onInfoContainer = AppColors.onInfoContainer;

  static const Color neutralInk = Color(0xFF2A2228);

  // ---- Spacing scale (kept as aliases of AppSpacing) ------------------------
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space48 = 48;

  // ---- Corner radii (aliases of AppRadius) ----------------------------------
  static const double radiusSm = AppRadius.sm;
  static const double radiusMd = AppRadius.md;
  static const double radiusLg = AppRadius.lg;
  static const double radiusPill = AppRadius.full;
  static const double gap = 16;

  // ---- Elevation helpers (aliases of AppShadows) ----------------------------
  static List<BoxShadow> get shadowSm => AppShadows.level1;
  static List<BoxShadow> get shadowMd => AppShadows.level2;
  static List<BoxShadow> get brandShadow => AppShadows.brand;

  static Color onContainerFor(Color container) =>
      AppColors.onContainerFor(container);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer:
      isLight ? AppColors.primary50 : AppColors.primary900,
      onPrimaryContainer:
      isLight ? AppColors.primary800 : AppColors.primary50,
      secondary: isLight ? AppColors.secondary : const Color(0xFFE6A2B6),
      tertiary: isLight ? AppColors.tertiary : const Color(0xFFE6C98C),
      error: isLight ? AppColors.error : const Color(0xFFF2A8B0),
      onError: isLight ? Colors.white : const Color(0xFF680018),
      errorContainer:
          isLight ? AppColors.errorContainer : const Color(0xFF640015),
      onErrorContainer:
          isLight ? AppColors.onErrorContainer : const Color(0xFFFFD9DE),
      surface: isLight ? AppColors.background : AppColors.backgroundDark,
      onSurface:
      isLight ? AppColors.textPrimary : AppColors.textPrimaryDark,
      surfaceContainerLowest:
      isLight ? AppColors.surface : AppColors.surfaceDark,
      surfaceContainerLow: isLight
          ? const Color(0xFFFDFCFC)
          : AppColors.surfaceElevatedDark,
      surfaceContainerHighest:
      isLight ? const Color(0xFFEDE7EA) : AppColors.surfaceMutedDark,
      outline: isLight ? const Color(0xFF756B72) : const Color(0xFFC0B3BC),
      outlineVariant:
      isLight ? AppColors.border : AppColors.borderDark,
      onSurfaceVariant: isLight
          ? AppColors.textSecondary
          : const Color(0xFFF2E8EC),
    );

    final textTheme = AppTextStyles.textTheme(
      onSurface: scheme.onSurface,
      onSurfaceVariant: scheme.onSurfaceVariant,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // ---- App bar ----------------------------------------------------------
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        systemOverlayStyle:
        isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      ),

      // ---- Cards (elevation level 1) ----------------------------------------
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isLight ? 1 : 0.85),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // ---- Inputs (clear affordance: visible box + focus ring) --------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? Colors.white
            : scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle:
        TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(
          color: isLight ? AppColors.textHint : AppColors.textHintDark,
        ),
        helperStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // ---- Buttons: large targets (Fitts' Law), one consistent style --------
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.inter(
              fontSize: 15.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle:
          GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.55)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle:
          GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 44),
          textStyle:
          GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: scheme.onSurfaceVariant,
        ),
      ),

      // ---- Chips ------------------------------------------------------------
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full)),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerLowest,
        labelStyle:
        GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        secondaryLabelStyle: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onPrimary),
        selectedColor: scheme.primary,
        checkmarkColor: scheme.onPrimary,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ---- Bottom navigation ------------------------------------------------
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isLight ? 0.14 : 0.22),
        indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full)),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          );
        }),
      ),

      // ---- Tabs -------------------------------------------------------------
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant.withValues(alpha: 0.5),
        labelStyle:
        GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
        GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      ),

      // ---- FAB --------------------------------------------------------------
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
      ),

      // ---- Feedback surfaces ------------------------------------------------
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: neutralInk,
        contentTextStyle:
        GoogleFonts.inter(fontSize: 14, color: Colors.white),
        actionTextColor: scheme.tertiary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        insetPadding: const EdgeInsets.all(16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 19, fontWeight: FontWeight.w700, color: scheme.onSurface),
        contentTextStyle: GoogleFonts.inter(
            fontSize: 14.5, height: 1.5, color: scheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: GoogleFonts.inter(
            fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
        subtitleTextStyle:
        GoogleFonts.inter(fontSize: 13, color: scheme.onSurfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? scheme.primary : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected)
            ? scheme.primary.withValues(alpha: 0.4)
            : null),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: neutralInk,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 400),
      ),

      // ---- Text selection / cursor ------------------------------------------
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.22),
        selectionHandleColor: scheme.primary,
      ),

      // ---- Checkbox / radio / slider ----------------------------------------
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? scheme.primary : null),
        checkColor: WidgetStateProperty.all(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? scheme.primary : scheme.outline),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.18),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.14),
        trackHeight: 4,
      ),

      // ---- Segmented button -------------------------------------------------
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant),
          side: WidgetStateProperty.all(
              BorderSide(color: scheme.outlineVariant)),
          textStyle: WidgetStateProperty.all(
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm))),
        ),
      ),

      // ---- Menus / dropdowns ------------------------------------------------
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: GoogleFonts.inter(fontSize: 14, color: scheme.onSurface),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor:
          WidgetStateProperty.all(scheme.surfaceContainerLowest),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: scheme.outlineVariant),
          )),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: isLight
              ? Colors.white
              : scheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        menuStyle: MenuStyle(
          backgroundColor:
          WidgetStateProperty.all(scheme.surfaceContainerLowest),
          surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: scheme.outlineVariant),
          )),
        ),
      ),

      // ---- Badges -----------------------------------------------------------
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.primary,
        textColor: scheme.onPrimary,
        textStyle:
        GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700),
      ),

      // ---- Drawer / navigation rail -----------------------------------------
      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.horizontal(right: Radius.circular(AppRadius.xl)),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: scheme.primary, size: 24),
        unselectedIconTheme:
        IconThemeData(color: scheme.onSurfaceVariant, size: 24),
        selectedLabelTextStyle: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary),
        unselectedLabelTextStyle: GoogleFonts.inter(
            fontSize: 12, color: scheme.onSurfaceVariant),
      ),

      // ---- Expansion tile ---------------------------------------------------
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: scheme.primary,
        collapsedIconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        collapsedTextColor: scheme.onSurface,
        shape: const Border(),
        collapsedShape: const Border(),
      ),

      // ---- Banner / scrollbar -----------------------------------------------
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle:
        GoogleFonts.inter(fontSize: 14, color: scheme.onSurface),
        elevation: 0,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
            scheme.onSurfaceVariant.withValues(alpha: 0.4)),
        radius: const Radius.circular(AppRadius.full),
        thickness: WidgetStateProperty.all(6),
      ),

      // ---- Date / time pickers ----------------------------------------------
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
    );
  }

  /// Brand gradient used in hero areas / headers.
  static const LinearGradient brandGradient = AppColors.brandGradient;

  /// Subtle deeper gradient for large feature surfaces.
  static const LinearGradient brandGradientDeep = AppColors.brandGradientDeep;
}
