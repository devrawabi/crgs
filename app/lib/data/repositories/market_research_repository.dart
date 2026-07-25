import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class MarketResearchRepository {
  MarketResearchRepository(this._client);

  final ApiClient _client;

  /// Lists market research rows from Oracle `CRGS_MARKETRESEARCH`.
  Future<List<MarketResearchRecordModel>> fetchResearch({
    String? employeeCode,
    String? route,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.marketResearch,
      queryParameters: {
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
    if (itemsJson is! List) return const [];

    return itemsJson
        .whereType<Map>()
        .map(
          (item) =>
              MarketResearchRecordModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
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
