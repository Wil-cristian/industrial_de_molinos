import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../datasources/products_datasource.dart';

/// Estado para la lista de productos
class ProductsState {
  final List<Product> products;
  final List<Category> categories;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String? selectedCategoryId;

  ProductsState({
    this.products = const [],
    this.categories = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedCategoryId,
  });

  ProductsState copyWith({
    List<Product>? products,
    List<Category>? categories,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? selectedCategoryId,
  }) {
    return ProductsState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
    );
  }

  List<Product> get filteredProducts {
    var filtered = products;
    
    if (selectedCategoryId != null) {
      filtered = filtered.where((p) => p.categoryId == selectedCategoryId).toList();
    }
    
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains(query) ||
        p.code.toLowerCase().contains(query) ||
        (p.description?.toLowerCase().contains(query) ?? false)
      ).toList();
    }
    
    return filtered;
  }

  List<Product> get lowStockProducts => products.where((p) => p.isLowStock).toList();
}

/// Notifier para gestionar productos (Riverpod 3.0)
class ProductsNotifier extends Notifier<ProductsState> {
  @override
  ProductsState build() {
    return ProductsState();
  }

  Future<void> loadProducts({bool activeOnly = true}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        ProductsDataSource.getAll(activeOnly: activeOnly),
        ProductsDataSource.getCategories(),
      ]);
      state = state.copyWith(
        products: results[0] as List<Product>,
        categories: results[1] as List<Category>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void filterByCategory(String? categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  Future<Product?> createProduct(Product product) async {
    try {
      final created = await ProductsDataSource.create(product);
      state = state.copyWith(
        products: [...state.products, created],
      );
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      final updated = await ProductsDataSource.update(product);
      final products = state.products.map((p) =>
        p.id == product.id ? updated : p
      ).toList();
      state = state.copyWith(products: products);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await ProductsDataSource.delete(id);
      final products = state.products.where((p) => p.id != id).toList();
      state = state.copyWith(products: products);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateStock(String id, double newStock) async {
    try {
      await ProductsDataSource.updateStock(id, newStock);
      final products = state.products.map((p) =>
        p.id == id ? p.copyWith(stock: newStock) : p
      ).toList();
      state = state.copyWith(products: products);
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

/// Provider principal de productos
final productsProvider = NotifierProvider<ProductsNotifier, ProductsState>(() {
  return ProductsNotifier();
});

/// Provider para producto individual
final productByIdProvider = FutureProvider.family<Product?, String>((ref, id) async {
  return await ProductsDataSource.getById(id);
});

/// Provider para productos con stock bajo
final lowStockProductsProvider = FutureProvider<List<Product>>((ref) async {
  return await ProductsDataSource.getLowStock();
});

/// Provider para categorías
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  return await ProductsDataSource.getCategories();
});
