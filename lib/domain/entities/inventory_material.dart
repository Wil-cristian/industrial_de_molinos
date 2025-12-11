/// Tipo de forma del material (para calcular peso)
enum MaterialShape {
  cylinder,      // Tubo/Cilindro hueco
  solidCylinder, // Cilindro sólido / Eje
  circularPlate, // Tapa circular / Placa redonda
  rectangularPlate, // Lámina rectangular
  ring,          // Anillo / Arandela
  bearing,       // Rodamiento (peso fijo por referencia)
  custom,        // Peso manual
}

/// Entidad: Material de inventario (elementos base)
/// Representa materiales como tubos, láminas, tapas, rodamientos, etc.
class InventoryMaterial {
  final String id;
  final String code;           // Código único (ej: TUB-001, LAM-A36-3MM)
  final String name;           // Nombre descriptivo
  final String? description;
  final MaterialShape shape;   // Forma para cálculo de peso
  final String category;       // Categoría: tubo, lamina, tapa, rodamiento, eje, etc.
  
  // Propiedades físicas
  final double density;        // Densidad en kg/m³ (7850 para acero)
  final double pricePerKg;     // Precio por kilogramo
  final double? fixedWeight;   // Peso fijo (para rodamientos, piezas estándar)
  final double? fixedPrice;    // Precio fijo (para items que no se calculan por kg)
  
  // Inventario
  final double stockKg;        // Stock actual en kilogramos
  final double minStockKg;     // Stock mínimo en kilogramos
  
  // Dimensiones por defecto (opcionales, para facilitar selección)
  final double? defaultThickness;   // Espesor por defecto en mm
  final double? defaultDiameter;    // Diámetro por defecto en mm
  final double? defaultLength;      // Longitud por defecto en mm
  
  // Estado
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryMaterial({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.shape,
    required this.category,
    this.density = 7850, // Acero por defecto
    required this.pricePerKg,
    this.fixedWeight,
    this.fixedPrice,
    this.stockKg = 0,
    this.minStockKg = 0,
    this.defaultThickness,
    this.defaultDiameter,
    this.defaultLength,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Stock bajo
  bool get isLowStock => stockKg <= minStockKg;

  // Nombre para mostrar con stock
  String get displayName => '$name (${stockKg.toStringAsFixed(1)} kg)';

  // Calcular peso según la forma y dimensiones dadas
  double calculateWeight({
    double? outerDiameter,     // Diámetro exterior en mm
    double? innerDiameter,     // Diámetro interior en mm (para tubos)
    double? thickness,         // Espesor en mm
    double? length,            // Longitud en mm
    double? width,             // Ancho en mm (para placas rectangulares)
    double? height,            // Alto en mm (para placas rectangulares)
    int quantity = 1,
  }) {
    // Si tiene peso fijo, retornarlo
    if (fixedWeight != null) {
      return fixedWeight! * quantity;
    }

    double weight = 0;
    // Convertir mm a metros para los cálculos
    final d1 = (outerDiameter ?? 0) / 1000;   // Diámetro exterior en m
    final d2 = (innerDiameter ?? 0) / 1000;   // Diámetro interior en m
    final t = (thickness ?? 0) / 1000;        // Espesor en m
    final l = (length ?? 0) / 1000;           // Longitud en m
    final w = (width ?? 0) / 1000;            // Ancho en m
    final h = (height ?? 0) / 1000;           // Alto en m
    
    const pi = 3.14159265359;

    switch (shape) {
      case MaterialShape.cylinder:
        // Tubo hueco: π × (R² - r²) × L × densidad
        // Si no hay diámetro interior, usar espesor para calcularlo
        double innerD = d2;
        if (innerD == 0 && t > 0) {
          innerD = d1 - (2 * t);
        }
        final outerRadius = d1 / 2;
        final innerRadius = innerD / 2;
        final volume = pi * (outerRadius * outerRadius - innerRadius * innerRadius) * l;
        weight = volume * density;
        break;

      case MaterialShape.solidCylinder:
        // Eje sólido: π × r² × L × densidad
        final radius = d1 / 2;
        final volume = pi * radius * radius * l;
        weight = volume * density;
        break;

      case MaterialShape.circularPlate:
        // Tapa circular: π × r² × espesor × densidad
        final radius = d1 / 2;
        final volume = pi * radius * radius * t;
        weight = volume * density;
        break;

      case MaterialShape.rectangularPlate:
        // Lámina rectangular: ancho × alto × espesor × densidad
        final volume = w * h * t;
        weight = volume * density;
        break;

      case MaterialShape.ring:
        // Anillo: π × (R² - r²) × espesor × densidad
        final outerRadius = d1 / 2;
        final innerRadius = d2 / 2;
        final volume = pi * (outerRadius * outerRadius - innerRadius * innerRadius) * t;
        weight = volume * density;
        break;

      case MaterialShape.bearing:
      case MaterialShape.custom:
        // Peso manual o fijo
        weight = fixedWeight ?? 0;
        break;
    }

    return weight * quantity;
  }

  // Calcular precio según peso
  double calculatePrice({
    double? outerDiameter,
    double? innerDiameter,
    double? thickness,
    double? length,
    double? width,
    double? height,
    int quantity = 1,
  }) {
    // Si tiene precio fijo, retornarlo
    if (fixedPrice != null) {
      return fixedPrice! * quantity;
    }

    final weight = calculateWeight(
      outerDiameter: outerDiameter,
      innerDiameter: innerDiameter,
      thickness: thickness,
      length: length,
      width: width,
      height: height,
      quantity: quantity,
    );

    return weight * pricePerKg;
  }

  // Obtener campos requeridos según la forma
  List<String> get requiredFields {
    switch (shape) {
      case MaterialShape.cylinder:
        return ['outerDiameter', 'thickness', 'length'];
      case MaterialShape.solidCylinder:
        return ['diameter', 'length'];
      case MaterialShape.circularPlate:
        return ['diameter', 'thickness'];
      case MaterialShape.rectangularPlate:
        return ['width', 'height', 'thickness'];
      case MaterialShape.ring:
        return ['outerDiameter', 'innerDiameter', 'thickness'];
      case MaterialShape.bearing:
      case MaterialShape.custom:
        return [];
    }
  }

  // Nombre legible de la forma
  String get shapeDisplayName {
    switch (shape) {
      case MaterialShape.cylinder:
        return 'Tubo / Cilindro hueco';
      case MaterialShape.solidCylinder:
        return 'Eje / Cilindro sólido';
      case MaterialShape.circularPlate:
        return 'Tapa / Placa circular';
      case MaterialShape.rectangularPlate:
        return 'Lámina rectangular';
      case MaterialShape.ring:
        return 'Anillo / Arandela';
      case MaterialShape.bearing:
        return 'Rodamiento';
      case MaterialShape.custom:
        return 'Personalizado';
    }
  }

  InventoryMaterial copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    MaterialShape? shape,
    String? category,
    double? density,
    double? pricePerKg,
    double? fixedWeight,
    double? fixedPrice,
    double? stockKg,
    double? minStockKg,
    double? defaultThickness,
    double? defaultDiameter,
    double? defaultLength,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryMaterial(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      shape: shape ?? this.shape,
      category: category ?? this.category,
      density: density ?? this.density,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      fixedWeight: fixedWeight ?? this.fixedWeight,
      fixedPrice: fixedPrice ?? this.fixedPrice,
      stockKg: stockKg ?? this.stockKg,
      minStockKg: minStockKg ?? this.minStockKg,
      defaultThickness: defaultThickness ?? this.defaultThickness,
      defaultDiameter: defaultDiameter ?? this.defaultDiameter,
      defaultLength: defaultLength ?? this.defaultLength,
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
    'shape': shape.name,
    'category': category,
    'density': density,
    'price_per_kg': pricePerKg,
    'fixed_weight': fixedWeight,
    'fixed_price': fixedPrice,
    'stock_kg': stockKg,
    'min_stock_kg': minStockKg,
    'default_thickness': defaultThickness,
    'default_diameter': defaultDiameter,
    'default_length': defaultLength,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory InventoryMaterial.fromJson(Map<String, dynamic> json) => InventoryMaterial(
    id: json['id'],
    code: json['code'],
    name: json['name'],
    description: json['description'],
    shape: MaterialShape.values.firstWhere(
      (e) => e.name == json['shape'],
      orElse: () => MaterialShape.custom,
    ),
    category: json['category'],
    density: (json['density'] ?? 7850).toDouble(),
    pricePerKg: (json['price_per_kg'] ?? 0).toDouble(),
    fixedWeight: json['fixed_weight']?.toDouble(),
    fixedPrice: json['fixed_price']?.toDouble(),
    stockKg: (json['stock_kg'] ?? 0).toDouble(),
    minStockKg: (json['min_stock_kg'] ?? 0).toDouble(),
    defaultThickness: json['default_thickness']?.toDouble(),
    defaultDiameter: json['default_diameter']?.toDouble(),
    defaultLength: json['default_length']?.toDouble(),
    isActive: json['is_active'] ?? true,
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: DateTime.parse(json['updated_at']),
  );
}

/// Categorías predefinidas de materiales
class MaterialCategories {
  static const String tubo = 'tubo';
  static const String lamina = 'lamina';
  static const String tapa = 'tapa';
  static const String eje = 'eje';
  static const String rodamiento = 'rodamiento';
  static const String tornilleria = 'tornilleria';
  static const String soldadura = 'soldadura';
  static const String pintura = 'pintura';
  static const String otros = 'otros';

  static List<String> get all => [
    tubo,
    lamina,
    tapa,
    eje,
    rodamiento,
    tornilleria,
    soldadura,
    pintura,
    otros,
  ];

  static String getDisplayName(String category) {
    switch (category) {
      case tubo: return 'Tubos';
      case lamina: return 'Láminas';
      case tapa: return 'Tapas';
      case eje: return 'Ejes';
      case rodamiento: return 'Rodamientos';
      case tornilleria: return 'Tornillería';
      case soldadura: return 'Soldadura';
      case pintura: return 'Pintura';
      case otros: return 'Otros';
      default: return category;
    }
  }
}
