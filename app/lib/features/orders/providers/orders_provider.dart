import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../data/repositories/orders_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/order_models.dart';

export '../models/order_models.dart';

class OrdersState {
  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
  });

  final List<CustomerOrder> orders;
  final bool isLoading;
  final String? error;

  OrdersState copyWith({
    List<CustomerOrder>? orders,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      OrdersState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier(this._repository, this._employeeCode)
      : super(const OrdersState(isLoading: true)) {
    load();
  }

  final OrdersRepository _repository;
  final String _employeeCode;
  bool _isSaving = false;

  bool get isSaving => _isSaving;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final orders = await _repository.fetchOrders(
        employeeCode: _employeeCode.isEmpty ? null : _employeeCode,
      );
      state = OrdersState(orders: orders);
    } catch (error) {
      state = OrdersState(
        orders: state.orders,
        error: error.toString(),
      );
    }
  }

  Future<CustomerOrder> saveOrder({
    required String employeeCode,
    required String customerId,
    required String customerName,
    required String route,
    required List<OrderLineItem> items,
    DateTime? expectedDate,
    String remarks = '',
  }) async {
    if (customerId.trim().isEmpty || items.isEmpty) {
      throw ArgumentError('Customer and items are required');
    }
    if (employeeCode.trim().isEmpty) {
      throw ArgumentError('Employee code is required');
    }
    if (route.trim().isEmpty) {
      throw ArgumentError('Route is required');
    }
    if (_isSaving) {
      throw StateError('An order is already being saved');
    }

    _isSaving = true;
    try {
      final totalAmount =
          items.fold<double>(0, (sum, item) => sum + item.lineTotal);
      final orderDate = DateTime.now();

      final response = await _repository.createExpectedOrder(
        employeeCode: employeeCode.trim(),
        customerCode: customerId.trim(),
        customerName: customerName.trim().isEmpty
            ? customerId.trim()
            : customerName.trim(),
        route: route.trim(),
        totalAmount: totalAmount,
        itemCount: items.length,
        orderDate: orderDate,
        expectedDate: expectedDate,
        items: [
          for (final item in items) item.toApiJson(route: route.trim()),
        ],
      );

      final orderNo = response['orderNo']?.toString() ?? '';
      final order = CustomerOrder(
        id: orderNo.isNotEmpty
            ? orderNo
            : 'order-${orderDate.millisecondsSinceEpoch}',
        customerId: customerId.trim(),
        customerName: customerName.trim().isEmpty
            ? customerId.trim()
            : customerName.trim(),
        items: List.unmodifiable(items),
        createdAt: orderDate,
        expectedDate: expectedDate,
        remarks: remarks.trim(),
        orderNo: orderNo,
        totalAmount: totalAmount,
        employeeCode: employeeCode.trim(),
        route: route.trim(),
        headerItemCount: items.length,
      );

      state = OrdersState(orders: [order, ...state.orders]);
      return order;
    } finally {
      _isSaving = false;
    }
  }

  void removeOrder(String orderId) {
    state = state.copyWith(
      orders: state.orders.where((order) => order.id != orderId).toList(),
    );
  }

  void clear() {
    state = const OrdersState();
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(apiClientProvider));
});

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  final user = ref.watch(currentUserProvider);
  return OrdersNotifier(
    ref.watch(ordersRepositoryProvider),
    user?.employeeCode.trim() ?? '',
  );
});
