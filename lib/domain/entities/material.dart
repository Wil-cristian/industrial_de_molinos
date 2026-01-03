// Entidad: Material de Inventario (Simplificada para Supabase)
// Representa materia prima en el almacén

class Material {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String category;      // tubo, lamina, eje, rodamiento, tornilleria, etc.
  final String shape;         // cylinder, plate, solid_cylinder, bearing, custom
  
  // Precios
  final double pricePerKg;    // Para materiales por peso
  final double unitPrice;     // Para materiales por unidad
  final double costPrice;     // Costo de compra
  
  // Stock
  final double stock;         // Cantidad actual
  final double minStock;      // Stock mínimo (alerta)
  final String unit;          // KG, UND, M, L, etc.
  
  // Propiedades físicas
  final double density;       // kg/m³ (acero = 7850)
  final double? defaultThickness;
  final double? fixedWeight;  // Peso fijo por unidad
  
  // Metadata
  final String? supplier;
  final String? location;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Material({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.category = 'general',
    this.shape = 'custom',
    this.pricePerKg = 0,
    this.unitPrice = 0,
    this.costPrice = 0,
    this.stock = 0,
    this.minStock = 0,
    this.unit = 'KG',
    this.density = 7850,
    this.defaultThickness,
    this.fixedWeight,
    this.supplier,
    this.location,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Stock bajo
  bool get isLowStock => stock <= minStock;

  // Precio efectivo de VENTA (según tipo)
  double get effectivePrice => unit == 'KG' ? pricePerKg : unitPrice;

  // Precio efectivo de COMPRA/COSTO (según tipo)
  // Si costPrice > 0, usar ese; sino usar effectivePrice como fallback
  double get effectiveCostPrice => costPrice > 0 ? costPrice : effectivePrice;

  // Nombre formateado con stock
  String get displayName => '$name (${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 2)} $unit)';

  // Categoría formateada
  String get categoryDisplay {
    switch (category) {
      case 'tubo': return 'Tubos';
      case 'lamina': return 'Láminas';
      case 'eje': return 'Ejes';
      case 'rodamiento': return 'Rodamientos';
      case 'tornilleria': return 'Tornillería';
      case 'consumible': return 'Consumibles';
      case 'pintura': return 'Pintura';
      default: return category;
    }
  }

  Material copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    String? category,
    String? shape,
    double? pricePerKg,
    double? unitPrice,
    double? costPrice,
    double? stock,
    double? minStock,
    String? unit,
    double? density,
    double? defaultThickness,
    double? fixedWeight,
    String? supplier,
    String? location,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Material(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      shape: shape ?? this.shape,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      unit: unit ?? this.unit,
      density: density ?? this.density,
      defaultThickness: defaultThickness ?? this.defaultThickness,
      fixedWeight: fixedWeight ?? this.fixedWeight,
      supplier: supplier ?? this.supplier,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Desde JSON (Supabase)
  factory Material.fromJson(Map<String, dynamic> json) {
    return Material(
      id: json['id'],
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      category: json['category'] ?? 'general',
      shape: json['shape'] ?? 'custom',
      pricePerKg: (json['price_per_kg'] ?? 0).toDouble(),
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      costPrice: (json['cost_price'] ?? 0).toDouble(),
      stock: (json['stock'] ?? 0).toDouble(),
      minStock: (json['min_stock'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'KG',
      density: (json['density'] ?? 7850).toDouble(),
      defaultThickness: json['default_thickness']?.toDouble(),
      fixedWeight: json['fixed_weight']?.toDouble(),
      supplier: json['supplier'],
      location: json['location'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  // A JSON (para Supabase)
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'description': description,
      'category': category,
      'shape': shape,
      'price_per_kg': pricePerKg,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'stock': stock,
      'min_stock': minStock,
      'unit': unit,
      'density': density,
      'default_thickness': defaultThickness,
      'fixed_weight': fixedWeight,
      'supplier': supplier,
      'location': location,
      'is_active': isActive,
    };
  }
}

// Componente de una receta (product_components)
class ProductComponent {
  final String id;
  final String productId;
  final String? materialId;
  final String name;
  final String? description;
  final double quantity;
  final String unit;
  
  // Dimensiones (para cálculo)
  final double? outerDiameter;
  final double? innerDiameter;
  final double? thickness;
  final double? length;
  final double? width;
  
  // Peso y costo
  final double calculatedWeight;
  final double unitCost;
  final double totalCost;
  final int sortOrder;
  
  // Material relacionado (opcional, para mostrar info)
  final Material? material;

  ProductComponent({
    required this.id,
    required this.productId,
    this.materialId,
    required this.name,
    this.description,
    this.quantity = 1,
    this.unit = 'KG',
    this.outerDiameter,
    this.innerDiameter,
    this.thickness,
    this.length,
    this.width,
    this.calculatedWeight = 0,
    this.unitCost = 0,
    this.totalCost = 0,
    this.sortOrder = 0,
    this.material,
  });

  ProductComponent copyWith({
    String? id,
    String? productId,
    String? materialId,
    String? name,
    String? description,
    double? quantity,
    String? unit,
    double? outerDiameter,
    double? innerDiameter,
    double? thickness,
    double? length,
    double? width,
    double? calculatedWeight,
    double? unitCost,
    double? totalCost,
    int? sortOrder,
    Material? material,
  }) {
    return ProductComponent(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      materialId: materialId ?? this.materialId,
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      outerDiameter: outerDiameter ?? this.outerDiameter,
      innerDiameter: innerDiameter ?? this.innerDiameter,
      thickness: thickness ?? this.thickness,
      length: length ?? this.length,
      width: width ?? this.width,
      calculatedWeight: calculatedWeight ?? this.calculatedWeight,
      unitCost: unitCost ?? this.unitCost,
      totalCost: totalCost ?? this.totalCost,
      sortOrder: sortOrder ?? this.sortOrder,
      material: material ?? this.material,
    );
  }

  factory ProductComponent.fromJson(Map<String, dynamic> json) {
    return ProductComponent(
      id: json['id'],
      productId: json['product_id'],
      materialId: json['material_id'],
      name: json['name'] ?? '',
      description: json['description'],
      quantity: (json['quantity'] ?? 1).toDouble(),
      unit: json['unit'] ?? 'KG',
      outerDiameter: json['outer_diameter']?.toDouble(),
      innerDiameter: json['inner_diameter']?.toDouble(),
      thickness: json['thickness']?.toDouble(),
      length: json['length']?.toDouble(),
      width: json['width']?.toDouble(),
      calculatedWeight: (json['calculated_weight'] ?? 0).toDouble(),
      unitCost: (json['unit_cost'] ?? 0).toDouble(),
      totalCost: (json['total_cost'] ?? 0).toDouble(),
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'material_id': materialId,
      'name': name,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'outer_diameter': outerDiameter,
      'inner_diameter': innerDiameter,
      'thickness': thickness,
      'length': length,
      'width': width,
      'calculated_weight': calculatedWeight,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'sort_order': sortOrder,
    };
  }
}
