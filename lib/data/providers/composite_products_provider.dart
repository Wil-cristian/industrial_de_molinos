import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/composite_product.dart';
import '../datasources/composite_products_datasource.dart';

/// Estado para productos compuestos
class CompositeProductsState {
  final List<CompositeProduct> products;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String selectedCategory;

  const CompositeProductsState({
    this.products = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedCategory = 'todos',
  });

  CompositeProductsState copyWith({
    List<CompositeProduct>? products,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? selectedCategory,
  }) {
    return CompositeProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  /// Productos filtrados por búsqueda y categoría
  List<CompositeProduct> get filteredProducts {
    return products.where((p) {
      final matchesSearch =
          searchQuery.isEmpty ||
          p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.code.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesCategory =
          selectedCategory == 'todos' || p.category == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }
}

/// Provider de productos compuestos
class CompositeProductsNotifier extends Notifier<CompositeProductsState> {
  @override
  CompositeProductsState build() {
    return const CompositeProductsState();
  }

  /// Cargar todos los productos compuestos
  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final products = await CompositeProductsDataSource.getAll();
      state = state.copyWith(products: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Crear un producto compuesto
  Future<bool> createProduct(CompositeProduct product) async {
    try {
      await CompositeProductsDataSource.create(product);
      await loadProducts(); // Recargar lista
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Actualizar un producto compuesto
  Future<bool> updateProduct(CompositeProduct product) async {
    try {
      await CompositeProductsDataSource.update(product);
      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Eliminar un producto compuesto
  Future<bool> deleteProduct(String id) async {
    try {
      await CompositeProductsDataSource.delete(id);
      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Duplicar un producto
  Future<bool> duplicateProduct(String id) async {
    try {
      await CompositeProductsDataSource.duplicate(id);
      await loadProducts();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Actualizar búsqueda
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Actualizar categoría seleccionada
  void setSelectedCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }
}

/// Provider global
final compositeProductsProvider =
    NotifierProvider<CompositeProductsNotifier, CompositeProductsState>(
      () => CompositeProductsNotifier(),
    );
