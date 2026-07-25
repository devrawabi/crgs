import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_extensions.dart';
import '../dashboard/route_master_widgets.dart';
import 'app_sidebar.dart';
import 'sidebar_provider.dart';

double _sidebarPanelWidth(double screenWidth) =>
    (screenWidth * 0.82).clamp(260.0, 320.0);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 280),
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncSidebarAnimation(bool open) {
    if (open) {
      HapticFeedback.lightImpact();
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  int _indexFromLocation(String location) {
    if (location.startsWith('/routes')) return 0;
    if (location.startsWith('/tasks')) return 1;
    if (location.startsWith('/orders')) return 2;
    if (location.startsWith('/dashboard')) return 3;
    return -1;
  }

  bool _showDefaultHeader(String location) {
    // Exact tab roots only. Nested pages like /routes/:id own their header;
    // matching with startsWith would stack two headers and feel jumpy.
    return location == RouteNames.routes ||
        location == RouteNames.tasks ||
        location == RouteNames.orders ||
        location == RouteNames.dashboard;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RouteNames.routes);
      case 1:
        context.go(RouteNames.tasks);
      case 2:
        context.go(RouteNames.orders);
      case 3:
        context.go(RouteNames.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sidebarOpenProvider, (previous, next) {
      _syncSidebarAnimation(next);
    });

    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _indexFromLocation(location);
    final showDefaultHeader = _showDefaultHeader(location);
    final sidebarOpen = ref.watch(sidebarOpenProvider);

    const items = [
      (AppIcons.route, 'Routes'),
      (AppIcons.tasks, 'Tasks'),
      (AppIcons.clipboard, 'Activity'),
      (AppIcons.dashboard, 'Dashboard'),
    ];

    return PopScope(
      canPop: !sidebarOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && sidebarOpen) closeSidebar(ref);
      },
      child: Scaffold(
        backgroundColor: AppColors.brand,
        body: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final reduceMotion = MediaQuery.disableAnimationsOf(context);
            final t = reduceMotion
                ? (sidebarOpen ? 1.0 : 0.0)
                : _progress.value;
            final panelWidth = _sidebarPanelWidth(
              MediaQuery.sizeOf(context).width,
            );
            final contentSlide = panelWidth * t;
            final sidebarSlide = -panelWidth * (1 - t);
            final radius = 24.0 * t;
            final dimAlpha = 0.28 * t;
            final blurSigma = 5.0 * t;
            final shadowAlpha = 0.2 * t;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Transform.translate(
                    offset: Offset(sidebarSlide, 0),
                    child: AppSidebarPanel(progress: t, panelWidth: panelWidth),
                  ),
                ),
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(contentSlide, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(radius),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: shadowAlpha),
                            blurRadius: 28,
                            spreadRadius: -4,
                            offset: const Offset(-10, 0),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(radius),
                        ),
                        child: ColoredBox(
                          color: RouteMasterColors.background(context),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: blurSigma,
                                  sigmaY: blurSigma,
                                ),
                                enabled: t > 0.01 && !reduceMotion,
                                child: Column(
                                  children: [
                                    // Collapse/expand instead of hard-removing the
                                    // shell header when opening /routes/:id — that
                                    // instant pop was the visible "jump" on open.
                                    AnimatedSize(
                                      duration: reduceMotion
                                          ? Duration.zero
                                          : const Duration(milliseconds: 220),
                                      curve: Curves.easeOutCubic,
                                      alignment: Alignment.topCenter,
                                      child: showDefaultHeader
                                          ? const DefaultAppHeader()
                                          : const SizedBox(
                                              width: double.infinity,
                                            ),
                                    ),
                                    Expanded(
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned.fill(
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                bottom: mainShellBottomNavInset(
                                                  context,
                                                ),
                                              ),
                                              child: widget.child,
                                            ),
                                          ),
                                          Positioned(
                                            left: 0,
                                            right: 0,
                                            bottom: 0,
                                            child: _MainShellBottomNav(
                                              items: items,
                                              selectedIndex: selectedIndex,
                                              onTap: (index) =>
                                                  _onTap(context, index),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (t > 0.01)
                                Positioned.fill(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => closeSidebar(ref),
                                    onHorizontalDragUpdate: (details) {
                                      if (details.primaryDelta != null &&
                                          details.primaryDelta! > 6) {
                                        closeSidebar(ref);
                                      }
                                    },
                                    child: ColoredBox(
                                      color: Colors.black.withValues(
                                        alpha: dimAlpha,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

double _bottomNavOuterPadding(BuildContext context) {
  final inset = MediaQuery.viewPaddingOf(context).bottom;
  return inset > 0 ? inset : 12;
}

/// Vertical space to reserve above the floating bottom nav in [MainShell].
double mainShellBottomNavInset(BuildContext context) {
  const innerVerticalPadding = 8.0;
  const contentGap = 8.0;
  return _bottomNavContentHeight(context) +
      innerVerticalPadding +
      _bottomNavOuterPadding(context) +
      contentGap;
}

double _bottomNavContentHeight(BuildContext context) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  if (screenHeight < 640) return 52;
  if (screenHeight > 820) return 58;
  return 56;
}

double _bottomNavHorizontalInset(BuildContext context) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  if (screenWidth < 360) return 12;
  return 16;
}

class _MainShellBottomNav extends StatelessWidget {
  const _MainShellBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<(IconData, String)> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final contentHeight = _bottomNavContentHeight(context);
    final horizontalInset = _bottomNavHorizontalInset(context);
    final labelSize = contentHeight <= 52 ? 10.0 : 11.0;
    final iconSizeSelected = contentHeight <= 52 ? 21.0 : 22.0;
    final iconSizeUnselected = contentHeight <= 52 ? 19.0 : 20.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalInset,
        0,
        horizontalInset,
        _bottomNavOuterPadding(context),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: SizedBox(
              height: contentHeight,
              child: Row(
                children: List.generate(items.length, (i) {
                  final selected = selectedIndex >= 0 && i == selectedIndex;
                  final (icon, label) = items[i];
                  final color = selected
                      ? RouteMasterColors.titleBlue
                      : theme.colorScheme.mutedForeground;

                  return Expanded(
                    child: ShadGestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: AnimatedContainer(
                        duration: AppConstants.animationDuration,
                        curve: Curves.easeOutCubic,
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.center,
                        decoration: selected
                            ? BoxDecoration(
                                color: RouteMasterColors.titleBlue.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              )
                            : null,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: selected
                                  ? iconSizeSelected
                                  : iconSizeUnselected,
                              color: color,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              label,
                              style: theme.textTheme.muted.copyWith(
                                fontSize: labelSize,
                                color: color,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
