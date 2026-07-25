import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../dashboard/providers/targets_provider.dart';

AlternativeProductModel _targetProductToAlternative({
  required String code,
  required String name,
  required int index,
  required String category,
  required String details,
  required String idPrefix,
  String baseUom = '',
  double unitPrice = 0,
}) {
  return AlternativeProductModel(
    id: code.isNotEmpty ? code : '$idPrefix-$index-${name.hashCode}',
    name: name,
    imageUrl: '',
    details: details,
    category: category,
    baseUom: baseUom,
    unitPrice: unitPrice,
  );
}

List<AlternativeProductModel> _productsForTargetType(
  ExecutiveTargetsData? targets,
  String type, {
  required String category,
  required String detailsFor,
  required String idPrefix,
}) {
  if (targets == null) return const [];

  final entries = <String, ({String code, String name, String baseUom, double unitPrice})>{};
  for (final target in targets.productTargets.where((target) => target.type == type)) {
    final codes = target.products;
    final names = target.displayProductNames;
    for (var i = 0; i < names.length; i++) {
      final name = names[i].trim();
      if (name.isEmpty) continue;
      final code = i < codes.length ? codes[i].trim() : name;
      final key = code.isNotEmpty ? code.toLowerCase() : name.toLowerCase();
      final existing = entries[key];
      if (existing != null &&
          (existing.baseUom.isNotEmpty || existing.unitPrice > 0)) {
        continue;
      }
      entries[key] = (
        code: code,
        name: name,
        baseUom: target.baseUomAt(i),
        unitPrice: target.retailPriceAt(i),
      );
    }
  }

  final uniqueEntries = entries.values.toList();

  return [
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
      ),
  ];
}

final visitNewProductsProvider = Provider<List<AlternativeProductModel>>((ref) {
  final targets = ref.watch(executiveTargetsProvider).valueOrNull;
  return _productsForTargetType(
    targets,
    'new_promotion',
    category: 'New Products',
    detailsFor: 'New product promotion',
    idPrefix: 'new',
  );
});

final visitReplacementProductsProvider =
    Provider<List<AlternativeProductModel>>((ref) {
  final targets = ref.watch(executiveTargetsProvider).valueOrNull;
  return _productsForTargetType(
    targets,
    'replacement',
    category: 'Product Replacement',
    detailsFor: 'Product replacement target',
    idPrefix: 'replacement',
  );
});

final visitOwnProductsProvider = Provider<List<AlternativeProductModel>>((ref) {
  final targets = ref.watch(executiveTargetsProvider).valueOrNull;
  return _productsForTargetType(
    targets,
    'own_products',
    category: 'Own Products',
    detailsFor: 'Own brand product',
    idPrefix: 'own',
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
