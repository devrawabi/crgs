import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/items_repository.dart';

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  return ItemsRepository(ref.watch(apiClientProvider));
});

/// Full ITEMMASTER catalog for the Products Recommended tab.
final allItemsProvider =
    FutureProvider.autoDispose<List<AlternativeProductModel>>((ref) async {
  return ref.watch(itemsRepositoryProvider).fetchItems(limit: 2000);
});
