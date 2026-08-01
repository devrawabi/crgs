import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../dashboard/providers/targets_provider.dart';
import '../../products/providers/items_provider.dart';

AlternativeProductModel _targetProductToAlternative({
  required String code,
  required String name,
  required int index,
  required String category,
  required String details,
  required String idPrefix,
  String baseUom = '',
  double unitPrice = 0,
  double stock = 0,
  double qtyLimit = 0,
  String imageUrl = '',
  bool isOwnProduct = false,
}) {
  return AlternativeProductModel(
    id: code.isNotEmpty ? code : '$idPrefix-$index-${name.hashCode}',
    name: name,
    imageUrl: imageUrl,
    details: details,
    category: category,
    baseUom: baseUom,
    unitPrice: unitPrice,
    stock: stock,
    qtyLimit: qtyLimit,
    isOwnProduct: isOwnProduct,
  );
}

bool _isTargetType(String raw, String expected) {
  final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
  return normalized == expected;
}

List<AlternativeProductModel> _enrichFromCatalogMap(
  List<AlternativeProductModel> products,
  Map<String, AlternativeProductModel> byId,
) {
  if (products.isEmpty || byId.isEmpty) return products;

  return products.map((product) {
    final match = byId[product.id.trim().toLowerCase()];
    if (match == null) return product;
    return AlternativeProductModel(
      id: product.id.isNotEmpty ? product.id : match.id,
      name: match.name.isNotEmpty ? match.name : product.name,
      imageUrl: match.imageUrl.isNotEmpty ? match.imageUrl : product.imageUrl,
      details: product.details,
      category: product.category.isNotEmpty ? product.category : match.category,
      baseUom: product.baseUom.isNotEmpty ? product.baseUom : match.baseUom,
      unitPrice: product.unitPrice > 0 ? product.unitPrice : match.unitPrice,
      stock: product.stock > 0 ? product.stock : match.stock,
      qtyLimit: product.qtyLimit > 0 ? product.qtyLimit : match.qtyLimit,
      isOwnProduct: product.isOwnProduct || match.isOwnProduct,
    );
  }).toList(growable: false);
}

List<AlternativeProductModel> _productsForTargetType(
  ExecutiveTargetsData? targets,
  String type, {
  required String category,
  required String detailsFor,
  required String idPrefix,
  Map<String, AlternativeProductModel> catalogById = const {},
}) {
  if (targets == null) return const [];

  final entries = <String, ({
    String code,
    String name,
    String baseUom,
    double unitPrice,
    double stock,
    double qtyLimit,
  })>{};
  for (final target in targets.productTargets
      .where((target) => _isTargetType(target.type, type))) {
    final codes = target.products;
    final names = target.displayProductNames;
    // Prefer product codes as the source of truth when names are missing.
    final count = names.isNotEmpty ? names.length : codes.length;
    for (var i = 0; i < count; i++) {
      final code = i < codes.length ? codes[i].trim() : '';
      final name = i < names.length ? names[i].trim() : code;
      if (name.isEmpty && code.isEmpty) continue;
      final key = (code.isNotEmpty ? code : name).toLowerCase();
      final existing = entries[key];
      if (existing != null &&
          (existing.baseUom.isNotEmpty ||
              existing.unitPrice > 0 ||
              existing.stock > 0 ||
              existing.qtyLimit > 0)) {
        continue;
      }
      entries[key] = (
        code: code.isNotEmpty ? code : name,
        name: name.isNotEmpty ? name : code,
        baseUom: target.baseUomAt(i),
        unitPrice: target.retailPriceAt(i),
        stock: target.currentStockAt(i),
        qtyLimit: target.quantityLimitAt(i),
      );
    }
  }

  final uniqueEntries = entries.values.toList();

  final products = [
    for (var i = 0; i < uniqueEntries.length; i++)
      _targetProductToAlternative(
        code: uniqueEntries[i].code,
        name: uniqueEntries[i].name,
        index: i,
        category: category,
        details: '$detailsFor — push with customer on this visit.',
        idPrefix: idPrefix,
        baseUom: uniqueEntries[i].baseUom,
        unitPrice: uniqueEntries[i].unitPrice,
        stock: uniqueEntries[i].stock,
        qtyLimit: uniqueEntries[i].qtyLimit,
        isOwnProduct: type == 'own_products',
      ),
  ];

  return _enrichFromCatalogMap(products, catalogById);
}

final visitNewProductsProvider = Provider<List<AlternativeProductModel>>((ref) {
  final targets = ref.watch(executiveTargetsProvider).valueOrNull;
  final catalogById = ref.watch(itemsByIdProvider);
  return _productsForTargetType(
    targets,
    'new_promotion',
    category: 'New Products',
    detailsFor: 'New product promotion',
    idPrefix: 'new',
    catalogById: catalogById,
  );
});

final visitReplacementProductsProvider =
    Provider<List<AlternativeProductModel>>((ref) {
  final targets = ref.watch(executiveTargetsProvider).valueOrNull;
  final catalogById = ref.watch(itemsByIdProvider);
  return _productsForTargetType(
    targets,
    'replacement',
    category: 'Product Replacement',
    detailsFor: 'Product replacement target',
    idPrefix: 'replacement',
    catalogById: catalogById,
  );
});

final visitOwnProductsProvider = Provider<List<AlternativeProductModel>>((ref) {
  final targets = ref.watch(executiveTargetsProvider).valueOrNull;
  final catalogById = ref.watch(itemsByIdProvider);
  return _productsForTargetType(
    targets,
    'own_products',
    category: 'Own Products',
    detailsFor: 'Own brand product',
    idPrefix: 'own',
    catalogById: catalogById,
  );
});

List<AlternativeProductModel> targetProductsForOrderedItem(
  List<AlternativeProductModel> products,
  OrderedProductModel ordered,
) {
  final orderedId = ordered.id.trim().toLowerCase();
  final orderedName = ordered.name.trim().toLowerCase();

  return products
      .where((product) {
        final id = product.id.trim().toLowerCase();
        final name = product.name.trim().toLowerCase();
        if (orderedId.isNotEmpty && id == orderedId) return false;
        if (orderedName.isNotEmpty && name == orderedName) return false;
        return true;
      })
      .toList();
}
