import 'package:flutter/material.dart' show TimeOfDay;

enum CustomerPriority {
  missing,
  outstanding,
  followUp,
  regular,
}

enum FollowUpStatus { pending, completed, missed }

enum TaskStatus { pending, inProgress, completed }

enum TaskPriority { low, medium, high, urgent }

enum TaskType { routeTask, additionalTask }

enum ProspectStatus { prospect, followUp, converted }

enum VisitStatus { notStarted, inProgress, completed }

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.employeeCode,
    required this.email,
    required this.assignedRoute,
    required this.assignedRouteId,
    this.assignedRouteNos = const [],
    this.onboardingCompleted = false,
    this.avatarUrl,
    this.monthlyTarget = 0,
    this.monthlyAchieved = 0,
    this.accessToken,
    this.roleCode,
  });

  final String id;
  final String name;
  final String employeeCode;
  final String email;
  final String assignedRoute;
  final String assignedRouteId;
  final List<String> assignedRouteNos;
  final bool onboardingCompleted;
  final String? avatarUrl;
  final double monthlyTarget;
  final double monthlyAchieved;
  final String? accessToken;
  final String? roleCode;

  double get targetPercentage =>
      monthlyTarget > 0 ? (monthlyAchieved / monthlyTarget) * 100 : 0;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        employeeCode: json['employee_code'] as String,
        email: json['email'] as String,
        assignedRoute: json['assigned_route'] as String,
        assignedRouteId: json['assigned_route_id'] as String,
        assignedRouteNos: _parseRouteNosFromJson(json),
        onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
        avatarUrl: json['avatar_url'] as String?,
        monthlyTarget: (json['monthly_target'] as num?)?.toDouble() ?? 0,
        monthlyAchieved: (json['monthly_achieved'] as num?)?.toDouble() ?? 0,
        accessToken: json['access_token'] as String?,
        roleCode: json['role_code']?.toString(),
      );

  factory UserModel.fromLoginResponse(Map<String, dynamic> json) {
    final routeRaw = json['route'];
    final routeText = routeRaw == null ? '' : routeRaw.toString().trim();
    final routeNos = routeText.isEmpty
        ? <String>[]
        : routeText
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();

    return UserModel(
      id: json['employeeCode']?.toString() ?? '',
      name: json['username']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? '',
      email: '',
      assignedRoute:
          routeNos.isEmpty ? 'No routes assigned' : routeNos.join(', '),
      assignedRouteId: routeNos.isNotEmpty ? routeNos.first : '',
      assignedRouteNos: routeNos,
      onboardingCompleted: _isOnboardingComplete(json['onboardFlag']),
      accessToken: json['token']?.toString(),
      roleCode: json['roleCode']?.toString(),
    );
  }

  static List<String> _parseRouteNosFromJson(Map<String, dynamic> json) {
    final stored = json['assigned_route_nos'];
    if (stored is List) {
      return stored
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }

    final routeText = json['assigned_route']?.toString() ?? '';
    if (routeText.isNotEmpty && routeText != 'No routes assigned') {
      return routeText
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }

    final single = json['assigned_route_id']?.toString() ?? '';
    if (single.isNotEmpty) return [single];
    return [];
  }

  static bool _isOnboardingComplete(dynamic value) {
    if (value == null) return false;
    final flag = value.toString().trim().toUpperCase();
    return flag == 'Y' || flag == '1';
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? employeeCode,
    String? email,
    String? assignedRoute,
    String? assignedRouteId,
    List<String>? assignedRouteNos,
    bool? onboardingCompleted,
    String? avatarUrl,
    double? monthlyTarget,
    double? monthlyAchieved,
    String? accessToken,
    String? roleCode,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeCode: employeeCode ?? this.employeeCode,
      email: email ?? this.email,
      assignedRoute: assignedRoute ?? this.assignedRoute,
      assignedRouteId: assignedRouteId ?? this.assignedRouteId,
      assignedRouteNos: assignedRouteNos ?? this.assignedRouteNos,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      monthlyTarget: monthlyTarget ?? this.monthlyTarget,
      monthlyAchieved: monthlyAchieved ?? this.monthlyAchieved,
      accessToken: accessToken ?? this.accessToken,
      roleCode: roleCode ?? this.roleCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'employee_code': employeeCode,
        'email': email,
        'assigned_route': assignedRoute,
        'assigned_route_id': assignedRouteId,
        'assigned_route_nos': assignedRouteNos,
        'onboarding_completed': onboardingCompleted,
        'avatar_url': avatarUrl,
        'monthly_target': monthlyTarget,
        'monthly_achieved': monthlyAchieved,
        'access_token': accessToken,
        'role_code': roleCode,
      };
}

class RouteModel {
  const RouteModel({
    required this.id,
    required this.name,
    required this.routeNumber,
    required this.imageAsset,
    this.zone = '',
  });

  final String id;
  final String name;
  final String routeNumber;
  final String imageAsset;
  final String zone;

  factory RouteModel.fromDb({
    required String routeno,
    required String routename,
    String? imageAsset,
  }) {
    return RouteModel(
      id: routeno,
      name: routename,
      routeNumber: routeno,
      imageAsset: imageAsset ?? 'assets/images/routes/route_abu_hamur.jpg',
      zone: 'Route ID: $routeno',
    );
  }
}

class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.mobile,
    required this.location,
    required this.routeName,
    required this.routeId,
    required this.priority,
    this.lastPurchaseDate,
    this.lastPurchaseAmount = 0,
    this.lastPurchaseBillNo = '',
    this.lastPurchaseLocation = '',
    this.outstandingAmount = 0,
    this.averageMonthlyPurchase = 0,
    this.purchaseFrequency = '',
    this.creditLimit = 0,
    this.riskScore = 0,
    this.gpsDistanceKm = 0,
    this.latitude = 0,
    this.longitude = 0,
    this.category = '',
    this.address = '',
    this.creditAmount = 0,
    this.categoryCode = '',
    this.categoryName = '',
    this.customerType = '',
    this.customerStatus = '',
    this.createdStatus = '',
    this.wpno = '',
    this.locationMap = '',
    this.isMissing = false,
    this.daysSincePurchase,
  });

  final String id;
  final String name;
  final String contactPerson;
  final String mobile;
  final String location;
  final String routeName;
  final String routeId;
  final CustomerPriority priority;
  final DateTime? lastPurchaseDate;
  final double lastPurchaseAmount;
  final String lastPurchaseBillNo;
  final String lastPurchaseLocation;
  final double outstandingAmount;
  final double averageMonthlyPurchase;
  final String purchaseFrequency;
  final double creditLimit;
  final int riskScore;
  final double gpsDistanceKm;
  final double latitude;
  final double longitude;
  final String category;
  final String address;
  final double creditAmount;
  final String categoryCode;
  final String categoryName;
  final String customerType;
  final String customerStatus;
  final String createdStatus;
  final String wpno;
  final String locationMap;
  final bool isMissing;
  final int? daysSincePurchase;

  CustomerModel copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? mobile,
    String? location,
    String? routeName,
    String? routeId,
    CustomerPriority? priority,
    DateTime? lastPurchaseDate,
    double? lastPurchaseAmount,
    String? lastPurchaseBillNo,
    String? lastPurchaseLocation,
    double? outstandingAmount,
    double? averageMonthlyPurchase,
    String? purchaseFrequency,
    double? creditLimit,
    int? riskScore,
    double? gpsDistanceKm,
    double? latitude,
    double? longitude,
    String? category,
    String? address,
    double? creditAmount,
    String? categoryCode,
    String? categoryName,
    String? customerType,
    String? customerStatus,
    String? createdStatus,
    String? wpno,
    String? locationMap,
    bool? isMissing,
    int? daysSincePurchase,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      mobile: mobile ?? this.mobile,
      location: location ?? this.location,
      routeName: routeName ?? this.routeName,
      routeId: routeId ?? this.routeId,
      priority: priority ?? this.priority,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      lastPurchaseAmount: lastPurchaseAmount ?? this.lastPurchaseAmount,
      lastPurchaseBillNo: lastPurchaseBillNo ?? this.lastPurchaseBillNo,
      lastPurchaseLocation: lastPurchaseLocation ?? this.lastPurchaseLocation,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      averageMonthlyPurchase:
          averageMonthlyPurchase ?? this.averageMonthlyPurchase,
      purchaseFrequency: purchaseFrequency ?? this.purchaseFrequency,
      creditLimit: creditLimit ?? this.creditLimit,
      riskScore: riskScore ?? this.riskScore,
      gpsDistanceKm: gpsDistanceKm ?? this.gpsDistanceKm,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      address: address ?? this.address,
      creditAmount: creditAmount ?? this.creditAmount,
      categoryCode: categoryCode ?? this.categoryCode,
      categoryName: categoryName ?? this.categoryName,
      customerType: customerType ?? this.customerType,
      customerStatus: customerStatus ?? this.customerStatus,
      createdStatus: createdStatus ?? this.createdStatus,
      wpno: wpno ?? this.wpno,
      locationMap: locationMap ?? this.locationMap,
      isMissing: isMissing ?? this.isMissing,
      daysSincePurchase: daysSincePurchase ?? this.daysSincePurchase,
    );
  }

  factory CustomerModel.fromDb(Map<String, dynamic> json) {
    final creditLimit = _toDouble(json['credit_limit']);
    final creditAmount = _toDouble(json['credit_amount']);
    final locationMap = json['locationmap']?.toString().trim() ?? '';
    final coords = _parseLocationMap(locationMap);
    final status = (json['customerstatus']?.toString() ?? '').toUpperCase();
    final categoryName = json['categoryname']?.toString().trim() ?? '';
    final categoryCode = json['category']?.toString().trim() ?? '';
    final address = json['address']?.toString().trim() ?? '';

    final lastPurchaseRaw = json['last_purchase_date'];
    DateTime? lastPurchaseDate;
    if (lastPurchaseRaw != null && lastPurchaseRaw.toString().trim().isNotEmpty) {
      lastPurchaseDate = DateTime.tryParse(lastPurchaseRaw.toString());
    }

    final isMissing = _toBool(json['is_missing']);
    final daysSinceRaw = json['days_since_purchase'];
    final daysSincePurchase =
        daysSinceRaw is num ? daysSinceRaw.toInt() : int.tryParse('$daysSinceRaw');

    return CustomerModel(
      id: json['cust_code']?.toString().trim() ?? '',
      name: json['cust_name']?.toString().trim() ?? '',
      contactPerson: json['type']?.toString().trim() ?? '',
      mobile: json['mobile']?.toString().trim() ?? '',
      location: address,
      address: address,
      routeName: json['routename']?.toString().trim() ?? '',
      routeId: _normalizeRouteNo(json['route']?.toString() ?? ''),
      priority: isMissing
          ? CustomerPriority.missing
          : _priorityFromStatus(status, creditAmount),
      isMissing: isMissing,
      daysSincePurchase: daysSincePurchase,
      lastPurchaseDate: lastPurchaseDate,
      lastPurchaseAmount: _toDouble(json['last_purchase_amount']),
      lastPurchaseBillNo: json['last_purchase_billno']?.toString().trim() ?? '',
      lastPurchaseLocation:
          json['last_purchase_location']?.toString().trim() ?? '',
      creditLimit: creditLimit,
      outstandingAmount: creditAmount,
      creditAmount: creditAmount,
      category: categoryName.isNotEmpty ? categoryName : categoryCode,
      categoryCode: categoryCode,
      categoryName: categoryName,
      customerType: json['type']?.toString().trim() ?? '',
      customerStatus: json['customerstatus']?.toString().trim() ?? '',
      createdStatus: json['createdstatus']?.toString().trim() ?? '',
      wpno: json['wpno']?.toString().trim() ?? '',
      locationMap: locationMap,
      latitude: coords.$1,
      longitude: coords.$2,
    );
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'] as String,
        name: json['name'] as String,
        contactPerson: json['contact_person'] as String,
        mobile: json['mobile'] as String,
        location: json['location'] as String,
        routeName: json['route_name'] as String,
        routeId: json['route_id'] as String,
        priority: CustomerPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => CustomerPriority.regular,
        ),
        lastPurchaseDate: json['last_purchase_date'] != null
            ? DateTime.parse(json['last_purchase_date'] as String)
            : null,
        lastPurchaseAmount:
            (json['last_purchase_amount'] as num?)?.toDouble() ?? 0,
        outstandingAmount:
            (json['outstanding_amount'] as num?)?.toDouble() ?? 0,
        averageMonthlyPurchase:
            (json['average_monthly_purchase'] as num?)?.toDouble() ?? 0,
        purchaseFrequency: json['purchase_frequency'] as String? ?? '',
        creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
        riskScore: json['risk_score'] as int? ?? 0,
        gpsDistanceKm: (json['gps_distance_km'] as num?)?.toDouble() ?? 0,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        category: json['category'] as String? ?? '',
      );

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'y';
  }

  static (double, double) _parseLocationMap(String value) {
    if (value.isEmpty) return (0, 0);
    final parts = value.split(',');
    if (parts.length < 2) return (0, 0);
    final lat = double.tryParse(parts[0].trim()) ?? 0;
    final lng = double.tryParse(parts[1].trim()) ?? 0;
    return (lat, lng);
  }

  static String _normalizeRouteNo(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    final numeric = int.tryParse(text);
    if (numeric != null) return numeric.toString();
    return text;
  }

  static CustomerPriority _priorityFromStatus(String status, double creditAmount) {
    if (status.contains('MISS')) return CustomerPriority.missing;
    if (status.contains('OUT') || creditAmount > 0) {
      return CustomerPriority.outstanding;
    }
    if (status.contains('FOLLOW')) return CustomerPriority.followUp;
    return CustomerPriority.regular;
  }
}

enum TargetPeriod {
  daily,
  weekly,
  monthly;

  String get apiValue => name;

  String get label => switch (this) {
        TargetPeriod.daily => 'Daily',
        TargetPeriod.weekly => 'Weekly',
        TargetPeriod.monthly => 'Monthly',
      };

  static TargetPeriod? fromApi(String? value) {
    final text = (value ?? '').trim().toLowerCase();
    return switch (text) {
      'daily' || 'd' => TargetPeriod.daily,
      'weekly' || 'w' => TargetPeriod.weekly,
      'monthly' || 'm' => TargetPeriod.monthly,
      _ => null,
    };
  }
}

class SalesTargetModel {
  const SalesTargetModel({
    required this.employeeCode,
    required this.period,
    required this.targetAmount,
    required this.achievedAmount,
    required this.routeNo,
    this.dueDate = '',
  });

  final String employeeCode;
  final TargetPeriod period;
  final double targetAmount;
  final double achievedAmount;
  final String routeNo;
  final String dueDate;

  factory SalesTargetModel.fromJson(Map<String, dynamic> json) =>
      SalesTargetModel(
        employeeCode: json['employeeCode']?.toString() ?? '',
        period: TargetPeriod.fromApi(json['period']?.toString()) ??
            TargetPeriod.monthly,
        targetAmount: _toDouble(json['targetAmount']),
        achievedAmount: _toDouble(json['achievedAmount']),
        routeNo: json['routeNo']?.toString() ?? '',
        dueDate: json['dueDate']?.toString() ?? '',
      );

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }
}

class ProductTargetModel {
  const ProductTargetModel({
    required this.employeeCode,
    required this.products,
    required this.productNames,
    required this.type,
    required this.targetValue,
    required this.achievedValue,
    required this.routeNo,
    this.baseUoms = const [],
    this.retailPrices = const [],
    this.currentStocks = const [],
    this.quantityLimits = const [],
  });

  final String employeeCode;
  final List<String> products;
  final List<String> productNames;
  final List<String> baseUoms;
  final List<double> retailPrices;
  final List<double> currentStocks;
  final List<double> quantityLimits;
  final String type;
  final double targetValue;
  final double achievedValue;
  final String routeNo;

  List<String> get displayProductNames =>
      productNames.isNotEmpty ? productNames : products;

  String get typeLabel => _productTypeLabel(type);

  String get productsLabel {
    final names = displayProductNames;
    if (names.isEmpty) return 'All products';
    if (names.length == 1) return names.first;
    return '${names.length} products';
  }

  String baseUomAt(int index) =>
      index >= 0 && index < baseUoms.length ? baseUoms[index] : '';

  double retailPriceAt(int index) =>
      index >= 0 && index < retailPrices.length ? retailPrices[index] : 0;

  double currentStockAt(int index) =>
      index >= 0 && index < currentStocks.length ? currentStocks[index] : 0;

  double quantityLimitAt(int index) =>
      index >= 0 && index < quantityLimits.length ? quantityLimits[index] : 0;

  factory ProductTargetModel.fromJson(Map<String, dynamic> json) {
    final productsRaw = json['products'];
    final products = productsRaw is List
        ? productsRaw.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList()
        : <String>[];
    final productNamesRaw = json['productNames'];
    final productNames = productNamesRaw is List
        ? productNamesRaw.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList()
        : <String>[];
    final baseUomsRaw = json['baseUoms'];
    final baseUoms = baseUomsRaw is List
        ? baseUomsRaw.map((item) => item.toString().trim()).toList()
        : <String>[];
    final retailPricesRaw = json['retailPrices'];
    final retailPrices = retailPricesRaw is List
        ? retailPricesRaw.map(SalesTargetModel._toDouble).toList()
        : <double>[];
    final currentStocksRaw = json['currentStocks'];
    final currentStocks = currentStocksRaw is List
        ? currentStocksRaw.map(SalesTargetModel._toDouble).toList()
        : <double>[];
    final quantityLimitsRaw = json['quantityLimits'];
    final quantityLimits = quantityLimitsRaw is List
        ? quantityLimitsRaw.map(SalesTargetModel._toDouble).toList()
        : <double>[];

    return ProductTargetModel(
      employeeCode: json['employeeCode']?.toString() ?? '',
      products: products,
      productNames: productNames,
      baseUoms: baseUoms,
      retailPrices: retailPrices,
      currentStocks: currentStocks,
      quantityLimits: quantityLimits,
      type: json['type']?.toString() ?? '',
      targetValue: SalesTargetModel._toDouble(json['targetValue']),
      achievedValue: SalesTargetModel._toDouble(json['achievedValue']),
      routeNo: json['routeNo']?.toString() ?? '',
    );
  }

  static String _productTypeLabel(String value) => switch (value) {
        'quantity' => 'Quantity',
        'volume' => 'Volume',
        'new_promotion' => 'New Promotion',
        'replacement' => 'Replacement',
        'own_products' => 'Own Products',
        _ => value.replaceAll('_', ' ').split(' ').map((part) {
            if (part.isEmpty) return part;
            return '${part[0].toUpperCase()}${part.substring(1)}';
          }).join(' '),
      };
}

class CustomerTargetModel {
  const CustomerTargetModel({
    required this.employeeCode,
    required this.type,
    required this.targetCount,
    required this.achievedCount,
    required this.targetAmount,
    required this.period,
    required this.routeNo,
  });

  final String employeeCode;
  final String type;
  final double targetCount;
  final double achievedCount;
  final double targetAmount;
  final TargetPeriod period;
  final String routeNo;

  String get typeLabel => _customerTypeLabel(type);

  factory CustomerTargetModel.fromJson(Map<String, dynamic> json) =>
      CustomerTargetModel(
        employeeCode: json['employeeCode']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        targetCount: SalesTargetModel._toDouble(json['targetCount']),
        achievedCount: SalesTargetModel._toDouble(json['achievedCount']),
        targetAmount: SalesTargetModel._toDouble(json['targetAmount']),
        period: TargetPeriod.fromApi(json['period']?.toString()) ??
            TargetPeriod.monthly,
        routeNo: json['routeNo']?.toString() ?? '',
      );

  static String _customerTypeLabel(String value) => switch (value) {
        'new_acquisition' => 'New Acquisition',
        'missing_recovery' => 'Missing Recovery',
        'outstanding_collection' => 'Outstanding Collection',
        'purchase_limit' => 'Purchase Limit',
        _ => value.replaceAll('_', ' ').split(' ').map((part) {
            if (part.isEmpty) return part;
            return '${part[0].toUpperCase()}${part.substring(1)}';
          }).join(' '),
      };
}

class PeriodTargetTotals {
  const PeriodTargetTotals({
    required this.period,
    this.target = 0,
    this.achieved = 0,
  });

  final TargetPeriod period;
  final double target;
  final double achieved;

  double get percent =>
      target > 0 ? ((achieved / target) * 100).clamp(0, 999) : 0;
}

class CustomerTargetsResult {
  const CustomerTargetsResult({
    this.targets = const [],
    this.newCustomersFlagN = 0,
  });

  final List<CustomerTargetModel> targets;
  /// Total add-customer rows in CONTACTINFO with FLAG = N.
  final int newCustomersFlagN;
}

class ExecutiveTargetsData {
  const ExecutiveTargetsData({
    this.salesByPeriod = const [],
    this.productTargets = const [],
    this.customerByPeriod = const [],
    this.newCustomersFlagN = 0,
  });

  final List<PeriodTargetTotals> salesByPeriod;
  final List<ProductTargetModel> productTargets;
  final List<CustomerTargetModel> customerByPeriod;
  final int newCustomersFlagN;

  PeriodTargetTotals? salesFor(TargetPeriod period) {
    for (final item in salesByPeriod) {
      if (item.period == period) return item;
    }
    return null;
  }

  List<CustomerTargetModel> customersFor(TargetPeriod period) =>
      customerByPeriod.where((item) => item.period == period).toList();

  /// New acquisition targets only (add-customer / FLAG=N progress).
  List<CustomerTargetModel> get newAcquisitionTargets => customerByPeriod
      .where((item) => item.type == 'new_acquisition')
      .toList();

  double get newAcquisitionTargetCount => newAcquisitionTargets.fold<double>(
        0,
        (sum, item) => sum + item.targetCount,
      );

  double get monthlySalesTarget => salesFor(TargetPeriod.monthly)?.target ?? 0;
  double get monthlySalesAchieved =>
      salesFor(TargetPeriod.monthly)?.achieved ?? 0;
  double get dailySalesTarget => salesFor(TargetPeriod.daily)?.target ?? 0;
  double get dailySalesAchieved => salesFor(TargetPeriod.daily)?.achieved ?? 0;
}

class DashboardSummary {
  const DashboardSummary({
    this.todaysVisits = 0,
    this.missingCustomers = 0,
    this.followUpCustomers = 0,
    this.newLeads = 0,
    this.outstandingCustomers = 0,
    this.todaysTasks = 0,
    this.dailySalesTargetPercent = 0,
    this.monthlyTargetPercent = 0,
    this.routePerformance = 0,
    this.dailyTargetAmount = 0,
    this.dailyAchievedAmount = 0,
    this.monthlyTargetAmount = 0,
    this.monthlyAchievedAmount = 0,
  });

  final int todaysVisits;
  final int missingCustomers;
  final int followUpCustomers;
  final int newLeads;
  final int outstandingCustomers;
  final int todaysTasks;
  final double dailySalesTargetPercent;
  final double monthlyTargetPercent;
  final double routePerformance;
  final double dailyTargetAmount;
  final double dailyAchievedAmount;
  final double monthlyTargetAmount;
  final double monthlyAchievedAmount;

  DashboardSummary copyWith({
    int? todaysVisits,
    int? missingCustomers,
    int? followUpCustomers,
    int? newLeads,
    int? outstandingCustomers,
    int? todaysTasks,
    double? dailySalesTargetPercent,
    double? monthlyTargetPercent,
    double? routePerformance,
    double? dailyTargetAmount,
    double? dailyAchievedAmount,
    double? monthlyTargetAmount,
    double? monthlyAchievedAmount,
  }) =>
      DashboardSummary(
        todaysVisits: todaysVisits ?? this.todaysVisits,
        missingCustomers: missingCustomers ?? this.missingCustomers,
        followUpCustomers: followUpCustomers ?? this.followUpCustomers,
        newLeads: newLeads ?? this.newLeads,
        outstandingCustomers: outstandingCustomers ?? this.outstandingCustomers,
        todaysTasks: todaysTasks ?? this.todaysTasks,
        dailySalesTargetPercent:
            dailySalesTargetPercent ?? this.dailySalesTargetPercent,
        monthlyTargetPercent: monthlyTargetPercent ?? this.monthlyTargetPercent,
        routePerformance: routePerformance ?? this.routePerformance,
        dailyTargetAmount: dailyTargetAmount ?? this.dailyTargetAmount,
        dailyAchievedAmount: dailyAchievedAmount ?? this.dailyAchievedAmount,
        monthlyTargetAmount: monthlyTargetAmount ?? this.monthlyTargetAmount,
        monthlyAchievedAmount:
            monthlyAchievedAmount ?? this.monthlyAchievedAmount,
      );
}

class TaskModel {
  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.status,
    required this.type,
    this.notes = '',
    this.customerId,
    this.customerName,
    this.routeId,
    this.routeName,
    this.taskTypeCode = '',
    this.employeeCode = '',
  });

  final String id;
  final String title;
  final String description;
  final TaskPriority priority;
  final DateTime dueDate;
  final TaskStatus status;
  final TaskType type;
  final String notes;
  final String? customerId;
  final String? customerName;
  final String? routeId;
  final String? routeName;
  /// Oracle `CRGS_TASK.TYPE` value (e.g. missing_customer_followup).
  final String taskTypeCode;
  final String employeeCode;

  TaskModel copyWith({
    TaskStatus? status,
    String? notes,
  }) {
    return TaskModel(
      id: id,
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
      status: status ?? this.status,
      type: type,
      notes: notes ?? this.notes,
      customerId: customerId,
      customerName: customerName,
      routeId: routeId,
      routeName: routeName,
      taskTypeCode: taskTypeCode,
      employeeCode: employeeCode,
    );
  }

  /// Maps a row from the Oracle `CRGS_TASK` table (TYPE, ROUTE, STATUS,
  /// DUEDATE) into a [TaskModel] for display in the task list.
  factory TaskModel.fromDb(Map<String, dynamic> json) {
    final typeCode = (json['type']?.toString() ?? '').trim().toLowerCase();
    final employeeCode = (json['employeeCode']?.toString() ?? '').trim();
    final routeNo = (json['routeNo']?.toString() ?? '').trim();
    final routeName = routeNo.isEmpty ? null : 'Route $routeNo';
    final dueDateRaw = (json['dueDate']?.toString() ?? '').trim();
    final dueDate = DateTime.tryParse(dueDateRaw) ?? DateTime.now();

    return TaskModel(
      id: [typeCode, employeeCode, routeNo, dueDateRaw]
          .where((part) => part.isNotEmpty)
          .join('-'),
      title: _dbTaskTitle(typeCode),
      description: _dbTaskDescription(typeCode),
      priority: TaskPriority.medium,
      dueDate: dueDate,
      status: _dbTaskStatus(json['status']?.toString()),
      type: TaskType.routeTask,
      routeId: routeNo.isEmpty ? null : routeNo,
      routeName: routeName,
      taskTypeCode: typeCode,
      employeeCode: employeeCode,
    );
  }

  static String _dbTaskTitle(String typeCode) => switch (typeCode) {
        'missing_customer_followup' => 'Missing Customer Follow-up',
        'outstanding_collection_followup' => 'Outstanding Collection Follow-up',
        'new_product_introduction' => 'New Product Introduction',
        'product_replacement_campaign' => 'Product Replacement Campaign',
        'customer_visit_campaign' => 'Customer Visit Campaign',
        'own_products' => 'Own Products',
        'market_research' => 'Market Research',
        'other' => 'Other',
        _ => typeCode.isEmpty
            ? 'Task'
            : typeCode
                .replaceAll('_', ' ')
                .split(' ')
                .map((part) => part.isEmpty
                    ? part
                    : '${part[0].toUpperCase()}${part.substring(1)}')
                .join(' '),
      };

  static String _dbTaskDescription(String typeCode) => switch (typeCode) {
        'missing_customer_followup' =>
          'Follow up with missing customers on the assigned route',
        'outstanding_collection_followup' =>
          'Collect outstanding balances from customers on the route',
        'new_product_introduction' =>
          'Introduce new products to customers on the route',
        'product_replacement_campaign' =>
          'Handle product replacement for customers on the route',
        'customer_visit_campaign' =>
          'Complete scheduled customer visits on the route',
        'own_products' => 'Push own products with customers on the route',
        'market_research' => 'Gather market research on the assigned route',
        'other' => 'Complete the assigned task on the route',
        _ => 'Complete the assigned task on the route',
      };

  static TaskStatus _dbTaskStatus(String? value) {
    final text = (value ?? '').trim().toLowerCase().replaceAll(' ', '_');
    return switch (text) {
      'completed' || 'complete' || 'done' || 'c' => TaskStatus.completed,
      'in_progress' || 'inprogress' || 'progress' || 'started' || 'p' =>
        TaskStatus.inProgress,
      _ => TaskStatus.pending,
    };
  }
}

class CustomerFollowUpProgress {
  const CustomerFollowUpProgress({
    required this.customerId,
    required this.customerName,
    required this.routeName,
    required this.completedFollowUps,
    required this.totalFollowUps,
  });

  final String customerId;
  final String customerName;
  final String routeName;
  final int completedFollowUps;
  final int totalFollowUps;

  double get progressFraction =>
      totalFollowUps > 0 ? completedFollowUps / totalFollowUps : 0;
}

class FollowUpModel {
  const FollowUpModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.date,
    required this.time,
    required this.priority,
    required this.notes,
    required this.status,
  });

  final String id;
  final String customerId;
  final String customerName;
  final DateTime date;
  final TimeOfDay time;
  final TaskPriority priority;
  final String notes;
  final FollowUpStatus status;
}

class VisitModel {
  const VisitModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.status,
    this.employeeCode = '',
    this.route = '',
    this.startTime,
    this.endTime,
    this.currentLocation = '',
    this.duration = Duration.zero,
    this.latitude,
    this.longitude,
    this.persisted = false,
  });

  final String id;
  final String customerId;
  final String customerName;
  final VisitStatus status;
  final String employeeCode;
  final String route;
  final DateTime? startTime;
  final DateTime? endTime;
  final String currentLocation;
  final Duration duration;
  final double? latitude;
  final double? longitude;
  final bool persisted;

  VisitModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    VisitStatus? status,
    String? employeeCode,
    String? route,
    DateTime? startTime,
    DateTime? endTime,
    String? currentLocation,
    Duration? duration,
    double? latitude,
    double? longitude,
    bool? persisted,
  }) {
    return VisitModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      employeeCode: employeeCode ?? this.employeeCode,
      route: route ?? this.route,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      currentLocation: currentLocation ?? this.currentLocation,
      duration: duration ?? this.duration,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      persisted: persisted ?? this.persisted,
    );
  }
}

/// Prospect / created-customer row from Oracle `CRGS_CONTACTINFO`.
class ContactInfoModel {
  const ContactInfoModel({
    required this.customerCode,
    required this.customerName,
    required this.shopName,
    this.contactNumber = '',
    this.location = '',
    this.address = '',
    this.businessType = '',
    this.expectedAmount,
    this.products = '',
    this.remarks = '',
    this.status = '',
    this.flag = '',
  });

  final String customerCode;
  final String customerName;
  final String shopName;
  final String contactNumber;
  final String location;
  final String address;
  final String businessType;
  final double? expectedAmount;
  final String products;
  final String remarks;
  final String status;
  final String flag;

  factory ContactInfoModel.fromJson(Map<String, dynamic> json) {
    final expectedRaw = json['expectedAmount'];
    double? expectedAmount;
    if (expectedRaw is num) {
      expectedAmount = expectedRaw.toDouble();
    } else if (expectedRaw != null) {
      expectedAmount = double.tryParse(expectedRaw.toString());
    }

    return ContactInfoModel(
      customerCode: json['customerCode']?.toString().trim() ?? '',
      customerName: json['customerName']?.toString().trim() ?? '',
      shopName: json['shopName']?.toString().trim() ?? '',
      contactNumber: json['contactNumber']?.toString().trim() ?? '',
      location: json['location']?.toString().trim() ?? '',
      address: json['address']?.toString().trim() ?? '',
      businessType: json['businessType']?.toString().trim() ?? '',
      expectedAmount: expectedAmount,
      products: json['products']?.toString().trim() ?? '',
      remarks: json['remarks']?.toString().trim() ?? '',
      status: json['status']?.toString().trim() ?? '',
      flag: json['flag']?.toString().trim() ?? '',
    );
  }
}

/// Persisted visit row from Oracle `CRGS_VISITDETAILS` list API.
class VisitRecordModel {
  const VisitRecordModel({
    required this.employeeCode,
    required this.customerCode,
    required this.customerName,
    this.route = '',
    this.visitDate = '',
    this.visitStart = '',
    this.visitEnd = '',
    this.totalDuration = '',
    this.location = '',
    this.reason = '',
    this.remarks = '',
    this.followUp = '',
  });

  final String employeeCode;
  final String customerCode;
  final String customerName;
  final String route;
  final String visitDate;
  final String visitStart;
  final String visitEnd;
  final String totalDuration;
  final String location;
  final String reason;
  final String remarks;
  final String followUp;

  bool get isCompleted => visitEnd.trim().isNotEmpty;

  factory VisitRecordModel.fromJson(Map<String, dynamic> json) {
    return VisitRecordModel(
      employeeCode: json['employeeCode']?.toString().trim() ?? '',
      customerCode: json['customerCode']?.toString().trim() ?? '',
      customerName: json['customerName']?.toString().trim() ?? '',
      route: json['route']?.toString().trim() ?? '',
      visitDate: json['visitDate']?.toString().trim() ?? '',
      visitStart: json['visitStart']?.toString().trim() ?? '',
      visitEnd: json['visitEnd']?.toString().trim() ?? '',
      totalDuration: json['totalDuration']?.toString().trim() ?? '',
      location: json['location']?.toString().trim() ?? '',
      reason: json['reason']?.toString().trim() ?? '',
      remarks: json['remarks']?.toString().trim() ?? '',
      followUp: json['followUp']?.toString().trim() ?? '',
    );
  }
}

/// Persisted market research row from Oracle `CRGS_MARKETRESEARCH`.
class MarketResearchRecordModel {
  const MarketResearchRecordModel({
    required this.employeeCode,
    required this.route,
    this.marketTrend = '',
    this.fastMovingProducts = '',
    this.slowMovingProducts = '',
    this.competitorPromotions = '',
    this.newOpportunities = '',
    this.notes = '',
  });

  final String employeeCode;
  final String route;
  final String marketTrend;
  final String fastMovingProducts;
  final String slowMovingProducts;
  final String competitorPromotions;
  final String newOpportunities;
  final String notes;

  factory MarketResearchRecordModel.fromJson(Map<String, dynamic> json) {
    return MarketResearchRecordModel(
      employeeCode: json['employeeCode']?.toString().trim() ?? '',
      route: json['route']?.toString().trim() ?? '',
      marketTrend: json['marketTrend']?.toString().trim() ?? '',
      fastMovingProducts: json['fastMovingProducts']?.toString().trim() ?? '',
      slowMovingProducts: json['slowMovingProducts']?.toString().trim() ?? '',
      competitorPromotions:
          json['competitorPromotions']?.toString().trim() ?? '',
      newOpportunities: json['newOpportunities']?.toString().trim() ?? '',
      notes: json['notes']?.toString().trim() ?? '',
    );
  }
}

class OutstandingInvoice {
  const OutstandingInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.outstandingAmount,
    required this.customerId,
    required this.customerName,
  });

  final String id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final double outstandingAmount;
  final String customerId;
  final String customerName;
}

class RecommendedProduct {
  const RecommendedProduct({
    required this.id,
    required this.name,
    required this.lastPurchasedQty,
    required this.suggestedQty,
    this.imageUrl,
    this.category = '',
  });

  final String id;
  final String name;
  final double lastPurchasedQty;
  final double suggestedQty;
  final String? imageUrl;
  final String category;
}

class AlternativeProductModel {
  const AlternativeProductModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.details,
    this.category = '',
    this.unitPrice = 0,
    this.baseUom = '',
    this.stock = 0,
    this.qtyLimit = 0,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String details;
  final String category;
  final double unitPrice;
  final String baseUom;
  /// CURRENTSTOCK from ITEMMASTER.
  final double stock;
  /// QUANTITYLIMIT from ITEMMASTER. When > 0, max order qty is this value.
  final double qtyLimit;

  bool get hasQtyLimit => qtyLimit > 0;

  String get priceLabel {
    if (unitPrice <= 0) return '';
    return unitPrice % 1 == 0
        ? unitPrice.toStringAsFixed(0)
        : unitPrice.toStringAsFixed(2);
  }

  String get uomPriceLabel {
    final uom = baseUom.trim();
    final price = priceLabel;
    if (uom.isNotEmpty && price.isNotEmpty) return '$uom · $price';
    if (uom.isNotEmpty) return uom;
    if (price.isNotEmpty) return price;
    return '';
  }

  String get _stockLabel {
    final value = stock % 1 == 0
        ? stock.toStringAsFixed(0)
        : stock.toStringAsFixed(2);
    return 'Stock $value';
  }

  String get _qtyLimitLabel {
    if (!hasQtyLimit) return '';
    final value = qtyLimit % 1 == 0
        ? qtyLimit.toStringAsFixed(0)
        : qtyLimit.toStringAsFixed(2);
    return 'Max $value';
  }

  String get stockLimitLabel {
    final limit = _qtyLimitLabel;
    if (limit.isEmpty) return _stockLabel;
    return '$_stockLabel · $limit';
  }
}

class BillItemModel {
  const BillItemModel({
    required this.slNo,
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    required this.rate,
    this.unit = '',
    this.itemDetails = '',
  });

  final int slNo;
  final String itemCode;
  final String itemName;
  final double quantity;
  final double rate;
  final String unit;
  final String itemDetails;

  factory BillItemModel.fromDb(Map<String, dynamic> json) {
    return BillItemModel(
      slNo: int.tryParse(json['slno']?.toString() ?? '') ?? 0,
      itemCode: json['itemcode']?.toString().trim() ?? '',
      itemName: json['itemname']?.toString().trim() ?? '',
      quantity: CustomerModel._toDouble(json['quantity']),
      rate: CustomerModel._toDouble(json['rate']),
      unit: json['unitofmeasurement']?.toString().trim() ?? '',
      itemDetails: json['itemdetails']?.toString().trim() ?? '',
    );
  }

  OrderedProductModel toOrderedProduct() {
    final id = itemCode.isNotEmpty ? itemCode : 'sl-$slNo';
    final unitLabel = unit.isNotEmpty ? unit : 'units';
    final resolvedName = _resolveItemName();

    return OrderedProductModel(
      id: id,
      name: resolvedName,
      quantity: quantity,
      imageUrl: '',
      details: itemDetails,
      category: unitLabel,
      unitPrice: rate,
    );
  }

  String _resolveItemName() {
    if (itemName.isEmpty) return itemCode;

    final normalizedName = itemName.trim();
    final normalizedCode = itemCode.trim();
    if (normalizedCode.isNotEmpty &&
        normalizedName == normalizedCode &&
        itemDetails.isNotEmpty &&
        itemDetails.trim() != normalizedCode) {
      return itemDetails.trim();
    }

    return normalizedName;
  }
}

class OrderedProductModel {
  const OrderedProductModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.imageUrl,
    required this.details,
    this.category = '',
    this.unitPrice = 0,
    this.alternatives = const [],
  });

  final String id;
  final String name;
  final double quantity;
  final String imageUrl;
  final String details;
  final String category;
  final double unitPrice;
  final List<AlternativeProductModel> alternatives;
}

class ActivityModel {
  const ActivityModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String icon;
}

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
}
