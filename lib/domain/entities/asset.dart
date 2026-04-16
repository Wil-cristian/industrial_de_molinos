import 'package:flutter/material.dart';
import '../../core/utils/colombia_time.dart';

/// Entidad de Activo Fijo
class Asset {
  final String id;
  final String name;
  final String? description;
  final String category;
  final DateTime purchaseDate;
  final DateTime? warrantyExpiry;
  final double purchasePrice;
  final double currentValue;
  final double depreciationRate;
  final String status;
  final String? location;
  final String? serialNumber;
  final String? brand;
  final String? model;
  final String? supplierId;
  final String? supplierName;
  final String? invoiceNumber;
  final String? assignedTo;
  final String? imageUrl;
  final String? notes;
  final int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  Asset({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.purchaseDate,
    this.warrantyExpiry,
    required this.purchasePrice,
    required this.currentValue,
    this.depreciationRate = 10.0,
    this.status = 'activo',
    this.location,
    this.serialNumber,
    this.brand,
    this.model,
    this.supplierId,
    this.supplierName,
    this.invoiceNumber,
    this.assignedTo,
    this.imageUrl,
    this.notes,
    this.quantity = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  String get categoryLabel {
    switch (category) {
      case 'maquinaria':
        return 'Maquinaria';
      case 'herramientas':
        return 'Herramientas';
      case 'equipos':
        return 'Equipos';
      case 'vehiculos':
        return 'Vehículos';
      case 'mobiliario':
        return 'Mobiliario';
      default:
        return 'Otros';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case 'maquinaria':
        return Icons.precision_manufacturing;
      case 'herramientas':
        return Icons.build;
      case 'equipos':
        return Icons.computer;
      case 'vehiculos':
        return Icons.local_shipping;
      case 'mobiliario':
        return Icons.chair;
      default:
        return Icons.category;
    }
  }

  Color get categoryColor {
    switch (category) {
      case 'maquinaria':
        return const Color(0xFF1565C0);
      case 'herramientas':
        return const Color(0xFFF9A825);
      case 'equipos':
        return const Color(0xFF7B1FA2);
      case 'vehiculos':
        return const Color(0xFF2E7D32);
      case 'mobiliario':
        return const Color(0xFF795548);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String get statusLabel {
    switch (status) {
      case 'activo':
        return 'ACTIVO';
      case 'mantenimiento':
        return 'MANTENIMIENTO';
      case 'baja':
        return 'DE BAJA';
      case 'vendido':
        return 'VENDIDO';
      default:
        return status.toUpperCase();
    }
  }

  Color get statusColor {
    switch (status) {
      case 'activo':
        return const Color(0xFF2E7D32);
      case 'mantenimiento':
        return const Color(0xFFF9A825);
      case 'baja':
        return const Color(0xFFC62828);
      case 'vendido':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  /// Calcular depreciación acumulada
  double get accumulatedDepreciation {
    final yearsOwned = ColombiaTime.now().difference(purchaseDate).inDays / 365;
    final depreciation = purchasePrice * (depreciationRate / 100) * yearsOwned;
    return depreciation > purchasePrice ? purchasePrice : depreciation;
  }

  /// Verificar si la garantía está vigente
  bool get isWarrantyValid {
    if (warrantyExpiry == null) return false;
    return warrantyExpiry!.isAfter(ColombiaTime.now());
  }

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'otros',
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
      warrantyExpiry: json['warranty_expiry'] != null
          ? DateTime.parse(json['warranty_expiry'] as String)
          : null,
      purchasePrice: (json['purchase_price'] as num).toDouble(),
      currentValue: (json['current_value'] as num).toDouble(),
      depreciationRate: (json['depreciation_rate'] as num?)?.toDouble() ?? 10.0,
      status: json['status'] as String? ?? 'activo',
      location: json['location'] as String?,
      serialNumber: json['serial_number'] as String?,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      supplierId: json['supplier_id'] as String?,
      supplierName: json['supplier_name'] as String?,
      invoiceNumber: json['invoice_number'] as String?,
      assignedTo: json['assigned_to'] as String?,
      imageUrl: json['image_url'] as String?,
      notes: json['notes'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'description': description,
      'category': category,
      'purchase_date': ColombiaTime.dateString(purchaseDate),
      'warranty_expiry': (warrantyExpiry != null
          ? ColombiaTime.dateString(warrantyExpiry!)
          : null),
      'purchase_price': purchasePrice,
      'current_value': currentValue,
      'depreciation_rate': depreciationRate,
      'status': status,
      'location': location,
      'serial_number': serialNumber,
      'brand': brand,
      'model': model,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'invoice_number': invoiceNumber,
      'assigned_to': assignedTo,
      'image_url': imageUrl,
      'notes': notes,
      'quantity': quantity,
    };
  }

  Asset copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    DateTime? purchaseDate,
    DateTime? warrantyExpiry,
    double? purchasePrice,
    double? currentValue,
    double? depreciationRate,
    String? status,
    String? location,
    String? serialNumber,
    String? brand,
    String? model,
    String? supplierId,
    String? supplierName,
    String? invoiceNumber,
    String? assignedTo,
    String? imageUrl,
    String? notes,
    int? quantity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Asset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currentValue: currentValue ?? this.currentValue,
      depreciationRate: depreciationRate ?? this.depreciationRate,
      status: status ?? this.status,
      location: location ?? this.location,
      serialNumber: serialNumber ?? this.serialNumber,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      assignedTo: assignedTo ?? this.assignedTo,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Entidad de Mantenimiento de Activo
class AssetMaintenance {
  final String id;
  final String assetId;
  final DateTime maintenanceDate;
  final String maintenanceType;
  final String description;
  final double cost;
  final String? performedBy;
  final DateTime? nextMaintenanceDate;
  final String? notes;
  final DateTime createdAt;

  AssetMaintenance({
    required this.id,
    required this.assetId,
    required this.maintenanceDate,
    required this.maintenanceType,
    required this.description,
    this.cost = 0,
    this.performedBy,
    this.nextMaintenanceDate,
    this.notes,
    required this.createdAt,
  });

  String get typeLabel {
    switch (maintenanceType) {
      case 'preventivo':
        return 'Preventivo';
      case 'correctivo':
        return 'Correctivo';
      case 'emergencia':
        return 'Emergencia';
      default:
        return maintenanceType;
    }
  }

  Color get typeColor {
    switch (maintenanceType) {
      case 'preventivo':
        return const Color(0xFF2E7D32);
      case 'correctivo':
        return const Color(0xFFF9A825);
      case 'emergencia':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  factory AssetMaintenance.fromJson(Map<String, dynamic> json) {
    return AssetMaintenance(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      maintenanceDate: DateTime.parse(json['maintenance_date'] as String),
      maintenanceType: json['maintenance_type'] as String? ?? 'preventivo',
      description: json['description'] as String,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      performedBy: json['performed_by'] as String?,
      nextMaintenanceDate: json['next_maintenance_date'] != null
          ? DateTime.parse(json['next_maintenance_date'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'asset_id': assetId,
      'maintenance_date': ColombiaTime.dateString(maintenanceDate),
      'maintenance_type': maintenanceType,
      'description': description,
      'cost': cost,
      'performed_by': performedBy,
      'next_maintenance_date': (nextMaintenanceDate != null
          ? ColombiaTime.dateString(nextMaintenanceDate!)
          : null),
      'notes': notes,
    };
  }
}
