import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/charts/sales_charts.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardProvider);
    final user = ref.watch(currentUserProvider);
    final currency = CurrencyFormatter.compact;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(AppIcons.user, color: AppColors.primaryBlue),
                ),
                title: Text(user?.name ?? 'Executive'),
                subtitle: Text('${user?.assignedRoute ?? ''} • ${DateFormat('MMMM yyyy').format(DateTime.now())}'),
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(title: 'Sales Performance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ReportRow('Daily Achievement', '${summary.dailySalesTargetPercent.toStringAsFixed(0)}%'),
                    _ReportRow('Monthly Achievement', '${summary.monthlyTargetPercent.toStringAsFixed(0)}%'),
                    _ReportRow('Route Performance', '${summary.routePerformance.toStringAsFixed(0)}%'),
                    _ReportRow('Monthly Sales', currency(summary.monthlyAchievedAmount)),
                  ],
                ),
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
                    _ReportRow('Missing Customers', '${summary.missingCustomers}'),
                    _ReportRow('Follow-ups', '${summary.followUpCustomers}'),
                    _ReportRow('New Leads', '${summary.newLeads}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
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
