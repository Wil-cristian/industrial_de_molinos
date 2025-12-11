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

/// Tipo de material para determinar cómo se calcula y almacena
enum InventoryMaterialType {
  tubo,      // Tubo: diám. exterior, espesor, largo → calcula peso
  lamina,    // Lámina: largo, ancho, espesor → calcula peso
  tapa,      // Tapa circular: diámetro, espesor → calcula peso
  eje,       // Eje sólido: diámetro, largo → calcula peso
  porKilo,   // Por Kilo: solo nombre, precio/kg, cantidad kg
  porUnidad, // Por Unidad: nombre, precio/unidad, cantidad unidades
}

/// Unidad de medida para dimensiones
enum MeasurementUnit {
  milimetros,
  pulgadas,
}

/// Fracciones de pulgada comunes
class InchFractions {
  static const List<String> common = [
    '1/16', '1/8', '3/16', '1/4', '5/16', '3/8', '7/16', '1/2',
    '9/16', '5/8', '11/16', '3/4', '13/16', '7/8', '15/16',
  ];
  
  /// Convertir fracción de pulgada a milímetros
  static double toMm(String fraction) {
    final parts = fraction.split('/');
    if (parts.length == 2) {
      final num = double.tryParse(parts[0]) ?? 0;
      final den = double.tryParse(parts[1]) ?? 1;
      return (num / den) * 25.4; // 1 pulgada = 25.4 mm
    }
    return 0;
  }
  
  /// Convertir pulgadas completas + fracción a mm
  static double inchesToMm(int inches, String? fraction) {
    double mm = inches * 25.4;
    if (fraction != null && fraction.isNotEmpty) {
      mm += toMm(fraction);
    }
    return mm;
  }
  
  /// Convertir mm a pulgadas (string formateado)
  static String mmToInches(double mm) {
    final totalInches = mm / 25.4;
    final wholeInches = totalInches.floor();
    final remainder = totalInches - wholeInches;
    
    // Encontrar la fracción más cercana
    String closestFraction = '';
    double minDiff = double.infinity;
    for (final frac in common) {
      final fracValue = toMm(frac) / 25.4;
      final diff = (remainder - fracValue).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestFraction = frac;
      }
    }
    
    if (wholeInches > 0 && closestFraction.isNotEmpty && minDiff < 0.01) {
      return '$wholeInches $closestFraction"';
    } else if (wholeInches > 0) {
      return '$wholeInches"';
    } else if (closestFraction.isNotEmpty) {
      return '$closestFraction"';
    }
    return '${totalInches.toStringAsFixed(3)}"';
  }
}

/// Entidad: Material de inventario (elementos base)
/// Representa materiales como tubos, láminas, tapas, rodamientos, etc.
class InventoryMaterial {
  final String id;
  final String code;           // Código único (ej: TUB-001, LAM-A36-3MM)
  final String name;           // Nombre descriptivo
  final String? description;
  final MaterialShape shape;   // Forma para cálculo de peso
  final InventoryMaterialType type;     // Tipo de material (tubo, lamina, tapa, eje, porKilo, porUnidad)
  final String category;       // Categoría: tubo, lamina, tapa, rodamiento, eje, etc.
  
  // Propiedades físicas
  final double density;        // Densidad en kg/m³ (7850 para acero - FIJA)
  final double pricePerKg;     // Precio por kilogramo
  final double? fixedWeight;   // Peso fijo (para rodamientos, piezas estándar)
  final double? fixedPrice;    // Precio fijo (para items por unidad)
  
  // Dimensiones ingresadas (en mm)
  final double? outerDiameter;  // Diámetro exterior (tubos, tapas, ejes)
  final double? wallThickness;  // Espesor de pared (tubos)
  final double? thickness;      // Espesor (láminas, tapas)
  final double? length;         // Largo
  final double? width;          // Ancho (láminas)
  
  // Peso calculado
  final double calculatedWeight; // Peso calculado con las fórmulas
  final double totalValue;       // Valor total = peso × precio/kg
  
  // Inventario
  final double stockKg;        // Stock actual en kilogramos
  final double minStockKg;     // Stock mínimo en kilogramos
  final int stockUnits;        // Stock actual en unidades (para porUnidad)
  final int minStockUnits;     // Stock mínimo en unidades (para porUnidad)
  
  // Unidad de medida usada para ingreso
  final MeasurementUnit measurementUnit;
  
  // Dimensiones por defecto (opcionales, para facilitar selección)
  final double? defaultThickness;   // Espesor por defecto en mm
  final double? defaultDiameter;    // Diámetro por defecto en mm
  final double? defaultLength;      // Longitud por defecto en mm
  
  // Estado
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Densidad fija para acero
  static const double steelDensity = 7850.0; // kg/m³

  InventoryMaterial({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.shape,
    this.type = InventoryMaterialType.tubo,
    required this.category,
    this.density = 7850, // Acero por defecto
    required this.pricePerKg,
    this.fixedWeight,
    this.fixedPrice,
    this.outerDiameter,
    this.wallThickness,
    this.thickness,
    this.length,
    this.width,
    this.calculatedWeight = 0,
    this.totalValue = 0,
    this.stockKg = 0,
    this.minStockKg = 0,
    this.stockUnits = 0,
    this.minStockUnits = 0,
    this.measurementUnit = MeasurementUnit.milimetros,
    this.defaultThickness,
    this.defaultDiameter,
    this.defaultLength,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Stock bajo - considera si es por kg o por unidad
  bool get isLowStock {
    if (type == InventoryMaterialType.porUnidad) {
      return stockUnits <= minStockUnits;
    }
    return stockKg <= minStockKg;
  }

  // Nombre para mostrar con stock
  String get displayName {
    if (type == InventoryMaterialType.porUnidad) {
      return '$name ($stockUnits unidades)';
    }
    return '$name (${stockKg.toStringAsFixed(1)} kg)';
  }
  
  // Descripción de dimensiones
  String get dimensionsDescription {
    switch (type) {
      case InventoryMaterialType.tubo:
        return 'Ø${outerDiameter?.toStringAsFixed(1)}mm × e${wallThickness?.toStringAsFixed(1)}mm × L${length?.toStringAsFixed(0)}mm';
      case InventoryMaterialType.lamina:
        return '${length?.toStringAsFixed(0)}mm × ${width?.toStringAsFixed(0)}mm × e${thickness?.toStringAsFixed(1)}mm';
      case InventoryMaterialType.tapa:
        return 'Ø${outerDiameter?.toStringAsFixed(1)}mm × e${thickness?.toStringAsFixed(1)}mm';
      case InventoryMaterialType.eje:
        return 'Ø${outerDiameter?.toStringAsFixed(1)}mm × L${length?.toStringAsFixed(0)}mm';
      case InventoryMaterialType.porKilo:
        return '${stockKg.toStringAsFixed(2)} kg';
      case InventoryMaterialType.porUnidad:
        return '$stockUnits unidades';
    }
  }

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
    InventoryMaterialType? type,
    String? category,
    double? density,
    double? pricePerKg,
    double? fixedWeight,
    double? fixedPrice,
    double? outerDiameter,
    double? wallThickness,
    double? thickness,
    double? length,
    double? width,
    double? calculatedWeight,
    double? totalValue,
    double? stockKg,
    double? minStockKg,
    int? stockUnits,
    int? minStockUnits,
    MeasurementUnit? measurementUnit,
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
      type: type ?? this.type,
      category: category ?? this.category,
      density: density ?? this.density,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      fixedWeight: fixedWeight ?? this.fixedWeight,
      fixedPrice: fixedPrice ?? this.fixedPrice,
      outerDiameter: outerDiameter ?? this.outerDiameter,
      wallThickness: wallThickness ?? this.wallThickness,
      thickness: thickness ?? this.thickness,
      length: length ?? this.length,
      width: width ?? this.width,
      calculatedWeight: calculatedWeight ?? this.calculatedWeight,
      totalValue: totalValue ?? this.totalValue,
      stockKg: stockKg ?? this.stockKg,
      minStockKg: minStockKg ?? this.minStockKg,
      stockUnits: stockUnits ?? this.stockUnits,
      minStockUnits: minStockUnits ?? this.minStockUnits,
      measurementUnit: measurementUnit ?? this.measurementUnit,
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
    'type': type.name,
    'category': category,
    'density': density,
    'price_per_kg': pricePerKg,
    'fixed_weight': fixedWeight,
    'fixed_price': fixedPrice,
    'outer_diameter': outerDiameter,
    'wall_thickness': wallThickness,
    'thickness': thickness,
    'length': length,
    'width': width,
    'calculated_weight': calculatedWeight,
    'total_value': totalValue,
    'stock_kg': stockKg,
    'min_stock_kg': minStockKg,
    'stock_units': stockUnits,
    'min_stock_units': minStockUnits,
    'measurement_unit': measurementUnit.name,
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
    type: InventoryMaterialType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => InventoryMaterialType.porKilo,
    ),
    category: json['category'],
    density: (json['density'] ?? 7850).toDouble(),
    pricePerKg: (json['price_per_kg'] ?? 0).toDouble(),
    fixedWeight: json['fixed_weight']?.toDouble(),
    fixedPrice: json['fixed_price']?.toDouble(),
    outerDiameter: json['outer_diameter']?.toDouble(),
    wallThickness: json['wall_thickness']?.toDouble(),
    thickness: json['thickness']?.toDouble(),
    length: json['length']?.toDouble(),
    width: json['width']?.toDouble(),
    calculatedWeight: (json['calculated_weight'] ?? 0).toDouble(),
    totalValue: (json['total_value'] ?? 0).toDouble(),
    stockKg: (json['stock_kg'] ?? 0).toDouble(),
    minStockKg: (json['min_stock_kg'] ?? 0).toDouble(),
    stockUnits: (json['stock_units'] ?? 0).toInt(),
    minStockUnits: (json['min_stock_units'] ?? 0).toInt(),
    measurementUnit: MeasurementUnit.values.firstWhere(
      (e) => e.name == json['measurement_unit'],
      orElse: () => MeasurementUnit.milimetros,
    ),
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
