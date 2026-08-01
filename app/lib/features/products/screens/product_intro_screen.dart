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
import '../../dashboard/providers/targets_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../../visit/providers/visit_product_provider.dart';
import '../../visit/providers/visit_provider.dart';
import '../providers/items_provider.dart';

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
  final _cartUoms = <String, String>{};
  final _cartUnitPrices = <String, double>{};
  final _expectedProductController = TextEditingController();
  final _expectedQtyController = TextEditingController();
  final _expectedRemarksController = TextEditingController();
  final _expectedDateController = TextEditingController();
  DateTime _expectedDate = DateTime.now().add(const Duration(days: 7));
  late final TabController _tabController;

  static const _tabs = [
    _ProductTab(
      title: 'New Product Promotion',
      shortTitle: 'New Promo',
      icon: AppIcons.addCircle,
      accent: AppColors.successGreen,
    ),
    _ProductTab(
      title: 'Own Products',
      shortTitle: 'Own',
      icon: AppIcons.inventory,
      accent: AppColors.ownProduct,
    ),
    _ProductTab(
      title: 'Product Replacement',
      shortTitle: 'Replace',
      icon: AppIcons.campaign,
      accent: AppColors.outstandingOrange,
    ),
    _ProductTab(
      title: 'All Products',
      shortTitle: 'All',
      icon: AppIcons.category,
      accent: AppColors.brand,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _syncExpectedDateController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _expectedProductController.dispose();
    _expectedQtyController.dispose();
    _expectedRemarksController.dispose();
    _expectedDateController.dispose();
    super.dispose();
  }

  void _syncExpectedDateController() {
    _expectedDateController.text =
        '${_expectedDate.day}/${_expectedDate.month}/${_expectedDate.year}';
  }

  List<AlternativeProductModel> _filterProducts(
    List<AlternativeProductModel> products,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return products;
    return products.where((p) {
      final haystack = [
        p.name,
        p.id,
        p.category,
        p.details,
        p.baseUom,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  AlternativeProductModel? _productById(String productId) {
    final catalog = <String, AlternativeProductModel>{
      for (final product in [
        ...ref.read(visitNewProductsProvider),
        ...ref.read(visitReplacementProductsProvider),
        ...ref.read(visitOwnProductsProvider),
        ...?ref.read(allItemsProvider).valueOrNull,
      ])
        product.id: product,
    };
    return catalog[productId];
  }

  void _rememberCartMeta(String productId) {
    final product = _productById(productId);
    if (product == null) return;
    _cartUoms.putIfAbsent(
      productId,
      () => product.baseUom.trim().isNotEmpty ? product.baseUom.trim() : 'PCS',
    );
    _cartUnitPrices.putIfAbsent(productId, () => product.unitPrice);
  }

  void _clearCartMeta(String productId) {
    _cartUoms.remove(productId);
    _cartUnitPrices.remove(productId);
  }

  void _adjustQty(String productId, double delta, {double fallback = 0}) {
    setState(() {
      final current = _cart[productId] ?? fallback;
      var next = current + delta;
      final product = _productById(productId);
      if (product != null && product.hasQtyLimit && next > product.qtyLimit) {
        next = product.qtyLimit;
      }
      if (next <= 0) {
        _cart.remove(productId);
        _clearCartMeta(productId);
      } else {
        _cart[productId] = next;
        _rememberCartMeta(productId);
      }
    });
  }

  void _setQty(
    String productId,
    double qty, {
    String? uom,
    double? unitPrice,
  }) {
    setState(() {
      var next = qty;
      final product = _productById(productId);
      if (product != null && product.hasQtyLimit && next > product.qtyLimit) {
        next = product.qtyLimit;
      }
      if (next <= 0) {
        _cart.remove(productId);
        _clearCartMeta(productId);
      } else {
        _cart[productId] = next;
        if (uom != null && uom.trim().isNotEmpty) {
          _cartUoms[productId] = uom.trim();
        } else {
          _rememberCartMeta(productId);
        }
        if (unitPrice != null) {
          _cartUnitPrices[productId] = unitPrice;
        } else {
          _rememberCartMeta(productId);
        }
      }
    });
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

  double _unitPriceFor(String productId, AlternativeProductModel product) {
    return _cartUnitPrices[productId] ?? product.unitPrice;
  }

  String _uomFor(String productId, AlternativeProductModel product) {
    final selected = _cartUoms[productId]?.trim() ?? '';
    if (selected.isNotEmpty) return selected;
    final base = product.baseUom.trim();
    return base.isNotEmpty ? base : 'PCS';
  }

  double _cartTotalAmount([List<AlternativeProductModel>? products]) {
    final items = products ?? _cartProducts();
    return items.fold<double>(0, (sum, product) {
      final qty = _cart[product.id] ?? 0;
      return sum + (_unitPriceFor(product.id, product) * qty);
    });
  }

  double _cartTotalQty() =>
      _cart.values.fold<double>(0, (sum, qty) => sum + qty);

  Future<void> _openProductDetail({
    required AlternativeProductModel product,
    required Color accent,
  }) async {
    await showModalBottomSheet<void>(
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
            final qty = _cart[product.id] ?? 0;
            return _ProductDetailPopup(
              product: product,
              accent: accent,
              qty: qty,
              initialUom: _cartUoms[product.id],
              onDecrease: () {
                _adjustQty(product.id, -1);
                setModalState(() {});
              },
              onIncrease: () {
                _adjustQty(product.id, 1);
                setModalState(() {});
              },
              onConfirm: (value, uom, unitPrice) {
                _setQty(
                  product.id,
                  value,
                  uom: uom,
                  unitPrice: unitPrice,
                );
                setModalState(() {});
              },
            );
          },
        );
      },
    );
  }

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
    final totalQty = _cart.values.fold<double>(0, (sum, qty) => sum + qty);

    setState(() {
      _expectedProductController.text = summary;
      _expectedQtyController.text = totalQty.toStringAsFixed(0);
    });

    Navigator.of(context).pop();
    _openExpectedOrderSheet();
  }

  void _openExpectedOrderSheet() {
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
            return _ExpectedOrderSheet(
              cartProducts: _cartProducts()
                  .where((p) => (_cart[p.id] ?? 0) > 0)
                  .toList(),
              cart: _cart,
              totalQty: _cartTotalQty(),
              totalAmount: _cartTotalAmount(),
              productController: _expectedProductController,
              qtyController: _expectedQtyController,
              remarksController: _expectedRemarksController,
              dateController: _expectedDateController,
              onPickDate: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _expectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() {
                    _expectedDate = date;
                    _syncExpectedDateController();
                  });
                  setModalState(() {});
                }
              },
              onSave: () async {
                await _saveExpectedOrder();
              },
            );
          },
        );
      },
    );
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
              unitPrices: _cartUnitPrices,
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
                setState(() {
                  _cart.remove(id);
                  _clearCartMeta(id);
                });
                setModalState(() {});
                if (_cart.isEmpty && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              onClear: () {
                setState(() {
                  _cart.clear();
                  _cartUoms.clear();
                  _cartUnitPrices.clear();
                });
                Navigator.of(context).pop();
              },
              onExpectedOrder: _goToExpectedOrderFromCart,
            );
          },
        );
      },
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
        const SnackBar(
          content: Text('Employee code missing. Please log in again.'),
        ),
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
                  unitPrice: _unitPriceFor(product.id, product),
                  uom: _uomFor(product.id, product),
                ),
            ],
            expectedDate: _expectedDate,
            remarks: _expectedRemarksController.text,
          );

      if (!mounted) return;
      setState(() {
        _cart.clear();
        _cartUoms.clear();
        _cartUnitPrices.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expected order saved')),
      );
      Navigator.of(context).pop();
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save expected order: $error')),
      );
    }
  }

  Future<void> _refreshAll() async {
    ref.invalidate(executiveTargetsProvider);
    try {
      await Future.wait([
        ref.read(itemsCatalogProvider.notifier).refresh(force: true),
        ref.read(executiveTargetsProvider.future),
      ]);
    } catch (_) {
      // Keep current lists; error UI is handled by providers.
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(customerByIdProvider(widget.customerId));
    final itemsAsync = ref.watch(allItemsProvider);
    final catalog = ref.watch(itemsCatalogProvider);
    final targetsAsync = ref.watch(executiveTargetsProvider);
    final targetsLoading = targetsAsync.isLoading;
    final targetsError = targetsAsync.hasError;
    final tabProducts = [
      _filterProducts(ref.watch(visitNewProductsProvider)),
      _filterProducts(ref.watch(visitOwnProductsProvider)),
      _filterProducts(ref.watch(visitReplacementProductsProvider)),
      _filterProducts(itemsAsync.valueOrNull ?? const []),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Products — ${customer?.name ?? ''}'),
        actions: [
          IconButton(
            tooltip: 'Expected order',
            onPressed: _openExpectedOrderSheet,
            icon: const Icon(AppIcons.eventNote, size: 20),
          ),
          if (catalog.isSyncing || targetsLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh products',
            onPressed: (catalog.isSyncing || targetsLoading) ? null : _refreshAll,
            icon: const Icon(AppIcons.refresh, size: 20),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final tab in _tabs)
              Tab(
                icon: Icon(tab.icon, size: 18),
                text: tab.shortTitle,
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(AppIcons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (catalog.fromCache && catalog.isSyncing)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Showing saved products · updating…',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  _ProductCardGrid(
                    title: _tabs[i].title,
                    accent: _tabs[i].accent,
                    products: tabProducts[i],
                    cart: _cart,
                    isLoading: i == 3
                        ? itemsAsync.isLoading
                        : targetsLoading && tabProducts[i].isEmpty,
                    hasError: i == 3
                        ? itemsAsync.hasError
                        : targetsError && tabProducts[i].isEmpty,
                    isSyncing: catalog.isSyncing || targetsLoading,
                    searchQuery: _searchController.text,
                    onRetry: _refreshAll,
                    onCardTap: (product) => _openProductDetail(
                      product: product,
                      accent: product.isOwnProduct
                          ? AppColors.ownProduct
                          : _tabs[i].accent,
                    ),
                    onDecrease: (id) => _adjustQty(id, -1),
                    onIncrease: (id) => _adjustQty(id, 1),
                  ),
              ],
            ),
          ),
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
}

class _ProductTab {
  const _ProductTab({
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String shortTitle;
  final IconData icon;
  final Color accent;
}

class _ProductCardGrid extends StatefulWidget {
  const _ProductCardGrid({
    required this.title,
    required this.accent,
    required this.products,
    required this.cart,
    required this.isLoading,
    required this.hasError,
    required this.isSyncing,
    required this.searchQuery,
    required this.onRetry,
    required this.onCardTap,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String title;
  final Color accent;
  final List<AlternativeProductModel> products;
  final Map<String, double> cart;
  final bool isLoading;
  final bool hasError;
  final bool isSyncing;
  final String searchQuery;
  final VoidCallback onRetry;
  final ValueChanged<AlternativeProductModel> onCardTap;
  final ValueChanged<String> onDecrease;
  final ValueChanged<String> onIncrease;

  @override
  State<_ProductCardGrid> createState() => _ProductCardGridState();
}

class _ProductCardGridState extends State<_ProductCardGrid> {
  static const _pageSize = 60;

  final _scrollController = ScrollController();
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _ProductCardGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.products.length != widget.products.length) {
      _visibleCount = _pageSize;
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_visibleCount >= widget.products.length) return;
    setState(() {
      _visibleCount =
          (_visibleCount + _pageSize).clamp(0, widget.products.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    if (widget.isLoading && widget.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.hasError && widget.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load products',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.products.isEmpty) {
      if (widget.isSyncing) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.searchQuery.trim().isEmpty
                ? 'No products in ${widget.title}'
                : 'No products match your search',
            style: theme.textTheme.muted,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final visibleCount = _visibleCount.clamp(0, widget.products.length);
    final visible = widget.products.take(visibleCount).toList();
    final hasMore = visibleCount < widget.products.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            '${widget.products.length} products',
            style: theme.textTheme.muted.copyWith(fontSize: 12),
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: visible.length + (hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              if (index >= visible.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final product = visible[index];
              final qty = widget.cart[product.id] ?? 0;
              final atLimit = product.hasQtyLimit && qty >= product.qtyLimit;
              final accent = product.isOwnProduct
                  ? AppColors.ownProduct
                  : widget.accent;

              return _ProductCard(
                product: product,
                accent: accent,
                qty: qty,
                onTap: () => widget.onCardTap(product),
                onDecrease: () => widget.onDecrease(product.id),
                onIncrease:
                    atLimit ? null : () => widget.onIncrease(product.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.accent,
    required this.qty,
    required this.onTap,
    required this.onDecrease,
    this.onIncrease,
  });

  final AlternativeProductModel product;
  final Color accent;
  final double qty;
  final VoidCallback onTap;
  final VoidCallback onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final inCart = qty > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: inCart
                ? accent.withValues(alpha: 0.08)
                : theme.colorScheme.card,
            borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
            border: Border.all(
              color: inCart ? accent : theme.colorScheme.border,
              width: inCart ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(AppIcons.inventory, color: accent, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.isOwnProduct
                          ? 'Own Products'
                          : (product.category.isNotEmpty
                              ? product.category
                              : product.id),
                      style: theme.textTheme.small.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (product.uomPriceLabel.isNotEmpty)
                          product.uomPriceLabel,
                        product.stockLimitLabel,
                      ].join(' · '),
                      style: theme.textTheme.muted.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyButton(
                    icon: AppIcons.removeCircle,
                    onPressed: inCart ? onDecrease : null,
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
                    onPressed: onIncrease,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductDetailPopup extends ConsumerStatefulWidget {
  const _ProductDetailPopup({
    required this.product,
    required this.accent,
    required this.qty,
    required this.onDecrease,
    required this.onIncrease,
    required this.onConfirm,
    this.initialUom,
  });

  final AlternativeProductModel product;
  final Color accent;
  final double qty;
  final String? initialUom;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final void Function(double qty, String uom, double unitPrice) onConfirm;

  @override
  ConsumerState<_ProductDetailPopup> createState() =>
      _ProductDetailPopupState();
}

class _ProductDetailPopupState extends ConsumerState<_ProductDetailPopup> {
  List<ItemUomOption> _uoms = const [];
  String _selectedUom = '';
  double _selectedPrice = 0;
  bool _loadingUoms = true;

  @override
  void initState() {
    super.initState();
    _selectedUom = (widget.initialUom?.trim().isNotEmpty ?? false)
        ? widget.initialUom!.trim()
        : widget.product.baseUom.trim();
    _selectedPrice = widget.product.unitPrice;
    _loadUoms();
  }

  Future<void> _loadUoms() async {
    final code = widget.product.id.trim();
    if (code.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loadingUoms = false;
        _uoms = _fallbackUoms();
        _applySelectedFromList();
      });
      return;
    }

    try {
      final uoms =
          await ref.read(itemsRepositoryProvider).fetchItemUoms(code);
      if (!mounted) return;
      setState(() {
        _uoms = uoms.isNotEmpty ? uoms : _fallbackUoms();
        _loadingUoms = false;
        _applySelectedFromList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uoms = _fallbackUoms();
        _loadingUoms = false;
        _applySelectedFromList();
      });
    }
  }

  List<ItemUomOption> _fallbackUoms() {
    final base = widget.product.baseUom.trim();
    if (base.isEmpty) return const [];
    return [
      ItemUomOption(
        code: base,
        retailPrice: widget.product.unitPrice,
        isBase: true,
      ),
    ];
  }

  void _applySelectedFromList() {
    if (_uoms.isEmpty) {
      _selectedUom = widget.product.baseUom.trim();
      _selectedPrice = widget.product.unitPrice;
      return;
    }

    ItemUomOption? match;
    for (final uom in _uoms) {
      if (uom.code.toUpperCase() == _selectedUom.toUpperCase()) {
        match = uom;
        break;
      }
    }
    match ??= _uoms.firstWhere((uom) => uom.isBase, orElse: () => _uoms.first);

    _selectedUom = match.code;
    _selectedPrice =
        match.retailPrice > 0 ? match.retailPrice : widget.product.unitPrice;
  }

  void _selectUom(ItemUomOption uom) {
    setState(() {
      _selectedUom = uom.code;
      _selectedPrice =
          uom.retailPrice > 0 ? uom.retailPrice : widget.product.unitPrice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final product = widget.product;
    final accent = widget.accent;
    final qty = widget.qty;
    final atLimit = product.hasQtyLimit && qty >= product.qtyLimit;
    final showUomPicker = !_loadingUoms && _uoms.length > 1;
    final priceLabel = _selectedPrice > 0
        ? CurrencyFormatter.format(
            _selectedPrice,
            decimalDigits: _selectedPrice % 1 == 0 ? 0 : 2,
          )
        : null;
    final activeUom = _selectedUom.isNotEmpty
        ? _selectedUom
        : product.baseUom.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Product details',
                    style: theme.textTheme.large.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
            const SizedBox(height: 8),
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              ),
              alignment: Alignment.center,
              child: Icon(AppIcons.inventory, color: accent, size: 48),
            ),
            const SizedBox(height: 16),
            if (product.category.isNotEmpty)
              Text(
                product.category,
                style: theme.textTheme.small.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              product.name,
              style: theme.textTheme.h4.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (product.id.isNotEmpty)
                  _DetailChip(label: 'Code ${product.id}', accent: accent),
                if (activeUom.isNotEmpty)
                  _DetailChip(label: activeUom, accent: accent),
                if (priceLabel != null)
                  _DetailChip(label: priceLabel, accent: accent),
                _DetailChip(label: product.stockLimitLabel, accent: accent),
              ],
            ),
            if (product.details.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                product.details,
                style: theme.textTheme.muted.copyWith(fontSize: 13),
              ),
            ],
            if (_loadingUoms) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
            if (showUomPicker) ...[
              const SizedBox(height: 16),
              Text(
                'Unit of measure',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final uom in _uoms)
                    ChoiceChip(
                      label: Text(
                        uom.retailPrice > 0
                            ? '${uom.code} · ${CurrencyFormatter.format(
                                uom.retailPrice,
                                decimalDigits:
                                    uom.retailPrice % 1 == 0 ? 0 : 2,
                              )}'
                            : uom.code,
                      ),
                      selected:
                          uom.code.toUpperCase() == _selectedUom.toUpperCase(),
                      onSelected: (_) => _selectUom(uom),
                      selectedColor: accent.withValues(alpha: 0.18),
                      labelStyle: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            uom.code.toUpperCase() == _selectedUom.toUpperCase()
                                ? accent
                                : theme.colorScheme.foreground,
                      ),
                      side: BorderSide(
                        color:
                            uom.code.toUpperCase() == _selectedUom.toUpperCase()
                                ? accent
                                : theme.colorScheme.border,
                      ),
                      showCheckmark: false,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    'Quantity',
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _QtyButton(
                    icon: AppIcons.removeCircle,
                    onPressed: qty > 0 ? widget.onDecrease : null,
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      qty.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _QtyButton(
                    icon: AppIcons.addCircle,
                    onPressed: atLimit ? null : widget.onIncrease,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final nextQty = qty <= 0 ? 1.0 : qty;
                final uom = activeUom.isNotEmpty ? activeUom : 'PCS';
                widget.onConfirm(nextQty, uom, _selectedPrice);
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: accent,
              ),
              child: Text(qty > 0 ? 'Update cart' : 'Add to cart'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.small.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ExpectedOrderSheet extends StatelessWidget {
  const _ExpectedOrderSheet({
    required this.cartProducts,
    required this.cart,
    required this.totalQty,
    required this.totalAmount,
    required this.productController,
    required this.qtyController,
    required this.remarksController,
    required this.dateController,
    required this.onPickDate,
    required this.onSave,
  });

  final List<AlternativeProductModel> cartProducts;
  final Map<String, double> cart;
  final double totalQty;
  final double totalAmount;
  final TextEditingController productController;
  final TextEditingController qtyController;
  final TextEditingController remarksController;
  final TextEditingController dateController;
  final VoidCallback onPickDate;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      child: SizedBox(
        height: maxHeight,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(AppIcons.eventNote, size: 20, color: AppColors.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Expected Order',
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
              if (cartProducts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.brandContainer.withValues(alpha: 0.4),
                    borderRadius:
                        BorderRadius.circular(AppDecorations.radiusMd),
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
                              style:
                                  theme.textTheme.muted.copyWith(fontSize: 13),
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
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AppTextField(
                controller: productController,
                label: 'Product',
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: qtyController,
                label: 'Quantity',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: dateController,
                label: 'Expected Date',
                readOnly: true,
                prefixIcon: AppIcons.calendar,
                onTap: onPickDate,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: remarksController,
                label: 'Remarks',
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onSave,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('Save Expected Order'),
              ),
            ],
          ),
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

class _CartSheet extends StatelessWidget {
  const _CartSheet({
    required this.products,
    required this.cart,
    required this.unitPrices,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
    required this.onClear,
    required this.onExpectedOrder,
  });

  final List<AlternativeProductModel> products;
  final Map<String, double> cart;
  final Map<String, double> unitPrices;
  final ValueChanged<String> onDecrease;
  final ValueChanged<String> onIncrease;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;
  final VoidCallback onExpectedOrder;

  double _priceFor(AlternativeProductModel product) =>
      unitPrices[product.id] ?? product.unitPrice;

  double get _totalQty =>
      cart.values.fold<double>(0, (sum, qty) => sum + qty);

  double get _totalAmount => products.fold<double>(0, (sum, product) {
        final qty = cart[product.id] ?? 0;
        if (qty <= 0) return sum;
        return sum + (_priceFor(product) * qty);
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
                        final atLimit =
                            product.hasQtyLimit && qty >= product.qtyLimit;
                        final lineAmount = _priceFor(product) * qty;
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
                                  color:
                                      AppColors.brand.withValues(alpha: 0.12),
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
                                        product.stockLimitLabel,
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
                                    onPressed: atLimit
                                        ? null
                                        : () => onIncrease(product.id),
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
