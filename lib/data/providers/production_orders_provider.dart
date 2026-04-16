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
    final filtered = orders.where((order) {
      final byStatus =
          selectedStatus == 'todos' || order.status == selectedStatus;
      if (!byStatus) return false;

      if (searchQuery.trim().isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return order.code.toLowerCase().contains(q) ||
          order.productName.toLowerCase().contains(q) ||
          order.productCode.toLowerCase().contains(q);
    }).toList();
    // Sort by manual sort_order (drag-reorder)
    filtered.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return filtered;
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
      rethrow;
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await ProductionOrdersDataSource.deleteOrder(orderId);
      await loadOrders();
      // Clear selection if deleted order was selected
      if (state.selectedOrderId == orderId) {
        final first = state.orders.isNotEmpty ? state.orders.first.id : null;
        state = state.copyWith(
          selectedOrderId: first,
          clearSelectedOrder: first == null,
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updatePriority(String orderId, String priority) async {
    try {
      await ProductionOrdersDataSource.updatePriority(orderId, priority);
      await loadOrders();
      state = state.copyWith(selectedOrderId: orderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateDueDate(String orderId, DateTime dueDate) async {
    try {
      await ProductionOrdersDataSource.updateDueDate(orderId, dueDate);
      await loadOrders();
      state = state.copyWith(selectedOrderId: orderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateStage(ProductionStage stage) async {
    try {
      await ProductionOrdersDataSource.updateStage(stage);
      await loadOrders();
      state = state.copyWith(selectedOrderId: stage.productionOrderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> createStage({
    required String orderId,
    required String processName,
    required String workstation,
    required double estimatedHours,
    double actualHours = 0,
    String status = 'pendiente',
    String? assignedEmployeeId,
    List<String> resources = const [],
    List<String> materialIds = const [],
    List<String> assetIds = const [],
    String? report,
    String? notes,
  }) async {
    try {
      await ProductionOrdersDataSource.createStage(
        orderId: orderId,
        processName: processName,
        workstation: workstation,
        estimatedHours: estimatedHours,
        actualHours: actualHours,
        status: status,
        assignedEmployeeId: assignedEmployeeId,
        resources: resources,
        materialIds: materialIds,
        assetIds: assetIds,
        report: report,
        notes: notes,
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

  /// Reorder orders by drag-and-drop
  Future<void> reorderOrders(int oldIndex, int newIndex) async {
    final orders = List<ProductionOrder>.from(state.filteredOrders);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = orders.removeAt(oldIndex);
    orders.insert(newIndex, item);

    // Update sort_order locally first for instant UI feedback
    final updatedAll = List<ProductionOrder>.from(state.orders);
    for (int i = 0; i < orders.length; i++) {
      final idx = updatedAll.indexWhere((o) => o.id == orders[i].id);
      if (idx >= 0) {
        updatedAll[idx] = updatedAll[idx].copyWith(sortOrder: i + 1);
      }
    }
    state = state.copyWith(orders: updatedAll);

    // Persist to DB
    try {
      await ProductionOrdersDataSource.updateSortOrders(
        orders.map((o) => o.id).toList(),
      );
    } catch (e) {
      // Reload on error to restore correct order
      await loadOrders();
    }
  }

  // ── BOM Materials ─────────────────────────────────────────────────

  Future<void> addMaterialToOrder({
    required String orderId,
    required String materialId,
    required String materialName,
    String? materialCode,
    required double requiredQuantity,
    String unit = 'UND',
    double estimatedCost = 0,
    String? pieceTitle,
    String? dimensions,
  }) async {
    try {
      await ProductionOrdersDataSource.addMaterialToOrder(
        orderId: orderId,
        materialId: materialId,
        materialName: materialName,
        materialCode: materialCode,
        requiredQuantity: requiredQuantity,
        unit: unit,
        estimatedCost: estimatedCost,
        pieceTitle: pieceTitle,
        dimensions: dimensions,
      );
      await loadOrders();
      state = state.copyWith(selectedOrderId: orderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeMaterialFromOrder({
    required String orderId,
    required String materialRowId,
  }) async {
    try {
      await ProductionOrdersDataSource.removeMaterialFromOrder(materialRowId);
      await loadOrders();
      state = state.copyWith(selectedOrderId: orderId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Vincular factura a OP
  Future<bool> linkInvoice(String orderId, String invoiceId) async {
    try {
      await ProductionOrdersDataSource.linkInvoice(orderId, invoiceId);
      await loadOrders();
      state = state.copyWith(selectedOrderId: orderId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Desvincular factura de OP
  Future<bool> unlinkInvoice(String orderId) async {
    try {
      await ProductionOrdersDataSource.unlinkInvoice(orderId);
      await loadOrders();
      state = state.copyWith(selectedOrderId: orderId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final productionOrdersProvider =
    NotifierProvider<ProductionOrdersNotifier, ProductionOrdersState>(
      ProductionOrdersNotifier.new,
    );
