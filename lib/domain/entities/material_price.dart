/// Entidad para gestionar precios de materiales
class MaterialPrice {
  final String id;
  final String name; // Nombre del material
  final String category; // Categoría: lamina, tubo, eje, etc.
  final String type; // Tipo específico: A36, Inox 304, etc.
  final double thickness; // Espesor en mm (para láminas)
  final double pricePerKg; // Precio por kilogramo
  final double density; // Densidad en kg/dm³ (7.85 para acero)
  final String unit; // Unidad de medida
  final bool isActive;
  final DateTime updatedAt;

  MaterialPrice({
    required this.id,
    required this.name,
    required this.category,
    this.type = '',
    this.thickness = 0,
    required this.pricePerKg,
    this.density = 7.85, // Densidad del acero por defecto
    this.unit = 'kg',
    this.isActive = true,
    required this.updatedAt,
  });

  MaterialPrice copyWith({
    String? id,
    String? name,
    String? category,
    String? type,
    double? thickness,
    double? pricePerKg,
    double? density,
    String? unit,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return MaterialPrice(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      type: type ?? this.type,
      thickness: thickness ?? this.thickness,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      density: density ?? this.density,
      unit: unit ?? this.unit,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'type': type,
    'thickness': thickness,
    'price_per_kg': pricePerKg,
    'density': density,
    'unit': unit,
    'is_active': isActive,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory MaterialPrice.fromJson(Map<String, dynamic> json) => MaterialPrice(
    id: json['id'],
    name: json['name'],
    category: json['category'],
    type: json['type'] ?? '',
    thickness: (json['thickness'] ?? 0).toDouble(),
    pricePerKg: (json['price_per_kg'] ?? 0).toDouble(),
    density: (json['density'] ?? 7.85).toDouble(),
    unit: json['unit'] ?? 'kg',
    isActive: json['is_active'] ?? true,
    updatedAt: DateTime.parse(json['updated_at']),
  );
}

/// Configuración de costos operativos
class OperationalCosts {
  final double laborRatePerHour; // Tarifa mano de obra por hora
  final double energyRatePerKwh; // Tarifa energía por kWh
  final double gasRatePerM3; // Tarifa gas por m³
  final double defaultProfitMargin; // Margen de ganancia por defecto

  const OperationalCosts({
    this.laborRatePerHour = 25.0,
    this.energyRatePerKwh = 0.50,
    this.gasRatePerM3 = 2.0,
    this.defaultProfitMargin = 20.0,
  });

  Map<String, dynamic> toJson() => {
    'labor_rate_per_hour': laborRatePerHour,
    'energy_rate_per_kwh': energyRatePerKwh,
    'gas_rate_per_m3': gasRatePerM3,
    'default_profit_margin': defaultProfitMargin,
  };

  factory OperationalCosts.fromJson(Map<String, dynamic> json) => OperationalCosts(
    laborRatePerHour: (json['labor_rate_per_hour'] ?? 25.0).toDouble(),
    energyRatePerKwh: (json['energy_rate_per_kwh'] ?? 0.50).toDouble(),
    gasRatePerM3: (json['gas_rate_per_m3'] ?? 2.0).toDouble(),
    defaultProfitMargin: (json['default_profit_margin'] ?? 20.0).toDouble(),
  );
}
