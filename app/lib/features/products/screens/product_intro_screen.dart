import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../customers/providers/customer_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../../visit/providers/visit_product_provider.dart';
import '../../visit/providers/visit_provider.dart';
import '../providers/items_provider.dart';

const _previewProductLimit = 3;

class ProductIntroScreen extends ConsumerStatefulWidget {
  const ProductIntroScreen({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<ProductIntroScreen> createState() => _ProductIntroScreenState();
}

class _ProductIntroScreenState extends ConsumerState<ProductIntroScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _cart = <String, double>{};
  final _expectedProductController = TextEditingController();
  final _expectedQtyController = TextEditingController();
  final _expectedRemarksController = TextEditingController();
  DateTime _expectedDate = DateTime.now().add(const Duration(days: 7));
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _expectedProductController.dispose();
    _expectedQtyController.dispose();
    _expectedRemarksController.dispose();
    super.dispose();
  }

  List<AlternativeProductModel> _filterProducts(
    List<AlternativeProductModel> products,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
  }

  void _adjustQty(String productId, double delta, {double fallback = 0}) {
    setState(() {
      final current = _cart[productId] ?? fallback;
      final next = current + delta;
      if (next <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = next;
      }
    });
  }

  void _openAllProducts({
    required String title,
    required IconData icon,
    required Color accent,
    required List<AlternativeProductModel> products,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _AllProductsSheet(
              title: title,
              icon: icon,
              accent: accent,
              products: products,
              cart: _cart,
              onDecrease: (id) {
                _adjustQty(id, -1);
                setModalState(() {});
              },
              onIncrease: (id) {
                _adjustQty(id, 1);
                setModalState(() {});
              },
            );
          },
        );
      },
    );
  }

  List<AlternativeProductModel> _cartProducts() {
    final catalog = <String, AlternativeProductModel>{
      for (final product in [
        ...ref.read(visitNewProductsProvider),
        ...ref.read(visitReplacementProductsProvider),
        ...ref.read(visitOwnProductsProvider),
        ...?ref.read(allItemsProvider).valueOrNull,
      ])
        product.id: product,
    };

    return [
      for (final id in _cart.keys)
        catalog[id] ??
            AlternativeProductModel(
              id: id,
              name: id,
              imageUrl: '',
              details: '',
              category: 'Cart',
            ),
    ];
  }

  double _cartTotalAmount([List<AlternativeProductModel>? products]) {
    final items = products ?? _cartProducts();
    return items.fold<double>(0, (sum, product) {
      final qty = _cart[product.id] ?? 0;
      return sum + (product.unitPrice * qty);
    });
  }

  double _cartTotalQty() =>
      _cart.values.fold<double>(0, (sum, qty) => sum + qty);

  void _goToExpectedOrderFromCart() {
    final products = _cartProducts()
        .where((product) => (_cart[product.id] ?? 0) > 0)
        .toList();
    if (products.isEmpty) return;

    final summary = products
        .map((product) {
          final qty = _cart[product.id] ?? 0;
          return '${product.name} × ${qty.toStringAsFixed(0)}';
        })
        .join(', ');
    final totalQty =
        _cart.values.fold<double>(0, (sum, qty) => sum + qty);

    setState(() {
      _expectedProductController.text = summary;
      _expectedQtyController.text = totalQty.toStringAsFixed(0);
    });

    Navigator.of(context).pop();
    _tabController.animateTo(1);
  }

  void _openCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final products = _cartProducts();
            return _CartSheet(
              products: products,
              cart: _cart,
              onDecrease: (id) {
                _adjustQty(id, -1);
                setModalState(() {});
                if (_cart.isEmpty && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              onIncrease: (id) {
                _adjustQty(id, 1);
                setModalState(() {});
              },
              onRemove: (id) {
                setState(() => _cart.remove(id));
                setModalState(() {});
                if (_cart.isEmpty && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              onClear: () {
                setState(() => _cart.clear());
                Navigator.of(context).pop();
              },
              onExpectedOrder: _goToExpectedOrderFromCart,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(customerByIdProvider(widget.customerId));
    final itemsAsync = ref.watch(allItemsProvider);
    final newProducts = _filterProducts(ref.watch(visitNewProductsProvider));
    final replacementProducts =
        _filterProducts(ref.watch(visitReplacementProductsProvider));
    final ownProducts = _filterProducts(ref.watch(visitOwnProductsProvider));
    final allProducts = _filterProducts(itemsAsync.valueOrNull ?? const []);

    return Scaffold(
      appBar: AppBar(
        title: Text('Products — ${customer?.name ?? ''}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              text: 'Recommended',
              icon: Icon(AppIcons.recommend, size: 20),
            ),
            Tab(
              text: 'Expected Order',
              icon: Icon(AppIcons.eventNote, size: 20),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecommendedTab(
            itemsAsync: itemsAsync,
            newProducts: newProducts,
            replacementProducts: replacementProducts,
            ownProducts: ownProducts,
            allProducts: allProducts,
          ),
          _buildExpectedOrderTab(),
        ],
      ),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openCart,
              icon: Badge(
                label: Text('${_cart.length}'),
                child: const Icon(AppIcons.cart),
              ),
              label: const Text('Cart'),
            )
          : null,
    );
  }

  Widget _buildRecommendedTab({
    required AsyncValue<List<AlternativeProductModel>> itemsAsync,
    required List<AlternativeProductModel> newProducts,
    required List<AlternativeProductModel> replacementProducts,
    required List<AlternativeProductModel> ownProducts,
    required List<AlternativeProductModel> allProducts,
  }) {
    final hasTargets = newProducts.isNotEmpty ||
        replacementProducts.isNotEmpty ||
        ownProducts.isNotEmpty;
    final hasAny = hasTargets || allProducts.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search products...',
              prefixIcon: Icon(AppIcons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load products',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (_) {
              if (!hasAny) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? 'No products available'
                          : 'No products match your search',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
                children: [
                  if (newProducts.isNotEmpty)
                    _ProductCarouselSection(
                      title: 'New Products',
                      icon: AppIcons.addCircle,
                      accent: AppColors.successGreen,
                      products: newProducts,
                      cart: _cart,
                      onDecrease: (id) => _adjustQty(id, -1),
                      onIncrease: (id) => _adjustQty(id, 1),
                      onViewMore: () => _openAllProducts(
                        title: 'New Products',
                        icon: AppIcons.addCircle,
                        accent: AppColors.successGreen,
                        products: newProducts,
                      ),
                    ),
                  if (replacementProducts.isNotEmpty)
                    _ProductCarouselSection(
                      title: 'Product Replacement',
                      icon: AppIcons.campaign,
                      accent: AppColors.outstandingOrange,
                      products: replacementProducts,
                      cart: _cart,
                      onDecrease: (id) => _adjustQty(id, -1),
                      onIncrease: (id) => _adjustQty(id, 1),
                      onViewMore: () => _openAllProducts(
                        title: 'Product Replacement',
                        icon: AppIcons.campaign,
                        accent: AppColors.outstandingOrange,
                        products: replacementProducts,
                      ),
                    ),
                  if (ownProducts.isNotEmpty)
                    _ProductCarouselSection(
                      title: 'Own Products',
                      icon: AppIcons.inventory,
                      accent: AppColors.primaryBlue,
                      products: ownProducts,
                      cart: _cart,
                      onDecrease: (id) => _adjustQty(id, -1),
                      onIncrease: (id) => _adjustQty(id, 1),
                      onViewMore: () => _openAllProducts(
                        title: 'Own Products',
                        icon: AppIcons.inventory,
                        accent: AppColors.primaryBlue,
                        products: ownProducts,
                      ),
                    ),
                  if (allProducts.isNotEmpty)
                    _ProductCarouselSection(
                      title: 'All Products',
                      icon: AppIcons.inventory,
                      accent: AppColors.brand,
                      products: allProducts,
                      cart: _cart,
                      onDecrease: (id) => _adjustQty(id, -1),
                      onIncrease: (id) => _adjustQty(id, 1),
                      onViewMore: () => _openAllProducts(
                        title: 'All Products',
                        icon: AppIcons.inventory,
                        accent: AppColors.brand,
                        products: allProducts,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveExpectedOrder() async {
    final customer = ref.read(customerByIdProvider(widget.customerId));
    final user = ref.read(currentUserProvider);
    final employeeCode = user?.employeeCode.trim() ?? '';
    final visit = ref.read(visitProvider);

    final products = _cartProducts()
        .where((product) => (_cart[product.id] ?? 0) > 0)
        .toList();

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add products to cart before saving')),
      );
      return;
    }

    if (employeeCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee code missing. Please log in again.')),
      );
      return;
    }

    final route = () {
      final visitRoute = visit?.route.trim() ?? '';
      if (visitRoute.isNotEmpty) return visitRoute;
      final routeId = customer?.routeId.trim() ?? '';
      if (routeId.isNotEmpty) return routeId;
      return customer?.routeName.trim() ?? '';
    }();

    if (route.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer route is missing')),
      );
      return;
    }

    try {
      await ref.read(ordersProvider.notifier).saveOrder(
            employeeCode: employeeCode,
            customerId: widget.customerId,
            customerName: customer?.name ?? widget.customerId,
            route: route,
            items: [
              for (final product in products)
                OrderLineItem(
                  productId: product.id,
                  productName: product.name,
                  quantity: _cart[product.id] ?? 0,
                  category: product.category,
                  unitPrice: product.unitPrice,
                  uom: product.baseUom.trim().isNotEmpty
                      ? product.baseUom.trim()
                      : 'PCS',
                ),
            ],
            expectedDate: _expectedDate,
            remarks: _expectedRemarksController.text,
          );

      if (!mounted) return;
      setState(() => _cart.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expected order saved')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save expected order: $error')),
      );
    }
  }

  Widget _buildExpectedOrderTab() {
    final cartProducts = _cartProducts()
        .where((product) => (_cart[product.id] ?? 0) > 0)
        .toList();
    final totalQty = _cartTotalQty();
    final totalAmount = _cartTotalAmount(cartProducts);
    final theme = ShadTheme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (cartProducts.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order summary',
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${cartProducts.length} products · ${totalQty.toStringAsFixed(0)} qty',
                          style: theme.textTheme.muted.copyWith(fontSize: 13),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(
                          totalAmount,
                          decimalDigits: totalAmount % 1 == 0 ? 0 : 2,
                        ),
                        style: theme.textTheme.large.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total amount',
                      style: theme.textTheme.muted.copyWith(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          AppTextField(
            controller: _expectedProductController,
            label: 'Product',
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _expectedQtyController,
            label: 'Quantity',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: TextEditingController(
              text:
                  '${_expectedDate.day}/${_expectedDate.month}/${_expectedDate.year}',
            ),
            label: 'Expected Date',
            readOnly: true,
            prefixIcon: AppIcons.calendar,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _expectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) setState(() => _expectedDate = date);
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _expectedRemarksController,
            label: 'Remarks',
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saveExpectedOrder,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('Save Expected Order'),
          ),
        ],
      ),
    );
  }
}

class _ProductCarouselSection extends StatelessWidget {
  const _ProductCarouselSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.products,
    required this.cart,
    required this.onDecrease,
    required this.onIncrease,
    required this.onViewMore,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<AlternativeProductModel> products;
  final Map<String, double> cart;
  final ValueChanged<String> onDecrease;
  final ValueChanged<String> onIncrease;
  final VoidCallback onViewMore;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final previewProducts = products.take(_previewProductLimit).toList();
    final hasMore = products.length > _previewProductLimit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.large.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onViewMore,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    hasMore
                        ? 'View more (${products.length})'
                        : 'View all',
                    style: theme.textTheme.small.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 212,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: previewProducts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final product = previewProducts[index];
                final qty = cart[product.id] ?? 0;
                return _ProductSliderCard(
                  product: product,
                  accent: accent,
                  qty: qty,
                  onDecrease: () => onDecrease(product.id),
                  onIncrease: () => onIncrease(product.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductSliderCard extends StatelessWidget {
  const _ProductSliderCard({
    required this.product,
    required this.accent,
    required this.qty,
    required this.onDecrease,
    required this.onIncrease,
  });

  final AlternativeProductModel product;
  final Color accent;
  final double qty;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final inCart = qty > 0;

    return SizedBox(
      width: 156,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: inCart
              ? accent.withValues(alpha: 0.08)
              : theme.colorScheme.card,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          border: Border.all(
            color: inCart ? accent : theme.colorScheme.border,
            width: inCart ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 72,
              color: accent.withValues(alpha: 0.12),
              alignment: Alignment.center,
              child: Icon(AppIcons.inventory, color: accent, size: 28),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.category,
                      style: theme.textTheme.small.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.uomPriceLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.uomPriceLabel,
                        style: theme.textTheme.muted.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        _QtyButton(
                          icon: AppIcons.removeCircle,
                          onPressed: inCart ? onDecrease : null,
                        ),
                        Expanded(
                          child: Text(
                            qty.toStringAsFixed(0),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _QtyButton(
                          icon: AppIcons.addCircle,
                          onPressed: onIncrease,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      ),
    );
  }
}

class _AllProductsSheet extends StatefulWidget {
  const _AllProductsSheet({
    required this.title,
    required this.icon,
    required this.accent,
    required this.products,
    required this.cart,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<AlternativeProductModel> products;
  final Map<String, double> cart;
  final ValueChanged<String> onDecrease;
  final ValueChanged<String> onIncrease;

  @override
  State<_AllProductsSheet> createState() => _AllProductsSheetState();
}

class _AllProductsSheetState extends State<_AllProductsSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AlternativeProductModel> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.products;

    return widget.products.where((product) {
      final haystack = [
        product.name,
        product.id,
        product.category,
        product.details,
        product.uomPriceLabel,
        product.baseUom,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final filtered = _filteredProducts;
    final query = _searchQuery.trim();

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
                  Icon(widget.icon, size: 20, color: widget.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.large.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          query.isEmpty
                              ? '${widget.products.length} products'
                              : '${filtered.length} of ${widget.products.length} products',
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ShadInput(
                controller: _searchController,
                placeholder: const Text('Search products...'),
                leading: const Icon(AppIcons.search, size: 18),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.border),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        query.isEmpty
                            ? 'No products found'
                            : 'No products match your search',
                        style: theme.textTheme.muted.copyWith(fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding:
                          EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final product = filtered[index];
                        final qty = widget.cart[product.id] ?? 0;
                        final inCart = qty > 0;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: inCart
                                ? widget.accent.withValues(alpha: 0.08)
                                : theme.colorScheme.card,
                            borderRadius:
                                BorderRadius.circular(AppDecorations.radiusMd),
                            border: Border.all(
                              color: inCart
                                  ? widget.accent
                                  : theme.colorScheme.border,
                              width: inCart ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: widget.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  AppIcons.inventory,
                                  color: widget.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: theme.textTheme.large.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        product.category,
                                        if (product.uomPriceLabel.isNotEmpty)
                                          product.uomPriceLabel,
                                      ].join(' · '),
                                      style: theme.textTheme.muted.copyWith(
                                        fontSize: 12,
                                        color: widget.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _QtyButton(
                                    icon: AppIcons.removeCircle,
                                    onPressed: inCart
                                        ? () => widget.onDecrease(product.id)
                                        : null,
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      qty.toStringAsFixed(0),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.small.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _QtyButton(
                                    icon: AppIcons.addCircle,
                                    onPressed: () =>
                                        widget.onIncrease(product.id),
                                  ),
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

class _CartSheet extends StatelessWidget {
  const _CartSheet({
    required this.products,
    required this.cart,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
    required this.onClear,
    required this.onExpectedOrder,
  });

  final List<AlternativeProductModel> products;
  final Map<String, double> cart;
  final ValueChanged<String> onDecrease;
  final ValueChanged<String> onIncrease;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;
  final VoidCallback onExpectedOrder;

  double get _totalQty =>
      cart.values.fold<double>(0, (sum, qty) => sum + qty);

  double get _totalAmount => products.fold<double>(0, (sum, product) {
        final qty = cart[product.id] ?? 0;
        if (qty <= 0) return sum;
        return sum + (product.unitPrice * qty);
      });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final visibleProducts =
        products.where((product) => (cart[product.id] ?? 0) > 0).toList();
    final totalAmount = _totalAmount;
    final totalLabel = CurrencyFormatter.format(
      totalAmount,
      decimalDigits: totalAmount % 1 == 0 ? 0 : 2,
    );

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
                  const Icon(AppIcons.cart, size: 20, color: AppColors.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cart',
                          style: theme.textTheme.large.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${visibleProducts.length} products · ${_totalQty.toStringAsFixed(0)} qty',
                          style: theme.textTheme.muted.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (visibleProducts.isNotEmpty)
                    TextButton(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.missingRed,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Clear'),
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
            Divider(height: 1, color: theme.colorScheme.border),
            Expanded(
              child: visibleProducts.isEmpty
                  ? Center(
                      child: Text(
                        'No products in cart',
                        style: theme.textTheme.muted,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: visibleProducts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final product = visibleProducts[index];
                        final qty = cart[product.id] ?? 0;
                        final lineAmount = product.unitPrice * qty;
                        final lineLabel = lineAmount > 0
                            ? CurrencyFormatter.format(
                                lineAmount,
                                decimalDigits: lineAmount % 1 == 0 ? 0 : 2,
                              )
                            : '';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.brandContainer.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius:
                                BorderRadius.circular(AppDecorations.radiusMd),
                            border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.12),
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
                                      product.name,
                                      style: theme.textTheme.large.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (product.category.isNotEmpty)
                                          product.category
                                        else
                                          'Added product',
                                        if (product.uomPriceLabel.isNotEmpty)
                                          product.uomPriceLabel,
                                        if (lineLabel.isNotEmpty) lineLabel,
                                      ].join(' · '),
                                      style: theme.textTheme.muted.copyWith(
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _QtyButton(
                                    icon: AppIcons.removeCircle,
                                    onPressed: () => onDecrease(product.id),
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      qty.toStringAsFixed(0),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.small.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _QtyButton(
                                    icon: AppIcons.addCircle,
                                    onPressed: () => onIncrease(product.id),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: () => onRemove(product.id),
                                tooltip: 'Remove',
                                icon: const Icon(
                                  AppIcons.remove,
                                  size: 18,
                                  color: AppColors.missingRed,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (visibleProducts.isNotEmpty)
              Container(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
                decoration: BoxDecoration(
                  color: theme.colorScheme.card,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.border.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Text(
                            'Total amount',
                            style: theme.textTheme.large.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            totalLabel,
                            style: theme.textTheme.large.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onExpectedOrder,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.brand,
                      ),
                      icon: const Icon(AppIcons.eventNote, size: 18),
                      label: const Text('Go to Expected Order'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
