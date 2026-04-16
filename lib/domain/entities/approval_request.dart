enum ApprovalRequestType {
  transfer,
  materialPurchase,
  expense,
  general,
}

enum ApprovalStatus {
  pending,
  approved,
  rejected,
}

class ApprovalRequest {
  final String id;
  final String conversationId;
  final ApprovalRequestType requestType;
  final ApprovalStatus status;
  final String requestedBy;
  final String? resolvedBy;
  final Map<String, dynamic> requestData;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final String? notes;

  const ApprovalRequest({
    required this.id,
    required this.conversationId,
    required this.requestType,
    required this.status,
    required this.requestedBy,
    this.resolvedBy,
    required this.requestData,
    this.resolvedAt,
    required this.createdAt,
    this.notes,
  });

  bool get isPending => status == ApprovalStatus.pending;
  bool get isApproved => status == ApprovalStatus.approved;
  bool get isRejected => status == ApprovalStatus.rejected;

  // === Getters para datos de traslado ===
  String? get fromAccountName => requestData['from_account_name'] as String?;
  String? get toAccountName => requestData['to_account_name'] as String?;
  String? get fromAccountId => requestData['from_account_id'] as String?;
  String? get toAccountId => requestData['to_account_id'] as String?;
  double? get transferAmount => (requestData['amount'] as num?)?.toDouble();
  String? get reason => requestData['reason'] as String?;

  // === Getters para datos de compra ===
  List<Map<String, dynamic>> get materials {
    final list = requestData['materials'];
    if (list is List) return list.cast<Map<String, dynamic>>();
    return [];
  }
  String? get supplier => requestData['supplier'] as String?;
  double? get totalEstimated => (requestData['total_estimated'] as num?)?.toDouble();
  String? get urgency => requestData['urgency'] as String?;

  // === Getters para datos de gasto ===
  String? get description => requestData['description'] as String?;
  double? get expenseAmount => (requestData['amount'] as num?)?.toDouble();
  String? get category => requestData['category'] as String?;

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      requestType: _parseRequestType(json['request_type'] as String),
      status: _parseStatus(json['status'] as String),
      requestedBy: json['requested_by'] as String,
      resolvedBy: json['resolved_by'] as String?,
      requestData: (json['request_data'] as Map<String, dynamic>?) ?? {},
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      notes: json['notes'] as String?,
    );
  }

  static ApprovalRequestType _parseRequestType(String value) {
    switch (value) {
      case 'transfer':
        return ApprovalRequestType.transfer;
      case 'material_purchase':
        return ApprovalRequestType.materialPurchase;
      case 'expense':
        return ApprovalRequestType.expense;
      default:
        return ApprovalRequestType.general;
    }
  }

  static String requestTypeToString(ApprovalRequestType type) {
    switch (type) {
      case ApprovalRequestType.transfer:
        return 'transfer';
      case ApprovalRequestType.materialPurchase:
        return 'material_purchase';
      case ApprovalRequestType.expense:
        return 'expense';
      case ApprovalRequestType.general:
        return 'general';
    }
  }

  static ApprovalStatus _parseStatus(String value) {
    switch (value) {
      case 'approved':
        return ApprovalStatus.approved;
      case 'rejected':
        return ApprovalStatus.rejected;
      default:
        return ApprovalStatus.pending;
    }
  }
}
