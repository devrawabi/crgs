import 'dart:isolate';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';

/// Local ITEMMASTER cache (Hive).
///
/// Why Hive: fast key/value upserts for delta sync, no SQL boilerplate.
/// Heavy decode/sort runs in a background isolate so hydrate does not hitch UI.
class ItemsLocalCache {
  ItemsLocalCache._();

  static const _boxName = 'itemmaster_products';
  static const _metaKey = '__meta__';

  /// Bump when cached product shape changes (e.g. OWNPRODUCT / isOwnProduct).
  static const int schemaVersion = 2;

  /// Decode+sort off the UI isolate when catalog is at least this large.
  static const int _isolateThreshold = 200;

  static Box<dynamic>? _box;

  static Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  static Box<dynamic> get _store {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('ItemsLocalCache.init() must be called before use');
    }
    return box;
  }

  /// Load catalog. Sort once for UI lists; skip sort for internal merge paths.
  static Future<List<AlternativeProductModel>> loadAll({
    bool sorted = true,
  }) async {
    final maps = <Map<String, dynamic>>[];
    for (final key in _store.keys) {
      if (key == _metaKey) continue;
      final value = _store.get(key);
      if (value is Map) {
        maps.add(Map<String, dynamic>.from(value));
      }
    }
    if (maps.isEmpty) return const [];

    if (maps.length < _isolateThreshold) {
      return _decodeMaps(maps, sorted);
    }
    return Isolate.run(() => _decodeMaps(maps, sorted));
  }

  static List<AlternativeProductModel> _decodeMaps(
    List<Map<String, dynamic>> maps,
    bool sorted,
  ) {
    final products = <AlternativeProductModel>[
      for (final map in maps) AlternativeProductModel.fromCacheMap(map),
    ];
    if (sorted && products.length > 1) {
      products.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    return products;
  }

  /// O(1) Hive lookup by product id (ITEMCODE).
  static AlternativeProductModel? getById(String id) {
    final key = id.trim();
    if (key.isEmpty) return null;
    final value = _store.get(key);
    if (value is! Map) return null;
    return AlternativeProductModel.fromCacheMap(
      Map<String, dynamic>.from(value),
    );
  }

  /// Batch lookup — only touches requested keys (no full catalog scan).
  static Map<String, AlternativeProductModel> getByIds(Iterable<String> ids) {
    final out = <String, AlternativeProductModel>{};
    for (final raw in ids) {
      final key = raw.trim();
      if (key.isEmpty || out.containsKey(key)) continue;
      final item = getById(key);
      if (item != null) out[key] = item;
    }
    return out;
  }

  /// Merge [upserts] into [existing] (or Hive) without a second full scan when
  /// [existing] is provided by the caller.
  static Future<List<AlternativeProductModel>> mergeInto({
    List<AlternativeProductModel>? existing,
    required List<AlternativeProductModel> upserts,
  }) async {
    if (upserts.isEmpty) {
      return existing ?? await loadAll(sorted: false);
    }
    final byId = <String, AlternativeProductModel>{
      for (final item in existing ?? await loadAll(sorted: false))
        if (item.id.isNotEmpty) item.id: item,
    };
    for (final item in upserts) {
      if (item.id.isEmpty) continue;
      byId[item.id] = item;
    }
    final merged = byId.values.toList(growable: false);
    merged.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return merged;
  }

  static Future<void> upsertAll(Iterable<AlternativeProductModel> items) async {
    final payload = <String, Map<String, dynamic>>{};
    for (final item in items) {
      if (item.id.isEmpty) continue;
      payload[item.id] = item.toCacheMap();
    }
    if (payload.isEmpty) return;
    await _store.putAll(payload);
  }

  static Future<void> replaceAll(Iterable<AlternativeProductModel> items) async {
    final meta = Map<String, dynamic>.from(
      (_store.get(_metaKey) as Map?) ?? const {},
    );
    await _store.clear();
    await upsertAll(items);
    if (meta.isNotEmpty) {
      await _store.put(_metaKey, meta);
    }
  }

  static String? get lastSyncedAt =>
      (_store.get(_metaKey) as Map?)?['lastSyncedAt']?.toString();

  static String? get maxLastUpdated =>
      (_store.get(_metaKey) as Map?)?['maxLastUpdated']?.toString();

  static int get storedSchemaVersion {
    final raw = (_store.get(_metaKey) as Map?)?['schemaVersion'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 1;
  }

  /// True when Hive rows predate fields like [AlternativeProductModel.isOwnProduct].
  static bool get needsSchemaResync => storedSchemaVersion < schemaVersion;

  static Future<void> saveSyncMeta({
    required String lastSyncedAt,
    String? maxLastUpdated,
    required bool deltaSupported,
  }) async {
    await _store.put(_metaKey, {
      'lastSyncedAt': lastSyncedAt,
      if (maxLastUpdated != null && maxLastUpdated.isNotEmpty)
        'maxLastUpdated': maxLastUpdated,
      'deltaSupported': deltaSupported,
      'schemaVersion': schemaVersion,
    });
  }

  /// O(1) count — Hive length minus the meta entry when present.
  static int get productCount {
    final length = _store.length;
    if (length == 0) return 0;
    return _store.containsKey(_metaKey) ? length - 1 : length;
  }
}
