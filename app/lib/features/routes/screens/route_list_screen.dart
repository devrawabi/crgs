import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/routes_repository.dart';
import '../../../shared/widgets/shad/shad_components.dart';
import '../../customers/providers/customer_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../providers/route_provider.dart';

class RouteListScreen extends ConsumerWidget {
  const RouteListScreen({super.key});

  void _openRouteCustomers(
    WidgetRef ref,
    BuildContext context,
    String routeId,
  ) {
    // Stamp the filter before navigation so CustomerListScreen never mounts
    // against an empty/stale routeId (avoids open flash + initState writes).
    ref.read(customerFilterProvider.notifier).state = const CustomerFilter()
        .copyWith(routeId: routeId);
    context.push(RouteNames.routeCustomersPath(routeId));
  }

  void _openOthersCustomers(BuildContext context) {
    context.push(RouteNames.othersCustomers);
  }

  /// Open (non-completed) task counts keyed by normalized route number.
  ///
  /// Oracle `CRGS_TASK.ROUTE` often stores multiple routes as `25,46,58,18`.
  Map<String, int> _openTaskCountsByRoute(List<TaskModel> tasks) {
    final counts = <String, int>{};
    for (final task in tasks) {
      if (task.status == TaskStatus.completed) continue;
      if (task.taskTypeCode == 'other_route') continue;
      for (final routeNo in parseRouteNos(task.routeId ?? '')) {
        counts[routeNo] = (counts[routeNo] ?? 0) + 1;
      }
    }
    return counts;
  }

  int _openOtherRouteTaskCount(List<TaskModel> tasks) {
    var count = 0;
    for (final task in tasks) {
      if (task.status == TaskStatus.completed) continue;
      if (task.taskTypeCode == 'other_route') count += 1;
    }
    return count;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(assignedRoutesProvider);
    final tasks = ref.watch(tasksProvider).tasks;
    final openTaskCounts = _openTaskCountsByRoute(tasks);
    final othersTaskCount = _openOtherRouteTaskCount(tasks);

    return ShadPageScaffold(
      showHeader: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(title: 'My Routes'),
          const SizedBox(height: 8),
          Expanded(
            child: routesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.missingRed),
                  ),
                ),
              ),
              data: (routes) {
                if (routes.isEmpty && othersTaskCount == 0) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No routes assigned to your account.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // Routes with open tasks first (most tasks on top), then the rest.
                final sortedRoutes = [...routes]..sort((a, b) {
                  final aCount =
                      openTaskCounts[normalizeRouteNo(a.routeNumber)] ?? 0;
                  final bCount =
                      openTaskCounts[normalizeRouteNo(b.routeNumber)] ?? 0;
                  final byTasks = bCount.compareTo(aCount);
                  if (byTasks != 0) return byTasks;
                  return a.name.compareTo(b.name);
                });

                final showOthers = othersTaskCount > 0;
                final itemCount =
                    sortedRoutes.length + (showOthers ? 1 : 0);

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: itemCount,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, index) {
                    if (showOthers && index == 0) {
                      return _OthersRouteCard(
                        openTaskCount: othersTaskCount,
                        onOpen: () => _openOthersCustomers(context),
                      );
                    }
                    final routeIndex = showOthers ? index - 1 : index;
                    final route = sortedRoutes[routeIndex];
                    final taskCount =
                        openTaskCounts[normalizeRouteNo(route.routeNumber)] ??
                            0;
                    return _RouteCard(
                      route: route,
                      openTaskCount: taskCount,
                      onOpen: () =>
                          _openRouteCustomers(ref, context, route.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.onOpen,
    this.openTaskCount = 0,
  });

  final RouteModel route;
  final VoidCallback onOpen;
  final int openTaskCount;

  bool get _hasTasks => openTaskCount > 0;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
            boxShadow: AppDecorations.cardShadow(theme.colorScheme.primary),
            border: _hasTasks
                ? Border.all(
                    color: AppColors.accent.withValues(alpha: 0.85),
                    width: 2,
                  )
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
            child: SizedBox(
              height: 176,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    route.imageAsset,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: 800,
                    cacheHeight: 352,
                    errorBuilder: (_, _, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.brandContainer,
                            AppColors.brand.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          AppIcons.route,
                          size: 48,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.82),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(
                              AppDecorations.radiusPill,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'ID ${route.routeNumber}',
                            style: theme.textTheme.small.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        if (_hasTasks) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(
                                AppDecorations.radiusPill,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  AppIcons.tasks,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  openTaskCount == 1
                                      ? '1 Task'
                                      : '$openTaskCount Tasks',
                                  style: theme.textTheme.small.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        AppIcons.chevronRight,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: 18,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: theme.textTheme.h3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              AppIcons.mapPin,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Route ID: ${route.routeNumber}',
                                style: theme.textTheme.muted.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OthersRouteCard extends StatelessWidget {
  const _OthersRouteCard({
    required this.openTaskCount,
    required this.onOpen,
  });

  final int openTaskCount;
  final VoidCallback onOpen;

  static const _imageAsset = 'assets/images/routes/route_abu_hamur.jpg';

  bool get _hasTasks => openTaskCount > 0;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
            boxShadow: AppDecorations.cardShadow(theme.colorScheme.primary),
            border: _hasTasks
                ? Border.all(
                    color: AppColors.accent.withValues(alpha: 0.85),
                    width: 2,
                  )
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
            child: SizedBox(
              height: 176,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _imageAsset,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: 800,
                    cacheHeight: 352,
                    errorBuilder: (_, _, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.brandContainer,
                            AppColors.brand.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          AppIcons.route,
                          size: 48,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.82),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(
                              AppDecorations.radiusPill,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'OTHERS',
                            style: theme.textTheme.small.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        if (_hasTasks) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(
                                AppDecorations.radiusPill,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  AppIcons.tasks,
                                  size: 13,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  openTaskCount == 1
                                      ? '1 Task'
                                      : '$openTaskCount Tasks',
                                  style: theme.textTheme.small.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        AppIcons.chevronRight,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: 18,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Others',
                          style: theme.textTheme.h3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              AppIcons.mapPin,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Other-route assigned customers',
                                style: theme.textTheme.muted.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
