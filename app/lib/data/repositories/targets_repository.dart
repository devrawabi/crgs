import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class TargetsRepository {
  TargetsRepository(this._client);

  final ApiClient _client;

  static const int _pageSize = 200;
  static const int _maxPages = 50;

  Future<List<SalesTargetModel>> fetchSalesTargets({
    String? employeeCode,
    TargetPeriod? period,
  }) async {
    return _fetchAllPages(
      path: ApiEndpoints.salesTargets,
      itemsKey: 'targets',
      fromJson: SalesTargetModel.fromJson,
      baseQuery: {
        if (employeeCode != null && employeeCode.isNotEmpty)
          'employeeCode': employeeCode,
        if (period != null) 'period': period.apiValue,
      },
    );
  }

  Future<List<ProductTargetModel>> fetchProductTargets({
    String? employeeCode,
  }) async {
    return _fetchAllPages(
      path: ApiEndpoints.productTargets,
      itemsKey: 'targets',
      fromJson: ProductTargetModel.fromJson,
      baseQuery: {
        if (employeeCode != null && employeeCode.isNotEmpty)
          'employeeCode': employeeCode,
      },
    );
  }

  Future<CustomerTargetsResult> fetchCustomerTargets({
    String? employeeCode,
    TargetPeriod? period,
  }) async {
    var newCustomersFlagN = 0;
    final targets = await _fetchAllPages(
      path: ApiEndpoints.customerTargets,
      itemsKey: 'targets',
      fromJson: CustomerTargetModel.fromJson,
      baseQuery: {
        if (employeeCode != null && employeeCode.isNotEmpty)
          'employeeCode': employeeCode,
        if (period != null) 'period': period.apiValue,
      },
      onPage: (data) {
        final flagNRaw = data['newCustomersFlagN'];
        if (flagNRaw is num) {
          newCustomersFlagN = flagNRaw.toInt();
        } else {
          newCustomersFlagN =
              int.tryParse(flagNRaw?.toString() ?? '') ?? newCustomersFlagN;
        }
      },
    );

    return CustomerTargetsResult(
      targets: targets,
      newCustomersFlagN: newCustomersFlagN,
    );
  }

  Future<List<T>> _fetchAllPages<T>({
    required String path,
    required String itemsKey,
    required T Function(Map<String, dynamic> json) fromJson,
    Map<String, dynamic> baseQuery = const {},
    void Function(Map<String, dynamic> data)? onPage,
  }) async {
    final all = <T>[];
    var offset = 0;

    for (var page = 0; page < _maxPages; page += 1) {
      final response = await _client.get<Map<String, dynamic>>(
        path,
        queryParameters: {
          ...baseQuery,
          'limit': _pageSize,
          'offset': offset,
        },
      );

      final data = response.data;
      if (data == null) {
        throw ApiException(message: 'Invalid targets response from server');
      }
      onPage?.call(data);

      final batch = _parseList(data[itemsKey], fromJson);
      all.addAll(batch);

      final hasMore = data['has_more'] == true;
      if (!hasMore || batch.isEmpty) break;

      final limitUsed = data['limit'] is num
          ? (data['limit'] as num).toInt()
          : _pageSize;
      offset += limitUsed > 0 ? limitUsed : _pageSize;
    }

    return all;
  }

  List<T> _parseList<T>(
    dynamic raw,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    if (raw is! List) {
      throw ApiException(message: 'Invalid targets response from server');
    }

    return raw
        .whereType<Map>()
        .map((item) => fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
