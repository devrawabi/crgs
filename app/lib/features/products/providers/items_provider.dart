import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../data/local/items_local_cache.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/items_repository.dart';

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  return ItemsRepository(ref.watch(apiClientProvider));
});

/// Catalog state: cached items shown immediately; sync runs in the background.
class ItemsCatalogState {
  const ItemsCatalogState({
    this.items = const [],
    this.isSyncing = false,
    this.isHydrated = false,
    this.fromCache = false,
    this.error,
  });

  final List<AlternativeProductModel> items;
  final bool isSyncing;
  final bool isHydrated;
  final bool fromCache;
  final Object? error;

  bool get hasItems => items.isNotEmpty;

  ItemsCatalogState copyWith({
    List<AlternativeProductModel>? items,
    bool? isSyncing,
    bool? isHydrated,
    bool? fromCache,
    Object? error,
    bool clearError = false,
  }) {
    return ItemsCatalogState(
      items: items ?? this.items,
      isSyncing: isSyncing ?? this.isSyncing,
      isHydrated: isHydrated ?? this.isHydrated,
      fromCache: fromCache ?? this.fromCache,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ItemsCatalogNotifier extends StateNotifier<ItemsCatalogState> {
  ItemsCatalogNotifier(this._repository) : super(const ItemsCatalogState()) {
    unawaited(_bootstrap());
  }

  final ItemsRepository _repository;
  bool _started = false;

  Future<void> _bootstrap() async {
    if (_started) return;
    _started = true;

    // 1) Paint from Hive immediately — no network, no UI freeze.
    final cached = await _repository.loadCachedItems();
    if (cached.isNotEmpty) {
      state = state.copyWith(
        items: cached,
        isHydrated: true,
        fromCache: true,
        clearError: true,
      );
    } else {
      state = state.copyWith(isHydrated: true);
    }

    // 2) Background sync. Schema bump forces a full OWNPRODUCT refresh.
    await refresh(force: cached.isEmpty || ItemsLocalCache.needsSchemaResync);
  }

  Future<void> refresh({bool force = false}) async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true, clearError: true);
    try {
      final items = await _repository.syncCatalog(
        force: force,
        existingItems: state.items,
      );
      if (!mounted) return;
      // Prefer merge result from sync; if delta returned a partial merge from
      // Hive, keep sorted list for UI consumers.
      state = state.copyWith(
        items: items,
        isSyncing: false,
        fromCache: false,
        isHydrated: true,
        clearError: true,
      );
    } catch (error) {
      if (!mounted) return;
      // Keep stale cache visible on failure — better offline UX.
      state = state.copyWith(
        isSyncing: false,
        isHydrated: true,
        error: state.items.isEmpty ? error : null,
      );
    }
  }

  /// Point lookup without exposing the full list to every watcher.
  AlternativeProductModel? findById(String id) {
    final key = id.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final item in state.items) {
      if (item.id.trim().toLowerCase() == key) return item;
    }
    return ItemsLocalCache.getById(id);
  }
}

final itemsCatalogProvider =
    StateNotifierProvider<ItemsCatalogNotifier, ItemsCatalogState>((ref) {
  return ItemsCatalogNotifier(ref.watch(itemsRepositoryProvider));
});

/// Compatibility provider used by product screens (list of all products).
/// Prefer [itemsCatalogProvider] when you need sync status.
final allItemsProvider =
    Provider<AsyncValue<List<AlternativeProductModel>>>((ref) {
  final catalog = ref.watch(itemsCatalogProvider);

  if (!catalog.isHydrated && catalog.items.isEmpty) {
    return const AsyncValue.loading();
  }
  if (catalog.error != null && catalog.items.isEmpty) {
    return AsyncValue.error(catalog.error!, StackTrace.current);
  }
  // Show cached/synced data even while a background sync is running.
  return AsyncValue.data(catalog.items);
});

/// Id → product map rebuilt only when the catalog list identity changes.
/// Visit/target enrichers should watch this (or look up by id) instead of
/// rebuilding maps from [allItemsProvider] on every dependent rebuild.
final itemsByIdProvider = Provider<Map<String, AlternativeProductModel>>((ref) {
  final items = ref.watch(itemsCatalogProvider.select((s) => s.items));
  if (items.isEmpty) return const {};
  return {
    for (final item in items) item.id.trim().toLowerCase(): item,
  };
});
