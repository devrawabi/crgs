import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../features/orders/models/order_models.dart';

/// One page from `GET /api/orders`.
class OrdersPage {
  const OrdersPage({
    required this.orders,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  final List<CustomerOrder> orders;
  final int offset;
  final int limit;
  final bool hasMore;
}

class OrdersRepository {
  OrdersRepository(this._client);

  final ApiClient _client;

  static const int pageSize = 50;

  /// Fetches one page of orders from Oracle `CRGS_ORDERHDR` + `CRGS_ORDERDTL`.
  Future<OrdersPage> fetchOrdersPage({
    String? employeeCode,
    int limit = pageSize,
    int offset = 0,
  }) async {
    final queryParameters = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (employeeCode != null && employeeCode.isNotEmpty) {
      queryParameters['employeeCode'] = employeeCode;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.orders,
      queryParameters: queryParameters,
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Empty orders response from server');
    }

    final raw = data['orders'];
    if (raw is! List) {
      throw ApiException(message: 'Invalid orders response from server');
    }

    final orders = raw
        .whereType<Map>()
        .map((item) => CustomerOrder.fromDb(Map<String, dynamic>.from(item)))
        .toList();

    return OrdersPage(
      orders: orders,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      hasMore: data['has_more'] as bool? ?? orders.length >= limit,
    );
  }

  /// Backward-compatible helper — walks pages until exhausted.
  Future<List<CustomerOrder>> fetchOrders({String? employeeCode}) async {
    final all = <CustomerOrder>[];
    var offset = 0;
    for (var i = 0; i < 100; i++) {
      final page = await fetchOrdersPage(
        employeeCode: employeeCode,
        limit: pageSize,
        offset: offset,
      );
      all.addAll(page.orders);
      if (!page.hasMore || page.orders.isEmpty) break;
      offset += page.limit;
    }
    return all;
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
