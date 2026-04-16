import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/asset.dart';
import '../datasources/assets_datasource.dart';

/// Estado de activos
class AssetsState {
  final List<Asset> assets;
  final List<AssetMaintenance> maintenanceHistory;
  final Map<String, dynamic> stats;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String categoryFilter;
  final String statusFilter;

  AssetsState({
    this.assets = const [],
    this.maintenanceHistory = const [],
    this.stats = const {},
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.categoryFilter = 'todas',
    this.statusFilter = 'todos',
  });

  AssetsState copyWith({
    List<Asset>? assets,
    List<AssetMaintenance>? maintenanceHistory,
    Map<String, dynamic>? stats,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? categoryFilter,
    String? statusFilter,
  }) {
    return AssetsState(
      assets: assets ?? this.assets,
      maintenanceHistory: maintenanceHistory ?? this.maintenanceHistory,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }

  /// Activos filtrados
  List<Asset> get filteredAssets {
    var result = assets;

    // Filtrar por categoría
    if (categoryFilter != 'todas') {
      result = result.where((a) => a.category == categoryFilter).toList();
    }

    // Filtrar por estado
    if (statusFilter != 'todos') {
      result = result.where((a) => a.status == statusFilter).toList();
    }

    // Filtrar por búsqueda
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result.where((a) =>
        a.name.toLowerCase().contains(query) ||
        (a.description?.toLowerCase().contains(query) ?? false) ||
        (a.brand?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    return result;
  }

  int get totalAssets => stats['totalAssets'] ?? assets.length;
  double get totalValue => stats['totalValue'] ?? 0.0;
  double get totalInvestment => stats['totalInvestment'] ?? 0.0;
  int get inMaintenance => stats['inMaintenance'] ?? 0;
}

/// Notifier para manejar activos
class AssetsNotifier extends Notifier<AssetsState> {
  @override
  AssetsState build() {
    return AssetsState();
  }

  /// Cargar activos
  Future<void> loadAssets() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assets = await AssetsDatasource.getAssets();
      final stats = await AssetsDatasource.getAssetStats();
      state = state.copyWith(
        assets: assets,
        stats: stats,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Buscar activos
  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Filtrar por categoría
  void filterByCategory(String category) {
    state = state.copyWith(categoryFilter: category);
  }

  /// Filtrar por estado
  void filterByStatus(String status) {
    state = state.copyWith(statusFilter: status);
  }

  /// Crear activo
  Future<Asset?> createAsset(Asset asset) async {
    try {
      final created = await AssetsDatasource.createAsset(asset);
      if (created != null) {
        await loadAssets(); // Recargar para actualizar stats
      }
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Actualizar activo
  Future<bool> updateAsset(Asset asset) async {
    try {
      final success = await AssetsDatasource.updateAsset(asset);
      if (success) {
        await loadAssets();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Eliminar activo
  Future<bool> deleteAsset(String id) async {
    try {
      final success = await AssetsDatasource.deleteAsset(id);
      if (success) {
        await loadAssets();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Cambiar estado
  Future<bool> updateStatus(String id, String status) async {
    try {
      final success = await AssetsDatasource.updateAssetStatus(id, status);
      if (success) {
        await loadAssets();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Cargar historial de mantenimiento
  Future<void> loadMaintenanceHistory(String assetId) async {
    try {
      final history = await AssetsDatasource.getMaintenanceHistory(assetId);
      state = state.copyWith(maintenanceHistory: history);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Registrar mantenimiento
  Future<AssetMaintenance?> createMaintenance(AssetMaintenance maintenance) async {
    try {
      final created = await AssetsDatasource.createMaintenance(maintenance);
      if (created != null) {
        await loadAssets();
        await loadMaintenanceHistory(maintenance.assetId);
      }
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

/// Provider de activos
final assetsProvider = NotifierProvider<AssetsNotifier, AssetsState>(() {
  return AssetsNotifier();
});
