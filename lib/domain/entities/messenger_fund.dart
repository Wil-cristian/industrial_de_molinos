import '../../core/utils/colombia_time.dart';

// ignore_for_file: constant_identifier_names

/// Estado del fondo de mensajería.
enum MessengerFundStatus { abierto, parcial, legalizado, cancelado }

/// Tipo de item de legalización.
enum FundItemType { compra, pago_factura, gasto, devolucion }

/// Fondo entregado a un mensajero para pagos y compras.
class MessengerFund {
  final String id;
  final String employeeId;
  final String employeeName;
  final double amountGiven;
  final double amountSpent;
  final double amountReturned;
  final String accountId;
  final String? cashMovementId;
  final MessengerFundStatus status;
  final DateTime dateGiven;
  final DateTime? dateLegalized;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MessengerFundItem> items;

  MessengerFund({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.amountGiven,
    this.amountSpent = 0,
    this.amountReturned = 0,
    required this.accountId,
    this.cashMovementId,
    this.status = MessengerFundStatus.abierto,
    required this.dateGiven,
    this.dateLegalized,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.items = const [],
  })  : createdAt = createdAt ?? ColombiaTime.now(),
        updatedAt = updatedAt ?? ColombiaTime.now();

  double get remainingBalance => amountGiven - amountSpent - amountReturned;
  double get progress => amountGiven > 0 ? (amountSpent + amountReturned) / amountGiven : 0;
  bool get isOpen => status == MessengerFundStatus.abierto || status == MessengerFundStatus.parcial;

  String get statusLabel {
    switch (status) {
      case MessengerFundStatus.abierto:
        return 'Abierto';
      case MessengerFundStatus.parcial:
        return 'Parcial';
      case MessengerFundStatus.legalizado:
        return 'Legalizado';
      case MessengerFundStatus.cancelado:
        return 'Cancelado';
    }
  }

  factory MessengerFund.fromJson(Map<String, dynamic> json) {
    return MessengerFund(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      employeeName: json['employee_name'] ?? '',
      amountGiven: (json['amount_given'] ?? 0).toDouble(),
      amountSpent: (json['amount_spent'] ?? 0).toDouble(),
      amountReturned: (json['amount_returned'] ?? 0).toDouble(),
      accountId: json['account_id'] ?? '',
      cashMovementId: json['cash_movement_id'],
      status: _parseStatus(json['status']),
      dateGiven: json['date_given'] != null
          ? DateTime.parse(json['date_given'])
          : ColombiaTime.now(),
      dateLegalized: json['date_legalized'] != null
          ? DateTime.parse(json['date_legalized'])
          : null,
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : ColombiaTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : ColombiaTime.now(),
      items: json['messenger_fund_items'] != null
          ? (json['messenger_fund_items'] as List)
                .map((e) => MessengerFundItem.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'amount_given': amountGiven,
      'amount_spent': amountSpent,
      'amount_returned': amountReturned,
      'account_id': accountId,
      'cash_movement_id': cashMovementId,
      'status': status.name,
      'date_given': ColombiaTime.toIso8601(dateGiven),
      'date_legalized': dateLegalized != null ? ColombiaTime.toIso8601(dateLegalized!) : null,
      'notes': notes,
    };
  }

  static MessengerFundStatus _parseStatus(String? value) {
    switch (value) {
      case 'abierto':
        return MessengerFundStatus.abierto;
      case 'parcial':
        return MessengerFundStatus.parcial;
      case 'legalizado':
        return MessengerFundStatus.legalizado;
      case 'cancelado':
        return MessengerFundStatus.cancelado;
      default:
        return MessengerFundStatus.abierto;
    }
  }
}

/// Item de legalización dentro de un fondo de mensajería.
class MessengerFundItem {
  final String id;
  final String fundId;
  final FundItemType itemType;
  final double amount;
  final String description;
  final String? reference;
  final String? category;
  final String? purchaseOrderId;
  final String? invoiceId;
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime createdAt;

  MessengerFundItem({
    required this.id,
    required this.fundId,
    required this.itemType,
    required this.amount,
    required this.description,
    this.reference,
    this.category,
    this.purchaseOrderId,
    this.invoiceId,
    this.attachmentUrl,
    this.attachmentName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? ColombiaTime.now();

  String get itemTypeLabel {
    switch (itemType) {
      case FundItemType.compra:
        return 'Compra';
      case FundItemType.pago_factura:
        return 'Pago Factura';
      case FundItemType.gasto:
        return 'Gasto';
      case FundItemType.devolucion:
        return 'Devolución';
    }
  }

  factory MessengerFundItem.fromJson(Map<String, dynamic> json) {
    return MessengerFundItem(
      id: json['id'] ?? '',
      fundId: json['fund_id'] ?? '',
      itemType: _parseItemType(json['item_type']),
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      reference: json['reference'],
      category: json['category'],
      purchaseOrderId: json['purchase_order_id'],
      invoiceId: json['invoice_id'],
      attachmentUrl: json['attachment_url'],
      attachmentName: json['attachment_name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : ColombiaTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fund_id': fundId,
      'item_type': itemType.name,
      'amount': amount,
      'description': description,
      'reference': reference,
      'category': category,
      'purchase_order_id': purchaseOrderId,
      'invoice_id': invoiceId,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
    };
  }

  static FundItemType _parseItemType(String? value) {
    switch (value) {
      case 'compra':
        return FundItemType.compra;
      case 'pago_factura':
        return FundItemType.pago_factura;
      case 'gasto':
        return FundItemType.gasto;
      case 'devolucion':
        return FundItemType.devolucion;
      default:
        return FundItemType.gasto;
    }
  }
}
