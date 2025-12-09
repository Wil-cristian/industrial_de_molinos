import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/material_price.dart';
import '../datasources/materials_datasource.dart';

/// Estado para materiales
class MaterialsState {
  final List<MaterialPrice> materials;
  final List<String> categories;
  final OperationalCosts operationalCosts;
  final bool isLoading;
  final String? error;
  final String? selectedCategory;

  MaterialsState({
    this.materials = const [],
    this.categories = const [],
    this.operationalCosts = const OperationalCosts(),
    this.isLoading = false,
    this.error,
    this.selectedCategory,
  });

  MaterialsState copyWith({
    List<MaterialPrice>? materials,
    List<String>? categories,
    OperationalCosts? operationalCosts,
    bool? isLoading,
    String? error,
    String? selectedCategory,
  }) {
    return MaterialsState(
      materials: materials ?? this.materials,
      categories: categories ?? this.categories,
      operationalCosts: operationalCosts ?? this.operationalCosts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  List<MaterialPrice> get filteredMaterials {
    if (selectedCategory == null) return materials;
    return materials.where((m) => m.category == selectedCategory).toList();
  }
}

/// Notifier para gestionar materiales (Riverpod 3.0)
class MaterialsNotifier extends Notifier<MaterialsState> {
  @override
  MaterialsState build() {
    return MaterialsState();
  }

  Future<void> loadMaterials() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        MaterialsDataSource.getAll(),
        MaterialsDataSource.getCategories(),
        MaterialsDataSource.getOperationalCosts(),
      ]);
      state = state.copyWith(
        materials: results[0] as List<MaterialPrice>,
        categories: results[1] as List<String>,
        operationalCosts: results[2] as OperationalCosts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void filterByCategory(String? category) {
    state = state.copyWith(selectedCategory: category);
  }

  Future<MaterialPrice?> createMaterial(MaterialPrice material) async {
    try {
      final created = await MaterialsDataSource.create(material);
      state = state.copyWith(
        materials: [...state.materials, created],
      );
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> updateMaterial(MaterialPrice material) async {
    try {
      final updated = await MaterialsDataSource.update(material);
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

  Future<bool> updatePrice(String id, double newPrice) async {
    try {
      await MaterialsDataSource.updatePrice(id, newPrice);
      final materials = state.materials.map((m) =>
        m.id == id ? m.copyWith(pricePerKg: newPrice, updatedAt: DateTime.now()) : m
      ).toList();
      state = state.copyWith(materials: materials);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteMaterial(String id) async {
    try {
      await MaterialsDataSource.delete(id);
      final materials = state.materials.where((m) => m.id != id).toList();
      state = state.copyWith(materials: materials);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateOperationalCosts(OperationalCosts costs) async {
    try {
      await MaterialsDataSource.updateOperationalCosts(costs);
      state = state.copyWith(operationalCosts: costs);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider principal de materiales
final materialsProvider = NotifierProvider<MaterialsNotifier, MaterialsState>(() {
  return MaterialsNotifier();
});

/// Provider para material individual
final materialByIdProvider = FutureProvider.family<MaterialPrice?, String>((ref, id) async {
  return await MaterialsDataSource.getById(id);
});

/// Provider para costos operativos
final operationalCostsProvider = FutureProvider<OperationalCosts>((ref) async {
  return await MaterialsDataSource.getOperationalCosts();
});

/// Provider para categorías de materiales
final materialCategoriesProvider = FutureProvider<List<String>>((ref) async {
  return await MaterialsDataSource.getCategories();
});
