import 'dart:async';
import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../local/items_local_cache.dart';
import '../models/models.dart';

/// One page from `GET /api/items`.
class ItemsPage {
  const ItemsPage({
    required this.items,
    required this.offset,
    required this.limit,
    required this.count,
    required this.hasMore,
    required this.deltaSupported,
    this.serverTime,
    this.nextCursor,
  });

  final List<AlternativeProductModel> items;
  final int offset;
  final int limit;
  final int count;
  final bool hasMore;
  final bool deltaSupported;
  final String? serverTime;
  final ItemsPageCursor? nextCursor;
}

/// Keyset cursor returned by the API (`next_cursor`).
class ItemsPageCursor {
  const ItemsPageCursor({
    this.afterItemcode,
    this.afterItemname,
    this.afterUpdated,
  });

  final String? afterItemcode;
  final String? afterItemname;
  final String? afterUpdated;

  factory ItemsPageCursor.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ItemsPageCursor();
    return ItemsPageCursor(
      afterItemcode: json['after_itemcode']?.toString(),
      afterItemname: json['after_itemname']?.toString(),
      afterUpdated: json['after_updated']?.toString(),
    );
  }

  bool get isEmpty =>
      (afterItemcode == null || afterItemcode!.isEmpty) &&
      (afterItemname == null || afterItemname!.isEmpty) &&
      (afterUpdated == null || afterUpdated!.isEmpty);
}

class ItemsRepository {
  ItemsRepository(this._client);

  final ApiClient _client;

  /// Default sync page size (server max is 1000).
  static const int pageSize = 750;

  /// Re-sync at most this often unless [force] is true.
  static const Duration cacheTtl = Duration(hours: 6);

  /// Single page fetch — used by search / admin-style callers.
  Future<ItemsPage> fetchItemsPage({
    String? search,
    int limit = pageSize,
    int offset = 0,
    String? updatedSince,
    ItemsPageCursor? cursor,
  }) async {
    final queryParameters = <String, dynamic>{
      'limit': math.min(limit, 1000),
    };
    final trimmedSearch = search?.trim() ?? '';
    if (trimmedSearch.isNotEmpty) {
      queryParameters['search'] = trimmedSearch;
    }
    final since = updatedSince?.trim() ?? '';
    if (since.isNotEmpty) {
      queryParameters['updated_since'] = since;
    }

    final c = cursor;
    if (c != null && !c.isEmpty) {
      if (c.afterItemcode != null && c.afterItemcode!.isNotEmpty) {
        queryParameters['after_itemcode'] = c.afterItemcode;
      }
      if (c.afterItemname != null && c.afterItemname!.isNotEmpty) {
        queryParameters['after_itemname'] = c.afterItemname;
      }
      if (c.afterUpdated != null && c.afterUpdated!.isNotEmpty) {
        queryParameters['after_updated'] = c.afterUpdated;
      }
    } else {
      queryParameters['offset'] = math.max(offset, 0);
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.items,
      queryParameters: queryParameters,
    );

    final body = response.data;
    if (body == null) {
      throw ApiException(message: 'Empty items response from server');
    }

    final raw = body['items'];
    if (raw is! List) {
      throw ApiException(message: 'Invalid items response from server');
    }

    final items = raw
        .whereType<Map>()
        .map((item) => _fromItemMaster(Map<String, dynamic>.from(item)))
        .where((product) => product.id.isNotEmpty || product.name.isNotEmpty)
        .toList();

    final cursorRaw = body['next_cursor'];
    final nextCursor = cursorRaw is Map
        ? ItemsPageCursor.fromJson(Map<String, dynamic>.from(cursorRaw))
        : null;

    return ItemsPage(
      items: items,
      offset: _asInt(body['offset'], offset),
      limit: _asInt(body['limit'], limit),
      count: _asInt(body['count'], items.length),
      hasMore: body['has_more'] == true,
      deltaSupported: body['delta_supported'] == true,
      serverTime: body['server_time']?.toString(),
      nextCursor: nextCursor,
    );
  }

  Future<List<AlternativeProductModel>> loadCachedItems() {
    return ItemsLocalCache.loadAll();
  }

  /// Sync catalog into Hive.
  ///
  /// - Shows cached data instantly via [loadCachedItems]
  /// - Uses `updated_since` when the API reports `delta_supported`
  /// - Walks pages via keyset cursors (falls back to offset)
  Future<List<AlternativeProductModel>> syncCatalog({
    bool force = false,
    List<AlternativeProductModel>? existingItems,
    void Function(int loaded)? onProgress,
  }) async {
    final mustFullResync = force || ItemsLocalCache.needsSchemaResync;
    if (!mustFullResync && !_shouldSync()) {
      return existingItems ?? await ItemsLocalCache.loadAll(sorted: false);
    }

    final cachedSince = ItemsLocalCache.maxLastUpdated;
    // Full pull when forced or after a schema bump (e.g. OWNPRODUCT) so every
    // cached row gets the new flag — delta would leave stale values forever.
    final tryDelta = !mustFullResync &&
        cachedSince != null &&
        cachedSince.isNotEmpty &&
        ItemsLocalCache.productCount > 0;

    var loaded = 0;
    var deltaSupported = false;
    String? serverTime;
    String? maxLastUpdated = cachedSince;
    final collected = <AlternativeProductModel>[];
    ItemsPageCursor? cursor;
    var offset = 0;
    var useKeyset = false;

    while (true) {
      final page = await fetchItemsPage(
        limit: pageSize,
        offset: useKeyset ? 0 : offset,
        updatedSince: tryDelta ? cachedSince : null,
        cursor: useKeyset ? cursor : null,
      );
      deltaSupported = page.deltaSupported;
      serverTime = page.serverTime ?? serverTime;

      if (page.items.isEmpty) break;

      collected.addAll(page.items);
      loaded += page.items.length;
      onProgress?.call(loaded);

      for (final item in page.items) {
        final ts = item.lastUpdated;
        if (ts == null || ts.isEmpty) continue;
        final current = maxLastUpdated;
        if (current == null || current.isEmpty || ts.compareTo(current) > 0) {
          maxLastUpdated = ts;
        }
      }

      if (!page.hasMore) break;

      final next = page.nextCursor;
      if (next != null && !next.isEmpty) {
        useKeyset = true;
        cursor = next;
      } else {
        // Legacy servers without next_cursor — offset walk (capped server-side).
        useKeyset = false;
        cursor = null;
        offset += page.limit;
      }
      // Yield so the UI isolate stays responsive during multi-page sync.
      await Future<void>.delayed(Duration.zero);
    }

    if (tryDelta && deltaSupported) {
      if (collected.isNotEmpty) {
        await ItemsLocalCache.upsertAll(collected);
      }
      await ItemsLocalCache.saveSyncMeta(
        lastSyncedAt: serverTime ?? DateTime.now().toUtc().toIso8601String(),
        maxLastUpdated: maxLastUpdated,
        deltaSupported: deltaSupported,
      );
      // Merge into in-memory list when the notifier already has it — skip Hive scan.
      return ItemsLocalCache.mergeInto(
        existing: existingItems,
        upserts: collected,
      );
    }

    if (collected.isNotEmpty) {
      collected.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      await ItemsLocalCache.replaceAll(collected);
    } else if (!tryDelta) {
      await ItemsLocalCache.replaceAll(const []);
    }

    await ItemsLocalCache.saveSyncMeta(
      lastSyncedAt: serverTime ?? DateTime.now().toUtc().toIso8601String(),
      maxLastUpdated: maxLastUpdated,
      deltaSupported: deltaSupported,
    );

    return collected;
  }

  bool _shouldSync() {
    final last = ItemsLocalCache.lastSyncedAt;
    if (last == null || last.isEmpty) return true;
    if (ItemsLocalCache.productCount == 0) return true;
    final parsed = DateTime.tryParse(last);
    if (parsed == null) return true;
    return DateTime.now().toUtc().difference(parsed.toUtc()) >= cacheTtl;
  }

  /// Fetch base + alternate UOMs for one itemcode from ITEMALTERNATEUOMMAP.
  Future<List<ItemUomOption>> fetchItemUoms(String itemCode) async {
    final code = itemCode.trim();
    if (code.isEmpty) return const [];

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.itemUoms(code),
    );
    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Empty UOM response from server');
    }

    final raw = data['uoms'];
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((item) => ItemUomOption.fromJson(Map<String, dynamic>.from(item)))
        .where((uom) => uom.code.isNotEmpty)
        .toList(growable: false);
  }

  AlternativeProductModel _fromItemMaster(Map<String, dynamic> json) {
    final code = json['itemcode']?.toString().trim() ?? '';
    final name = json['itemname']?.toString().trim() ?? '';
    final baseUom = json['baseuom']?.toString().trim() ?? '';
    final unitPrice = _toDouble(json['retailprice']);
    final stock = _toDouble(json['currentstock']);
    final qtyLimit = _toDouble(json['quantitylimit']);
    final lastUpdated = json['last_updated']?.toString().trim();

    return AlternativeProductModel(
      id: code.isNotEmpty ? code : name,
      name: name.isNotEmpty ? name : code,
      imageUrl: '',
      details: '',
      category: 'All Products',
      baseUom: baseUom,
      unitPrice: unitPrice,
      stock: stock,
      qtyLimit: qtyLimit,
      lastUpdated: (lastUpdated == null || lastUpdated.isEmpty)
          ? null
          : lastUpdated,
      isOwnProduct: _asOwnProduct(json['ownproduct']),
    );
  }

  static bool _asOwnProduct(dynamic value) {
    if (value is bool) return value;
    final text =
        value?.toString().replaceAll(RegExp(r'\s+'), '').toUpperCase() ?? '';
    return text == 'Y' ||
        text == 'YES' ||
        text == 'TRUE' ||
        text == '1' ||
        text == 'T';
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
