import '../../core/utils/colombia_time.dart';
// Entidad: Factura/Comprobante
enum InvoiceType { invoice, receipt, creditNote, debitNote }

enum InvoiceStatus { draft, issued, paid, partial, cancelled, overdue }

enum PaymentMethod { cash, card, transfer, credit, check, yape, plin }

class Invoice {
  final String id;
  final InvoiceType type;
  final String series;
  final String number;
  final String? customerId;
  final String customerName;
  final String customerDocument;
  final DateTime issueDate;
  final DateTime? dueDate;
  final double subtotal;
  final double taxAmount;
  final double discount;
  final double total;
  final double paidAmount;
  final InvoiceStatus status;
  final PaymentMethod? paymentMethod;
  final String? notes;
  final List<InvoiceItem> items;
  final double materialCostTotal;
  final double materialCostPending;
  final DateTime? deliveryDate;
  final String salePaymentType; // cash, credit, advance
  final int creditDays; // Días de crédito desde entrega
  final double laborCost;
  final String? sellerId;
  final String? sellerName;
  final bool hasCommission;
  final double commissionPercentage;
  final double commissionAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Invoice({
    required this.id,
    required this.type,
    required this.series,
    required this.number,
    this.customerId,
    required this.customerName,
    required this.customerDocument,
    required this.issueDate,
    this.dueDate,
    required this.subtotal,
    required this.taxAmount,
    this.discount = 0,
    required this.total,
    this.paidAmount = 0,
    this.status = InvoiceStatus.draft,
    this.paymentMethod,
    this.notes,
    this.items = const [],
    this.materialCostTotal = 0,
    this.materialCostPending = 0,
    this.deliveryDate,
    this.salePaymentType = 'cash',
    this.creditDays = 0,
    this.laborCost = 0,
    this.sellerId,
    this.sellerName,
    this.hasCommission = false,
    this.commissionPercentage = 0,
    this.commissionAmount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // Número completo de factura
  String get fullNumber => '$series-$number';

  // Monto pendiente
  double get pendingAmount => total - paidAmount;

  // Está vencida
  bool get isOverdue =>
      dueDate != null &&
      dueDate!.isBefore(ColombiaTime.now()) &&
      status != InvoiceStatus.paid &&
      status != InvoiceStatus.cancelled;

  // Está pagada
  bool get isPaid => status == InvoiceStatus.paid;

  // Es adelanto sin entregar (no es deuda, es adelanto de trabajo)
  bool get isAdvanceNotDelivered =>
      salePaymentType == 'advance' && deliveryDate == null;

  // Es adelanto ya entregado (ahora sí es deuda si tiene pendiente)
  bool get isAdvanceDelivered =>
      salePaymentType == 'advance' && deliveryDate != null;

  Invoice copyWith({
    String? id,
    InvoiceType? type,
    String? series,
    String? number,
    String? customerId,
    String? customerName,
    String? customerDocument,
    DateTime? issueDate,
    DateTime? dueDate,
    double? subtotal,
    double? taxAmount,
    double? discount,
    double? total,
    double? paidAmount,
    InvoiceStatus? status,
    PaymentMethod? paymentMethod,
    String? notes,
    List<InvoiceItem>? items,
    double? materialCostTotal,
    double? materialCostPending,
    DateTime? deliveryDate,
    String? salePaymentType,
    int? creditDays,
    double? laborCost,
    String? sellerId,
    String? sellerName,
    bool? hasCommission,
    double? commissionPercentage,
    double? commissionAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      type: type ?? this.type,
      series: series ?? this.series,
      number: number ?? this.number,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerDocument: customerDocument ?? this.customerDocument,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      materialCostTotal: materialCostTotal ?? this.materialCostTotal,
      materialCostPending: materialCostPending ?? this.materialCostPending,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      salePaymentType: salePaymentType ?? this.salePaymentType,
      creditDays: creditDays ?? this.creditDays,
      laborCost: laborCost ?? this.laborCost,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      hasCommission: hasCommission ?? this.hasCommission,
      commissionPercentage: commissionPercentage ?? this.commissionPercentage,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    // Parsear items si vienen incluidos en el JSON
    final itemsList = json['invoice_items'] ?? json['items'];
    List<InvoiceItem> parsedItems = [];
    if (itemsList != null && itemsList is List) {
      parsedItems = itemsList
          .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Invoice(
      id: json['id'] ?? '',
      type: _parseInvoiceType(json['type']),
      series: json['series'] ?? '',
      number: json['number'] ?? '',
      customerId: json['customer_id'],
      customerName: json['customer_name'] ?? '',
      customerDocument: json['customer_document'] ?? '',
      issueDate: DateTime.parse(json['issue_date']),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      status: _parseInvoiceStatus(json['status']),
      paymentMethod: json['payment_method'] != null
          ? _parsePaymentMethod(json['payment_method'])
          : null,
      notes: json['notes'],
      items: parsedItems,
      materialCostTotal: (json['material_cost_total'] as num?)?.toDouble() ?? 0,
      materialCostPending:
          (json['material_cost_pending'] as num?)?.toDouble() ?? 0,
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'])
          : null,
      salePaymentType: json['sale_payment_type'] ?? 'cash',
      creditDays: (json['credit_days'] as num?)?.toInt() ?? 0,
      laborCost: (json['labor_cost'] as num?)?.toDouble() ?? 0,
      sellerId: json['seller_id'],
      sellerName: json['seller_name'],
      hasCommission: json['has_commission'] ?? false,
      commissionPercentage:
          (json['commission_percentage'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? ColombiaTime.nowIso8601(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? ColombiaTime.nowIso8601(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'series': series,
      'number': number,
      'customer_id': customerId,
      'customer_name': customerName,
      'customer_document': customerDocument,
      'issue_date': ColombiaTime.dateString(issueDate),
      'due_date': (dueDate != null ? ColombiaTime.dateString(dueDate!) : null),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'discount': discount,
      'total': total,
      'paid_amount': paidAmount,
      'status': status.name,
      'payment_method': paymentMethod?.name,
      'notes': notes,
      'material_cost_total': materialCostTotal,
      'material_cost_pending': materialCostPending,
      'delivery_date': (deliveryDate != null ? ColombiaTime.dateString(deliveryDate!) : null),
      'sale_payment_type': salePaymentType,
      'credit_days': creditDays,
      'labor_cost': laborCost,
      'seller_id': sellerId,
      'has_commission': hasCommission,
      'commission_percentage': commissionPercentage,
      'commission_amount': commissionAmount,
    };
  }

  static InvoiceType _parseInvoiceType(String? value) {
    switch (value) {
      case 'invoice':
        return InvoiceType.invoice;
      case 'receipt':
        return InvoiceType.receipt;
      case 'credit_note':
        return InvoiceType.creditNote;
      case 'debit_note':
        return InvoiceType.debitNote;
      default:
        return InvoiceType.invoice;
    }
  }

  static InvoiceStatus _parseInvoiceStatus(String? value) {
    switch (value) {
      case 'draft':
        return InvoiceStatus.draft;
      case 'issued':
        return InvoiceStatus.issued;
      case 'paid':
        return InvoiceStatus.paid;
      case 'partial':
        return InvoiceStatus.partial;
      case 'cancelled':
        return InvoiceStatus.cancelled;
      case 'overdue':
        return InvoiceStatus.overdue;
      default:
        return InvoiceStatus.draft;
    }
  }

  static PaymentMethod _parsePaymentMethod(String? value) {
    switch (value) {
      case 'cash':
        return PaymentMethod.cash;
      case 'card':
        return PaymentMethod.card;
      case 'transfer':
        return PaymentMethod.transfer;
      case 'credit':
        return PaymentMethod.credit;
      case 'check':
        return PaymentMethod.check;
      case 'yape':
        return PaymentMethod.yape;
      case 'plin':
        return PaymentMethod.plin;
      default:
        return PaymentMethod.cash;
    }
  }
}

// Item de Factura
class InvoiceItem {
  final String id;
  final String invoiceId;
  final String? productId;
  final String? materialId;
  final String productName;
  final String? productCode;
  final String? description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discount;
  final double taxRate;
  final double subtotal;
  final double taxAmount;
  final double total;
  final double costPrice;

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    this.productId,
    this.materialId,
    required this.productName,
    this.productCode,
    this.description,
    required this.quantity,
    this.unit = 'UND',
    required this.unitPrice,
    this.discount = 0,
    this.taxRate = 0,
    required this.subtotal,
    this.taxAmount = 0,
    required this.total,
    this.costPrice = 0,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] ?? '',
      invoiceId: json['invoice_id'] ?? '',
      productId: json['product_id'],
      materialId: json['material_id'],
      productName: json['product_name'] ?? '',
      productCode: json['product_code'],
      description: json['description'],
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] ?? 'UND',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
    );
  }

  InvoiceItem copyWith({
    String? id,
    String? invoiceId,
    String? productId,
    String? materialId,
    String? productName,
    String? productCode,
    String? description,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? discount,
    double? taxRate,
    double? subtotal,
    double? taxAmount,
    double? total,
    double? costPrice,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      materialId: materialId ?? this.materialId,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      discount: discount ?? this.discount,
      taxRate: taxRate ?? this.taxRate,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      costPrice: costPrice ?? this.costPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'material_id': materialId,
      'product_name': productName,
      'product_code': productCode,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'discount': discount,
      'tax_rate': taxRate,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'cost_price': costPrice,
    };
  }
}
