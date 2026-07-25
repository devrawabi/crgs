import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';

class TargetsRepository {
  TargetsRepository(this._client);

  final ApiClient _client;

  Future<List<SalesTargetModel>> fetchSalesTargets({
    String? employeeCode,
    TargetPeriod? period,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (employeeCode != null && employeeCode.isNotEmpty) {
      queryParameters['employeeCode'] = employeeCode;
    }
    if (period != null) {
      queryParameters['period'] = period.apiValue;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.salesTargets,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    return _parseList(response.data?['targets'], SalesTargetModel.fromJson);
  }

  Future<List<ProductTargetModel>> fetchProductTargets({
    String? employeeCode,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (employeeCode != null && employeeCode.isNotEmpty) {
      queryParameters['employeeCode'] = employeeCode;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.productTargets,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    return _parseList(response.data?['targets'], ProductTargetModel.fromJson);
  }

  Future<CustomerTargetsResult> fetchCustomerTargets({
    String? employeeCode,
    TargetPeriod? period,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (employeeCode != null && employeeCode.isNotEmpty) {
      queryParameters['employeeCode'] = employeeCode;
    }
    if (period != null) {
      queryParameters['period'] = period.apiValue;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.customerTargets,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final data = response.data;
    final flagNRaw = data?['newCustomersFlagN'];
    final flagN = flagNRaw is num
        ? flagNRaw.toInt()
        : int.tryParse(flagNRaw?.toString() ?? '') ?? 0;

    return CustomerTargetsResult(
      targets: _parseList(data?['targets'], CustomerTargetModel.fromJson),
      newCustomersFlagN: flagN,
    );
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
