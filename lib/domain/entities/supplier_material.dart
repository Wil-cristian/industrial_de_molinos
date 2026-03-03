// Entidad: Relación Proveedor-Material con precio de compra

class SupplierMaterial {
  final String id;
  final String supplierId;
  final String materialId;
  final double unitPrice;
  final double? lastPurchasePrice;
  final DateTime? lastPurchaseDate;
  final double minOrderQuantity;
  final int leadTimeDays;
  final String? notes;
  final bool isPreferred;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Datos de join opcionales
  final String? supplierName;
  final String? materialName;
  final String? materialUnit;

  SupplierMaterial({
    required this.id,
    required this.supplierId,
    required this.materialId,
    this.unitPrice = 0,
    this.lastPurchasePrice,
    this.lastPurchaseDate,
    this.minOrderQuantity = 1,
    this.leadTimeDays = 0,
    this.notes,
    this.isPreferred = false,
    required this.createdAt,
    required this.updatedAt,
    this.supplierName,
    this.materialName,
    this.materialUnit,
  });

  double get effectivePrice => lastPurchasePrice ?? unitPrice;

  SupplierMaterial copyWith({
    String? id,
    String? supplierId,
    String? materialId,
    double? unitPrice,
    double? lastPurchasePrice,
    DateTime? lastPurchaseDate,
    double? minOrderQuantity,
    int? leadTimeDays,
    String? notes,
    bool? isPreferred,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supplierName,
    String? materialName,
    String? materialUnit,
  }) {
    return SupplierMaterial(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      materialId: materialId ?? this.materialId,
      unitPrice: unitPrice ?? this.unitPrice,
      lastPurchasePrice: lastPurchasePrice ?? this.lastPurchasePrice,
      lastPurchaseDate: lastPurchaseDate ?? this.lastPurchaseDate,
      minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      notes: notes ?? this.notes,
      isPreferred: isPreferred ?? this.isPreferred,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplierName: supplierName ?? this.supplierName,
      materialName: materialName ?? this.materialName,
      materialUnit: materialUnit ?? this.materialUnit,
    );
  }

  factory SupplierMaterial.fromJson(Map<String, dynamic> json) {
    return SupplierMaterial(
      id: json['id'] as String,
      supplierId: json['supplier_id'] as String,
      materialId: json['material_id'] as String,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      lastPurchasePrice: (json['last_purchase_price'] as num?)?.toDouble(),
      lastPurchaseDate: json['last_purchase_date'] != null
          ? DateTime.parse(json['last_purchase_date'] as String)
          : null,
      minOrderQuantity: (json['min_order_quantity'] as num?)?.toDouble() ?? 1,
      leadTimeDays: (json['lead_time_days'] as int?) ?? 0,
      notes: json['notes'] as String?,
      isPreferred: json['is_preferred'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      // Datos de join
      supplierName: json['proveedores'] != null
          ? json['proveedores']['name'] as String?
          : null,
      materialName: json['materials'] != null
          ? json['materials']['name'] as String?
          : null,
      materialUnit: json['materials'] != null
          ? json['materials']['unit'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supplier_id': supplierId,
      'material_id': materialId,
      'unit_price': unitPrice,
      'last_purchase_price': lastPurchasePrice,
      'last_purchase_date': lastPurchaseDate?.toIso8601String(),
      'min_order_quantity': minOrderQuantity,
      'lead_time_days': leadTimeDays,
      'notes': notes,
      'is_preferred': isPreferred,
    };
  }
}
