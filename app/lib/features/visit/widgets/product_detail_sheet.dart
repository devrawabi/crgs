import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../orders/providers/orders_provider.dart';
import '../providers/product_review_provider.dart';
import '../providers/visit_provider.dart';

const _previewProductLimit = 3;

class ProductSheetResult {
  const ProductSheetResult({this.reviewSubmitted = false});

  final bool reviewSubmitted;
}

enum _ProductKind { ordered, newPromotion, replacement, own }

class _ProductViewItem {
  const _ProductViewItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.details,
    required this.category,
    required this.unitPrice,
    required this.kind,
    this.baseUom = '',
    this.quantity,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String details;
  final String category;
  final double unitPrice;
  final String baseUom;
  final _ProductKind kind;
  final double? quantity;

  String get uomPriceLabel {
    final uom = baseUom.trim().isNotEmpty
        ? baseUom.trim()
        : (kind == _ProductKind.ordered &&
                category.trim().isNotEmpty &&
                category.trim().length <= 10
            ? category.trim()
            : '');
    final price = unitPrice > 0
        ? (unitPrice % 1 == 0
            ? unitPrice.toStringAsFixed(0)
            : unitPrice.toStringAsFixed(2))
        : '';
    if (uom.isNotEmpty && price.isNotEmpty) return '$uom · $price';
    if (uom.isNotEmpty) return uom;
    if (price.isNotEmpty) return price;
    return '';
  }

  static _ProductViewItem fromOrdered(OrderedProductModel product) =>
      _ProductViewItem(
        id: product.id,
        name: product.name,
        imageUrl: product.imageUrl,
        details: product.details.isNotEmpty
            ? product.details
            : 'Previously ordered item from the customer\'s last bill.',
        category: product.category,
        unitPrice: product.unitPrice,
        baseUom: product.category.trim().length <= 10 ? product.category : '',
        quantity: product.quantity,
        kind: _ProductKind.ordered,
      );

  static _ProductViewItem fromTarget(
    AlternativeProductModel alt,
    _ProductKind kind,
  ) =>
      _ProductViewItem(
        id: alt.id,
        name: alt.name,
        imageUrl: alt.imageUrl,
        details: alt.details,
        category: alt.category,
        unitPrice: alt.unitPrice,
        baseUom: alt.baseUom,
        kind: kind,
      );

  static _ProductViewItem fromOwn(AlternativeProductModel alt) =>
      _ProductViewItem(
        id: alt.id,
        name: alt.name,
        imageUrl: alt.imageUrl,
        details: alt.details,
        category: alt.category,
        unitPrice: alt.unitPrice,
        baseUom: alt.baseUom,
        kind: _ProductKind.own,
      );
}

Future<ProductSheetResult?> showProductDetailSheet(
  BuildContext context, {
  required OrderedProductModel product,
  required String customerId,
  required String customerName,
  List<AlternativeProductModel> newProducts = const [],
  List<AlternativeProductModel> replacementProducts = const [],
  List<AlternativeProductModel> ownProducts = const [],
  Set<String> suggestedProductIds = const {},
  ValueChanged<String>? onSuggestionAdded,
}) {
  return showModalBottomSheet<ProductSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: ShadTheme.of(context).colorScheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProductDetailSheet(
      product: product,
      customerId: customerId,
      customerName: customerName,
      newProducts: newProducts,
      replacementProducts: replacementProducts,
      ownProducts: ownProducts,
      suggestedProductIds: suggestedProductIds,
      onSuggestionAdded: onSuggestionAdded,
    ),
  );
}

class ProductDetailSheet extends ConsumerStatefulWidget {
  const ProductDetailSheet({
    super.key,
    required this.product,
    required this.customerId,
    required this.customerName,
    this.newProducts = const [],
    this.replacementProducts = const [],
    this.ownProducts = const [],
    this.suggestedProductIds = const {},
    this.onSuggestionAdded,
  });

  final OrderedProductModel product;
  final String customerId;
  final String customerName;
  final List<AlternativeProductModel> newProducts;
  final List<AlternativeProductModel> replacementProducts;
  final List<AlternativeProductModel> ownProducts;
  final Set<String> suggestedProductIds;
  final ValueChanged<String>? onSuggestionAdded;

  @override
  ConsumerState<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends ConsumerState<ProductDetailSheet> {
  late final TextEditingController _reviewController;
  late final _ProductViewItem _orderedProduct;
  late final List<_ProductViewItem> _newProducts;
  late final List<_ProductViewItem> _replacementProducts;
  late final List<_ProductViewItem> _ownProducts;
  late final List<_ProductViewItem> _allProducts;
  late String _selectedId;
  final _cart = <String, double>{};
  final _imagePicker = ImagePicker();
  Uint8List? _reviewImageBytes;
  String? _reviewImageName;
  bool _isSubmittingReview = false;
  bool _reviewSubmitted = false;

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController();
    _orderedProduct = _ProductViewItem.fromOrdered(widget.product);
    _newProducts = widget.newProducts
        .map((p) => _ProductViewItem.fromTarget(p, _ProductKind.newPromotion))
        .toList();
    _replacementProducts = widget.replacementProducts
        .map((p) => _ProductViewItem.fromTarget(p, _ProductKind.replacement))
        .toList();
    _ownProducts = widget.ownProducts.map(_ProductViewItem.fromOwn).toList();
    _allProducts = [
      _orderedProduct,
      ..._newProducts,
      ..._replacementProducts,
      ..._ownProducts,
    ];
    _selectedId = widget.product.id;
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  _ProductViewItem get _current =>
      _allProducts.firstWhere((p) => p.id == _selectedId);

  void _selectProduct(String id) {
    if (_selectedId == id) return;
    setState(() => _selectedId = id);
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

  List<_ProductViewItem> _cartProducts() {
    final catalog = <String, _ProductViewItem>{
      for (final product in _allProducts) product.id: product,
    };

    return [
      for (final id in _cart.keys)
        catalog[id] ??
            _ProductViewItem(
              id: id,
              name: id,
              imageUrl: '',
              details: '',
              category: 'Cart',
              unitPrice: 0,
              kind: _ProductKind.own,
            ),
    ];
  }

  void _openAllProducts({
    required String title,
    required IconData icon,
    required Color accent,
    required List<_ProductViewItem> products,
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
              selectedId: _selectedId,
              onSelect: (id) {
                _selectProduct(id);
                setModalState(() {});
              },
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

  Future<void> _saveExpectedOrder() async {
    final products = _cartProducts()
        .where((product) => (_cart[product.id] ?? 0) > 0)
        .toList();

    if (products.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Add products to cart before saving')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    final employeeCode = user?.employeeCode.trim() ?? '';
    if (employeeCode.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Employee code missing. Please log in again.')),
      );
      return;
    }

    final customer = ref.read(customerByIdProvider(widget.customerId));
    final visit = ref.read(visitProvider);
    final route = () {
      final visitRoute = visit?.route.trim() ?? '';
      if (visitRoute.isNotEmpty) return visitRoute;
      final routeId = customer?.routeId.trim() ?? '';
      if (routeId.isNotEmpty) return routeId;
      return customer?.routeName.trim() ?? '';
    }();

    if (route.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Customer route is missing')),
      );
      return;
    }

    try {
      await ref.read(ordersProvider.notifier).saveOrder(
            employeeCode: employeeCode,
            customerId: widget.customerId,
            customerName: widget.customerName,
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
                      : (product.kind == _ProductKind.ordered &&
                              product.category.trim().isNotEmpty &&
                              product.category.trim().length <= 10
                          ? product.category.trim()
                          : 'PCS'),
                ),
            ],
            expectedDate: DateTime.now().add(const Duration(days: 7)),
            remarks: '',
          );

      if (!mounted) return;
      setState(() => _cart.clear());
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Expected order saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to save expected order: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
              onSaveExpectedOrder: () {
                Navigator.of(context).pop();
                _saveExpectedOrder();
              },
            );
          },
        );
      },
    );
  }

  Future<void> _pickReviewImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _reviewImageBytes = bytes;
        _reviewImageName = file.name;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Could not pick image: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showReviewImageSourceSheet() async {
    if (_isSubmittingReview) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: ShadTheme.of(context).colorScheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.camera, color: AppColors.brand),
                  title: const Text('Take photo'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickReviewImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(AppIcons.image, color: AppColors.brand),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _pickReviewImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearReviewImage() {
    if (_isSubmittingReview) return;
    setState(() {
      _reviewImageBytes = null;
      _reviewImageName = null;
    });
  }

  Future<void> _submitProductReview() async {
    if (_isSubmittingReview) return;

    final reason = _reviewController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Enter product review details')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    final employeeCode = user?.employeeCode.trim() ?? '';
    if (employeeCode.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Employee code missing. Please log in again.'),
        ),
      );
      return;
    }

    final customer = ref.read(customerByIdProvider(widget.customerId));
    final visit = ref.read(visitProvider);
    final route = () {
      final visitRoute = visit?.route.trim() ?? '';
      if (visitRoute.isNotEmpty) return visitRoute;
      final routeId = customer?.routeId.trim() ?? '';
      if (routeId.isNotEmpty) return routeId;
      return customer?.routeName.trim() ?? '';
    }();

    if (route.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Customer route is missing')),
      );
      return;
    }

    final itemCode = widget.product.id.trim();
    final itemName = widget.product.name.trim().isNotEmpty
        ? widget.product.name.trim()
        : itemCode;
    if (itemCode.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Item code is missing')),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);
    try {
      await ref.read(productReviewsRepositoryProvider).submitReview(
            employeeCode: employeeCode,
            route: route,
            customerCode: widget.customerId,
            customerName: widget.customerName,
            itemCode: itemCode,
            itemName: itemName,
            reason: reason,
            imageBytes: _reviewImageBytes,
            imageFileName: _reviewImageName,
          );

      if (!mounted) return;
      setState(() {
        _reviewSubmitted = true;
        _reviewController.clear();
        _reviewImageBytes = null;
        _reviewImageName = null;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Product review submitted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to submit review: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  void _close() {
    Navigator.of(context).pop(
      ProductSheetResult(reviewSubmitted: _reviewSubmitted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final current = _current;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (_, scrollController) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: _ProductHeader(
                    key: ValueKey(current.id),
                    item: current,
                    theme: theme,
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: Column(
                    key: ValueKey('details-${current.id}'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Product Details',
                        style: theme.textTheme.large.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.brandContainer.withValues(alpha: 0.35),
                          borderRadius:
                              BorderRadius.circular(AppDecorations.radiusMd),
                          border: Border.all(
                            color: AppColors.brand.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Text(
                          current.details,
                          style: theme.textTheme.muted.copyWith(
                            height: 1.5,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ProductReviewSection(
                  reviewController: _reviewController,
                  isSubmitting: _isSubmittingReview,
                  imageBytes: _reviewImageBytes,
                  imageName: _reviewImageName,
                  onAddImage: _showReviewImageSourceSheet,
                  onRemoveImage: _clearReviewImage,
                  onSubmit: _submitProductReview,
                ),
                const SizedBox(height: 18),
                if (_newProducts.isNotEmpty) ...[
                  _ProductCarouselSection(
                    title: 'New Products',
                    icon: AppIcons.addCircle,
                    accent: AppColors.successGreen,
                    products: _newProducts,
                    theme: theme,
                    selectedId: _selectedId,
                    cart: _cart,
                    onSelect: _selectProduct,
                    onDecrease: (id) => _adjustQty(id, -1),
                    onIncrease: (id) => _adjustQty(id, 1),
                    onViewMore: () => _openAllProducts(
                      title: 'New Products',
                      icon: AppIcons.addCircle,
                      accent: AppColors.successGreen,
                      products: _newProducts,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_replacementProducts.isNotEmpty) ...[
                  _ProductCarouselSection(
                    title: 'Product Replacement',
                    icon: AppIcons.campaign,
                    accent: AppColors.outstandingOrange,
                    products: _replacementProducts,
                    theme: theme,
                    selectedId: _selectedId,
                    cart: _cart,
                    onSelect: _selectProduct,
                    onDecrease: (id) => _adjustQty(id, -1),
                    onIncrease: (id) => _adjustQty(id, 1),
                    onViewMore: () => _openAllProducts(
                      title: 'Product Replacement',
                      icon: AppIcons.campaign,
                      accent: AppColors.outstandingOrange,
                      products: _replacementProducts,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_ownProducts.isNotEmpty)
                  _ProductCarouselSection(
                    title: 'Own Products',
                    icon: AppIcons.inventory,
                    accent: AppColors.primaryBlue,
                    products: _ownProducts,
                    theme: theme,
                    selectedId: _selectedId,
                    cart: _cart,
                    onSelect: _selectProduct,
                    onDecrease: (id) => _adjustQty(id, -1),
                    onIncrease: (id) => _adjustQty(id, 1),
                    onViewMore: () => _openAllProducts(
                      title: 'Own Products',
                      icon: AppIcons.inventory,
                      accent: AppColors.primaryBlue,
                      products: _ownProducts,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
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
                if (_cart.isNotEmpty) ...[
                  ShadButton(
                    onPressed: _openCart,
                    width: double.infinity,
                    leading: Badge(
                      label: Text('${_cart.length}'),
                      child: const Icon(AppIcons.cart, size: 18),
                    ),
                    child: const Text('Cart'),
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: ShadButton.outline(
                        onPressed: _close,
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductReviewSection extends StatelessWidget {
  const _ProductReviewSection({
    required this.reviewController,
    required this.isSubmitting,
    required this.imageBytes,
    required this.imageName,
    required this.onAddImage,
    required this.onRemoveImage,
    required this.onSubmit,
  });

  final TextEditingController reviewController;
  final bool isSubmitting;
  final Uint8List? imageBytes;
  final String? imageName;
  final VoidCallback onAddImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final hasImage = imageBytes != null && imageBytes!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(AppIcons.report, size: 18, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Customer Product Feedback',
                  style: theme.textTheme.large.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Capture product review or item name issues.',
            style: theme.textTheme.muted.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: reviewController,
            label: 'Reason',
            hint: 'Customer feedback about this product...',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Text(
            'Photo (optional)',
            style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (hasImage)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
                  child: Image.memory(
                    imageBytes!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isSubmitting ? null : onRemoveImage,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          AppIcons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                if ((imageName ?? '').trim().isNotEmpty)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    right: 48,
                    child: Text(
                      imageName!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small.copyWith(
                        color: Colors.white,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black54),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          else
            ShadButton.outline(
              onPressed: isSubmitting ? null : onAddImage,
              width: double.infinity,
              leading: const Icon(AppIcons.camera, size: 16),
              child: const Text('Add Photo'),
            ),
          if (hasImage) ...[
            const SizedBox(height: 8),
            ShadButton.outline(
              onPressed: isSubmitting ? null : onAddImage,
              width: double.infinity,
              leading: const Icon(AppIcons.image, size: 16),
              child: const Text('Replace Photo'),
            ),
          ],
          const SizedBox(height: 12),
          ShadButton(
            onPressed: isSubmitting ? null : onSubmit,
            width: double.infinity,
            leading: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIcons.upload, size: 16),
            child: Text(isSubmitting ? 'Submitting...' : 'Submit Feedback'),
          ),
        ],
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({
    super.key,
    required this.item,
    required this.theme,
  });

  final _ProductViewItem item;
  final ShadThemeData theme;

  @override
  Widget build(BuildContext context) {
    final meta = switch (item.kind) {
      _ProductKind.ordered =>
        '${item.category} · Qty ${item.quantity!.toStringAsFixed(0)} · ${CurrencyFormatter.format(item.unitPrice)}',
      _ProductKind.newPromotion =>
        '${item.category} · New product · ${item.unitPrice > 0 ? CurrencyFormatter.format(item.unitPrice) : 'Tap to review'}',
      _ProductKind.replacement =>
        '${item.category} · Replacement · ${item.unitPrice > 0 ? CurrencyFormatter.format(item.unitPrice) : 'Tap to review'}',
      _ProductKind.own =>
        '${item.category} · Own product · ${item.unitPrice > 0 ? CurrencyFormatter.format(item.unitPrice) : 'Push on visit'}',
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
      child: Stack(
        children: [
          ProductNetworkImage(
            imageUrl: item.imageUrl,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.kind == _ProductKind.ordered)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Ordered Item',
                        style: theme.textTheme.small.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    )
                  else if (item.kind == _ProductKind.newPromotion)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'New Product',
                        style: theme.textTheme.small.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    )
                  else if (item.kind == _ProductKind.replacement)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            AppColors.outstandingOrange.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Replacement',
                        style: theme.textTheme.small.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Own Product',
                        style: theme.textTheme.small.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  Text(
                    item.name,
                    style: theme.textTheme.h4.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    style: theme.textTheme.small.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
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

class _SelectableProductCard extends StatelessWidget {
  const _SelectableProductCard({
    required this.item,
    required this.theme,
    required this.accent,
    required this.isSelected,
    required this.qty,
    required this.onTap,
    required this.onDecrease,
    required this.onIncrease,
  });

  final _ProductViewItem item;
  final ShadThemeData theme;
  final Color accent;
  final bool isSelected;
  final double qty;
  final VoidCallback onTap;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final inCart = qty > 0;

    return SizedBox(
      width: 156,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
              border: Border.all(
                color: isSelected
                    ? AppColors.brand
                    : inCart
                        ? accent
                        : theme.colorScheme.border,
                width: isSelected || inCart ? 2 : 1,
              ),
              color: isSelected
                  ? AppColors.brandContainer.withValues(alpha: 0.45)
                  : inCart
                      ? accent.withValues(alpha: 0.08)
                      : theme.colorScheme.card,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProductNetworkImage(
                  imageUrl: item.imageUrl,
                  height: 72,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (item.kind) {
                            _ProductKind.ordered => 'Ordered',
                            _ProductKind.newPromotion => 'New',
                            _ProductKind.replacement => 'Replace',
                            _ProductKind.own => 'Own',
                          },
                          style: theme.textTheme.small.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.name,
                          style: theme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.uomPriceLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.uomPriceLabel,
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
        ),
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
    required this.theme,
    required this.selectedId,
    required this.cart,
    required this.onSelect,
    required this.onDecrease,
    required this.onIncrease,
    required this.onViewMore,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<_ProductViewItem> products;
  final ShadThemeData theme;
  final String selectedId;
  final Map<String, double> cart;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDecrease;
  final ValueChanged<String> onIncrease;
  final VoidCallback onViewMore;

  @override
  Widget build(BuildContext context) {
    final previewProducts = products.take(_previewProductLimit).toList();
    final hasMore = products.length > _previewProductLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
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
                hasMore ? 'View more (${products.length})' : 'View all',
                style: theme.textTheme.small.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 212,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: previewProducts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final item = previewProducts[i];
              return _SelectableProductCard(
                item: item,
                theme: theme,
                accent: accent,
                isSelected: item.id == selectedId,
                qty: cart[item.id] ?? 0,
                onTap: () => onSelect(item.id),
                onDecrease: () => onDecrease(item.id),
                onIncrease: () => onIncrease(item.id),
              );
            },
          ),
        ),
      ],
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
    required this.selectedId,
    required this.onSelect,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<_ProductViewItem> products;
  final Map<String, double> cart;
  final String selectedId;
  final ValueChanged<String> onSelect;
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

  List<_ProductViewItem> get _filteredProducts {
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
                        final isSelected = product.id == widget.selectedId;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => widget.onSelect(product.id),
                            borderRadius: BorderRadius.circular(
                              AppDecorations.radiusMd,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.brandContainer
                                        .withValues(alpha: 0.45)
                                    : inCart
                                        ? widget.accent.withValues(alpha: 0.08)
                                        : theme.colorScheme.card,
                                borderRadius: BorderRadius.circular(
                                  AppDecorations.radiusMd,
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.brand
                                      : inCart
                                          ? widget.accent
                                          : theme.colorScheme.border,
                                  width: isSelected || inCart ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: ProductNetworkImage(
                                      imageUrl: product.imageUrl,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style:
                                              theme.textTheme.large.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            product.category,
                                            if (product
                                                .uomPriceLabel.isNotEmpty)
                                              product.uomPriceLabel,
                                          ].join(' · '),
                                          style:
                                              theme.textTheme.muted.copyWith(
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
                                            ? () => widget
                                                .onDecrease(product.id)
                                            : null,
                                      ),
                                      SizedBox(
                                        width: 28,
                                        child: Text(
                                          qty.toStringAsFixed(0),
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.small
                                              .copyWith(
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
                            ),
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
    required this.onSaveExpectedOrder,
  });

  final List<_ProductViewItem> products;
  final Map<String, double> cart;
  final ValueChanged<String> onDecrease;
  final ValueChanged<String> onIncrease;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;
  final VoidCallback onSaveExpectedOrder;

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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ProductNetworkImage(
                                  imageUrl: product.imageUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
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
                      onPressed: onSaveExpectedOrder,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.brand,
                      ),
                      icon: const Icon(AppIcons.eventNote, size: 18),
                      label: const Text('Save Expected Order'),
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

class ProductNetworkImage extends StatelessWidget {
  const ProductNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: AppColors.brandContainer.withValues(alpha: 0.35),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: AppColors.brandContainer.withValues(alpha: 0.35),
        alignment: Alignment.center,
        child: const Icon(AppIcons.inventory, color: AppColors.brand),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
