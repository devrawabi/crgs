import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/customers_repository.dart';

/// Recency window (in days) used to decide whether a customer is "missing".
/// A value of 0 means "all missing" (any customer not billed today).
const int kDefaultMissingDays = 30;

class CustomerFilter {
  const CustomerFilter({
    this.searchQuery = '',
    this.routeId,
    this.category,
    this.priority,
    this.missingDays = kDefaultMissingDays,
  });

  final String searchQuery;
  final String? routeId;
  final String? category;
  final CustomerPriority? priority;
  final int missingDays;

  CustomerFilter copyWith({
    String? searchQuery,
    String? routeId,
    String? category,
    CustomerPriority? priority,
    int? missingDays,
    bool clearRouteId = false,
    bool clearPriority = false,
  }) => CustomerFilter(
    searchQuery: searchQuery ?? this.searchQuery,
    routeId: clearRouteId ? null : (routeId ?? this.routeId),
    category: category ?? this.category,
    priority: clearPriority ? null : (priority ?? this.priority),
    missingDays: missingDays ?? this.missingDays,
  );

  /// Cache key for list pages. Day-wise window only affects Missing results
  /// (and IS_MISSING enrichment when that tab is active).
  String get listCacheKey {
    final priorityKey = priority?.name ?? 'all';
    final missingKey = priority == CustomerPriority.missing
        ? missingDays.toString()
        : '-';
    // outv2: Outstanding folds CASHCUSTOMERBALANCE dues (bust credit-only caches).
    final balanceKey =
        priority == CustomerPriority.outstanding ? 'outv2' : '-';
    return '${routeId ?? ''}|$priorityKey|$missingKey|$balanceKey|${searchQuery.trim()}';
  }

  bool affectsCustomerList(CustomerFilter other) {
    if (searchQuery != other.searchQuery) return true;
    if (routeId != other.routeId) return true;
    if (category != other.category) return true;
    if (priority != other.priority) return true;
    // Day-wise chips only change the Missing list query.
    if (missingDays != other.missingDays &&
        (priority == CustomerPriority.missing ||
            other.priority == CustomerPriority.missing)) {
      return true;
    }
    return false;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerFilter &&
          searchQuery == other.searchQuery &&
          routeId == other.routeId &&
          category == other.category &&
          priority == other.priority &&
          missingDays == other.missingDays;

  @override
  int get hashCode =>
      Object.hash(searchQuery, routeId, category, priority, missingDays);
}

class PaginatedCustomersState {
  const PaginatedCustomersState({
    this.customers = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<CustomerModel> customers;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  PaginatedCustomersState copyWith({
    List<CustomerModel>? customers,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) => PaginatedCustomersState(
    customers: customers ?? this.customers,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
  );
}

final customerFilterProvider = StateProvider<CustomerFilter>(
  (ref) => const CustomerFilter(),
);

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository(ref.watch(apiClientProvider));
});

final loadedCustomersProvider = StateProvider<List<CustomerModel>>(
  (ref) => const [],
);

final routeCustomerStatsProvider = FutureProvider.autoDispose
    .family<CustomerRouteStats, ({String routeId, int missingDays})>((
      ref,
      key,
    ) async {
      if (key.routeId.isEmpty) return const CustomerRouteStats();

      // Keep stats warm across short navigations / tab switches.
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 2), link.close);
      ref.onDispose(timer.cancel);

      return ref
          .read(customersRepositoryProvider)
          .fetchRouteStats(route: key.routeId, missingDays: key.missingDays);
    });

class PaginatedCustomersNotifier
    extends StateNotifier<PaginatedCustomersState> {
  PaginatedCustomersNotifier(this._ref)
    : super(const PaginatedCustomersState(isLoading: true)) {
    _ref.listen(customerFilterProvider, (previous, next) {
      if (previous == next) return;
      if (previous != null && !previous.affectsCustomerList(next)) {
        // e.g. missingDays changed while on All/Outstanding — stats refresh
        // separately; list payload is unchanged.
        return;
      }

      // Cancel any pending window coalesce; load the latest filter now.
      // (UI already debounces day-chip taps before writing the filter.)
      _missingWindowDebounce?.cancel();
      _loadInitial();
    });
    _loadInitial();
  }

  final Ref _ref;

  int _loadGeneration = 0;
  int _softRefreshToken = 0;
  Timer? _missingWindowDebounce;

  /// In-memory pages keyed by [CustomerFilter.listCacheKey] for instant tab
  /// switching without duplicate network round-trips.
  final Map<String, PaginatedCustomersState> _pageCache = {};
  final Map<String, DateTime> _pageCacheAt = {};

  static const _cacheFreshFor = Duration(seconds: 45);

  @override
  void dispose() {
    _missingWindowDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial({bool forceNetwork = false}) async {
    final filter = _ref.read(customerFilterProvider);
    if (filter.routeId == null || filter.routeId!.isEmpty) {
      // Stay in loading until the screen stamps a routeId — avoids a wasted
      // empty round-trip and an empty flash before the real fetch.
      if (!state.isLoading || state.customers.isNotEmpty) {
        state = const PaginatedCustomersState(isLoading: true);
      }
      return;
    }

    final cacheKey = filter.listCacheKey;
    final cached = _pageCache[cacheKey];
    final cachedAt = _pageCacheAt[cacheKey];
    final cacheIsFresh =
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheFreshFor;

    // Serve cached pages (including empty Missing windows) immediately.
    if (!forceNetwork && cached != null) {
      state = cached.copyWith(isLoading: false, isLoadingMore: false);
      _ref.read(loadedCustomersProvider.notifier).state = cached.customers;
      if (!cacheIsFresh && cached.customers.isNotEmpty) {
        // Soft-refresh must NOT bump [_loadGeneration] or it cancels the next
        // Missing-window fetch and leaves the list stuck on skeleton.
        unawaited(_softRefresh(filter, cacheKey));
      }
      return;
    }

    final generation = ++_loadGeneration;
    state = const PaginatedCustomersState(isLoading: true, hasMore: true);
    _ref.read(loadedCustomersProvider.notifier).state = const [];

    try {
      final page = await _fetchPage(filter, offset: 0);
      if (generation != _loadGeneration) return;
      final current = _ref.read(customerFilterProvider);
      if (current.listCacheKey != cacheKey) return;
      final next = PaginatedCustomersState(
        customers: page.customers,
        isLoading: false,
        hasMore: page.hasMore,
      );
      _storeCache(cacheKey, next);
      state = next;
      _ref.read(loadedCustomersProvider.notifier).state = page.customers;
      if (page.hasMore && filter.priority != CustomerPriority.missing) {
        unawaited(loadMore());
      }
    } catch (error) {
      if (generation != _loadGeneration) return;
      final current = _ref.read(customerFilterProvider);
      if (current.listCacheKey != cacheKey) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  void _storeCache(String key, PaginatedCustomersState value) {
    _pageCache[key] = value;
    _pageCacheAt[key] = DateTime.now();
  }

  Future<void> _softRefresh(CustomerFilter filter, String cacheKey) async {
    final token = ++_softRefreshToken;
    try {
      final page = await _fetchPage(filter, offset: 0);
      if (token != _softRefreshToken) return;
      // Only apply if the user is still on this filter.
      final current = _ref.read(customerFilterProvider);
      if (current.listCacheKey != cacheKey) return;

      // Preserve already-scrolled pages: refresh only the first page, keep the
      // previously loaded tail so soft-refresh does not truncate the list.
      final previous = _pageCache[cacheKey] ?? state;
      final pageSize = page.limit > 0 ? page.limit : page.customers.length;
      final previousTail = previous.customers.length > pageSize
          ? previous.customers.sublist(pageSize)
          : const <CustomerModel>[];
      final freshIds = page.customers.map((c) => c.id).toSet();
      final preservedTail = previousTail
          .where((c) => !freshIds.contains(c.id))
          .toList(growable: false);
      final merged = [...page.customers, ...preservedTail];

      final next = PaginatedCustomersState(
        customers: merged,
        isLoading: false,
        // If we kept a tail, trust prior hasMore until the next loadMore.
        hasMore: preservedTail.isEmpty ? page.hasMore : previous.hasMore,
      );
      _storeCache(cacheKey, next);
      state = next;
      _ref.read(loadedCustomersProvider.notifier).state = merged;
    } catch (_) {
      // Keep cached UI on soft-refresh failure.
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    final filter = _ref.read(customerFilterProvider);
    if (filter.routeId == null || filter.routeId!.isEmpty) return;

    final generation = _loadGeneration;
    final cacheKey = filter.listCacheKey;
    final offset = state.customers.length;

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await _fetchPage(filter, offset: offset);
      if (generation != _loadGeneration) return;
      final current = _ref.read(customerFilterProvider);
      if (current.listCacheKey != cacheKey) return;

      final merged = [...state.customers, ...page.customers];
      final next = state.copyWith(
        customers: merged,
        isLoadingMore: false,
        hasMore: page.hasMore,
      );
      _storeCache(cacheKey, next);
      state = next;
      _ref.read(loadedCustomersProvider.notifier).state = merged;
    } catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(isLoadingMore: false, error: error);
    }
  }

  Future<void> refresh() {
    final filter = _ref.read(customerFilterProvider);
    _pageCache.remove(filter.listCacheKey);
    _pageCacheAt.remove(filter.listCacheKey);
    return _loadInitial(forceNetwork: true);
  }

  /// Replaces a customer in the current list and any cached pages.
  void replaceCustomer(CustomerModel updated) {
    List<CustomerModel> swap(List<CustomerModel> source) {
      final index = source.indexWhere((c) => c.id == updated.id);
      if (index < 0) return source;
      final next = List<CustomerModel>.from(source);
      next[index] = updated;
      return next;
    }

    final current = swap(state.customers);
    if (!identical(current, state.customers)) {
      final nextState = state.copyWith(customers: current);
      state = nextState;
      final filter = _ref.read(customerFilterProvider);
      _storeCache(filter.listCacheKey, nextState);
    }

    for (final entry in _pageCache.entries.toList()) {
      final swapped = swap(entry.value.customers);
      if (identical(swapped, entry.value.customers)) continue;
      _storeCache(entry.key, entry.value.copyWith(customers: swapped));
    }

    final loaded = _ref.read(loadedCustomersProvider);
    final swappedLoaded = swap(loaded);
    if (!identical(swappedLoaded, loaded)) {
      _ref.read(loadedCustomersProvider.notifier).state = swappedLoaded;
    }
  }

  void clearCache() {
    _pageCache.clear();
    _pageCacheAt.clear();
  }

  Future<CustomersPageResult> _fetchPage(
    CustomerFilter filter, {
    required int offset,
  }) {
    return _ref
        .read(customersRepositoryProvider)
        .fetchCustomersPage(
          route: filter.routeId!,
          offset: offset,
          search: filter.searchQuery.trim(),
          priority: filter.priority,
          missingDays: filter.missingDays,
        );
  }
}

final paginatedCustomersProvider =
    StateNotifierProvider.autoDispose<
      PaginatedCustomersNotifier,
      PaginatedCustomersState
    >((ref) {
      // Keep list state alive briefly so back-navigation does not cold-reload.
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 3), link.close);
      ref.onDispose(timer.cancel);
      return PaginatedCustomersNotifier(ref);
    });

List<CustomerModel> _applyClientFilters(
  List<CustomerModel> source,
  CustomerFilter filter,
) {
  var list = List<CustomerModel>.from(source);

  if (filter.category != null && filter.category!.isNotEmpty) {
    list = list.where((c) => c.category == filter.category).toList();
  }

  return list;
}

final customersStateProvider = Provider<List<CustomerModel>>((ref) {
  final filter = ref.watch(customerFilterProvider);
  final paginated = ref.watch(paginatedCustomersProvider);
  return _applyClientFilters(paginated.customers, filter);
});

final customerByIdProvider = Provider.family<CustomerModel?, String>((ref, id) {
  final cached = ref.watch(loadedCustomersProvider);
  try {
    return cached.firstWhere((c) => c.id == id);
  } catch (_) {
    return null;
  }
});

class CustomerLastOrderState {
  const CustomerLastOrderState({
    this.lastPurchase,
    this.products = const [],
    this.isLoading = false,
    this.isLoadingItems = false,
    this.isLoadingMore = false,
    this.itemsLoaded = false,
    this.hasMore = false,
    this.billNo = '',
    this.error,
  });

  final LastPurchaseInfo? lastPurchase;
  final List<OrderedProductModel> products;
  final bool isLoading;
  final bool isLoadingItems;
  final bool isLoadingMore;
  final bool itemsLoaded;
  final bool hasMore;
  final String billNo;
  final Object? error;

  bool get hasLastPurchase =>
      lastPurchase != null && lastPurchase!.billNo.isNotEmpty;

  CustomerLastOrderState copyWith({
    LastPurchaseInfo? lastPurchase,
    List<OrderedProductModel>? products,
    bool? isLoading,
    bool? isLoadingItems,
    bool? isLoadingMore,
    bool? itemsLoaded,
    bool? hasMore,
    String? billNo,
    Object? error,
    bool clearError = false,
  }) => CustomerLastOrderState(
    lastPurchase: lastPurchase ?? this.lastPurchase,
    products: products ?? this.products,
    isLoading: isLoading ?? this.isLoading,
    isLoadingItems: isLoadingItems ?? this.isLoadingItems,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    itemsLoaded: itemsLoaded ?? this.itemsLoaded,
    hasMore: hasMore ?? this.hasMore,
    billNo: billNo ?? this.billNo,
    error: clearError ? null : (error ?? this.error),
  );
}

CustomerLastOrderState _initialLastOrderState(Ref ref, String customerId) {
  final customer = ref.read(customerByIdProvider(customerId));
  if (customer != null && customer.lastPurchaseBillNo.isNotEmpty) {
    final lastPurchase = LastPurchaseInfo.fromCustomer(customer);
    return CustomerLastOrderState(
      lastPurchase: lastPurchase,
      billNo: lastPurchase.billNo,
    );
  }
  return const CustomerLastOrderState(isLoading: true);
}

class CustomerLastOrderNotifier extends StateNotifier<CustomerLastOrderState> {
  CustomerLastOrderNotifier(this._ref, this._customerId)
    : super(_initialLastOrderState(_ref, _customerId)) {
    _locationCode = state.lastPurchase?.locationCode ?? '';
    if (!state.hasLastPurchase) {
      _loadHeaderFromApi();
    } else {
      Future.microtask(loadItems);
    }
  }

  final Ref _ref;
  final String _customerId;
  String _locationCode = '';

  Future<void> _loadHeaderFromApi() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final page = await _ref
          .read(customersRepositoryProvider)
          .fetchLastOrderPage(custCode: _customerId, itemsLimit: 0);

      final lastPurchase = page.lastPurchase;
      if (lastPurchase == null || lastPurchase.billNo.isEmpty) {
        state = CustomerLastOrderState(
          isLoading: false,
          lastPurchase: lastPurchase,
        );
        return;
      }

      _locationCode = lastPurchase.locationCode;
      state = CustomerLastOrderState(
        lastPurchase: lastPurchase,
        isLoading: false,
        billNo: lastPurchase.billNo,
      );
      Future.microtask(loadItems);
    } catch (error) {
      state = CustomerLastOrderState(isLoading: false, error: error);
    }
  }

  Future<void> loadItems() async {
    if (state.isLoadingItems || state.itemsLoaded || state.billNo.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingItems: true, clearError: true);

    try {
      final page = await _ref
          .read(customersRepositoryProvider)
          .fetchBillItemsPage(
            billNo: state.billNo,
            locationCode: _locationCode,
          );

      state = state.copyWith(
        products: _mapItems(page.items),
        isLoadingItems: false,
        itemsLoaded: true,
        hasMore: page.hasMore,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingItems: false,
        itemsLoaded: true,
        error: error,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingItems ||
        state.isLoadingMore ||
        !state.hasMore ||
        !state.itemsLoaded) {
      return;
    }
    if (state.billNo.isEmpty) return;

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final page = await _ref
          .read(customersRepositoryProvider)
          .fetchBillItemsPage(
            billNo: state.billNo,
            locationCode: _locationCode,
            offset: state.products.length,
          );

      state = state.copyWith(
        products: [...state.products, ..._mapItems(page.items)],
        isLoadingMore: false,
        hasMore: page.hasMore,
      );
    } catch (error) {
      state = state.copyWith(isLoadingMore: false, error: error);
    }
  }

  Future<void> refresh() async {
    state = const CustomerLastOrderState(isLoading: true);
    _locationCode = '';
    await _loadHeaderFromApi();
    if (state.hasLastPurchase) {
      await loadItems();
    }
  }

  List<OrderedProductModel> _mapItems(List<BillItemModel> items) {
    return items.map((item) => item.toOrderedProduct()).toList();
  }
}

final customerLastOrderProvider = StateNotifierProvider.autoDispose
    .family<CustomerLastOrderNotifier, CustomerLastOrderState, String>((
      ref,
      customerId,
    ) {
      return CustomerLastOrderNotifier(ref, customerId);
    });
