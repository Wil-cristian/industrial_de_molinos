// Entidad: Orden de Compra

enum PurchaseOrderStatus {
  borrador,
  enviada,
  parcial,
  recibida,
  cancelada;

  String get display {
    switch (this) {
      case borrador:
        return 'Borrador';
      case enviada:
        return 'Enviada';
      case parcial:
        return 'Parcial';
      case recibida:
        return 'Recibida';
      case cancelada:
        return 'Cancelada';
    }
  }

  bool get isEditable => this == borrador;
  bool get canReceive => this == enviada || this == parcial;
}

enum PaymentStatus {
  pendiente,
  parcial,
  pagada;

  String get display {
    switch (this) {
      case pendiente:
        return 'Pendiente';
      case parcial:
        return 'Parcial';
      case pagada:
        return 'Pagada';
    }
  }
}

class PurchaseOrder {
  final String id;
  final String orderNumber;
  final String supplierId;
  final PurchaseOrderStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentMethod;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double total;
  final double amountPaid;
  final String? notes;
  final DateTime? expectedDate;
  final DateTime? receivedDate;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Datos de join
  final String? supplierName;
  final List<PurchaseOrderItem> items;

  PurchaseOrder({
    required this.id,
    required this.orderNumber,
    required this.supplierId,
    this.status = PurchaseOrderStatus.borrador,
    this.paymentStatus = PaymentStatus.pendiente,
    this.paymentMethod,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.total = 0,
    this.amountPaid = 0,
    this.notes,
    this.expectedDate,
    this.receivedDate,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.supplierName,
    this.items = const [],
  });

  double get balance => total - amountPaid;
  bool get isFullyPaid => amountPaid >= total;
  int get itemCount => items.length;

  PurchaseOrder copyWith({
    String? id,
    String? orderNumber,
    String? supplierId,
    PurchaseOrderStatus? status,
    PaymentStatus? paymentStatus,
    String? paymentMethod,
    double? subtotal,
    double? taxAmount,
    double? discountAmount,
    double? total,
    double? amountPaid,
    String? notes,
    DateTime? expectedDate,
    DateTime? receivedDate,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? supplierName,
    List<PurchaseOrderItem>? items,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      supplierId: supplierId ?? this.supplierId,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      total: total ?? this.total,
      amountPaid: amountPaid ?? this.amountPaid,
      notes: notes ?? this.notes,
      expectedDate: expectedDate ?? this.expectedDate,
      receivedDate: receivedDate ?? this.receivedDate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
    );
  }

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    return PurchaseOrder(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      supplierId: json['supplier_id'] as String,
      status: PurchaseOrderStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PurchaseOrderStatus.borrador,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == json['payment_status'],
        orElse: () => PaymentStatus.pendiente,
      ),
      paymentMethod: json['payment_method'] as String?,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      expectedDate: json['expected_date'] != null
          ? DateTime.parse(json['expected_date'] as String)
          : null,
      receivedDate: json['received_date'] != null
          ? DateTime.parse(json['received_date'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      supplierName: json['proveedores'] != null
          ? json['proveedores']['name'] as String?
          : null,
      items: json['purchase_order_items'] != null
          ? (json['purchase_order_items'] as List)
                .map(
                  (e) => PurchaseOrderItem.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_number': orderNumber,
      'supplier_id': supplierId,
      'status': status.name,
      'payment_status': paymentStatus.name,
      'payment_method': paymentMethod,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'amount_paid': amountPaid,
      'notes': notes,
      'expected_date': expectedDate?.toIso8601String().split('T').first,
      'created_by': createdBy,
    };
  }
}

class PurchaseOrderItem {
  final String id;
  final String orderId;
  final String materialId;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double subtotal;
  final double quantityReceived;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Datos de join
  final String? materialName;
  final String? materialCode;

  PurchaseOrderItem({
    required this.id,
    required this.orderId,
    required this.materialId,
    this.quantity = 1,
    this.unit = 'UND',
    this.unitPrice = 0,
    this.subtotal = 0,
    this.quantityReceived = 0,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.materialName,
    this.materialCode,
  });

  bool get isFullyReceived => quantityReceived >= quantity;
  double get pendingQuantity => quantity - quantityReceived;

  PurchaseOrderItem copyWith({
    String? id,
    String? orderId,
    String? materialId,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? subtotal,
    double? quantityReceived,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? materialName,
    String? materialCode,
  }) {
    return PurchaseOrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      materialId: materialId ?? this.materialId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      subtotal: subtotal ?? this.subtotal,
      quantityReceived: quantityReceived ?? this.quantityReceived,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      materialName: materialName ?? this.materialName,
      materialCode: materialCode ?? this.materialCode,
    );
  }

  factory PurchaseOrderItem.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      materialId: json['material_id'] as String,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit'] as String? ?? 'UND',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      quantityReceived: (json['quantity_received'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      materialName: json['materials'] != null
          ? json['materials']['name'] as String?
          : null,
      materialCode: json['materials'] != null
          ? json['materials']['code'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'material_id': materialId,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'subtotal': quantity * unitPrice,
      'quantity_received': quantityReceived,
      'notes': notes,
    };
  }
}
