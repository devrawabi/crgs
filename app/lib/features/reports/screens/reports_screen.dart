import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/charts/sales_charts.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../dashboard/providers/targets_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final user = ref.watch(currentUserProvider);
    final targetsAsync = ref.watch(executiveTargetsProvider);
    final currency = CurrencyFormatter.compact;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.dashboard);
            }
          },
        ),
        title: const Text('Reports & Analytics'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(executiveTargetsProvider);
          await ref.read(executiveTargetsProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        AppColors.primaryBlue.withValues(alpha: 0.1),
                    child: const Icon(
                      AppIcons.user,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  title: Text(user?.name ?? 'Executive'),
                  subtitle: Text(
                    '${user?.assignedRoute ?? ''} • ${DateFormat('MMMM yyyy').format(DateTime.now())}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: 'Sales Performance'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ReportRow(
                        'Daily Achievement',
                        '${summary.dailySalesTargetPercent.toStringAsFixed(0)}%',
                      ),
                      _ReportRow(
                        'Monthly Achievement',
                        '${summary.monthlyTargetPercent.toStringAsFixed(0)}%',
                      ),
                      _ReportRow(
                        'Route Performance',
                        '${summary.routePerformance.toStringAsFixed(0)}%',
                      ),
                      _ReportRow(
                        'Monthly Sales',
                        currency(summary.monthlyAchievedAmount),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(
                title: 'Product Targets',
                actionLabel: 'Refresh',
                action: () {
                  ref.invalidate(executiveTargetsProvider);
                },
              ),
              targetsAsync.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Could not load product targets',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(executiveTargetsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (targets) => _ProductTargetsSection(
                  targets: targets.productTargets,
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: 'Category-wise Sales'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SalesBarChart(height: 220),
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: 'Purchase Trends'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PurchaseTrendChart(height: 200),
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(title: 'Visit Summary'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _ReportRow('Today\'s Visits', '${summary.todaysVisits}'),
                      _ReportRow(
                        'Missing Customers',
                        '${summary.missingCustomers}',
                      ),
                      _ReportRow(
                        'Follow-ups',
                        '${summary.followUpCustomers}',
                      ),
                      _ReportRow('New Leads', '${summary.newLeads}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductTargetsSection extends StatelessWidget {
  const _ProductTargetsSection({required this.targets});

  final List<ProductTargetModel> targets;

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                AppIcons.bag,
                color: AppColors.primaryBlue.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No product targets assigned for your routes.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalTarget =
        targets.fold<double>(0, (sum, item) => sum + item.targetValue);
    final totalAchieved =
        targets.fold<double>(0, (sum, item) => sum + item.achievedValue);
    final overallPercent =
        totalTarget > 0 ? (totalAchieved / totalTarget) * 100 : 0.0;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ReportRow('Targets', '${targets.length}'),
                _ReportRow('Total Target', _formatValue(totalTarget)),
                _ReportRow('Total Achieved', _formatValue(totalAchieved)),
                _ReportRow(
                  'Overall Progress',
                  '${overallPercent.toStringAsFixed(0)}%',
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (overallPercent / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor:
                        AppColors.primaryBlue.withValues(alpha: 0.12),
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...targets.map(
          (target) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ProductTargetCard(target: target),
          ),
        ),
      ],
    );
  }
}

class _ProductTargetCard extends StatelessWidget {
  const _ProductTargetCard({required this.target});

  final ProductTargetModel target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = target.targetValue > 0
        ? (target.achievedValue / target.targetValue) * 100
        : 0.0;
    final names = target.displayProductNames;
    final codes = target.products;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    target.productsLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    target.typeLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (target.routeNo.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Route ${target.routeNo}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _ReportRow('Target', _formatValue(target.targetValue)),
            _ReportRow('Achieved', _formatValue(target.achievedValue)),
            _ReportRow('Progress', '${percent.toStringAsFixed(0)}%'),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                color: percent >= 100
                    ? AppColors.successGreen
                    : AppColors.primaryBlue,
              ),
            ),
            if (names.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Products',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(names.length, (index) {
                final name = names[index];
                final code = index < codes.length ? codes[index] : '';
                final uom = target.baseUomAt(index);
                final price = target.retailPriceAt(index);
                final stock = target.currentStockAt(index);
                final qtyLimit = target.quantityLimitAt(index);
                final meta = <String>[
                  if (code.isNotEmpty) code,
                  if (uom.isNotEmpty) uom,
                  if (price > 0) CurrencyFormatter.format(price),
                  if (stock > 0) 'Stock ${_formatValue(stock)}',
                  if (qtyLimit > 0) 'Limit ${_formatValue(qtyLimit)}',
                ].join(' · ');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        AppIcons.bag,
                        size: 16,
                        color: AppColors.primaryBlue.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (meta.isNotEmpty)
                              Text(
                                meta,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatValue(double value) {
  if (value == value.roundToDouble()) {
    return NumberFormat('#,##0').format(value);
  }
  return NumberFormat('#,##0.##').format(value);
}
