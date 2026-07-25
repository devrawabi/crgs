import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Responsive layout helpers for mobile-first design.
abstract final class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppConstants.mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppConstants.mobileBreakpoint &&
        width < AppConstants.tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

  static double contentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppConstants.tabletBreakpoint) return 800;
    if (width >= AppConstants.mobileBreakpoint) return 600;
    return width;
  }

  static int gridCrossAxisCount(BuildContext context, {int mobile = 2, int tablet = 3, int desktop = 4}) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final horizontal = isMobile(context) ? 16.0 : 24.0;
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: 16);
  }
}
