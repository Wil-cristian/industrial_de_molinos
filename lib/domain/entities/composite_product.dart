import 'inventory_material.dart';

/// Componente de un producto compuesto
/// Representa un material específico con sus dimensiones dentro de un producto
class ProductComponent {
  final String id;
  final String materialId;         // ID del material base
  final String? materialName;      // Nombre del material (para display)
  final String? materialCode;      // Código del material
  final MaterialShape? shape;      // Forma heredada del material
  
  // Dimensiones específicas de este componente
  final double? outerDiameter;     // mm
  final double? innerDiameter;     // mm
  final double? thickness;         // mm
  final double? length;            // mm
  final double? width;             // mm
  final double? height;            // mm
  
  final int quantity;              // Cantidad de este componente
  final double weightPerUnit;      // Peso calculado por unidad (kg)
  final double pricePerUnit;       // Precio calculado por unidad
  final String? notes;             // Notas adicionales

  ProductComponent({
    required this.id,
    required this.materialId,
    this.materialName,
    this.materialCode,
    this.shape,
    this.outerDiameter,
    this.innerDiameter,
    this.thickness,
    this.length,
    this.width,
    this.height,
    this.quantity = 1,
    this.weightPerUnit = 0,
    this.pricePerUnit = 0,
    this.notes,
  });

  // Peso total del componente
  double get totalWeight => weightPerUnit * quantity;
  
  // Precio total del componente
  double get totalPrice => pricePerUnit * quantity;

  // Descripción de dimensiones
  String get dimensionsDescription {
    final parts = <String>[];
    if (outerDiameter != null) parts.add('Ø${outerDiameter!.toStringAsFixed(1)}mm');
    if (innerDiameter != null) parts.add('Øint ${innerDiameter!.toStringAsFixed(1)}mm');
    if (thickness != null) parts.add('e=${thickness!.toStringAsFixed(1)}mm');
    if (length != null) parts.add('L=${length!.toStringAsFixed(1)}mm');
    if (width != null) parts.add('A=${width!.toStringAsFixed(1)}mm');
    if (height != null) parts.add('H=${height!.toStringAsFixed(1)}mm');
    return parts.isEmpty ? 'Sin dimensiones' : parts.join(' × ');
  }

  // Descripción completa para factura empresa
  String get fullDescription {
    final desc = materialName ?? 'Material';
    return '$desc ($dimensionsDescription) × $quantity';
  }

  ProductComponent copyWith({
    String? id,
    String? materialId,
    String? materialName,
    String? materialCode,
    MaterialShape? shape,
    double? outerDiameter,
    double? innerDiameter,
    double? thickness,
    double? length,
    double? width,
    double? height,
    int? quantity,
    double? weightPerUnit,
    double? pricePerUnit,
    String? notes,
  }) {
    return ProductComponent(
      id: id ?? this.id,
      materialId: materialId ?? this.materialId,
      materialName: materialName ?? this.materialName,
      materialCode: materialCode ?? this.materialCode,
      shape: shape ?? this.shape,
      outerDiameter: outerDiameter ?? this.outerDiameter,
      innerDiameter: innerDiameter ?? this.innerDiameter,
      thickness: thickness ?? this.thickness,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      quantity: quantity ?? this.quantity,
      weightPerUnit: weightPerUnit ?? this.weightPerUnit,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'material_id': materialId,
    'material_name': materialName,
    'material_code': materialCode,
    'shape': shape?.name,
    'outer_diameter': outerDiameter,
    'inner_diameter': innerDiameter,
    'thickness': thickness,
    'length': length,
    'width': width,
    'height': height,
    'quantity': quantity,
    'weight_per_unit': weightPerUnit,
    'price_per_unit': pricePerUnit,
    'notes': notes,
  };

  factory ProductComponent.fromJson(Map<String, dynamic> json) => ProductComponent(
    id: json['id'],
    materialId: json['material_id'],
    materialName: json['material_name'],
    materialCode: json['material_code'],
    shape: json['shape'] != null 
      ? MaterialShape.values.firstWhere((e) => e.name == json['shape'], orElse: () => MaterialShape.custom)
      : null,
    outerDiameter: json['outer_diameter']?.toDouble(),
    innerDiameter: json['inner_diameter']?.toDouble(),
    thickness: json['thickness']?.toDouble(),
    length: json['length']?.toDouble(),
    width: json['width']?.toDouble(),
    height: json['height']?.toDouble(),
    quantity: json['quantity'] ?? 1,
    weightPerUnit: (json['weight_per_unit'] ?? 0).toDouble(),
    pricePerUnit: (json['price_per_unit'] ?? 0).toDouble(),
    notes: json['notes'],
  );
}

/// Entidad: Producto Compuesto (Bill of Materials)
/// Representa un producto final como "Molino 44m" compuesto de varios materiales
class CompositeProduct {
  final String id;
  final String code;               // Código único (ej: MOL-44M)
  final String name;               // Nombre del producto (ej: Molino 44m)
  final String? description;       // Descripción detallada
  final String? category;          // Categoría: molino, transportador, etc.
  
  final List<ProductComponent> components;  // Lista de componentes/materiales
  
  // Costos adicionales del producto
  final double laborHours;         // Horas de mano de obra
  final double laborRate;          // Tarifa por hora
  final double indirectCosts;      // Costos indirectos (energía, etc.)
  final double profitMargin;       // Margen de ganancia (%)
  
  // Estado
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompositeProduct({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.category,
    this.components = const [],
    this.laborHours = 0,
    this.laborRate = 25,
    this.indirectCosts = 0,
    this.profitMargin = 20,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Peso total de todos los componentes
  double get totalWeight => components.fold(0.0, (sum, c) => sum + c.totalWeight);
  
  // Costo de materiales
  double get materialsCost => components.fold(0.0, (sum, c) => sum + c.totalPrice);
  
  // Costo de mano de obra
  double get laborCost => laborHours * laborRate;
  
  // Subtotal (materiales + mano de obra + indirectos)
  double get subtotal => materialsCost + laborCost + indirectCosts;
  
  // Ganancia
  double get profitAmount => subtotal * (profitMargin / 100);
  
  // Precio total del producto
  double get totalPrice => subtotal + profitAmount;

  // Número de componentes
  int get componentCount => components.length;

  // Resumen para mostrar al cliente
  String get clientSummary => '$name - ${totalWeight.toStringAsFixed(1)} kg';

  // Descripción detallada para la empresa
  String get enterpriseDetail {
    final buffer = StringBuffer();
    buffer.writeln('$name (Código: $code)');
    buffer.writeln('Componentes:');
    for (final c in components) {
      buffer.writeln('  - ${c.fullDescription}: \$${c.totalPrice.toStringAsFixed(2)}');
    }
    buffer.writeln('Materiales: \$${materialsCost.toStringAsFixed(2)}');
    buffer.writeln('Mano de obra: \$${laborCost.toStringAsFixed(2)}');
    buffer.writeln('Costos indirectos: \$${indirectCosts.toStringAsFixed(2)}');
    buffer.writeln('Margen (${profitMargin.toStringAsFixed(0)}%): \$${profitAmount.toStringAsFixed(2)}');
    buffer.writeln('TOTAL: \$${totalPrice.toStringAsFixed(2)}');
    return buffer.toString();
  }

  CompositeProduct copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    String? category,
    List<ProductComponent>? components,
    double? laborHours,
    double? laborRate,
    double? indirectCosts,
    double? profitMargin,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompositeProduct(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      components: components ?? this.components,
      laborHours: laborHours ?? this.laborHours,
      laborRate: laborRate ?? this.laborRate,
      indirectCosts: indirectCosts ?? this.indirectCosts,
      profitMargin: profitMargin ?? this.profitMargin,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'description': description,
    'category': category,
    'components': components.map((c) => c.toJson()).toList(),
    'labor_hours': laborHours,
    'labor_rate': laborRate,
    'indirect_costs': indirectCosts,
    'profit_margin': profitMargin,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory CompositeProduct.fromJson(Map<String, dynamic> json) => CompositeProduct(
    id: json['id'],
    code: json['code'],
    name: json['name'],
    description: json['description'],
    category: json['category'],
    components: (json['components'] as List<dynamic>?)
        ?.map((c) => ProductComponent.fromJson(c))
        .toList() ?? [],
    laborHours: (json['labor_hours'] ?? 0).toDouble(),
    laborRate: (json['labor_rate'] ?? 25).toDouble(),
    indirectCosts: (json['indirect_costs'] ?? 0).toDouble(),
    profitMargin: (json['profit_margin'] ?? 20).toDouble(),
    isActive: json['is_active'] ?? true,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );
}

/// Categorías de productos compuestos
class ProductCategories {
  static const String molino = 'molino';
  static const String transportador = 'transportador';
  static const String tanque = 'tanque';
  static const String estructura = 'estructura';
  static const String maquinaria = 'maquinaria';
  static const String otros = 'otros';

  static List<String> get all => [
    molino,
    transportador,
    tanque,
    estructura,
    maquinaria,
    otros,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case molino: return 'Molinos';
      case transportador: return 'Transportadores';
      case tanque: return 'Tanques';
      case estructura: return 'Estructuras';
      case maquinaria: return 'Maquinaria';
      case otros: return 'Otros';
      default: return category;
    }
  }
}
