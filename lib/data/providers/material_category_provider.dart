import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/material_category.dart';
import '../datasources/material_category_datasource.dart';

/// Estado para categorías de materiales
class MaterialCategoryState {
  final List<MaterialCategory> categories;
  final bool isLoading;
  final String? error;

  MaterialCategoryState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  MaterialCategoryState copyWith({
    List<MaterialCategory>? categories,
    bool? isLoading,
    String? error,
  }) {
    return MaterialCategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier para gestionar categorías de materiales
class MaterialCategoryNotifier extends Notifier<MaterialCategoryState> {
  @override
  MaterialCategoryState build() {
    return MaterialCategoryState();
  }

  /// Cargar todas las categorías
  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cats = await MaterialCategoryDatasource.getAll();
      state = state.copyWith(categories: cats, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Crear categoría
  Future<MaterialCategory?> createCategory(MaterialCategory category) async {
    try {
      final created = await MaterialCategoryDatasource.create(category);
      state = state.copyWith(categories: [...state.categories, created]);
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Actualizar categoría
  Future<bool> updateCategory(MaterialCategory category) async {
    try {
      final updated = await MaterialCategoryDatasource.update(category);
      final cats = state.categories
          .map((c) => c.id == category.id ? updated : c)
          .toList();
      state = state.copyWith(categories: cats);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Eliminar categoría
  Future<bool> deleteCategory(String id) async {
    try {
      final ok = await MaterialCategoryDatasource.delete(id);
      if (ok) {
        final cats = state.categories.where((c) => c.id != id).toList();
        state = state.copyWith(categories: cats);
      }
      return ok;
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

/// Provider principal de categorías
final materialCategoryProvider = NotifierProvider<MaterialCategoryNotifier, MaterialCategoryState>(
  () => MaterialCategoryNotifier(),
);
