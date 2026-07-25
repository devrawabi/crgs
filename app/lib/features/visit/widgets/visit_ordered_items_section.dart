import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';
import '../../customers/providers/customer_provider.dart';
import '../providers/visit_product_provider.dart';
import 'product_detail_sheet.dart';

Future<void> openVisitProductSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String customerId,
  required OrderedProductModel product,
  Set<String> suggestedProductIds = const {},
  ValueChanged<String>? onSuggestionAdded,
}) async {
  final customerName =
      ref.read(customerByIdProvider(customerId))?.name ?? customerId;

  await showProductDetailSheet(
    context,
    product: product,
    customerId: customerId,
    customerName: customerName,
    newProducts: targetProductsForOrderedItem(
      ref.read(visitNewProductsProvider),
      product,
    ),
    replacementProducts: targetProductsForOrderedItem(
      ref.read(visitReplacementProductsProvider),
      product,
    ),
    ownProducts: targetProductsForOrderedItem(
      ref.read(visitOwnProductsProvider),
      product,
    ),
    suggestedProductIds: suggestedProductIds,
    onSuggestionAdded: onSuggestionAdded,
  );
}

class VisitOrderedItemsSection extends ConsumerWidget {
  const VisitOrderedItemsSection({
    super.key,
    required this.customerId,
    this.suggestedProductIds = const {},
    this.onSuggestionAdded,
  });

  final String customerId;
  final Set<String> suggestedProductIds;
  final ValueChanged<String>? onSuggestionAdded;

  void _showLastOrderDialog(
    BuildContext context,
    WidgetRef ref,
    CustomerLastOrderState ordered,
  ) {
    if (!ordered.hasLastPurchase) return;

    ref.read(customerLastOrderProvider(customerId).notifier).loadItems();

    showDialog<void>(
      context: context,
      builder: (ctx) => _LastOrderItemsDialog(
        customerId: customerId,
        billNo: ordered.billNo,
        suggestedProductIds: suggestedProductIds,
        onSuggestionAdded: onSuggestionAdded,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordered = ref.watch(customerLastOrderProvider(customerId));
    final theme = ShadTheme.of(context);
    final lastPurchase = ordered.lastPurchase;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Ordered Items',
              style: theme.textTheme.large.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (ordered.isLoading)
              const _OrderedItemsSkeletonLine(width: 68, height: 10)
            else if (ordered.itemsLoaded && ordered.products.isNotEmpty)
              Text(
                '${ordered.products.length} products',
                style: theme.textTheme.muted.copyWith(fontSize: 13),
              ),
          ],
        ),
        if (ordered.billNo.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Last order bill no: ${ordered.billNo}',
            style: theme.textTheme.muted.copyWith(fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        if (ordered.isLoading)
          const _OrderedItemsSkeleton()
        else if (ordered.error != null && !ordered.hasLastPurchase)
          Text(
            'Could not load ordered items',
            style: theme.textTheme.muted.copyWith(fontSize: 13),
          )
        else if (!ordered.hasLastPurchase)
          Text(
            'No previous orders found',
            style: theme.textTheme.muted.copyWith(fontSize: 13),
          )
        else
          _LastPurchaseCard(
            purchaseDate: lastPurchase?.date,
            amount: lastPurchase?.amount ?? 0,
            productCount: ordered.itemsLoaded ? ordered.products.length : null,
            dateFormat: dateFormat,
            onTap: () => _showLastOrderDialog(context, ref, ordered),
          ),
      ],
    );
  }
}

class _OrderedItemsSkeleton extends StatelessWidget {
  const _OrderedItemsSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderedItemsSkeletonLine(width: 170, height: 14),
          SizedBox(height: 10),
          _OrderedItemsSkeletonLine(width: 110, height: 10),
          SizedBox(height: 14),
          _OrderedItemsSkeletonLine(width: double.infinity, height: 10),
        ],
      ),
    );
  }
}

class _OrderedItemsSkeletonLine extends StatelessWidget {
  const _OrderedItemsSkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.mutedForeground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

class _LastPurchaseCard extends StatelessWidget {
  const _LastPurchaseCard({
    required this.purchaseDate,
    required this.amount,
    required this.productCount,
    required this.dateFormat,
    required this.onTap,
  });

  final DateTime? purchaseDate;
  final double amount;
  final int? productCount;
  final DateFormat dateFormat;
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            border: Border.all(color: theme.colorScheme.border),
            boxShadow: AppDecorations.cardShadow(theme.colorScheme.primary),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.brandContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  AppIcons.document,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Purchase',
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          AppIcons.calendar,
                          size: 14,
                          color: theme.colorScheme.mutedForeground,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          purchaseDate != null
                              ? dateFormat.format(purchaseDate!)
                              : 'Date unavailable',
                          style: theme.textTheme.muted.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(amount),
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (productCount != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$productCount products',
                        style: theme.textTheme.muted.copyWith(fontSize: 12),
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      Text(
                        'Tap to view items',
                        style: theme.textTheme.muted.copyWith(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
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

class _LastOrderItemsDialog extends ConsumerStatefulWidget {
  const _LastOrderItemsDialog({
    required this.customerId,
    required this.billNo,
    this.suggestedProductIds = const {},
    this.onSuggestionAdded,
  });

  final String customerId;
  final String billNo;
  final Set<String> suggestedProductIds;
  final ValueChanged<String>? onSuggestionAdded;

  @override
  ConsumerState<_LastOrderItemsDialog> createState() =>
      _LastOrderItemsDialogState();
}

class _LastOrderItemsDialogState extends ConsumerState<_LastOrderItemsDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _itemDetails(OrderedProductModel product) {
    final parts = <String>[];
    if (product.id.isNotEmpty && product.id != product.name) {
      parts.add('Code ${product.id}');
    }
    if (product.category.isNotEmpty) parts.add(product.category);
    if (product.details.isNotEmpty &&
        product.details != product.name &&
        product.details != product.id) {
      parts.add(product.details);
    }
    if (product.unitPrice > 0) {
      parts.add('${CurrencyFormatter.format(product.unitPrice)} / unit');
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  String _displayName(OrderedProductModel product) {
    final name = product.name.trim();
    if (name.isNotEmpty) return name;
    return product.id.isNotEmpty ? product.id : 'Unknown item';
  }

  List<OrderedProductModel> _filterProducts(
    List<OrderedProductModel> products,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return products;

    return products.where((product) {
      final haystack = [
        product.name,
        product.id,
        product.category,
        product.details,
        _itemDetails(product),
        product.quantity.toStringAsFixed(0),
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ordered = ref.watch(customerLastOrderProvider(widget.customerId));
    final theme = ShadTheme.of(context);
    final filteredProducts = _filterProducts(ordered.products);

    return Dialog(
      backgroundColor: theme.colorScheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Ordered Items',
                          style: theme.textTheme.large.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        if (widget.billNo.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Bill no: ${widget.billNo}',
                            style: theme.textTheme.muted.copyWith(fontSize: 13),
                          ),
                        ],
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
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ShadInput(
                controller: _searchController,
                placeholder: const Text('Search items...'),
                leading: const Icon(AppIcons.search, size: 18),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ordered.isLoadingItems
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.trim().isEmpty
                              ? ordered.error != null
                                    ? 'Could not load ordered items'
                                    : 'No items found'
                              : 'No items match your search',
                          style: theme.textTheme.muted.copyWith(fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredProducts.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: theme.colorScheme.border),
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => openVisitProductSheet(
                                context: context,
                                ref: ref,
                                customerId: widget.customerId,
                                product: product,
                                suggestedProductIds: widget.suggestedProductIds,
                                onSuggestionAdded: widget.onSuggestionAdded,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _displayName(product),
                                            style: theme.textTheme.large
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _itemDetails(product),
                                            style: theme.textTheme.muted
                                                .copyWith(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.brandContainer
                                            .withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Qty ${product.quantity.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      AppIcons.chevronRight,
                                      size: 16,
                                      color: theme.colorScheme.mutedForeground,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (ordered.hasMore && _searchQuery.trim().isEmpty) ...[
                const SizedBox(height: 8),
                ShadButton.outline(
                  width: double.infinity,
                  onPressed: ordered.isLoadingMore
                      ? null
                      : () => ref
                            .read(
                              customerLastOrderProvider(
                                widget.customerId,
                              ).notifier,
                            )
                            .loadMore(),
                  leading: ordered.isLoadingMore
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  child: Text(
                    ordered.isLoadingMore
                        ? 'Loading...'
                        : 'Load more (${ordered.products.length} shown)',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
