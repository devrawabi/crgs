import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/badges/priority_badge.dart';
import '../../../core/theme/app_theme_extensions.dart';
import '../../../shared/widgets/shad/shad_components.dart';
import '../../dashboard/providers/targets_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../utils/task_target_progress.dart';
import '../widgets/work_report_sheet.dart';

enum _TaskTab { all, completed }

class TaskManagementScreen extends ConsumerStatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  ConsumerState<TaskManagementScreen> createState() =>
      _TaskManagementScreenState();
}

class _TaskManagementScreenState extends ConsumerState<TaskManagementScreen> {
  _TaskTab _selectedTab = _TaskTab.all;

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksProvider);
    final tasks = tasksState.tasks;
    final activeTasks =
        tasks.where((t) => t.status != TaskStatus.completed).toList();
    final completedTasks =
        tasks.where((t) => t.status == TaskStatus.completed).toList();

    return Scaffold(
      backgroundColor: RouteMasterColors.background(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showWorkReportSheet(context),
        icon: const Icon(AppIcons.report, size: 18),
        label: const Text('Report Work'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeading(
            title: 'Task Management',
            subtitle: tasksState.isLoading
                ? 'Loading tasks...'
                : '${activeTasks.length} pending tasks',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _TaskTabBar(
              selected: _selectedTab,
              onSelected: (tab) => setState(() => _selectedTab = tab),
              allCount: activeTasks.length,
              completedCount: completedTasks.length,
            ),
          ),
          Expanded(
            child: _buildBody(
              tasksState: tasksState,
              activeTasks: activeTasks,
              completedTasks: completedTasks,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required TasksState tasksState,
    required List<TaskModel> activeTasks,
    required List<TaskModel> completedTasks,
  }) {
    if (tasksState.isLoading &&
        activeTasks.isEmpty &&
        completedTasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tasksState.error != null &&
        activeTasks.isEmpty &&
        completedTasks.isEmpty) {
      return _TaskErrorState(
        message: tasksState.error!,
        onRetry: () => ref.read(tasksProvider.notifier).load(),
      );
    }

    final content = switch (_selectedTab) {
      _TaskTab.all => _TaskListView(
          emptyMessage: 'No pending tasks',
          hasMore: tasksState.hasMore,
          isLoadingMore: tasksState.isLoadingMore,
          onLoadMore: () => ref.read(tasksProvider.notifier).loadMore(),
          children: activeTasks
              .map((task) => _TaskCard(task: task, ref: ref))
              .toList(),
        ),
      _TaskTab.completed => _TaskListView(
          emptyMessage: 'No completed tasks yet',
          hasMore: tasksState.hasMore,
          isLoadingMore: tasksState.isLoadingMore,
          onLoadMore: () => ref.read(tasksProvider.notifier).loadMore(),
          children: completedTasks
              .map((task) => _TaskCard(task: task, ref: ref))
              .toList(),
        ),
    };

    return RefreshIndicator(
      onRefresh: () => ref.read(tasksProvider.notifier).load(),
      child: content,
    );
  }
}

class _TaskErrorState extends StatelessWidget {
  const _TaskErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.tasks,
              size: 40,
              color: theme.colorScheme.mutedForeground.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load tasks',
              style: theme.textTheme.large.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: theme.textTheme.muted.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ShadButton.outline(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTabBar extends StatelessWidget {
  const _TaskTabBar({
    required this.selected,
    required this.onSelected,
    required this.allCount,
    required this.completedCount,
  });

  final _TaskTab selected;
  final ValueChanged<_TaskTab> onSelected;
  final int allCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final tabs = [
      (_TaskTab.all, 'All Tasks ($allCount)'),
      (_TaskTab.completed, 'Completed ($completedCount)'),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final (tab, label) in tabs)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _TaskTabChip(
                    label: label,
                    selected: selected == tab,
                    onTap: () => onSelected(tab),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskTabChip extends StatelessWidget {
  const _TaskTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Material(
      color: selected ? theme.colorScheme.background : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.small.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? theme.colorScheme.foreground
                    : theme.colorScheme.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskListView extends StatelessWidget {
  const _TaskListView({
    required this.children,
    required this.emptyMessage,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
  });

  final List<Widget> children;
  final String emptyMessage;
  final bool hasMore;
  final bool isLoadingMore;
  final Future<void> Function()? onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty && !hasMore) {
      return _EmptyTabState(message: emptyMessage);
    }

    final showFooter = hasMore || isLoadingMore;
    final itemCount = children.length + (showFooter ? 1 : 0);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index < children.length) return children[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: isLoadingMore
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: onLoadMore == null
                        ? null
                        : () => onLoadMore!(),
                    child: const Text('Load more tasks'),
                  ),
          ),
        );
      },
    );
  }
}

class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return SizedBox.expand(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.tasks,
                size: 40,
                color: theme.colorScheme.mutedForeground.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.muted.copyWith(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, required this.ref});

  final TaskModel task;
  final WidgetRef ref;

  Color get _priorityColor => switch (task.priority) {
        TaskPriority.urgent => AppColors.missingRed,
        TaskPriority.high => AppColors.outstandingOrange,
        TaskPriority.medium => AppColors.followUpBlue,
        TaskPriority.low => AppColors.regularGreen,
      };

  Color get _statusColor => switch (task.status) {
        TaskStatus.completed => AppColors.successGreen,
        TaskStatus.inProgress => AppColors.primaryBlue,
        TaskStatus.pending => AppColors.textSecondaryLight,
      };

  (IconData, Color, Color) get _typeVisuals => task.type == TaskType.additionalTask
      ? (AppIcons.event, AppColors.followUpBlue, AppColors.followUpBlue.withValues(alpha: 0.12))
      : (AppIcons.route, AppColors.brand, AppColors.brand.withValues(alpha: 0.12));

  String get _typeLabel => task.type == TaskType.additionalTask
      ? 'Additional Task'
      : 'Route Task';

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final theme = ShadTheme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');
    final (typeIcon, typeColor, typeBg) = _typeVisuals;
    final targetsAsync = ref.watch(executiveTargetsProvider);
    final targetProgress = targetsAsync.maybeWhen(
      data: (targets) =>
          resolveTaskTargetProgress(task: task, targets: targets),
      orElse: () => null,
    );

    final card = Container(
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.large.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.25,
                        ),
                      ),
                      if (task.customerName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            task.customerName!,
                            if (task.routeName != null) task.routeName!,
                          ].join(' · '),
                          style: theme.textTheme.muted.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StatusBadge(label: _typeLabel, color: typeColor),
                          if (task.type == TaskType.routeTask &&
                              task.routeName != null)
                            StatusBadge(
                              label: task.routeName!,
                              color: AppColors.brandDark,
                            ),
                          StatusBadge(
                            label: task.priority.name,
                            color: _priorityColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: _formatStatus(task.status),
                  color: _statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.description,
              style: theme.textTheme.muted.copyWith(
                fontSize: 13,
                height: 1.45,
              ),
            ),
            if (targetProgress != null) ...[
              const SizedBox(height: 12),
              _TaskTargetProgressCard(progress: targetProgress),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: theme.colorScheme.border),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  AppIcons.calendar,
                  size: 14,
                  color: _isMarketResearch
                      ? AppColors.brand
                      : theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 6),
                Text(
                  'Due ${dateFormat.format(task.dueDate)}',
                  style: theme.textTheme.muted.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _isMarketResearch ? AppColors.brand : null,
                  ),
                ),
                if (_isMarketResearch) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    AppIcons.chevronRight,
                    size: 14,
                    color: AppColors.brand,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (task.status != TaskStatus.completed)
                  Expanded(
                    child: ShadButton(
                      size: ShadButtonSize.sm,
                      backgroundColor: AppColors.successGreen,
                      onPressed: () => _markCompleted(context),
                      leading: const Icon(AppIcons.check, size: 16),
                      child: const Text('Completed'),
                    ),
                  )
                else
                  Expanded(
                    child: Text(
                      'Completed',
                      style: theme.textTheme.muted.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ),
                if (_isMarketResearch) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Open research form',
                    onPressed: () => _openMarketResearch(context),
                    icon: const Icon(AppIcons.calendar, size: 18),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (!_isMarketResearch) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openMarketResearch(context),
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }

  String _formatStatus(TaskStatus status) => switch (status) {
        TaskStatus.pending => 'Pending',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.completed => 'Completed',
      };

  bool get _isMarketResearch =>
      task.taskTypeCode.trim().toLowerCase() == 'market_research';

  void _openMarketResearch(BuildContext context) {
    context.push(
      RouteNames.marketResearchPath(routeId: task.routeId),
    );
  }

  Future<void> _markCompleted(BuildContext context) async {
    await ref
        .read(tasksProvider.notifier)
        .updateStatus(task.id, TaskStatus.completed);

    if (!context.mounted) return;
    final error = ref.read(tasksProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null ? 'Task marked as Completed' : error,
        ),
      ),
    );
  }

}

class _TaskTargetProgressCard extends StatelessWidget {
  const _TaskTargetProgressCard({required this.progress});

  final TaskTargetProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.trend, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  progress.label.isNotEmpty
                      ? 'Target · ${progress.label}'
                      : 'Task Target',
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandDark,
                  ),
                ),
              ),
            ],
          ),
          if (progress.hasCount) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TargetMetric(
                    label: 'Target count',
                    value: formatTargetNumber(progress.targetCount ?? 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TargetMetric(
                    label: 'Achieved count',
                    value: formatTargetNumber(progress.achievedCount ?? 0),
                  ),
                ),
              ],
            ),
          ],
          if (progress.hasAmount) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TargetMetric(
                    label: 'Target amount',
                    value: CurrencyFormatter.format(progress.targetAmount ?? 0),
                  ),
                ),
                if (progress.achievedAmount != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TargetMetric(
                      label: 'Achieved amount',
                      value: CurrencyFormatter.format(progress.achievedAmount!),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TargetMetric extends StatelessWidget {
  const _TargetMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.muted.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.small.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

