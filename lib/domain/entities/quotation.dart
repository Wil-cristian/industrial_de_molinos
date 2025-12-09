/// Entidad principal de Cotización
class Quotation {
  final String id;
  final String number; // COT-2024-001
  final DateTime date;
  final DateTime validUntil;
  final String customerId;
  final String customerName;
  final String status; // Borrador, Enviada, Aprobada, Rechazada, Vencida
  final List<QuotationItem> items;
  final double laborCost; // Mano de obra
  final double energyCost; // Energía
  final double gasCost; // Gas
  final double suppliesCost; // Insumos (soldadura, pintura, etc.)
  final double otherCosts; // Otros costos
  final double profitMargin; // Margen de ganancia (porcentaje)
  final String notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool synced;

  Quotation({
    required this.id,
    required this.number,
    required this.date,
    required this.validUntil,
    required this.customerId,
    required this.customerName,
    this.status = 'Borrador',
    this.items = const [],
    this.laborCost = 0,
    this.energyCost = 0,
    this.gasCost = 0,
    this.suppliesCost = 0,
    this.otherCosts = 0,
    this.profitMargin = 20, // 20% por defecto
    this.notes = '',
    required this.createdAt,
    this.updatedAt,
    this.synced = false,
  });

  /// Subtotal de materiales (suma de todos los items)
  double get materialsCost => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Subtotal de costos indirectos
  double get indirectCosts => energyCost + gasCost + suppliesCost + otherCosts;

  /// Subtotal antes de ganancia
  double get subtotal => materialsCost + laborCost + indirectCosts;

  /// Monto de ganancia
  double get profitAmount => subtotal * (profitMargin / 100);

  /// Total final de la cotización
  double get total => subtotal + profitAmount;

  /// Peso total en kg
  double get totalWeight => items.fold(0.0, (sum, item) => sum + item.totalWeight);

  Quotation copyWith({
    String? id,
    String? number,
    DateTime? date,
    DateTime? validUntil,
    String? customerId,
    String? customerName,
    String? status,
    List<QuotationItem>? items,
    double? laborCost,
    double? energyCost,
    double? gasCost,
    double? suppliesCost,
    double? otherCosts,
    double? profitMargin,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return Quotation(
      id: id ?? this.id,
      number: number ?? this.number,
      date: date ?? this.date,
      validUntil: validUntil ?? this.validUntil,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      items: items ?? this.items,
      laborCost: laborCost ?? this.laborCost,
      energyCost: energyCost ?? this.energyCost,
      gasCost: gasCost ?? this.gasCost,
      suppliesCost: suppliesCost ?? this.suppliesCost,
      otherCosts: otherCosts ?? this.otherCosts,
      profitMargin: profitMargin ?? this.profitMargin,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'number': number,
    'date': date.toIso8601String(),
    'valid_until': validUntil.toIso8601String(),
    'customer_id': customerId,
    'customer_name': customerName,
    'status': status,
    'items': items.map((e) => e.toJson()).toList(),
    'labor_cost': laborCost,
    'energy_cost': energyCost,
    'gas_cost': gasCost,
    'supplies_cost': suppliesCost,
    'other_costs': otherCosts,
    'profit_margin': profitMargin,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'synced': synced,
  };

  factory Quotation.fromJson(Map<String, dynamic> json) => Quotation(
    id: json['id'],
    number: json['number'],
    date: DateTime.parse(json['date']),
    validUntil: DateTime.parse(json['valid_until']),
    customerId: json['customer_id'],
    customerName: json['customer_name'],
    status: json['status'] ?? 'Borrador',
    items: (json['items'] as List?)?.map((e) => QuotationItem.fromJson(e)).toList() ?? [],
    laborCost: (json['labor_cost'] ?? 0).toDouble(),
    energyCost: (json['energy_cost'] ?? 0).toDouble(),
    gasCost: (json['gas_cost'] ?? 0).toDouble(),
    suppliesCost: (json['supplies_cost'] ?? 0).toDouble(),
    otherCosts: (json['other_costs'] ?? 0).toDouble(),
    profitMargin: (json['profit_margin'] ?? 20).toDouble(),
    notes: json['notes'] ?? '',
    createdAt: DateTime.parse(json['created_at']),
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    synced: json['synced'] ?? false,
  );
}

/// Item individual de una cotización (puede ser un componente calculado o producto simple)
class QuotationItem {
  final String id;
  final String name;
  final String description;
  final String type; // cylinder, plate, shaft, custom, product
  final int quantity;
  final double unitWeight; // Peso unitario en kg
  final double pricePerKg; // Precio por kg del material
  final double unitPrice; // Precio unitario (para productos que no se calculan por peso)
  final Map<String, dynamic> dimensions; // Dimensiones específicas según el tipo
  final String materialType; // Tipo de material/lámina

  QuotationItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.type,
    this.quantity = 1,
    this.unitWeight = 0,
    this.pricePerKg = 0,
    this.unitPrice = 0,
    this.dimensions = const {},
    this.materialType = '',
  });

  /// Peso total del item
  double get totalWeight => unitWeight * quantity;

  /// Precio total del item
  double get totalPrice {
    if (unitPrice > 0) {
      return unitPrice * quantity;
    }
    return totalWeight * pricePerKg;
  }

  QuotationItem copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    int? quantity,
    double? unitWeight,
    double? pricePerKg,
    double? unitPrice,
    Map<String, dynamic>? dimensions,
    String? materialType,
  }) {
    return QuotationItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      unitWeight: unitWeight ?? this.unitWeight,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      unitPrice: unitPrice ?? this.unitPrice,
      dimensions: dimensions ?? this.dimensions,
      materialType: materialType ?? this.materialType,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type,
    'quantity': quantity,
    'unit_weight': unitWeight,
    'price_per_kg': pricePerKg,
    'unit_price': unitPrice,
    'dimensions': dimensions,
    'material_type': materialType,
  };

  factory QuotationItem.fromJson(Map<String, dynamic> json) => QuotationItem(
    id: json['id'],
    name: json['name'],
    description: json['description'] ?? '',
    type: json['type'],
    quantity: json['quantity'] ?? 1,
    unitWeight: (json['unit_weight'] ?? 0).toDouble(),
    pricePerKg: (json['price_per_kg'] ?? 0).toDouble(),
    unitPrice: (json['unit_price'] ?? 0).toDouble(),
    dimensions: json['dimensions'] ?? {},
    materialType: json['material_type'] ?? '',
  );
}
