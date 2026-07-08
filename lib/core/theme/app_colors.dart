import 'package:flutter/material.dart';

/// UjustBUY colour tokens.
///
/// Single source of truth for every colour in the app. Derived from the brand
/// primary **#8E153E** (deep rose / burgundy). All other systems
/// (`AppTheme`, widgets, screens) read from here — never hardcode a hex value
/// in a screen.
///
/// Usage follows the 60-30-10 rule:
///   • 60% neutral surfaces  (background / cards)
///   • 30% supporting greys & text
///   • 10% brand primary     (calls to action, accents)
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // PRIMARY — brand burgundy tonal scale (50 lightest → 900 darkest)
  // ---------------------------------------------------------------------------
  static const Color primary50 = Color(0xFFFBEAF0);
  static const Color primary100 = Color(0xFFF6D2DE);
  static const Color primary200 = Color(0xFFECA6BD);
  static const Color primary300 = Color(0xFFDE7596);
  static const Color primary400 = Color(0xFFC44A72);
  static const Color primary500 = Color(0xFF8E153E); // brand base
  static const Color primary600 = Color(0xFF7F1F40);
  static const Color primary700 = Color(0xFF6A1936);
  static const Color primary800 = Color(0xFF54142B);
  static const Color primary900 = Color(0xFF3D0E20);

  /// Canonical brand colour alias.
  static const Color primary = primary500;

  // ---------------------------------------------------------------------------
  // SECONDARY / TERTIARY — supporting accents that complement burgundy
  // ---------------------------------------------------------------------------
  static const Color secondary = Color(0xFFC75B7A); // muted rose
  static const Color tertiary = Color(0xFFC8973F); // warm gold (ratings)

  // ---------------------------------------------------------------------------
  // NEUTRAL / GREY scale
  // ---------------------------------------------------------------------------
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF8F9FA);
  static const Color neutral100 = Color(0xFFF1F3F5);
  static const Color neutral200 = Color(0xFFE9ECEF);
  static const Color neutral300 = Color(0xFFDEE2E6);
  static const Color neutral400 = Color(0xFFCED4DA);
  static const Color neutral500 = Color(0xFFADB5BD);
  static const Color neutral600 = Color(0xFF868E96);
  static const Color neutral700 = Color(0xFF495057);
  static const Color neutral800 = Color(0xFF343A40);
  static const Color neutral900 = Color(0xFF212529);

  // ---------------------------------------------------------------------------
  // SEMANTIC — always paired with an icon/label, never colour-only
  // ---------------------------------------------------------------------------
  static const Color success = Color(0xFF1B873F);
  static const Color successContainer = Color(0xFFE6F4EA);
  static const Color onSuccessContainer = Color(0xFF0B521F);

  static const Color warning = Color(0xFFB7791F);
  static const Color warningContainer = Color(0xFFFBF0DA);
  static const Color onWarningContainer = Color(0xFF6B4A0F);

  static const Color error = Color(0xFFC5283D);
  static const Color errorContainer = Color(0xFFFBE5E8);
  static const Color onErrorContainer = Color(0xFF7A0F1C);

  static const Color info = Color(0xFF2563EB);
  static const Color infoContainer = Color(0xFFE4ECFD);
  static const Color onInfoContainer = Color(0xFF15356E);

  // ---------------------------------------------------------------------------
  // SURFACES — light mode
  // ---------------------------------------------------------------------------
  /// App page background (the "60%").
  static const Color background = Color(0xFFF6F3F5);

  /// Default card / sheet surface (the "30%").
  static const Color surface = neutral0;

  /// Slightly raised surface (menus, elevated cards).
  static const Color surfaceElevated = neutral0;

  /// Low-emphasis filled surface (chips, skeletons, input fill at rest).
  static const Color surfaceMuted = Color(0xFFF0EBEE);

  /// Hairline dividers / card borders.
  static const Color divider = Color(0xFFE2DADF);

  /// Resting border for inputs / outlined cards.
  static const Color border = Color(0xFFCFC3CA);

  // ---------------------------------------------------------------------------
  // SURFACES — dark mode (warm greys, never pure black)
  // ---------------------------------------------------------------------------
  static const Color backgroundDark = Color(0xFF120F11);
  static const Color surfaceDark = Color(0xFF1D191C);
  static const Color surfaceElevatedDark = Color(0xFF272126);
  static const Color surfaceMutedDark = Color(0xFF332B31);
  static const Color dividerDark = Color(0xFF4A4047);
  static const Color borderDark = Color(0xFF5B4E57);

  // ---------------------------------------------------------------------------
  // TEXT
  // ---------------------------------------------------------------------------
  static const Color textPrimary = Color(0xFF1C1A1B);
  static const Color textSecondary = Color(0xFF595157);
  static const Color textHint = Color(0xFF776E74);
  static const Color textDisabled = Color(0xFFBDB5BA);

  /// Text/icon colour on top of the brand primary.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Text/icon colour on dark surfaces.
  static const Color onDark = Color(0xFFECE3E7);

  // Dark-mode text
  static const Color textPrimaryDark = Color(0xFFFFF4F8);
  static const Color textSecondaryDark = Color(0xFFF2C9D8);
  static const Color textHintDark = Color(0xFFDFA9BD);

  // ---------------------------------------------------------------------------
  // GRADIENTS
  // ---------------------------------------------------------------------------
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary500, Color(0xFFB84A6E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradientDeep = LinearGradient(
    colors: [primary700, primary500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Readable foreground colour for a known semantic container.
  static Color onContainerFor(Color container) {
    if (container == successContainer) return onSuccessContainer;
    if (container == warningContainer) return onWarningContainer;
    if (container == errorContainer) return onErrorContainer;
    if (container == infoContainer) return onInfoContainer;
    if (container == primary50 || container == primary100) return primary800;
    return ThemeData.estimateBrightnessForColor(container) == Brightness.dark
        ? neutral0
        : neutral900;
  }
}
