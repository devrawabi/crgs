import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/badges/priority_badge.dart';
import '../../../shared/widgets/charts/sales_charts.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/customer_provider.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerByIdProvider(customerId));
    final dateFormat = DateFormat('dd MMM yyyy');

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Details')),
        body: const Center(child: Text('Customer not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          PriorityBadge(priority: customer.priority),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionCard(context, 'Customer Information', [
              InfoRow(label: 'Name', value: customer.name, icon: AppIcons.store),
              InfoRow(label: 'Contact Person', value: customer.contactPerson, icon: AppIcons.user),
              InfoRow(label: 'Mobile', value: customer.mobile, icon: AppIcons.phone),
              InfoRow(label: 'Location', value: customer.location, icon: AppIcons.locationPin),
              InfoRow(label: 'Route', value: customer.routeName, icon: AppIcons.route),
            ]),
            const SizedBox(height: 16),
            _sectionCard(context, 'Purchase Information', [
              InfoRow(
                label: 'Last Purchase Date',
                value: customer.lastPurchaseDate != null
                    ? dateFormat.format(customer.lastPurchaseDate!)
                    : 'N/A',
              ),
              InfoRow(
                label: 'Last Purchase Amount',
                value: CurrencyFormatter.format(customer.lastPurchaseAmount),
              ),
              InfoRow(
                label: 'Outstanding Balance',
                value: CurrencyFormatter.format(customer.outstandingAmount),
              ),
              InfoRow(
                label: 'Avg Monthly Purchase',
                value: CurrencyFormatter.format(customer.averageMonthlyPurchase),
              ),
              InfoRow(label: 'Purchase Frequency', value: customer.purchaseFrequency),
              InfoRow(
                label: 'Credit Limit',
                value: CurrencyFormatter.format(customer.creditLimit),
              ),
            ]),
            const SizedBox(height: 16),
            SectionHeader(title: 'Micro Category Sales'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SalesBarChart(height: 200),
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(title: 'Purchase Trends'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: PurchaseTrendChart(height: 180),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _actionChip(context, 'Start Visit', AppIcons.play, () {
                  context.push('/visit/$customerId');
                }),
                _actionChip(context, 'Follow-up', AppIcons.event, () {
                  context.push(RouteNames.followUp);
                }),
                _actionChip(context, 'Recovery', AppIcons.assignment, () {
                  context.push('/recovery/$customerId');
                }, AppColors.missingRed),
                _actionChip(context, 'Research', AppIcons.science, () {
                  context.push(RouteNames.marketResearch);
                }),
                _actionChip(context, 'Expected Order', AppIcons.bag, () {
                  context.push('/products/$customerId');
                }, AppColors.successGreen),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/visit/$customerId'),
        icon: const Icon(AppIcons.play),
        label: const Text('Start Visit'),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _actionChip(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, [
    Color? color,
  ]) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
