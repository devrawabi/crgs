import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../dashboard/route_master_widgets.dart';
import 'sidebar_provider.dart';

const _sidebarInset = 16.0;
const _tileGap = 12.0;
const _iconBoxSize = 40.0;

class AppSidebarPanel extends ConsumerWidget {
  const AppSidebarPanel({
    super.key,
    required this.progress,
    this.panelWidth,
  });

  final double progress;
  final double? panelWidth;

  void _navigate(BuildContext context, WidgetRef ref, String route) {
    closeSidebar(ref);
    context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final user = ref.watch(currentUserProvider);
    final location = GoRouterState.of(context).uri.toString();
    final width = panelWidth ?? MediaQuery.sizeOf(context).width * 0.82;
    final resolvedPanelWidth = width.clamp(260.0, 320.0);

    final mainItems = [
      (AppIcons.route, 'Routes', RouteNames.routes, location.startsWith('/routes')),
      (AppIcons.tasks, 'Tasks', RouteNames.tasks, location == RouteNames.tasks),
      (AppIcons.clipboard, 'Activity', RouteNames.orders, location.startsWith('/orders')),
      (AppIcons.dashboard, 'Dashboard', RouteNames.dashboard, location == RouteNames.dashboard),
    ];

    final moreItems = [
      (AppIcons.profile, 'Profile', RouteNames.profile, location == RouteNames.profile),
      (AppIcons.reports, 'Reports', RouteNames.reports, location == RouteNames.reports),
      (AppIcons.wallet, 'Outstanding', RouteNames.outstanding, location == RouteNames.outstanding),
      (AppIcons.event, 'Follow-ups', RouteNames.followUp, location == RouteNames.followUp),
      (AppIcons.settings, 'Settings', RouteNames.settings, location == RouteNames.settings),
    ];

    return SizedBox(
      width: resolvedPanelWidth,
      child: Material(
        color: theme.colorScheme.card,
        elevation: 24,
        shadowColor: AppColors.brand.withValues(alpha: 0.25),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StaggeredEntry(
                progress: progress,
                index: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _sidebarInset,
                    8,
                    8,
                    0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.appShortName,
                              style: theme.textTheme.large.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.brand,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              AppConstants.companyName,
                              style: theme.textTheme.muted.copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => closeSidebar(ref),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          AppIcons.close,
                          size: 20,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _StaggeredEntry(
                progress: progress,
                index: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _sidebarInset,
                    12,
                    _sidebarInset,
                    8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.brand.withValues(alpha: 0.12),
                          AppColors.brandContainer.withValues(alpha: 0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.brand.withValues(alpha: 0.15),
                          child: Text(
                            initialsFromName(user?.name),
                            style: const TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: _tileGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Executive',
                                style: theme.textTheme.large.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (user?.employeeCode != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  user!.employeeCode,
                                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: _sidebarInset),
                  children: [
                    const _SidebarSectionLabel(title: 'MAIN'),
                    for (var i = 0; i < mainItems.length; i++)
                      _StaggeredEntry(
                        progress: progress,
                        index: i + 2,
                        child: _SidebarTile(
                          icon: mainItems[i].$1,
                          label: mainItems[i].$2,
                          selected: mainItems[i].$4,
                          onTap: () => _navigate(context, ref, mainItems[i].$3),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const _SidebarSectionLabel(title: 'MORE'),
                    for (var i = 0; i < moreItems.length; i++)
                      _StaggeredEntry(
                        progress: progress,
                        index: i + 5,
                        child: _SidebarTile(
                          icon: moreItems[i].$1,
                          label: moreItems[i].$2,
                          selected: moreItems[i].$4,
                          onTap: () => _navigate(context, ref, moreItems[i].$3),
                        ),
                      ),
                  ],
                ),
              ),
              _StaggeredEntry(
                progress: progress,
                index: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1, indent: _sidebarInset, endIndent: _sidebarInset),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _sidebarInset,
                        8,
                        _sidebarInset,
                        4,
                      ),
                      child: _SidebarTile(
                        icon: AppIcons.logout,
                        label: 'Logout',
                        destructive: true,
                        onTap: () {
                          closeSidebar(ref);
                          ref.read(authProvider.notifier).logout();
                          context.go(RouteNames.login);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _sidebarInset,
                        0,
                        _sidebarInset,
                        12,
                      ),
                      child: Text(
                        '${AppConstants.appShortName} v${AppConstants.appVersion}',
                        style: theme.textTheme.muted.copyWith(fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondaryLight,
            letterSpacing: 1.1,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _StaggeredEntry extends StatelessWidget {
  const _StaggeredEntry({
    required this.progress,
    required this.index,
    required this.child,
  });

  final double progress;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const stagger = 0.04;
    const window = 0.38;
    final start = index * stagger;
    final local = ((progress - start) / window).clamp(0.0, 1.0);
    final fade = Curves.easeOut.transform(local);
    final motion = Curves.easeOutQuart.transform(local);

    return Opacity(
      opacity: fade,
      child: Transform.translate(
        offset: Offset(-14 * (1 - motion), 0),
        child: child,
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final color = destructive
        ? AppColors.missingRed
        : selected
            ? AppColors.brand
            : theme.colorScheme.foreground;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? AppColors.brand.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: _iconBoxSize,
                  height: _iconBoxSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brand.withValues(alpha: 0.15)
                          : theme.colorScheme.muted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                ),
                const SizedBox(width: _tileGap),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.small.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Legacy drawer wrapper — prefer [AppSidebarPanel] via [MainShell].
class AppSidebarDrawer extends ConsumerWidget {
  const AppSidebarDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppSidebarPanel(progress: 1);
  }
}
