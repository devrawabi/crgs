class OrderLineItem {
  const OrderLineItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.category = '',
    this.unitPrice = 0,
    this.uom = 'PCS',
    this.amount = 0,
  });

  final String productId;
  final String productName;
  final double quantity;
  final String category;
  final double unitPrice;
  final String uom;
  final double amount;

  double get lineTotal => amount > 0 ? amount : unitPrice * quantity;

  factory OrderLineItem.fromDb(Map<String, dynamic> json) {
    final qty = _toDouble(json['qty'] ?? json['quantity']);
    final price = _toDouble(json['price'] ?? json['unitPrice']);
    final amount = _toDouble(json['amount']);
    final itemCode = json['itemCode']?.toString().trim() ?? '';
    final itemName = json['itemName']?.toString().trim() ?? '';
    final uom = json['uom']?.toString().trim() ?? 'PCS';

    return OrderLineItem(
      productId: itemCode,
      productName: itemName.isNotEmpty ? itemName : itemCode,
      quantity: qty,
      category: uom,
      unitPrice: price,
      uom: uom.isNotEmpty ? uom : 'PCS',
      amount: amount > 0 ? amount : price * qty,
    );
  }

  Map<String, dynamic> toApiJson({required String route}) {
    final resolvedUom = uom.trim().isNotEmpty
        ? uom.trim()
        : (category.trim().length <= 10 && category.trim().isNotEmpty
            ? category.trim()
            : 'PCS');
    return {
      'itemCode': productId,
      'qty': quantity,
      'uom': resolvedUom.length > 10 ? resolvedUom.substring(0, 10) : resolvedUom,
      'price': unitPrice,
      'amount': double.parse(lineTotal.toStringAsFixed(2)),
      'route': route,
    };
  }
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.createdAt,
    this.expectedDate,
    this.remarks = '',
    this.orderNo = '',
    this.totalAmount = 0,
    this.employeeCode = '',
    this.route = '',
    this.headerItemCount = 0,
  });

  final String id;
  final String customerId;
  final String customerName;
  final List<OrderLineItem> items;
  final DateTime createdAt;
  final DateTime? expectedDate;
  final String remarks;
  final String orderNo;
  final double totalAmount;
  final String employeeCode;
  final String route;
  final int headerItemCount;

  int get itemCount =>
      headerItemCount > 0 ? headerItemCount : items.length;

  double get totalQuantity =>
      items.fold<double>(0, (sum, item) => sum + item.quantity);

  double get computedTotalAmount =>
      items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  factory CustomerOrder.fromDb(Map<String, dynamic> json) {
    final orderNo = json['orderNo']?.toString().trim() ?? '';
    final orderDate = _parseDate(json['orderDate']) ?? DateTime.now();
    final expectedDate = _parseDate(json['expectedDate']);
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => OrderLineItem.fromDb(Map<String, dynamic>.from(item)))
            .toList()
        : <OrderLineItem>[];

    return CustomerOrder(
      id: orderNo.isNotEmpty
          ? orderNo
          : 'order-${orderDate.millisecondsSinceEpoch}',
      customerId: json['customerCode']?.toString().trim() ?? '',
      customerName: json['customerName']?.toString().trim() ?? '',
      items: List.unmodifiable(items),
      createdAt: orderDate,
      expectedDate: expectedDate,
      orderNo: orderNo,
      totalAmount: _toDouble(json['totalAmount']),
      employeeCode: json['employeeCode']?.toString().trim() ?? '',
      route: json['route']?.toString().trim() ?? '',
      headerItemCount: _toInt(json['itemCount']),
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseDate(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
