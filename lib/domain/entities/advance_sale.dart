import '../../core/utils/colombia_time.dart';

enum AdvanceSaleStatus { pending, confirmed, cancelled }

class AdvanceSale {
  final String id;
  final String series;
  final String number;
  final String? customerId;
  final String customerName;
  final String description;
  final double estimatedTotal;
  final double? finalTotal;
  final double paidAmount;
  final AdvanceSaleStatus status;
  final String? notes;
  final String? invoiceId;
  final List<AdvanceSalePayment> payments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? confirmedAt;
  final String? createdBy;

  AdvanceSale({
    required this.id,
    this.series = 'ANT',
    required this.number,
    this.customerId,
    required this.customerName,
    required this.description,
    this.estimatedTotal = 0,
    this.finalTotal,
    this.paidAmount = 0,
    this.status = AdvanceSaleStatus.pending,
    this.notes,
    this.invoiceId,
    this.payments = const [],
    required this.createdAt,
    required this.updatedAt,
    this.confirmedAt,
    this.createdBy,
  });

  String get fullNumber => '$series-$number';

  double get pendingAmount {
    final total = finalTotal ?? estimatedTotal;
    return total - paidAmount;
  }

  double get effectiveTotal => finalTotal ?? estimatedTotal;

  bool get isPending => status == AdvanceSaleStatus.pending;
  bool get isConfirmed => status == AdvanceSaleStatus.confirmed;
  bool get isCancelled => status == AdvanceSaleStatus.cancelled;

  AdvanceSale copyWith({
    String? id,
    String? series,
    String? number,
    String? customerId,
    String? customerName,
    String? description,
    double? estimatedTotal,
    double? finalTotal,
    double? paidAmount,
    AdvanceSaleStatus? status,
    String? notes,
    String? invoiceId,
    List<AdvanceSalePayment>? payments,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? confirmedAt,
    String? createdBy,
  }) {
    return AdvanceSale(
      id: id ?? this.id,
      series: series ?? this.series,
      number: number ?? this.number,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      description: description ?? this.description,
      estimatedTotal: estimatedTotal ?? this.estimatedTotal,
      finalTotal: finalTotal ?? this.finalTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      payments: payments ?? this.payments,
      notes: notes ?? this.notes,
      invoiceId: invoiceId ?? this.invoiceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  factory AdvanceSale.fromJson(Map<String, dynamic> json) {
    final paymentsList = json['advance_sale_payments'] ?? json['payments'];
    List<AdvanceSalePayment> parsedPayments = [];
    if (paymentsList != null && paymentsList is List) {
      parsedPayments = paymentsList
          .map((e) => AdvanceSalePayment.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return AdvanceSale(
      id: json['id'] ?? '',
      series: json['series'] ?? 'ANT',
      number: json['number'] ?? '',
      customerId: json['customer_id'],
      customerName: json['customer_name'] ?? '',
      description: json['description'] ?? '',
      estimatedTotal: (json['estimated_total'] as num?)?.toDouble() ?? 0,
      finalTotal: (json['final_total'] as num?)?.toDouble(),
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      status: _parseStatus(json['status']),
      notes: json['notes'],
      invoiceId: json['invoice_id'],
      payments: parsedPayments,
      createdAt: DateTime.parse(
        json['created_at'] ?? ColombiaTime.nowIso8601(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? ColombiaTime.nowIso8601(),
      ),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'])
          : null,
      createdBy: json['created_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'series': series,
      'number': number,
      'customer_id': customerId,
      'customer_name': customerName,
      'description': description,
      'estimated_total': estimatedTotal,
      'final_total': finalTotal,
      'paid_amount': paidAmount,
      'status': status.name,
      'notes': notes,
      'invoice_id': invoiceId,
    };
  }

  static AdvanceSaleStatus _parseStatus(String? value) {
    switch (value) {
      case 'pending':
        return AdvanceSaleStatus.pending;
      case 'confirmed':
        return AdvanceSaleStatus.confirmed;
      case 'cancelled':
        return AdvanceSaleStatus.cancelled;
      default:
        return AdvanceSaleStatus.pending;
    }
  }
}

class AdvanceSalePayment {
  final String id;
  final String advanceSaleId;
  final double amount;
  final String method;
  final String? accountId;
  final String? accountName;
  final String? reference;
  final String? notes;
  final DateTime paymentDate;
  final DateTime createdAt;
  final String? createdBy;

  AdvanceSalePayment({
    required this.id,
    required this.advanceSaleId,
    required this.amount,
    this.method = 'cash',
    this.accountId,
    this.accountName,
    this.reference,
    this.notes,
    required this.paymentDate,
    required this.createdAt,
    this.createdBy,
  });

  factory AdvanceSalePayment.fromJson(Map<String, dynamic> json) {
    return AdvanceSalePayment(
      id: json['id'] ?? '',
      advanceSaleId: json['advance_sale_id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      method: json['method'] ?? 'cash',
      accountId: json['account_id'],
      accountName: json['account_name'],
      reference: json['reference'],
      notes: json['notes'],
      paymentDate: DateTime.parse(
        json['payment_date'] ?? ColombiaTime.todayString(),
      ),
      createdAt: DateTime.parse(
        json['created_at'] ?? ColombiaTime.nowIso8601(),
      ),
      createdBy: json['created_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'advance_sale_id': advanceSaleId,
      'amount': amount,
      'method': method,
      'account_id': accountId,
      'account_name': accountName,
      'reference': reference,
      'notes': notes,
      'payment_date': ColombiaTime.dateString(paymentDate),
    };
  }
}
