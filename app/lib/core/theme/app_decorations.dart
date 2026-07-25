import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_theme_extensions.dart';

/// Shared gradients, shadows, and decorative surfaces for the app UI.
abstract final class AppDecorations {
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 24.0;
  static const radiusPill = 999.0;

  static const loginGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.brandDark,
      AppColors.brand,
      AppColors.brandLight,
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF8FAFC),
      Color(0xFFF1F5F9),
      Color(0xFFEFF6FF),
    ],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.brandDark,
      AppColors.brand,
      AppColors.brandLight,
    ],
  );

  static const cardSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8FAFC),
    ],
  );

  static List<BoxShadow> cardShadow(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> elevatedShadow(Color tint) => [
        BoxShadow(
          color: tint.withValues(alpha: 0.18),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> navShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 20,
      offset: const Offset(0, -4),
    ),
  ];
}

/// Page background with a flat gradient.
class AppMeshBackground extends StatelessWidget {
  const AppMeshBackground({
    super.key,
    required this.child,
    this.gradient = AppDecorations.pageGradient,
  });

  final Widget child;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final gradient = context.pageBackgroundGradient;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
        child,
      ],
    );
  }
}

/// Elevated surface card with optional accent strip.
class AccentSurface extends StatelessWidget {
  const AccentSurface({
    super.key,
    required this.child,
    this.accentColor,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = AppDecorations.radiusLg,
  });

  final Widget child;
  final Color? accentColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primaryBlue;
    final cardColor = context.surfaceCard;
    final borderColor = context.surfaceBorder;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: cardColor,
        border: Border.all(color: borderColor),
        boxShadow: AppDecorations.cardShadow(accent),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            if (accentColor != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: accent),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
