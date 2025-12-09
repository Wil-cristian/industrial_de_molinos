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
}

// Item de Factura
class InvoiceItem {
  final String id;
  final String invoiceId;
  final String? productId;
  final String productName;
  final String? productCode;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double taxRate;
  final double subtotal;
  final double total;

  InvoiceItem({
    required this.id,
    required this.invoiceId,
    this.productId,
    required this.productName,
    this.productCode,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0,
    this.taxRate = 18,
    required this.subtotal,
    required this.total,
  });
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
