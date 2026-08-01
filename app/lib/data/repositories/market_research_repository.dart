import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class MarketResearchPage {
  const MarketResearchPage({
    required this.items,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  final List<MarketResearchRecordModel> items;
  final int offset;
  final int limit;
  final bool hasMore;
}

class MarketResearchRepository {
  MarketResearchRepository(this._client);

  final ApiClient _client;

  static const int pageSize = 50;

  Future<MarketResearchPage> fetchResearchPage({
    String? employeeCode,
    String? route,
    int limit = pageSize,
    int offset = 0,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.marketResearch,
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (employeeCode != null && employeeCode.trim().isNotEmpty)
          'employeeCode': employeeCode.trim(),
        if (route != null && route.trim().isNotEmpty) 'route': route.trim(),
      },
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Empty response from server');
    }

    final itemsJson = data['items'];
    final items = itemsJson is List
        ? itemsJson
            .whereType<Map>()
            .map(
              (item) => MarketResearchRecordModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : const <MarketResearchRecordModel>[];

    return MarketResearchPage(
      items: items,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      hasMore: data['has_more'] as bool? ?? items.length >= limit,
    );
  }

  /// Lists market research rows — walks pages for Activity completeness.
  Future<List<MarketResearchRecordModel>> fetchResearch({
    String? employeeCode,
    String? route,
  }) async {
    final all = <MarketResearchRecordModel>[];
    var offset = 0;
    for (var i = 0; i < 100; i++) {
      final page = await fetchResearchPage(
        employeeCode: employeeCode,
        route: route,
        limit: pageSize,
        offset: offset,
      );
      all.addAll(page.items);
      if (!page.hasMore || page.items.isEmpty) break;
      offset += page.limit;
    }
    return all;
  }

  /// Insert into Oracle `CRGS_MARKETRESEARCH`.
  Future<Map<String, dynamic>> submitResearch({
    required String employeeCode,
    required String route,
    required String marketTrend,
    required String fastMovingProducts,
    required String slowMovingProducts,
    required String competitorPromotions,
    required String newOpportunities,
    required String notes,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.marketResearch,
      data: {
        'employeeCode': employeeCode,
        'route': route,
        'marketTrend': marketTrend,
        'fastMovingProducts': fastMovingProducts,
        'slowMovingProducts': slowMovingProducts,
        'competitorPromotions': competitorPromotions,
        'newOpportunities': newOpportunities,
        'notes': notes,
      },
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Invalid market research response from server');
    }
    return data;
  }
}
