import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/shipment_order.dart';
import '../datasources/shipments_datasource.dart';

class ShipmentsState {
  final List<ShipmentOrder> shipments;
  final List<FutureDelivery> futureDeliveries;
  final Map<String, int> summaryCounts;
  final int futureInProduction;
  final int futureReady;
  final bool isLoading;
  final String? error;
  final int selectedTab;
  final String filterStatus;
  final String searchQuery;

  const ShipmentsState({
    this.shipments = const [],
    this.futureDeliveries = const [],
    this.summaryCounts = const {},
    this.futureInProduction = 0,
    this.futureReady = 0,
    this.isLoading = false,
    this.error,
    this.selectedTab = 0,
    this.filterStatus = 'todos',
    this.searchQuery = '',
  });

  ShipmentsState copyWith({
    List<ShipmentOrder>? shipments,
    List<FutureDelivery>? futureDeliveries,
    Map<String, int>? summaryCounts,
    int? futureInProduction,
    int? futureReady,
    bool? isLoading,
    String? error,
    int? selectedTab,
    String? filterStatus,
    String? searchQuery,
  }) {
    return ShipmentsState(
      shipments: shipments ?? this.shipments,
      futureDeliveries: futureDeliveries ?? this.futureDeliveries,
      summaryCounts: summaryCounts ?? this.summaryCounts,
      futureInProduction: futureInProduction ?? this.futureInProduction,
      futureReady: futureReady ?? this.futureReady,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedTab: selectedTab ?? this.selectedTab,
      filterStatus: filterStatus ?? this.filterStatus,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<ShipmentOrder> get filteredShipments {
    return shipments.where((s) {
      final byStatus =
          filterStatus == 'todos' ||
          ShipmentOrder.statusToString(s.status) == filterStatus;
      if (!byStatus) return false;

      if (searchQuery.trim().isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return s.code.toLowerCase().contains(q) ||
          s.customerName.toLowerCase().contains(q) ||
          (s.invoiceFullNumber?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<ShipmentOrder> get historyShipments {
    return shipments
        .where(
          (s) =>
              s.status == ShipmentStatus.entregada ||
              s.status == ShipmentStatus.anulada,
        )
        .toList();
  }
}

class ShipmentsNotifier extends Notifier<ShipmentsState> {
  @override
  ShipmentsState build() {
    return const ShipmentsState();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        ShipmentsDataSource.getAll(),
        ShipmentsDataSource.getFutureDeliveries(),
        ShipmentsDataSource.getSummaryCounts(),
      ]);

      final shipments = results[0] as List<ShipmentOrder>;
      final futures = results[1] as List<FutureDelivery>;
      final counts = results[2] as Map<String, int>;

      final inProd = futures.where((f) => !f.isCompleted).length;
      final ready = futures.where((f) => f.isCompleted).length;

      state = state.copyWith(
        shipments: shipments,
        futureDeliveries: futures,
        summaryCounts: counts,
        futureInProduction: inProd,
        futureReady: ready,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createShipment(ShipmentOrder order) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final created = await ShipmentsDataSource.create(order);
      await loadAll();
      return created != null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateShipment(ShipmentOrder order) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await ShipmentsDataSource.update(order);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> dispatchShipment(String id) async {
    try {
      await ShipmentsDataSource.updateStatus(id, 'despachada');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> confirmDelivery(String id, {String? receivedBy}) async {
    try {
      await ShipmentsDataSource.updateStatus(
        id,
        'entregada',
        receivedBy: receivedBy,
      );
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> cancelShipment(String id) async {
    try {
      await ShipmentsDataSource.updateStatus(id, 'anulada');
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void setTab(int tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void setFilter(String status) {
    state = state.copyWith(filterStatus: status);
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final shipmentsProvider = NotifierProvider<ShipmentsNotifier, ShipmentsState>(
  ShipmentsNotifier.new,
);
