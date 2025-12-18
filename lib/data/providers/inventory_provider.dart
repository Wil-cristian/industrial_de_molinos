import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/material.dart';
import '../datasources/inventory_datasource.dart';

/// Estado para el inventario de materiales
class InventoryState {
  final List<Material> materials;
  final List<String> categories;
  final bool isLoading;
  final String? error;
  final String? selectedCategory;

  InventoryState({
    this.materials = const [],
    this.categories = const [],
    this.isLoading = false,
    this.error,
    this.selectedCategory,
  });

  InventoryState copyWith({
    List<Material>? materials,
    List<String>? categories,
    bool? isLoading,
    String? error,
    String? selectedCategory,
  }) {
    return InventoryState(
      materials: materials ?? this.materials,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  /// Materiales filtrados por categoría
  List<Material> get filteredMaterials {
    if (selectedCategory == null || selectedCategory == 'todos') {
      return materials;
    }
    return materials.where((m) => m.category == selectedCategory).toList();
  }

  /// Materiales con stock bajo
  List<Material> get lowStockMaterials {
    return materials.where((m) => m.isLowStock).toList();
  }

  /// Valor total del inventario
  double get totalInventoryValue {
    return materials.fold(0.0, (sum, m) => sum + (m.stock * m.effectivePrice));
  }
}

/// Notifier para gestionar inventario (Riverpod 3.0)
class InventoryNotifier extends Notifier<InventoryState> {
  @override
  InventoryState build() {
    return InventoryState();
  }

  /// Cargar todos los materiales
  Future<void> loadMaterials() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        InventoryDataSource.getAllMaterials(),
        InventoryDataSource.getCategories(),
      ]);
      state = state.copyWith(
        materials: results[0] as List<Material>,
        categories: results[1] as List<String>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Filtrar por categoría
  void filterByCategory(String? category) {
    state = state.copyWith(selectedCategory: category);
  }

  /// Crear material
  Future<Material?> createMaterial(Material material) async {
    try {
      final created = await InventoryDataSource.createMaterial(material);
      state = state.copyWith(
        materials: [...state.materials, created],
      );
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Actualizar material
  Future<bool> updateMaterial(Material material) async {
    try {
      final updated = await InventoryDataSource.updateMaterial(material);
      final materials = state.materials.map((m) =>
        m.id == material.id ? updated : m
      ).toList();
      state = state.copyWith(materials: materials);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Actualizar stock
  Future<bool> updateStock(String id, double newStock) async {
    try {
      await InventoryDataSource.updateStock(id, newStock);
      final materials = state.materials.map((m) =>
        m.id == id ? m.copyWith(stock: newStock, updatedAt: DateTime.now()) : m
      ).toList();
      state = state.copyWith(materials: materials);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Ajustar stock (incrementar/decrementar)
  Future<bool> adjustStock(String id, double adjustment) async {
    final material = state.materials.firstWhere((m) => m.id == id);
    return updateStock(id, material.stock + adjustment);
  }

  /// Eliminar material
  Future<bool> deleteMaterial(String id) async {
    try {
      await InventoryDataSource.deleteMaterial(id);
      final materials = state.materials.where((m) => m.id != id).toList();
      state = state.copyWith(materials: materials);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Limpiar error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider principal de inventario
final inventoryProvider = NotifierProvider<InventoryNotifier, InventoryState>(() {
  return InventoryNotifier();
});

// ==================== COMPONENTES DE RECETAS ====================

/// Estado para componentes de una receta
class ComponentsState {
  final List<ProductComponent> components;
  final bool isLoading;
  final String? error;
  final String? productId;

  ComponentsState({
    this.components = const [],
    this.isLoading = false,
    this.error,
    this.productId,
  });

  ComponentsState copyWith({
    List<ProductComponent>? components,
    bool? isLoading,
    String? error,
    String? productId,
  }) {
    return ComponentsState(
      components: components ?? this.components,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      productId: productId ?? this.productId,
    );
  }

  /// Peso total de la receta
  double get totalWeight {
    return components.fold(0.0, (sum, c) => sum + c.calculatedWeight);
  }

  /// Costo total de la receta
  double get totalCost {
    return components.fold(0.0, (sum, c) => sum + c.totalCost);
  }
}

/// Notifier para componentes de receta
class ComponentsNotifier extends Notifier<ComponentsState> {
  @override
  ComponentsState build() {
    return ComponentsState();
  }

  /// Cargar componentes de un producto
  Future<void> loadComponents(String productId) async {
    state = state.copyWith(isLoading: true, error: null, productId: productId);
    try {
      final components = await InventoryDataSource.getProductComponents(productId);
      state = state.copyWith(
        components: components,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Agregar componente
  Future<ProductComponent?> addComponent(ProductComponent component) async {
    try {
      final created = await InventoryDataSource.createComponent(component);
      state = state.copyWith(
        components: [...state.components, created],
      );
      // Actualizar totales del producto
      if (state.productId != null) {
        await InventoryDataSource.updateProductTotals(state.productId!);
      }
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Actualizar componente
  Future<bool> updateComponent(ProductComponent component) async {
    try {
      final updated = await InventoryDataSource.updateComponent(component);
      final components = state.components.map((c) =>
        c.id == component.id ? updated : c
      ).toList();
      state = state.copyWith(components: components);
      // Actualizar totales del producto
      if (state.productId != null) {
        await InventoryDataSource.updateProductTotals(state.productId!);
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Eliminar componente
  Future<bool> deleteComponent(String id) async {
    try {
      await InventoryDataSource.deleteComponent(id);
      final components = state.components.where((c) => c.id != id).toList();
      state = state.copyWith(components: components);
      // Actualizar totales del producto
      if (state.productId != null) {
        await InventoryDataSource.updateProductTotals(state.productId!);
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Limpiar componentes
  void clear() {
    state = ComponentsState();
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider para componentes de receta
final componentsProvider = NotifierProvider<ComponentsNotifier, ComponentsState>(() {
  return ComponentsNotifier();
});
