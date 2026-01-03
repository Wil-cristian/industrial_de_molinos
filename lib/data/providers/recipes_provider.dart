import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../datasources/recipes_datasource.dart';

/// Estado para el manejo de recetas
class RecipesState {
  final List<Product> recipes;
  final bool isLoading;
  final String? error;
  final Product? currentRecipe;

  RecipesState({
    this.recipes = const [],
    this.isLoading = false,
    this.error,
    this.currentRecipe,
  });

  RecipesState copyWith({
    List<Product>? recipes,
    bool? isLoading,
    String? error,
    Product? currentRecipe,
  }) {
    return RecipesState(
      recipes: recipes ?? this.recipes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentRecipe: currentRecipe ?? this.currentRecipe,
    );
  }
}

/// Notificador para gestionar recetas (usando Notifier de Riverpod 2.0+)
class RecipesNotifier extends Notifier<RecipesState> {
  @override
  RecipesState build() {
    _loadRecipes();
    return RecipesState();
  }

  /// Cargar todas las recetas
  Future<void> _loadRecipes() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final recipes = await RecipeDataSource.getRecipes();
      state = state.copyWith(recipes: recipes, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  /// Guardar una nueva receta
  Future<bool> saveRecipe({
    required String title,
    required String description,
    required List<RecipeComponent> components,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Calcular totales
      final totalWeight = components.fold<double>(
        0.0,
        (sum, c) => sum + c.weight,
      );
      final totalCost = components.fold<double>(
        0.0,
        (sum, c) => sum + (c.weight * c.pricePerKg),
      );
      
      // Calcular precio de venta usando el precio de venta real de cada material
      final unitPrice = components.fold<double>(
        0.0,
        (sum, c) => sum + (c.weight * c.salePricePerKg),
      );

      // Convertir componentes al formato del datasource
      final componentData = components.map((c) {
        return RecipeComponentData(
          materialId: c.materialId,
          name: c.name,
          description: c.description,
          quantity: c.weight,
          unit: 'KG',
          calculatedWeight: c.weight,
          unitCost: c.pricePerKg,
          totalCost: c.weight * c.pricePerKg,
        );
      }).toList();

      // Guardar en Supabase
      final recipe = await RecipeDataSource.saveRecipe(
        title: title,
        description: description,
        components: componentData,
        totalWeight: totalWeight,
        totalCost: totalCost,
        unitPrice: unitPrice,
      );

      // Actualizar estado
      state = state.copyWith(
        recipes: [...state.recipes, recipe],
        currentRecipe: recipe,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return false;
    }
  }

  /// Actualizar una receta existente
  Future<bool> updateRecipe({
    required String productId,
    required String title,
    required String description,
    required List<RecipeComponent> components,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Calcular totales
      final totalWeight = components.fold<double>(
        0.0,
        (sum, c) => sum + c.weight,
      );
      final totalCost = components.fold<double>(
        0.0,
        (sum, c) => sum + (c.weight * c.pricePerKg),
      );
      // Calcular precio de venta usando el precio de venta real de cada material
      final unitPrice = components.fold<double>(
        0.0,
        (sum, c) => sum + (c.weight * c.salePricePerKg),
      );

      // Convertir componentes
      final componentData = components.map((c) {
        return RecipeComponentData(
          materialId: c.materialId,
          name: c.name,
          description: c.description,
          quantity: c.weight,
          unit: 'KG',
          calculatedWeight: c.weight,
          unitCost: c.pricePerKg,
          totalCost: c.weight * c.pricePerKg,
        );
      }).toList();

      // Actualizar en Supabase
      await RecipeDataSource.updateRecipe(
        productId: productId,
        title: title,
        description: description,
        components: componentData,
        totalWeight: totalWeight,
        totalCost: totalCost,
        unitPrice: unitPrice,
      );

      // Recargar recetas
      await _loadRecipes();
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return false;
    }
  }

  /// Eliminar una receta
  Future<bool> deleteRecipe(String productId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      await RecipeDataSource.deleteRecipe(productId);
      
      final recipes = state.recipes.where((r) => r.id != productId).toList();
      state = state.copyWith(
        recipes: recipes,
        isLoading: false,
      );
      
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
      return false;
    }
  }

  /// Obtener componentes de una receta
  Future<List<RecipeComponentData>> getRecipeComponents(String productId) async {
    try {
      return await RecipeDataSource.getRecipeComponents(productId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  /// Limpiar error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider principal para recetas
final recipesProvider = NotifierProvider<RecipesNotifier, RecipesState>(() {
  return RecipesNotifier();
});

/// Modelo de componente de receta para pasar desde la UI
class RecipeComponent {
  final String? materialId;
  final String name;
  final String? description;
  final String category;
  final double weight;
  final double pricePerKg; // Precio de costo por kg
  final double salePricePerKg; // Precio de venta por kg

  RecipeComponent({
    this.materialId,
    required this.name,
    this.description,
    required this.category,
    required this.weight,
    required this.pricePerKg,
    required this.salePricePerKg,
  });
}
