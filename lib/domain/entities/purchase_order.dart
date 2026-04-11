import '../../core/utils/colombia_time.dart';
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

  // Campos de factura de proveedor (migración 053)
  final String? supplierInvoiceNumber; // Ej: "FE 4196"
  final DateTime? supplierInvoiceDate;
  final String? cufe; // Código Único Facturación Electrónica DIAN
  final double taxRate; // Tasa IVA general (19%, 5%, 0%)
  final double retentionRteFte; // Retención en la Fuente
  final double retentionIca; // Retención ICA
  final double retentionIva; // ReteIVA
  final double freightAmount; // Fletes
  final List<Map<String, dynamic>> attachments; // Archivos adjuntos
  final String? ivaInvoiceId; // Vínculo con iva_invoices
  final int creditDays; // Días de crédito
  final DateTime? dueDate; // Fecha de vencimiento

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
    this.supplierInvoiceNumber,
    this.supplierInvoiceDate,
    this.cufe,
    this.taxRate = 19.00,
    this.retentionRteFte = 0,
    this.retentionIca = 0,
    this.retentionIva = 0,
    this.freightAmount = 0,
    this.attachments = const [],
    this.ivaInvoiceId,
    this.creditDays = 0,
    this.dueDate,
    this.supplierName,
    this.items = const [],
  });

  double get balance => total - amountPaid;
  bool get isFullyPaid => amountPaid >= total;
  int get itemCount => items.length;
  double get totalRetentions => retentionRteFte + retentionIca + retentionIva;
  bool get hasInvoice =>
      supplierInvoiceNumber != null && supplierInvoiceNumber!.isNotEmpty;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get isOverdue =>
      dueDate != null && ColombiaTime.now().isAfter(dueDate!) && !isFullyPaid;

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
    String? supplierInvoiceNumber,
    DateTime? supplierInvoiceDate,
    String? cufe,
    double? taxRate,
    double? retentionRteFte,
    double? retentionIca,
    double? retentionIva,
    double? freightAmount,
    List<Map<String, dynamic>>? attachments,
    String? ivaInvoiceId,
    int? creditDays,
    DateTime? dueDate,
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
      supplierInvoiceNumber:
          supplierInvoiceNumber ?? this.supplierInvoiceNumber,
      supplierInvoiceDate: supplierInvoiceDate ?? this.supplierInvoiceDate,
      cufe: cufe ?? this.cufe,
      taxRate: taxRate ?? this.taxRate,
      retentionRteFte: retentionRteFte ?? this.retentionRteFte,
      retentionIca: retentionIca ?? this.retentionIca,
      retentionIva: retentionIva ?? this.retentionIva,
      freightAmount: freightAmount ?? this.freightAmount,
      attachments: attachments ?? this.attachments,
      ivaInvoiceId: ivaInvoiceId ?? this.ivaInvoiceId,
      creditDays: creditDays ?? this.creditDays,
      dueDate: dueDate ?? this.dueDate,
      supplierName: supplierName ?? this.supplierName,
      items: items ?? this.items,
    );
  }

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) {
    // Parsear attachments JSONB
    List<Map<String, dynamic>> parseAttachments(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .toList();
      }
      return [];
    }

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
      // Nuevos campos de factura (migración 053)
      supplierInvoiceNumber: json['supplier_invoice_number'] as String?,
      supplierInvoiceDate: json['supplier_invoice_date'] != null
          ? DateTime.parse(json['supplier_invoice_date'] as String)
          : null,
      cufe: json['cufe'] as String?,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 19.00,
      retentionRteFte: (json['retention_rte_fte'] as num?)?.toDouble() ?? 0,
      retentionIca: (json['retention_ica'] as num?)?.toDouble() ?? 0,
      retentionIva: (json['retention_iva'] as num?)?.toDouble() ?? 0,
      freightAmount: (json['freight_amount'] as num?)?.toDouble() ?? 0,
      attachments: parseAttachments(json['attachments']),
      ivaInvoiceId: json['iva_invoice_id'] as String?,
      creditDays: (json['credit_days'] as num?)?.toInt() ?? 0,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
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
      'expected_date': expectedDate != null
          ? ColombiaTime.dateString(expectedDate!)
          : null,
      'created_by': createdBy,
      // Campos de factura (migración 053)
      'supplier_invoice_number': supplierInvoiceNumber,
      'supplier_invoice_date': supplierInvoiceDate != null
          ? ColombiaTime.dateString(supplierInvoiceDate!)
          : null,
      'cufe': cufe,
      'tax_rate': taxRate,
      'retention_rte_fte': retentionRteFte,
      'retention_ica': retentionIca,
      'retention_iva': retentionIva,
      'freight_amount': freightAmount,
      'attachments': attachments,
      'iva_invoice_id': ivaInvoiceId,
      'credit_days': creditDays,
      'due_date': dueDate != null ? ColombiaTime.dateString(dueDate!) : null,
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

  // Campos de factura por ítem (migración 053)
  final double taxRate; // IVA por ítem (19%, 5%, 0%)
  final double taxAmount; // Monto IVA del ítem
  final double discount; // Descuento por ítem
  final String? referenceCode; // Código del proveedor (ej: "BALLDIA1.5")
  final String? description; // Descripción libre
  final double itemTotal; // Total con IVA

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
    this.taxRate = 19.00,
    this.taxAmount = 0,
    this.discount = 0,
    this.referenceCode,
    this.description,
    this.itemTotal = 0,
    this.materialName,
    this.materialCode,
  });

  bool get isFullyReceived => quantityReceived >= quantity;
  double get pendingQuantity => quantity - quantityReceived;
  double get calculatedSubtotal => quantity * unitPrice;
  double get calculatedTax => (calculatedSubtotal - discount) * (taxRate / 100);
  double get calculatedTotal => calculatedSubtotal - discount + calculatedTax;

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
    double? taxRate,
    double? taxAmount,
    double? discount,
    String? referenceCode,
    String? description,
    double? itemTotal,
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
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      discount: discount ?? this.discount,
      referenceCode: referenceCode ?? this.referenceCode,
      description: description ?? this.description,
      itemTotal: itemTotal ?? this.itemTotal,
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
      // Campos de factura (migración 053)
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 19.00,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      referenceCode: json['reference_code'] as String?,
      description: json['description'] as String?,
      itemTotal: (json['total'] as num?)?.toDouble() ?? 0,
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
      // Campos de factura (migración 053)
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'discount': discount,
      'reference_code': referenceCode,
      'description': description,
      'total': itemTotal,
    };
  }
}
