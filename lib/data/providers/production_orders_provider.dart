import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/production_order.dart';
import '../datasources/production_orders_datasource.dart';

class ProductionOrdersState {
  final List<ProductionOrder> orders;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String selectedStatus;
  final String? selectedOrderId;

  const ProductionOrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedStatus = 'todos',
    this.selectedOrderId,
  });

  ProductionOrdersState copyWith({
    List<ProductionOrder>? orders,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? selectedStatus,
    String? selectedOrderId,
    bool clearSelectedOrder = false,
  }) {
    return ProductionOrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedOrderId: clearSelectedOrder
          ? null
          : selectedOrderId ?? this.selectedOrderId,
    );
  }

  List<ProductionOrder> get filteredOrders {
    return orders.where((order) {
      final byStatus =
          selectedStatus == 'todos' || order.status == selectedStatus;
      if (!byStatus) return false;

      if (searchQuery.trim().isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return order.code.toLowerCase().contains(q) ||
          order.productName.toLowerCase().contains(q) ||
          order.productCode.toLowerCase().contains(q);
    }).toList();
  }

  ProductionOrder? get selectedOrder {
    if (selectedOrderId == null) return null;
    for (final o in orders) {
      if (o.id == selectedOrderId) return o;
    }
    return null;
  }
}

class ProductionOrdersNotifier extends Notifier<ProductionOrdersState> {
  @override
  ProductionOrdersState build() {
    return const ProductionOrdersState();
  }

  Future<void> loadOrders() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orders = await ProductionOrdersDataSource.getAll();
      String? selected = state.selectedOrderId;
      if (selected != null && !orders.any((o) => o.id == selected)) {
        selected = orders.isNotEmpty ? orders.first.id : null;
      }
      state = state.copyWith(
        orders: orders,
        isLoading: false,
        selectedOrderId: selected,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createOrder(ProductionOrderCreationInput input) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final created = await ProductionOrdersDataSource.createFromProduct(input);
      await loadOrders();
      if (created != null) {
        state = state.copyWith(selectedOrderId: created.id);
      }
      return created != null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await ProductionOrdersDataSource.updateOrderStatus(orderId, status);
      await loadOrders();
      state = state.copyWith(selectedOrderId: orderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateStage(ProductionStage stage) async {
    try {
      await ProductionOrdersDataSource.updateStage(stage);
      await loadOrders();
      state = state.copyWith(selectedOrderId: stage.productionOrderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> createStage({
    required String orderId,
    required String processName,
    required String workstation,
    required double estimatedHours,
  }) async {
    try {
      await ProductionOrdersDataSource.createStage(
        orderId: orderId,
        processName: processName,
        workstation: workstation,
        estimatedHours: estimatedHours,
      );
      await loadOrders();
      state = state.copyWith(selectedOrderId: orderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteStage({
    required String orderId,
    required String stageId,
  }) async {
    try {
      await ProductionOrdersDataSource.deleteStage(stageId);
      await loadOrders();
      state = state.copyWith(selectedOrderId: orderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedStatus(String status) {
    state = state.copyWith(selectedStatus: status);
  }

  void selectOrder(String? orderId) {
    if (orderId == null) {
      state = state.copyWith(clearSelectedOrder: true);
      return;
    }
    state = state.copyWith(selectedOrderId: orderId);
  }
}

final productionOrdersProvider =
    NotifierProvider<ProductionOrdersNotifier, ProductionOrdersState>(
      ProductionOrdersNotifier.new,
    );
