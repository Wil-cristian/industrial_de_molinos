import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/material_category.dart';
import '../../domain/entities/material_subcategory.dart';
import '../datasources/material_category_datasource.dart';
import '../datasources/material_subcategory_datasource.dart';

/// Estado para categorías de materiales
class MaterialCategoryState {
  final List<MaterialCategory> categories;
  final List<MaterialSubcategory> subcategories;
  final bool isLoading;
  final String? error;

  MaterialCategoryState({
    this.categories = const [],
    this.subcategories = const [],
    this.isLoading = false,
    this.error,
  });

  MaterialCategoryState copyWith({
    List<MaterialCategory>? categories,
    List<MaterialSubcategory>? subcategories,
    bool? isLoading,
    String? error,
  }) {
    return MaterialCategoryState(
      categories: categories ?? this.categories,
      subcategories: subcategories ?? this.subcategories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Obtener subcategorías filtradas por categoría (usando category ID)
  List<MaterialSubcategory> subcategoriesForCategory(String categoryId) {
    return subcategories.where((s) => s.categoryId == categoryId).toList();
  }

  /// Obtener subcategorías filtradas por slug de categoría
  List<MaterialSubcategory> subcategoriesForSlug(String slug) {
    final cat = categories.where((c) => c.slug == slug);
    if (cat.isEmpty) return [];
    return subcategories.where((s) => s.categoryId == cat.first.id).toList();
  }
}

/// Notifier para gestionar categorías de materiales
class MaterialCategoryNotifier extends Notifier<MaterialCategoryState> {
  @override
  MaterialCategoryState build() {
    return MaterialCategoryState();
  }

  /// Cargar todas las categorías y subcategorías
  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cats = await MaterialCategoryDatasource.getAll();
      final subcats = await MaterialSubcategoryDatasource.getAll();
      state = state.copyWith(
        categories: cats,
        subcategories: subcats,
        isLoading: false,
      );
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
        // También eliminar subcategorías huérfanas del estado local
        final subcats = state.subcategories
            .where((s) => s.categoryId != id)
            .toList();
        state = state.copyWith(categories: cats, subcategories: subcats);
      }
      return ok;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // =============================================
  // Subcategorías
  // =============================================

  /// Crear subcategoría
  Future<MaterialSubcategory?> createSubcategory(
    MaterialSubcategory subcategory,
  ) async {
    try {
      final created = await MaterialSubcategoryDatasource.create(subcategory);
      state = state.copyWith(subcategories: [...state.subcategories, created]);
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Actualizar subcategoría
  Future<bool> updateSubcategory(MaterialSubcategory subcategory) async {
    try {
      final updated = await MaterialSubcategoryDatasource.update(subcategory);
      final subcats = state.subcategories
          .map((s) => s.id == subcategory.id ? updated : s)
          .toList();
      state = state.copyWith(subcategories: subcats);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Eliminar subcategoría
  Future<bool> deleteSubcategory(String id) async {
    try {
      final ok = await MaterialSubcategoryDatasource.delete(id);
      if (ok) {
        final subcats = state.subcategories.where((s) => s.id != id).toList();
        state = state.copyWith(subcategories: subcats);
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
final materialCategoryProvider =
    NotifierProvider<MaterialCategoryNotifier, MaterialCategoryState>(
      () => MaterialCategoryNotifier(),
    );
