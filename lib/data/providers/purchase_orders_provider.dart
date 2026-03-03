import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/supplier_material.dart';
import '../datasources/purchase_orders_datasource.dart';
import '../datasources/supplier_materials_datasource.dart';

// ====================================
// STATE: Precios proveedor-material
// ====================================
class SupplierMaterialsState {
  final List<SupplierMaterial> items;
  final bool isLoading;
  final String? error;

  SupplierMaterialsState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  SupplierMaterialsState copyWith({
    List<SupplierMaterial>? items,
    bool? isLoading,
    String? error,
  }) {
    return SupplierMaterialsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ====================================
// NOTIFIER: Precios proveedor-material
// ====================================
class SupplierMaterialsNotifier extends Notifier<SupplierMaterialsState> {
  @override
  SupplierMaterialsState build() {
    return SupplierMaterialsState();
  }

  Future<void> loadBySupplier(String supplierId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await SupplierMaterialsDataSource.getBySupplier(supplierId);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadByMaterial(String materialId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await SupplierMaterialsDataSource.getByMaterial(materialId);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<SupplierMaterial?> upsertPrice({
    required String supplierId,
    required String materialId,
    required double unitPrice,
    double? minOrderQuantity,
    int? leadTimeDays,
    String? notes,
    bool? isPreferred,
  }) async {
    try {
      final result = await SupplierMaterialsDataSource.upsert(
        supplierId: supplierId,
        materialId: materialId,
        unitPrice: unitPrice,
        minOrderQuantity: minOrderQuantity,
        leadTimeDays: leadTimeDays,
        notes: notes,
        isPreferred: isPreferred,
      );
      // Recargar lista
      final updated = [...state.items];
      final idx = updated.indexWhere(
        (i) => i.supplierId == supplierId && i.materialId == materialId,
      );
      if (idx >= 0) {
        updated[idx] = result;
      } else {
        updated.add(result);
      }
      state = state.copyWith(items: updated);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> deletePrice(String id) async {
    try {
      await SupplierMaterialsDataSource.delete(id);
      state = state.copyWith(
        items: state.items.where((i) => i.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Obtener precio de un material con un proveedor
  Future<double?> getPrice(String supplierId, String materialId) async {
    try {
      final sm = await SupplierMaterialsDataSource.getPrice(
        supplierId,
        materialId,
      );
      return sm?.effectivePrice;
    } catch (_) {
      return null;
    }
  }
}

// ====================================
// STATE: Órdenes de Compra
// ====================================
class PurchaseOrdersState {
  final List<PurchaseOrder> orders;
  final PurchaseOrder? selectedOrder;
  final bool isLoading;
  final String? error;
  final String? statusFilter;

  PurchaseOrdersState({
    this.orders = const [],
    this.selectedOrder,
    this.isLoading = false,
    this.error,
    this.statusFilter,
  });

  PurchaseOrdersState copyWith({
    List<PurchaseOrder>? orders,
    PurchaseOrder? selectedOrder,
    bool? isLoading,
    String? error,
    String? statusFilter,
    bool clearSelected = false,
  }) {
    return PurchaseOrdersState(
      orders: orders ?? this.orders,
      selectedOrder: clearSelected
          ? null
          : (selectedOrder ?? this.selectedOrder),
      isLoading: isLoading ?? this.isLoading,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }

  List<PurchaseOrder> get filteredOrders {
    if (statusFilter == null || statusFilter!.isEmpty) return orders;
    return orders.where((o) => o.status.name == statusFilter).toList();
  }
}

// ====================================
// NOTIFIER: Órdenes de Compra
// ====================================
class PurchaseOrdersNotifier extends Notifier<PurchaseOrdersState> {
  @override
  PurchaseOrdersState build() {
    return PurchaseOrdersState();
  }

  Future<void> loadOrders({String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🔄 Cargando órdenes de compra...');
      final orders = await PurchaseOrdersDataSource.getAll(status: status);
      print('✅ Órdenes cargadas: ${orders.length}');
      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      print('❌ Error cargando órdenes: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadBySupplier(String supplierId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orders = await PurchaseOrdersDataSource.getBySupplier(supplierId);
      state = state.copyWith(orders: orders, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setStatusFilter(String? status) {
    state = state.copyWith(statusFilter: status);
  }

  Future<PurchaseOrder?> createOrder(PurchaseOrder order) async {
    try {
      final created = await PurchaseOrdersDataSource.create(order);
      state = state.copyWith(orders: [created, ...state.orders]);
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<PurchaseOrder?> updateOrder(PurchaseOrder order) async {
    try {
      final updated = await PurchaseOrdersDataSource.update(order);
      final orders = state.orders
          .map((o) => o.id == order.id ? updated : o)
          .toList();
      state = state.copyWith(orders: orders, selectedOrder: updated);
      return updated;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> updateStatus(String orderId, PurchaseOrderStatus status) async {
    try {
      final updated = await PurchaseOrdersDataSource.updateStatus(
        orderId,
        status,
      );
      final orders = state.orders
          .map((o) => o.id == orderId ? updated : o)
          .toList();
      state = state.copyWith(orders: orders, selectedOrder: updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> registerPayment(
    String orderId,
    double amount,
    String method, {
    String? accountId,
    String? supplierName,
  }) async {
    try {
      final updated = await PurchaseOrdersDataSource.registerPayment(
        orderId,
        amount,
        method,
      );
      final orders = state.orders
          .map((o) => o.id == orderId ? updated : o)
          .toList();
      state = state.copyWith(orders: orders, selectedOrder: updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteOrder(String id) async {
    try {
      await PurchaseOrdersDataSource.delete(id);
      state = state.copyWith(
        orders: state.orders.where((o) => o.id != id).toList(),
        clearSelected: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void selectOrder(PurchaseOrder? order) {
    state = state.copyWith(selectedOrder: order, clearSelected: order == null);
  }

  // ---- Items ----

  Future<PurchaseOrderItem?> addItem(PurchaseOrderItem item) async {
    try {
      final created = await PurchaseOrdersDataSource.addItem(item);
      // Recargar la orden para tener totales actualizados
      await _refreshOrder(item.orderId);
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> updateItem(PurchaseOrderItem item) async {
    try {
      await PurchaseOrdersDataSource.updateItem(item);
      await _refreshOrder(item.orderId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteItem(String itemId, String orderId) async {
    try {
      await PurchaseOrdersDataSource.deleteItem(itemId);
      await _refreshOrder(orderId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> _refreshOrder(String orderId) async {
    final refreshed = await PurchaseOrdersDataSource.getById(orderId);
    if (refreshed != null) {
      final orders = state.orders
          .map((o) => o.id == orderId ? refreshed : o)
          .toList();
      state = state.copyWith(orders: orders, selectedOrder: refreshed);
    }
  }

  /// Generar número de orden
  Future<String> generateOrderNumber() async {
    return await PurchaseOrdersDataSource.generateOrderNumber();
  }
}

// ====================================
// PROVIDERS
// ====================================
final supplierMaterialsProvider =
    NotifierProvider<SupplierMaterialsNotifier, SupplierMaterialsState>(
      SupplierMaterialsNotifier.new,
    );

final purchaseOrdersProvider =
    NotifierProvider<PurchaseOrdersNotifier, PurchaseOrdersState>(
      PurchaseOrdersNotifier.new,
    );
