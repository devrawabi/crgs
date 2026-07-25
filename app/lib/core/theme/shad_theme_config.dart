import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'app_colors.dart';

/// shadcn/ui theme — Figtree typography + teal/slate palette.
abstract final class ShadThemeConfig {
  static const radius = 12.0;
  static final borderRadius = BorderRadius.circular(radius);

  static ShadThemeData? _lightCache;
  static ShadThemeData? _darkCache;
  static ShadTextTheme? _textThemeCache;

  static ShadTextTheme get _textTheme =>
      _textThemeCache ??= ShadTextTheme.fromGoogleFont(GoogleFonts.figtree);

  static ShadThemeData light() => _lightCache ??= _build(Brightness.light);

  static ShadThemeData dark() => _darkCache ??= _build(Brightness.dark);

  static ShadThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    return ShadThemeData(
      brightness: brightness,
      colorScheme: isLight
          ? const ShadBlueColorScheme.light(
              background: AppColors.surfaceLight,
              foreground: AppColors.textPrimaryLight,
              card: AppColors.white,
              cardForeground: AppColors.textPrimaryLight,
              primary: AppColors.brand,
              primaryForeground: AppColors.white,
              secondary: AppColors.brandContainer,
              secondaryForeground: AppColors.brandDark,
              muted: AppColors.surfaceContainerLight,
              mutedForeground: AppColors.textSecondaryLight,
              accent: Color(0xFFECFEFF),
              accentForeground: AppColors.brandDark,
              destructive: AppColors.missingRed,
              destructiveForeground: AppColors.white,
              border: AppColors.borderLight,
              input: AppColors.fieldBorder,
              ring: AppColors.brand,
            )
          : const ShadBlueColorScheme.dark(
              background: AppColors.surfaceDark,
              foreground: AppColors.textPrimaryDark,
              card: AppColors.cardDark,
              cardForeground: AppColors.textPrimaryDark,
              primary: AppColors.brandLight,
              primaryForeground: AppColors.white,
              secondary: Color(0xFF134E4A),
              secondaryForeground: AppColors.brandLight,
              muted: Color(0xFF1E293B),
              mutedForeground: AppColors.textSecondaryDark,
              accent: Color(0xFF164E63),
              accentForeground: AppColors.brandLight,
              destructive: AppColors.missingRed,
              border: AppColors.borderDark,
              input: AppColors.borderDark,
              ring: AppColors.brandLight,
            ),
      radius: borderRadius,
      textTheme: _textTheme,
      cardTheme: ShadCardTheme(
        radius: borderRadius,
        padding: const EdgeInsets.all(16),
      ),
    );
  }
}
