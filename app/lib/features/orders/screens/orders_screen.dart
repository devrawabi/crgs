import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_theme_extensions.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: RouteMasterColors.background(context),
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: OrdersListBody(showHeader: true)),
        ],
      ),
    );
  }
}

/// Orders list used by [OrdersScreen] and the Activity tab.
class OrdersListBody extends ConsumerWidget {
  const OrdersListBody({super.key, this.showHeader = false});

  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final state = ref.watch(ordersProvider);
    final orders = state.orders;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orders',
                        style: theme.textTheme.h3.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (state.isLoading && orders.isEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Loading orders...',
                          style: theme.textTheme.muted.copyWith(fontSize: 13),
                        ),
                      ] else if (orders.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${orders.length} order${orders.length == 1 ? '' : 's'}',
                          style: theme.textTheme.muted.copyWith(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: state.isLoading
                      ? null
                      : () => ref.read(ordersProvider.notifier).load(),
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.refresh, size: 20),
                ),
              ],
            ),
          ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.missingRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                border: Border.all(
                  color: AppColors.missingRed.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                state.error!,
                style: theme.textTheme.small.copyWith(
                  color: AppColors.missingRed,
                ),
              ),
            ),
          ),
        Expanded(
          child: state.isLoading && orders.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : orders.isEmpty
                  ? _EmptyOrdersState(theme: theme)
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(ordersProvider.notifier).load(),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: orders.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return _OrderCard(
                            order: order,
                            dateLabel: order.expectedDate != null
                                ? dateFormat.format(order.expectedDate!)
                                : dateFormat.format(order.createdAt),
                            onTap: () => _openOrderDetails(context, order),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _openOrderDetails(BuildContext context, CustomerOrder order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OrderDetailsSheet(order: order),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  const _EmptyOrdersState({required this.theme});

  final ShadThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.brandContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                AppIcons.bag,
                size: 32,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No orders yet',
              style: theme.textTheme.large.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.dateLabel,
    required this.onTap,
  });

  final CustomerOrder order;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Material(
      color: theme.colorScheme.card,
      borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brandContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(AppIcons.store, color: AppColors.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (order.orderNo.isNotEmpty) '#${order.orderNo}',
                        dateLabel,
                        if (order.route.isNotEmpty) 'Route ${order.route}',
                      ].join(' · '),
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    ),
                    if (order.totalAmount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(
                          order.totalAmount,
                          decimalDigits: 2,
                        ),
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      '${order.itemCount}',
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.brand,
                      ),
                    ),
                    Text(
                      order.itemCount == 1 ? 'item' : 'items',
                      style: theme.textTheme.muted.copyWith(
                        fontSize: 10,
                        color: AppColors.brandDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                AppIcons.chevronRight,
                size: 18,
                color: theme.colorScheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  const _OrderDetailsSheet({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final dateFormat = DateFormat('dd MMM yyyy');

    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
              child: Row(
                children: [
                  const Icon(AppIcons.bag, size: 20, color: AppColors.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.customerName,
                          style: theme.textTheme.large.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (order.orderNo.isNotEmpty) 'Order #${order.orderNo}',
                            '${order.itemCount} products',
                            if (order.expectedDate != null)
                              dateFormat.format(order.expectedDate!),
                            if (order.totalAmount > 0)
                              CurrencyFormatter.format(
                                order.totalAmount,
                                decimalDigits: 2,
                              ),
                          ].join(' · '),
                          style: theme.textTheme.muted.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      AppIcons.close,
                      size: 20,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (order.remarks.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  order.remarks,
                  style: theme.textTheme.muted.copyWith(fontSize: 13),
                ),
              ),
            ],
            Divider(height: 1, color: theme.colorScheme.border),
            Expanded(
              child: order.items.isEmpty
                  ? Center(
                      child: Text(
                        'No line items found for this order',
                        style: theme.textTheme.muted,
                      ),
                    )
                  : ListView.separated(
                      padding:
                          EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
                      itemCount: order.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final item = order.items[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.card,
                            borderRadius: BorderRadius.circular(
                              AppDecorations.radiusMd,
                            ),
                            border:
                                Border.all(color: theme.colorScheme.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.brandContainer.withValues(
                                    alpha: 0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  AppIcons.inventory,
                                  color: AppColors.brand,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: theme.textTheme.large.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (item.productId.isNotEmpty)
                                          item.productId,
                                        item.uom,
                                        if (item.unitPrice > 0)
                                          CurrencyFormatter.format(
                                            item.unitPrice,
                                            decimalDigits: 2,
                                          ),
                                      ].join(' · '),
                                      style: theme.textTheme.muted.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Qty ${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)}',
                                      style: theme.textTheme.small.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brand,
                                      ),
                                    ),
                                  ),
                                  if (item.lineTotal > 0) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      CurrencyFormatter.format(
                                        item.lineTotal,
                                        decimalDigits: 2,
                                      ),
                                      style: theme.textTheme.small.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
