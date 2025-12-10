// Entidad: Factura/Comprobante
enum InvoiceType { invoice, receipt, creditNote, debitNote }
enum InvoiceStatus { draft, issued, paid, partial, cancelled, overdue }
enum PaymentMethod { cash, card, transfer, credit, check }

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
    required this.createdAt,
    required this.updatedAt,
  });

  // Número completo de factura
  String get fullNumber => '$series-$number';

  // Monto pendiente
  double get pendingAmount => total - paidAmount;

  // Está vencida
  bool get isOverdue => dueDate != null && 
      dueDate!.isBefore(DateTime.now()) && 
      status != InvoiceStatus.paid &&
      status != InvoiceStatus.cancelled;

  // Está pagada
  bool get isPaid => status == InvoiceStatus.paid;

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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? '',
      type: _parseInvoiceType(json['type']),
      series: json['series'] ?? '',
      number: json['number'] ?? '',
      customerId: json['customer_id'],
      customerName: json['customer_name'] ?? '',
      customerDocument: json['customer_document'] ?? '',
      issueDate: DateTime.parse(json['issue_date']),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
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
      items: [],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
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
      'issue_date': issueDate.toIso8601String().split('T')[0],
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'discount': discount,
      'total': total,
      'paid_amount': paidAmount,
      'status': status.name,
      'payment_method': paymentMethod?.name,
      'notes': notes,
    };
  }

  static InvoiceType _parseInvoiceType(String? value) {
    switch (value) {
      case 'invoice': return InvoiceType.invoice;
      case 'receipt': return InvoiceType.receipt;
      case 'credit_note': return InvoiceType.creditNote;
      case 'debit_note': return InvoiceType.debitNote;
      default: return InvoiceType.invoice;
    }
  }

  static InvoiceStatus _parseInvoiceStatus(String? value) {
    switch (value) {
      case 'draft': return InvoiceStatus.draft;
      case 'issued': return InvoiceStatus.issued;
      case 'paid': return InvoiceStatus.paid;
      case 'partial': return InvoiceStatus.partial;
      case 'cancelled': return InvoiceStatus.cancelled;
      case 'overdue': return InvoiceStatus.overdue;
      default: return InvoiceStatus.draft;
    }
  }

  static PaymentMethod _parsePaymentMethod(String? value) {
    switch (value) {
      case 'cash': return PaymentMethod.cash;
      case 'card': return PaymentMethod.card;
      case 'transfer': return PaymentMethod.transfer;
      case 'credit': return PaymentMethod.credit;
      case 'check': return PaymentMethod.check;
      default: return PaymentMethod.cash;
    }
  }
}

// Item de Factura
class InvoiceItem {
  final String id;
  final String invoiceId;
  final String? productId;
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

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    this.productId,
    required this.productName,
    this.productCode,
    this.description,
    required this.quantity,
    this.unit = 'UND',
    required this.unitPrice,
    this.discount = 0,
    this.taxRate = 18,
    required this.subtotal,
    this.taxAmount = 0,
    required this.total,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] ?? '',
      invoiceId: json['invoice_id'] ?? '',
      productId: json['product_id'],
      productName: json['product_name'] ?? '',
      productCode: json['product_code'],
      description: json['description'],
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] ?? 'UND',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 18,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
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
    };
  }
}

// Pago
class Payment {
  final String id;
  final String invoiceId;
  final double amount;
  final PaymentMethod method;
  final String? reference;
  final String? notes;
  final DateTime paymentDate;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.invoiceId,
    required this.amount,
    required this.method,
    this.reference,
    this.notes,
    required this.paymentDate,
    required this.createdAt,
  });
}
