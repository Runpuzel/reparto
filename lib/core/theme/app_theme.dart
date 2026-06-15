import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reparto's design system — a refined, cohesive, mobile-first Material 3 theme.
///
/// Brand palette
///   • Primary  : Reparto blue           (#2563EB)
///   • Secondary: sky/cyan accent         (#0EA5E9)
///   • Tertiary : warm amber              (#F59E0B)
class AppTheme {
  // Core brand colors
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color tertiary = Color(0xFFF59E0B);

  // Semantic colors
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFE8A317);
  static const Color danger = Color(0xFFE5484D);
  static const Color info = Color(0xFF2563EB);

  // Design tokens
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double gap = 16;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: isLight ? primary : const Color(0xFF6BA0FF),
      secondary: secondary,
      tertiary: tertiary,
      error: danger,
      // Light: a soft blue-grey page background so white cards stand out and
      // don't blend into the scaffold.
      surface: isLight ? const Color(0xFFEEF2F9) : const Color(0xFF0E1117),
      // Cards / sheets sit ABOVE the surface — keep them pure white in light
      // mode for clear separation.
      surfaceContainerLowest:
      isLight ? Colors.white : const Color(0xFF161B22),
      surfaceContainerLow:
      isLight ? const Color(0xFFFBFCFE) : const Color(0xFF1A2029),
      surfaceContainerHighest:
      isLight ? const Color(0xFFE2E8F2) : const Color(0xFF222A36),
      // Stronger, more visible borders/dividers in light mode.
      outlineVariant:
      isLight ? const Color(0xFFCAD3E0) : const Color(0xFF2A323D),
      onSurfaceVariant:
      isLight ? const Color(0xFF55606E) : const Color(0xFF9AA5B4),
    );

    final base = ThemeData(brightness: brightness);
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700, letterSpacing: -0.2),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
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
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isLight ? 0.5 : 0,
        shadowColor: isLight
            ? const Color(0xFF1E293B).withValues(alpha: 0.10)
            : Colors.transparent,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isLight ? 0.9 : 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? Colors.white
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm + 2),
          borderSide: isLight
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm + 2),
          borderSide: isLight
              ? BorderSide(color: scheme.outlineVariant)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm + 2),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm + 2),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm + 2),
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm + 4)),
          textStyle: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm + 4)),
          textStyle: GoogleFonts.inter(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle:
          GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm)),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle:
        GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        selectedColor: scheme.primary,
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: isLight ? 3 : 0,
        shadowColor: isLight ? Colors.black26 : Colors.transparent,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm + 2)),
        insetPadding: const EdgeInsets.all(16),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  /// Brand gradient used in headers, logos, hero areas.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
