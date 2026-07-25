import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../features/orders/models/order_models.dart';

class OrdersRepository {
  OrdersRepository(this._client);

  final ApiClient _client;

  /// Fetches orders from Oracle `CRGS_ORDERHDR` + `CRGS_ORDERDTL`.
  Future<List<CustomerOrder>> fetchOrders({String? employeeCode}) async {
    final queryParameters = <String, dynamic>{};
    if (employeeCode != null && employeeCode.isNotEmpty) {
      queryParameters['employeeCode'] = employeeCode;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.orders,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final raw = response.data?['orders'];
    if (raw is! List) {
      throw ApiException(message: 'Invalid orders response from server');
    }

    return raw
        .whereType<Map>()
        .map((item) => CustomerOrder.fromDb(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Inserts `CRGS_ORDERHDR` + `CRGS_ORDERDTL` (ORDERNO = max + 1).
  Future<Map<String, dynamic>> createExpectedOrder({
    required String employeeCode,
    required String customerCode,
    required String customerName,
    required String route,
    required double totalAmount,
    required int itemCount,
    required List<Map<String, dynamic>> items,
    DateTime? orderDate,
    DateTime? expectedDate,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.orders,
      data: {
        'employeeCode': employeeCode,
        'customerCode': customerCode,
        'customerName': customerName,
        'route': route,
        'totalAmount': totalAmount,
        'itemCount': itemCount,
        'orderDate': _dateOnly(orderDate ?? DateTime.now()),
        if (expectedDate != null) 'expectedDate': _dateOnly(expectedDate),
        'items': items,
      },
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Invalid create order response from server');
    }
    return data;
  }

  static String _dateOnly(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
