import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'app_colors.dart';
import 'app_decorations.dart';

/// Theme-aware colors and decorations for screens that predate full shadcn adoption.
extension AppThemeContext on BuildContext {
  ShadThemeData get shadTheme => ShadTheme.of(this);
  ShadColorScheme get appColors => shadTheme.colorScheme;
  bool get isDarkTheme => shadTheme.brightness == Brightness.dark;

  Color get surfaceBackground => appColors.background;
  Color get surfaceCard => appColors.card;
  Color get surfaceBorder => appColors.border;
  Color get surfaceMuted => appColors.muted;

  Gradient get pageBackgroundGradient => isDarkTheme
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surfaceDark,
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        )
      : AppDecorations.pageGradient;
}

/// Route Master palette — brand accents plus theme-aware surfaces.
abstract final class RouteMasterColors {
  static Color background(BuildContext context) =>
      context.surfaceBackground;

  static Color card(BuildContext context) => context.surfaceCard;

  static Color border(BuildContext context) => context.surfaceBorder;

  static const titleBlue = AppColors.brand;
  static const mapRoute = AppColors.brand;
  static const monthlyBar = AppColors.brandDark;
  static const nextVisitBlue = AppColors.brand;
  static const chartLight = Color(0xFF99F6E4);
  static const chartHighlight = AppColors.brand;

  static Color mapSurface(BuildContext context) => context.isDarkTheme
      ? const Color(0xFF134E4A)
      : const Color(0xFFECFEFF);

  static Color onTrackGreen(BuildContext context) => context.isDarkTheme
      ? const Color(0xFF14532D)
      : const Color(0xFFDCFCE7);

  static Color onTrackText(BuildContext context) => context.isDarkTheme
      ? const Color(0xFFBBF7D0)
      : const Color(0xFF166534);
}
