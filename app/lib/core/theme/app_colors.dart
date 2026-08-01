import 'package:flutter/material.dart';

/// Balanced palette — calm teal primary, neutral surfaces, clear status colors.
abstract final class AppColors {
  // Primary brand (teal — readable, professional, easy on the eyes)
  static const Color brand = Color(0xFF0F766E);
  static const Color brandLight = Color(0xFF14B8A6);
  static const Color brandDark = Color(0xFF0D5C56);
  static const Color brandContainer = Color(0xFFCCFBF1);
  static const Color onBrandContainer = Color(0xFF134E4A);

  // Warm accent — login hero & primary CTAs only
  static const Color accent = Color(0xFFEA580C);
  static const Color accentLight = Color(0xFFFB923C);
  static const Color accentDark = Color(0xFFC2410C);

  /// Legacy aliases used across the app.
  static const Color primaryBlue = brand;
  static const Color primaryBlueLight = brandLight;
  static const Color primaryBlueDark = brandDark;
  static const Color primaryBlueContainer = brandContainer;
  static const Color onPrimaryBlueContainer = onBrandContainer;

  // Success Green
  static const Color successGreen = Color(0xFF16A34A);
  static const Color successGreenLight = Color(0xFF4ADE80);
  static const Color successGreenDark = Color(0xFF15803D);
  static const Color successGreenContainer = Color(0xFFDCFCE7);
  static const Color onSuccessGreenContainer = Color(0xFF14532D);

  // Own products (indigo — distinct from brand teal / promo green / replace orange)
  static const Color ownProduct = Color(0xFF4F46E5);
  static const Color ownProductLight = Color(0xFF6366F1);
  static const Color ownProductDark = Color(0xFF3730A3);
  static const Color ownProductContainer = Color(0xFFE0E7FF);
  static const Color onOwnProductContainer = Color(0xFF312E81);

  // Priority / Status
  static const Color missingRed = Color(0xFFDC2626);
  static const Color outstandingOrange = Color(0xFFEA580C);
  static const Color followUpBlue = Color(0xFF0D9488);
  static const Color regularGreen = Color(0xFF22C55E);

  // Neutrals — Light (cool slate, low eye strain)
  static const Color white = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceContainerLight = Color(0xFFF1F5F9);
  static const Color surfaceContainerHighLight = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color outlineVariantLight = Color(0xFFCBD5E1);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color fieldBorder = Color(0xFFE2E8F0);
  static const Color fieldHint = Color(0xFF94A3B8);
  static const Color fieldLabel = Color(0xFF334155);

  // Neutrals — Dark
  static const Color surfaceDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Offline indicator
  static const Color offlineAmber = Color(0xFFF59E0B);
  static const Color onlineGreen = Color(0xFF22C55E);

  /// Material 3 light color scheme.
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: brand,
    onPrimary: white,
    primaryContainer: brandContainer,
    onPrimaryContainer: onBrandContainer,
    secondary: successGreen,
    onSecondary: white,
    secondaryContainer: successGreenContainer,
    onSecondaryContainer: onSuccessGreenContainer,
    tertiary: accent,
    onTertiary: white,
    tertiaryContainer: Color(0xFFFFEDD5),
    onTertiaryContainer: Color(0xFF9A3412),
    error: missingRed,
    onError: white,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: white,
    onSurface: textPrimaryLight,
    onSurfaceVariant: textSecondaryLight,
    outline: borderLight,
    outlineVariant: outlineVariantLight,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: textPrimaryLight,
    onInverseSurface: white,
    inversePrimary: brandLight,
    surfaceTint: brand,
    surfaceContainerHighest: surfaceContainerHighLight,
    surfaceContainerHigh: surfaceContainerLight,
    surfaceContainer: Color(0xFFF1F5F9),
    surfaceContainerLow: surfaceLight,
    surfaceContainerLowest: white,
  );
}
