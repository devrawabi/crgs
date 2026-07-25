import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/models.dart';
import 'routes_repository.dart';

/// First paint stays fast: small pages, more rows load on scroll / prefetch.
const int customersPageSize = 10;
const int orderedItemsPageSize = 50;

class BillItemsPageResult {
  const BillItemsPageResult({
    required this.items,
    required this.offset,
    required this.limit,
    required this.hasMore,
    this.billNo = '',
  });

  final List<BillItemModel> items;
  final int offset;
  final int limit;
  final bool hasMore;
  final String billNo;
}

class LastOrderPageResult {
  const LastOrderPageResult({
    this.lastPurchase,
    required this.items,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  final LastPurchaseInfo? lastPurchase;
  final List<BillItemModel> items;
  final int offset;
  final int limit;
  final bool hasMore;
}

class CustomerRouteStats {
  const CustomerRouteStats({
    this.all = 0,
    this.missing = 0,
    this.outstanding = 0,
  });

  final int all;
  final int missing;
  final int outstanding;

  factory CustomerRouteStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomerRouteStats();
    return CustomerRouteStats(
      all: (json['all'] as num?)?.toInt() ?? 0,
      missing: (json['missing'] as num?)?.toInt() ?? 0,
      outstanding: (json['outstanding'] as num?)?.toInt() ?? 0,
    );
  }
}

class LastPurchaseInfo {
  const LastPurchaseInfo({
    this.billNo = '',
    this.locationCode = '',
    this.date,
    this.amount = 0,
  });

  final String billNo;
  final String locationCode;
  final DateTime? date;
  final double amount;

  factory LastPurchaseInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LastPurchaseInfo();

    DateTime? date;
    final rawDate = json['billdate'];
    if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
      date = DateTime.tryParse(rawDate.toString());
    }

    final rawAmount = json['netbillamount'];
    final amount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0;

    return LastPurchaseInfo(
      billNo: json['billno']?.toString().trim() ?? '',
      locationCode: json['locationcode']?.toString().trim() ?? '',
      date: date,
      amount: amount,
    );
  }

  factory LastPurchaseInfo.fromCustomer(CustomerModel customer) {
    return LastPurchaseInfo(
      billNo: customer.lastPurchaseBillNo,
      locationCode: customer.lastPurchaseLocation,
      date: customer.lastPurchaseDate,
      amount: customer.lastPurchaseAmount,
    );
  }
}

class CustomersPageResult {
  const CustomersPageResult({
    required this.customers,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  final List<CustomerModel> customers;
  final int offset;
  final int limit;
  final bool hasMore;
}

class CustomersRepository {
  CustomersRepository(this._client);

  final ApiClient _client;

  Future<CustomersPageResult> fetchCustomersPage({
    required String route,
    int offset = 0,
    int limit = customersPageSize,
    String search = '',
    CustomerPriority? priority,
    int? missingDays,
  }) async {
    final routeNo = normalizeRouteNo(route);
    if (routeNo.isEmpty) {
      return const CustomersPageResult(
        customers: [],
        offset: 0,
        limit: customersPageSize,
        hasMore: false,
      );
    }

    final queryParameters = <String, dynamic>{
      'route': routeNo,
      'offset': offset,
      'limit': limit,
    };

    if (missingDays != null) {
      queryParameters['missing_days'] = missingDays;
    }

    if (search.isNotEmpty) {
      queryParameters['search'] = search;
    }

    // Only send priority for Missing / Outstanding. Regular/followUp are
    // client-side concepts and must not narrow the server All list.
    if (priority == CustomerPriority.missing ||
        priority == CustomerPriority.outstanding) {
      queryParameters['priority'] = priority!.name;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.customers,
      queryParameters: queryParameters,
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Empty response from server');
    }

    final customersJson = data['customers'];
    final customers = customersJson is List
        ? customersJson
            .whereType<Map>()
            .map((item) => CustomerModel.fromDb(Map<String, dynamic>.from(item)))
            .where((customer) => customer.id.isNotEmpty)
            .toList()
        : <CustomerModel>[];

    return CustomersPageResult(
      customers: customers,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      hasMore: data['has_more'] as bool? ?? customers.length >= limit,
    );
  }

  Future<CustomerRouteStats> fetchRouteStats({
    required String route,
    int? missingDays,
  }) async {
    final routeNo = normalizeRouteNo(route);
    if (routeNo.isEmpty) return const CustomerRouteStats();

    final queryParameters = <String, dynamic>{'route': routeNo};
    if (missingDays != null) {
      queryParameters['missing_days'] = missingDays;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.customerStats,
      queryParameters: queryParameters,
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Empty response from server');
    }

    return CustomerRouteStats.fromJson(
      data['stats'] is Map ? Map<String, dynamic>.from(data['stats'] as Map) : null,
    );
  }

  Future<LastOrderPageResult> fetchLastOrderPage({
    required String custCode,
    int itemsOffset = 0,
    int itemsLimit = orderedItemsPageSize,
  }) async {
    final code = custCode.trim();
    if (code.isEmpty) {
      return const LastOrderPageResult(
        items: [],
        offset: 0,
        limit: orderedItemsPageSize,
        hasMore: false,
      );
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.customerLastOrder,
      queryParameters: {
        'cust_code': code,
        'items_offset': itemsOffset,
        'items_limit': itemsLimit,
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
            .map((item) => BillItemModel.fromDb(Map<String, dynamic>.from(item)))
            .where((item) => item.itemName.isNotEmpty || item.itemCode.isNotEmpty)
            .toList()
        : <BillItemModel>[];

    return LastOrderPageResult(
      lastPurchase: LastPurchaseInfo.fromJson(
        data['last_purchase'] is Map
            ? Map<String, dynamic>.from(data['last_purchase'] as Map)
            : null,
      ),
      items: items,
      offset: (data['items_offset'] as num?)?.toInt() ?? itemsOffset,
      limit: (data['items_limit'] as num?)?.toInt() ?? itemsLimit,
      hasMore: data['has_more_items'] as bool? ?? items.length >= itemsLimit,
    );
  }

  Future<BillItemsPageResult> fetchBillItemsPage({
    required String billNo,
    String? locationCode,
    int offset = 0,
    int limit = orderedItemsPageSize,
  }) async {
    if (billNo.isEmpty) {
      return const BillItemsPageResult(
        items: [],
        offset: 0,
        limit: orderedItemsPageSize,
        hasMore: false,
      );
    }

    final queryParameters = <String, dynamic>{
      'billno': billNo,
      'offset': offset,
      'limit': limit,
    };
    if (locationCode != null && locationCode.isNotEmpty) {
      queryParameters['location'] = locationCode;
    }

    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.customerBillItems,
      queryParameters: queryParameters,
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Empty response from server');
    }

    final itemsJson = data['items'];
    final items = itemsJson is List
        ? itemsJson
            .whereType<Map>()
            .map((item) => BillItemModel.fromDb(Map<String, dynamic>.from(item)))
            .where((item) => item.itemName.isNotEmpty || item.itemCode.isNotEmpty)
            .toList()
        : <BillItemModel>[];

    return BillItemsPageResult(
      items: items,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      hasMore: data['has_more'] as bool? ?? items.length >= limit,
      billNo: data['billno']?.toString() ?? billNo,
    );
  }

  /// Lists prospects from Oracle `CRGS_CONTACTINFO`.
  Future<List<ContactInfoModel>> fetchContactInfo({
    String? status,
    String? search,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.customerContactInfo,
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
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
        .map((item) => ContactInfoModel.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.customerName.isNotEmpty || item.shopName.isNotEmpty)
        .toList();
  }

  /// Inserts into Oracle `CRGS_CONTACTINFO`.
  ///
  /// [flag]:
  /// - `N` new prospect (auto CUSTOMERCODE)
  /// - `E` edit existing customer ([customerCode] required)
  Future<Map<String, dynamic>> createContactInfo({
    required String customerName,
    required String shopName,
    required String contactNumber,
    required String location,
    required String address,
    required String businessType,
    required String products,
    required String remarks,
    required String status,
    double? expectedAmount,
    String flag = 'N',
    String? customerCode,
  }) async {
    final addressValue = address.trim();
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.customerContactInfo,
      data: {
        'customerName': customerName.trim(),
        'shopName': shopName.trim(),
        'contactNumber': contactNumber.trim(),
        'location': location.trim(),
        'address': addressValue,
        'Address': addressValue,
        'businessType': businessType.trim(),
        'products': products.trim(),
        'remarks': remarks.trim(),
        'status': status.trim(),
        'flag': flag.trim().toUpperCase(),
        if (customerCode != null && customerCode.trim().isNotEmpty)
          'customerCode': customerCode.trim(),
        if (expectedAmount != null) 'expectedAmount': expectedAmount,
      },
    );

    final data = response.data;
    if (data == null) {
      throw ApiException(message: 'Empty response from server');
    }
    return data;
  }

  /// Records an edit of name / mobile / address into `CRGS_CONTACTINFO` (FLAG=E).
  Future<Map<String, dynamic>> submitCustomerEdit({
    required String customerCode,
    required String customerName,
    required String mobile,
    required String address,
    String shopName = '',
    String location = '',
  }) {
    return createContactInfo(
      customerName: customerName,
      shopName: shopName.isNotEmpty ? shopName : customerName,
      contactNumber: mobile,
      location: location,
      address: address,
      businessType: '',
      products: '',
      remarks: '',
      status: 'Prospect',
      flag: 'E',
      customerCode: customerCode,
    );
  }

  /// Updates editable fields on an existing customer (`PUT /customers/:code`).
  Future<CustomerModel> updateCustomer({
    required String custCode,
    String? customerName,
    String? mobile,
    String? wpno,
    String? address,
    String? locationMap,
    String? type,
  }) async {
    final data = <String, dynamic>{
      if (customerName != null) 'customerName': customerName.trim(),
      if (mobile != null) 'mobile': mobile.trim(),
      if (wpno != null) 'wpno': wpno.trim(),
      if (address != null) 'address': address.trim(),
      if (locationMap != null) 'locationMap': locationMap.trim(),
      if (type != null) 'type': type.trim(),
    };
    if (data.isEmpty) {
      throw ApiException(message: 'No fields to update');
    }

    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.customerByCode(custCode),
      data: data,
    );

    final body = response.data;
    if (body == null) {
      throw ApiException(message: 'Empty response from server');
    }
    return CustomerModel.fromDb(body);
  }
}
