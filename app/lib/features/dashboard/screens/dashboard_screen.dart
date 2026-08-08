import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../../shared/widgets/dashboard/route_master_widgets.dart';
import '../../../core/theme/app_theme_extensions.dart';
import '../../../shared/widgets/shad/shad_components.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/targets_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final user = ref.watch(currentUserProvider);
    final tasks = ref.watch(tasksProvider).tasks;
    final firstName = user?.name.split(' ').first ?? 'Executive';
    final pendingTasks =
        tasks.where((t) => t.status != TaskStatus.completed).length;
    final targets = ref.watch(executiveTargetsProvider).valueOrNull;
    final todayLabel = DateFormat('EEEE, d MMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: RouteMasterColors.background(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.newCustomer),
        backgroundColor: RouteMasterColors.titleBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(AppIcons.add, color: Colors.white),
        label: const Text(
          'New Lead',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(executiveTargetsProvider);
                await ref.read(executiveTargetsProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _DashboardPageHeader(subtitle: todayLabel),
                  const SizedBox(height: 8),
                  _DashboardHeroCard(
                    name: firstName,
                    monthlyPercent: summary.monthlyTargetPercent,
                    routePerformance: summary.routePerformance,
                    pendingTasks: pendingTasks,
                    todaysTasks: summary.todaysTasks,
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Overview'),
                  _DashboardStatsGrid(
                    summary: summary,
                    targets: targets,
                    totalTasks: tasks.length,
                    pendingTasks: pendingTasks,
                    onSalesTap: () => context.push(RouteNames.reports),
                    onProductTap: () => context.push(RouteNames.reports),
                    onTasksTap: () => context.go(RouteNames.tasks),
                    onCustomerTap: () => context.push(RouteNames.reports),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: "Today's Route"),
                  const TodaysRouteMap(),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Weekly Performance'),
                  RoutePerformancePanel(
                    values: const [55, 62, 58, 70, 88, 45],
                    highlightIndex: 4,
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Up Next'),
                  NextVisitCard(
                    minutes: 15,
                    customerName: 'SuperMart Downtown',
                    onTap: () => context.push('${RouteNames.visit}/c4'),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Quick Actions'),
                  _DashboardQuickActions(
                    onRoutes: () => context.go(RouteNames.routes),
                    onTasks: () => context.go(RouteNames.tasks),
                    onOutstanding: () => context.push(RouteNames.outstanding),
                    onReports: () => context.push(RouteNames.reports),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPageHeader extends StatelessWidget {
  const _DashboardPageHeader({required this.subtitle});

  static const _avatarAsset = 'assets/images/avatar-dashboard-card.png';

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        PageHeading(
          title: 'Dashboard',
          subtitle: subtitle,
          padding: const EdgeInsets.fromLTRB(0, 8, 68, 4),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Image.asset(
            _avatarAsset,
            height: 72,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            cacheHeight: 144,
          ),
        ),
      ],
    );
  }
}

class _DashboardHeroCard extends StatelessWidget {
  const _DashboardHeroCard({
    required this.name,
    required this.monthlyPercent,
    required this.routePerformance,
    required this.pendingTasks,
    required this.todaysTasks,
  });

  final String name;
  final double monthlyPercent;
  final double routePerformance;
  final int pendingTasks;
  final int todaysTasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppDecorations.heroGradient,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        boxShadow: AppDecorations.elevatedShadow(AppColors.brand),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, $name',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppConstants.appShortName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroMetric(
                label: 'Monthly',
                value: '${monthlyPercent.toStringAsFixed(0)}%',
              ),
              _HeroMetric(
                label: 'Route Score',
                value: '${routePerformance.toStringAsFixed(0)}%',
              ),
              _HeroMetric(
                label: 'Tasks',
                value: '$pendingTasks/$todaysTasks',
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDecorations.radiusPill),
            child: LinearProgressIndicator(
              value: (monthlyPercent.clamp(0, 100) / 100).toDouble(),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Monthly target progress',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatsGrid extends StatelessWidget {
  const _DashboardStatsGrid({
    required this.summary,
    required this.targets,
    required this.totalTasks,
    required this.pendingTasks,
    required this.onSalesTap,
    required this.onProductTap,
    required this.onTasksTap,
    required this.onCustomerTap,
  });

  final DashboardSummary summary;
  final ExecutiveTargetsData? targets;
  final int totalTasks;
  final int pendingTasks;
  final VoidCallback onSalesTap;
  final VoidCallback onProductTap;
  final VoidCallback onTasksTap;
  final VoidCallback onCustomerTap;

  @override
  Widget build(BuildContext context) {
    final sales = _resolveSalesTarget(targets, summary);
    final salesPercent = sales.percent;
    final salesAchieved = sales.achieved;
    final salesTarget = sales.target;

    final productTarget = targets?.productTargets.fold<double>(
          0,
          (sum, item) => sum + item.targetValue,
        ) ??
        0;
    final productAchieved = targets?.productTargets.fold<double>(
          0,
          (sum, item) => sum + item.achievedValue,
        ) ??
        0;
    final productPercent =
        productTarget > 0 ? ((productAchieved / productTarget) * 100) : 0.0;

    final customerProgress = _resolveCustomerTarget(targets);
    final customerTarget = customerProgress.target;
    final customerAchieved = customerProgress.achieved;
    final customerPercent = customerProgress.percent;

    final completedTasks = (totalTasks - pendingTasks).clamp(0, totalTasks);
    final tasksPercent =
        totalTasks > 0 ? ((completedTasks / totalTasks) * 100) : 0.0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: [
        _OverviewChartCard(
          title: 'Sales Target',
          value: '${salesPercent.toStringAsFixed(0)}%',
          subtitle:
              '${CurrencyFormatter.compact(salesAchieved)} of ${CurrencyFormatter.compact(salesTarget)}',
          detailLabel: sales.label,
          progress: (salesPercent / 100).clamp(0.0, 1.0),
          color: RouteMasterColors.titleBlue,
          icon: AppIcons.trend,
          onTap: onSalesTap,
        ),
        _OverviewChartCard(
          title: 'Product Target',
          value: '${productPercent.toStringAsFixed(0)}%',
          subtitle:
              '${_formatCount(productAchieved)} of ${_formatCount(productTarget)}',
          progress: (productPercent / 100).clamp(0.0, 1.0),
          color: AppColors.missingRed,
          icon: AppIcons.bag,
          onTap: onProductTap,
        ),
        _OverviewChartCard(
          title: 'Tasks Done',
          value: '$completedTasks/$totalTasks',
          subtitle: '$pendingTasks pending',
          progress: (tasksPercent / 100).clamp(0.0, 1.0),
          color: AppColors.outstandingOrange,
          icon: AppIcons.tasks,
          onTap: onTasksTap,
        ),
        _OverviewChartCard(
          title: 'Customer Target',
          value: '${customerPercent.toStringAsFixed(0)}%',
          subtitle:
              '${_formatCount(customerAchieved)} of ${_formatCount(customerTarget)}',
          detailLabel: customerProgress.label,
          progress: (customerPercent / 100).clamp(0.0, 1.0),
          color: AppColors.followUpBlue,
          icon: AppIcons.customers,
          onTap: onCustomerTap,
        ),
      ],
    );
  }

  /// Target = set new_acquisition count; achieved = total add customers (FLAG=N).
  static ({double percent, double achieved, double target, String label})
      _resolveCustomerTarget(ExecutiveTargetsData? targets) {
    final newAcquisition = targets?.newAcquisitionTargets ?? const [];

    if (newAcquisition.isNotEmpty) {
      final daily =
          newAcquisition.where((t) => t.period == TargetPeriod.daily).toList();
      final active = daily.isNotEmpty ? daily : newAcquisition;
      final target =
          active.fold<double>(0, (sum, item) => sum + item.targetCount);
      // Achieved = total add customers in CONTACTINFO with FLAG = N.
      final achieved = (targets?.newCustomersFlagN ?? 0).toDouble();
      final percent = target > 0 ? ((achieved / target) * 100) : 0.0;

      return (
        percent: percent,
        achieved: achieved,
        target: target,
        label: 'New',
      );
    }

    final scoped = targets?.customerByPeriod ?? const <CustomerTargetModel>[];
    final daily = scoped.where((t) => t.period == TargetPeriod.daily).toList();
    final active = daily.isNotEmpty ? daily : scoped;
    final target =
        active.fold<double>(0, (sum, item) => sum + item.targetCount);
    final achieved =
        active.fold<double>(0, (sum, item) => sum + item.achievedCount);
    final percent = target > 0 ? ((achieved / target) * 100) : 0.0;

    return (
      percent: percent,
      achieved: achieved,
      target: target,
      label: 'Set',
    );
  }

  static ({double percent, double achieved, double target, String label})
      _resolveSalesTarget(
    ExecutiveTargetsData? targets,
    DashboardSummary summary,
  ) {
    final daily = targets?.salesFor(TargetPeriod.daily);
    if (daily != null && daily.target > 0) {
      return (
        percent: daily.percent,
        achieved: daily.achieved,
        target: daily.target,
        label: 'Daily',
      );
    }

    final monthly = targets?.salesFor(TargetPeriod.monthly);
    if (monthly != null && monthly.target > 0) {
      return (
        percent: monthly.percent,
        achieved: monthly.achieved,
        target: monthly.target,
        label: 'Monthly',
      );
    }

    return (
      percent: summary.dailySalesTargetPercent,
      achieved: summary.dailyAchievedAmount,
      target: summary.dailyTargetAmount,
      label: 'Daily',
    );
  }

  static String _formatCount(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _OverviewChartCard extends StatelessWidget {
  const _OverviewChartCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress,
    required this.color,
    required this.icon,
    this.detailLabel,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final String? detailLabel;
  final double progress;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final trackColor = RouteMasterColors.border(context).withValues(alpha: 0.55);
    final filled = progress.clamp(0.0, 1.0);

    return Material(
      color: RouteMasterColors.card(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: RouteMasterColors.card(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: RouteMasterColors.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: context.isDarkTheme ? 0.24 : 0.04,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (detailLabel != null)
                      Text(
                        detailLabel!,
                        style: theme.textTheme.muted.copyWith(fontSize: 10),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Center(
                    child: SizedBox(
                      width: 78,
                      height: 78,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              value: filled,
                              strokeWidth: 8,
                              backgroundColor: trackColor,
                              color: color,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            value,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.h3.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: value.length > 5 ? 15 : 18,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.muted.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardQuickActions extends StatelessWidget {
  const _DashboardQuickActions({
    required this.onRoutes,
    required this.onTasks,
    required this.onOutstanding,
    required this.onReports,
  });

  final VoidCallback onRoutes;
  final VoidCallback onTasks;
  final VoidCallback onOutstanding;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final actions = [
      (AppIcons.route, 'Routes', onRoutes, AppColors.brand),
      (AppIcons.tasks, 'Tasks', onTasks, AppColors.followUpBlue),
      (AppIcons.wallet, 'Outstanding', onOutstanding, AppColors.outstandingOrange),
      (AppIcons.reports, 'Reports', onReports, AppColors.brandDark),
    ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < actions.length - 1 ? 8 : 0),
              child: Material(
                color: RouteMasterColors.card(context),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: actions[i].$3,
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: RouteMasterColors.card(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: RouteMasterColors.border(context)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: actions[i].$4.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(actions[i].$1, color: actions[i].$4, size: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            actions[i].$2,
                            style: theme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
