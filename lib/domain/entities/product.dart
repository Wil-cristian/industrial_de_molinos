// Entidad: Producto
class Product {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String? categoryId;
  final double unitPrice;
  final double costPrice;
  final double stock;
  final double minStock;
  final String unit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Campos de receta
  final bool isRecipe;
  final String? recipeDescription;
  final double totalWeight;
  final double totalCost;

  Product({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.categoryId,
    required this.unitPrice,
    required this.costPrice,
    this.stock = 0,
    this.minStock = 0,
    this.unit = 'UND',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.isRecipe = false,
    this.recipeDescription,
    this.totalWeight = 0,
    this.totalCost = 0,
  });

  // Stock bajo
  bool get isLowStock => stock <= minStock;

  // Margen de ganancia
  double get profitMargin => costPrice > 0 
      ? ((unitPrice - costPrice) / costPrice) * 100 
      : 0;

  Product copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    String? categoryId,
    double? unitPrice,
    double? costPrice,
    double? stock,
    double? minStock,
    String? unit,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRecipe,
    String? recipeDescription,
    double? totalWeight,
    double? totalCost,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRecipe: isRecipe ?? this.isRecipe,
      recipeDescription: recipeDescription ?? this.recipeDescription,
      totalWeight: totalWeight ?? this.totalWeight,
      totalCost: totalCost ?? this.totalCost,
    );
  }
}

// Entidad: Categoría
class Category {
  final String id;
  final String name;
  final String? description;
  final String? parentId;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.parentId,
    required this.createdAt,
  });
}

// Movimiento de Stock
enum StockMovementType { incoming, outgoing, adjustment }

class StockMovement {
  final String id;
  final String productId;
  final StockMovementType type;
  final double quantity;
  final String? reason;
  final String? reference;
  final DateTime createdAt;
  final String? createdBy;

  StockMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    this.reason,
    this.reference,
    required this.createdAt,
    this.createdBy,
  });
}
