// Entidades: Remisión / Orden de Envío

enum ShipmentStatus { borrador, despachada, enTransito, entregada, anulada }

enum ShipmentItemType { producto, material, pieza, herramienta, otro }

class ShipmentOrder {
  final String id;
  final String code;
  final String? invoiceId;
  final String? productionOrderId;
  final String? customerId;
  final String customerName;
  final String? customerAddress;

  // Transporte
  final String? carrierName;
  final String? carrierDocument;
  final String? vehiclePlate;
  final String? driverName;
  final String? driverDocument;

  // Fechas
  final DateTime dispatchDate;
  final DateTime? deliveryDate;
  final DateTime? deliveredAt;

  // Estado
  final ShipmentStatus status;

  // Notas
  final String? notes;
  final String? internalNotes;

  // Firmas
  final String? preparedBy;
  final String? approvedBy;
  final String? receivedBy;

  final List<ShipmentOrderItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Campos display opcionales
  final String? invoiceFullNumber;
  final String? productionOrderCode;

  const ShipmentOrder({
    required this.id,
    required this.code,
    this.invoiceId,
    this.productionOrderId,
    this.customerId,
    required this.customerName,
    this.customerAddress,
    this.carrierName,
    this.carrierDocument,
    this.vehiclePlate,
    this.driverName,
    this.driverDocument,
    required this.dispatchDate,
    this.deliveryDate,
    this.deliveredAt,
    this.status = ShipmentStatus.borrador,
    this.notes,
    this.internalNotes,
    this.preparedBy,
    this.approvedBy,
    this.receivedBy,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
    this.invoiceFullNumber,
    this.productionOrderCode,
  });

  String get statusLabel {
    switch (status) {
      case ShipmentStatus.borrador:
        return 'Borrador';
      case ShipmentStatus.despachada:
        return 'Despachada';
      case ShipmentStatus.enTransito:
        return 'En Tránsito';
      case ShipmentStatus.entregada:
        return 'Entregada';
      case ShipmentStatus.anulada:
        return 'Anulada';
    }
  }

  int get totalItems => items.length;

  double get totalWeight => items.fold(0.0, (s, i) => s + (i.weightKg ?? 0));

  ShipmentOrder copyWith({
    String? id,
    String? code,
    String? invoiceId,
    String? productionOrderId,
    String? customerId,
    String? customerName,
    String? customerAddress,
    String? carrierName,
    String? carrierDocument,
    String? vehiclePlate,
    String? driverName,
    String? driverDocument,
    DateTime? dispatchDate,
    DateTime? deliveryDate,
    DateTime? deliveredAt,
    ShipmentStatus? status,
    String? notes,
    String? internalNotes,
    String? preparedBy,
    String? approvedBy,
    String? receivedBy,
    List<ShipmentOrderItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? invoiceFullNumber,
    String? productionOrderCode,
  }) {
    return ShipmentOrder(
      id: id ?? this.id,
      code: code ?? this.code,
      invoiceId: invoiceId ?? this.invoiceId,
      productionOrderId: productionOrderId ?? this.productionOrderId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      carrierName: carrierName ?? this.carrierName,
      carrierDocument: carrierDocument ?? this.carrierDocument,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      driverName: driverName ?? this.driverName,
      driverDocument: driverDocument ?? this.driverDocument,
      dispatchDate: dispatchDate ?? this.dispatchDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      internalNotes: internalNotes ?? this.internalNotes,
      preparedBy: preparedBy ?? this.preparedBy,
      approvedBy: approvedBy ?? this.approvedBy,
      receivedBy: receivedBy ?? this.receivedBy,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      invoiceFullNumber: invoiceFullNumber ?? this.invoiceFullNumber,
      productionOrderCode: productionOrderCode ?? this.productionOrderCode,
    );
  }

  factory ShipmentOrder.fromJson(
    Map<String, dynamic> json, {
    List<ShipmentOrderItem> items = const [],
  }) {
    // Relaciones opcionales
    final invoice = json['invoices'] as Map<String, dynamic>?;
    final po = json['production_orders'] as Map<String, dynamic>?;

    String? invoiceNumber;
    if (invoice != null) {
      final series = invoice['series'] ?? '';
      final number = invoice['number'] ?? '';
      invoiceNumber = '$series-$number';
    }

    return ShipmentOrder(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      invoiceId: json['invoice_id']?.toString(),
      productionOrderId: json['production_order_id']?.toString(),
      customerId: json['customer_id']?.toString(),
      customerName: (json['customer_name'] ?? '').toString(),
      customerAddress: json['customer_address']?.toString(),
      carrierName: json['carrier_name']?.toString(),
      carrierDocument: json['carrier_document']?.toString(),
      vehiclePlate: json['vehicle_plate']?.toString(),
      driverName: json['driver_name']?.toString(),
      driverDocument: json['driver_document']?.toString(),
      dispatchDate: json['dispatch_date'] != null
          ? DateTime.parse(json['dispatch_date'].toString())
          : DateTime.now(),
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'].toString())
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'].toString())
          : null,
      status: _parseStatus(json['status']),
      notes: json['notes']?.toString(),
      internalNotes: json['internal_notes']?.toString(),
      preparedBy: json['prepared_by']?.toString(),
      approvedBy: json['approved_by']?.toString(),
      receivedBy: json['received_by']?.toString(),
      items: items,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      invoiceFullNumber: invoiceNumber,
      productionOrderCode: po?['code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'invoice_id': invoiceId,
      'production_order_id': productionOrderId,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_address': customerAddress,
      'carrier_name': carrierName,
      'carrier_document': carrierDocument,
      'vehicle_plate': vehiclePlate,
      'driver_name': driverName,
      'driver_document': driverDocument,
      'dispatch_date': dispatchDate.toIso8601String().split('T')[0],
      'delivery_date': deliveryDate?.toIso8601String().split('T')[0],
      'delivered_at': deliveredAt?.toIso8601String(),
      'status': statusToString(status),
      'notes': notes,
      'internal_notes': internalNotes,
      'prepared_by': preparedBy,
      'approved_by': approvedBy,
      'received_by': receivedBy,
    };
  }

  static ShipmentStatus _parseStatus(String? value) {
    switch (value) {
      case 'borrador':
        return ShipmentStatus.borrador;
      case 'despachada':
        return ShipmentStatus.despachada;
      case 'en_transito':
        return ShipmentStatus.enTransito;
      case 'entregada':
        return ShipmentStatus.entregada;
      case 'anulada':
        return ShipmentStatus.anulada;
      default:
        return ShipmentStatus.borrador;
    }
  }

  static String statusToString(ShipmentStatus status) {
    switch (status) {
      case ShipmentStatus.borrador:
        return 'borrador';
      case ShipmentStatus.despachada:
        return 'despachada';
      case ShipmentStatus.enTransito:
        return 'en_transito';
      case ShipmentStatus.entregada:
        return 'entregada';
      case ShipmentStatus.anulada:
        return 'anulada';
    }
  }
}

class ShipmentOrderItem {
  final String id;
  final String shipmentOrderId;
  final ShipmentItemType itemType;
  final String? productId;
  final String? materialId;
  final String description;
  final String? code;
  final double quantity;
  final String unit;
  final double? weightKg;
  final String? dimensions;
  final String? notes;
  final int sequenceOrder;

  const ShipmentOrderItem({
    required this.id,
    required this.shipmentOrderId,
    required this.itemType,
    this.productId,
    this.materialId,
    required this.description,
    this.code,
    required this.quantity,
    this.unit = 'UND',
    this.weightKg,
    this.dimensions,
    this.notes,
    this.sequenceOrder = 0,
  });

  String get itemTypeLabel {
    switch (itemType) {
      case ShipmentItemType.producto:
        return 'Producto';
      case ShipmentItemType.material:
        return 'Material';
      case ShipmentItemType.pieza:
        return 'Pieza';
      case ShipmentItemType.herramienta:
        return 'Herramienta';
      case ShipmentItemType.otro:
        return 'Otro';
    }
  }

  ShipmentOrderItem copyWith({
    String? id,
    String? shipmentOrderId,
    ShipmentItemType? itemType,
    String? productId,
    String? materialId,
    String? description,
    String? code,
    double? quantity,
    String? unit,
    double? weightKg,
    String? dimensions,
    String? notes,
    int? sequenceOrder,
  }) {
    return ShipmentOrderItem(
      id: id ?? this.id,
      shipmentOrderId: shipmentOrderId ?? this.shipmentOrderId,
      itemType: itemType ?? this.itemType,
      productId: productId ?? this.productId,
      materialId: materialId ?? this.materialId,
      description: description ?? this.description,
      code: code ?? this.code,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      weightKg: weightKg ?? this.weightKg,
      dimensions: dimensions ?? this.dimensions,
      notes: notes ?? this.notes,
      sequenceOrder: sequenceOrder ?? this.sequenceOrder,
    );
  }

  factory ShipmentOrderItem.fromJson(Map<String, dynamic> json) {
    return ShipmentOrderItem(
      id: (json['id'] ?? '').toString(),
      shipmentOrderId: (json['shipment_order_id'] ?? '').toString(),
      itemType: _parseItemType(json['item_type']),
      productId: json['product_id']?.toString(),
      materialId: json['material_id']?.toString(),
      description: (json['description'] ?? '').toString(),
      code: json['code']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: (json['unit'] ?? 'UND').toString(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      dimensions: json['dimensions']?.toString(),
      notes: json['notes']?.toString(),
      sequenceOrder: (json['sequence_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shipment_order_id': shipmentOrderId,
      'item_type': _itemTypeToString(itemType),
      'product_id': productId,
      'material_id': materialId,
      'description': description,
      'code': code,
      'quantity': quantity,
      'unit': unit,
      'weight_kg': weightKg,
      'dimensions': dimensions,
      'notes': notes,
      'sequence_order': sequenceOrder,
    };
  }

  static ShipmentItemType _parseItemType(String? value) {
    switch (value) {
      case 'producto':
        return ShipmentItemType.producto;
      case 'material':
        return ShipmentItemType.material;
      case 'pieza':
        return ShipmentItemType.pieza;
      case 'herramienta':
        return ShipmentItemType.herramienta;
      case 'otro':
        return ShipmentItemType.otro;
      default:
        return ShipmentItemType.producto;
    }
  }

  static String _itemTypeToString(ShipmentItemType type) {
    switch (type) {
      case ShipmentItemType.producto:
        return 'producto';
      case ShipmentItemType.material:
        return 'material';
      case ShipmentItemType.pieza:
        return 'pieza';
      case ShipmentItemType.herramienta:
        return 'herramienta';
      case ShipmentItemType.otro:
        return 'otro';
    }
  }
}

/// Entrega futura: OP vinculada a factura con delivery_date
class FutureDelivery {
  final String productionOrderId;
  final String productionOrderCode;
  final String productName;
  final String productionStatus;
  final double quantity;
  final DateTime? productionDueDate;
  final String invoiceId;
  final String invoiceNumber;
  final String customerName;
  final DateTime? deliveryDate;
  final double invoiceTotal;
  final double invoicePaid;
  final int completedStages;
  final int totalStages;

  const FutureDelivery({
    required this.productionOrderId,
    required this.productionOrderCode,
    required this.productName,
    required this.productionStatus,
    required this.quantity,
    this.productionDueDate,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.customerName,
    this.deliveryDate,
    required this.invoiceTotal,
    required this.invoicePaid,
    required this.completedStages,
    required this.totalStages,
  });

  double get progress => totalStages > 0 ? completedStages / totalStages : 0.0;

  bool get isCompleted => productionStatus == 'completada';

  bool get isOverdue =>
      deliveryDate != null &&
      deliveryDate!.isBefore(DateTime.now()) &&
      !isCompleted;

  String get currentStageName {
    if (isCompleted) return 'Completada';
    return 'En proceso';
  }

  factory FutureDelivery.fromJson(Map<String, dynamic> json) {
    return FutureDelivery(
      productionOrderId: (json['id'] ?? '').toString(),
      productionOrderCode: (json['code'] ?? '').toString(),
      productName: (json['product_name'] ?? '').toString(),
      productionStatus: (json['status'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      productionDueDate: json['production_due_date'] != null
          ? DateTime.parse(json['production_due_date'].toString())
          : null,
      invoiceId: (json['invoice_id'] ?? '').toString(),
      invoiceNumber: (json['invoice_number'] ?? '').toString(),
      customerName: (json['customer_name'] ?? '').toString(),
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'].toString())
          : null,
      invoiceTotal: (json['total'] as num?)?.toDouble() ?? 0,
      invoicePaid: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      completedStages: (json['completed_stages'] as num?)?.toInt() ?? 0,
      totalStages: (json['total_stages'] as num?)?.toInt() ?? 0,
    );
  }
}
