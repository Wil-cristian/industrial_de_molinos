import 'package:flutter/material.dart';

enum ConversationType {
  transferApproval,
  purchaseApproval,
  expenseApproval,
  general,
  aiChat,
  group,
}

enum ConversationStatus {
  open,
  pending,
  approved,
  rejected,
  closed,
}

class Conversation {
  final String id;
  final String title;
  final ConversationType type;
  final ConversationStatus status;
  final String createdBy;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final Map<String, dynamic> metadata;

  // Campos de la vista v_chat_conversations
  final String? creatorName;
  final String? creatorRole;
  final String? assignedName;
  final String? assignedRole;
  final String? otherParticipantName;
  final String? otherParticipantRole;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String? approvalId;
  final String? requestType;
  final String? approvalStatus;
  final Map<String, dynamic>? requestData;
  final int participantCount;

  const Conversation({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.createdBy,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.metadata = const {},
    this.creatorName,
    this.creatorRole,
    this.assignedName,
    this.assignedRole,
    this.otherParticipantName,
    this.otherParticipantRole,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.approvalId,
    this.requestType,
    this.approvalStatus,
    this.requestData,
    this.participantCount = 0,
  });

  bool get isPending => status == ConversationStatus.pending;
  bool get isApproved => status == ConversationStatus.approved;
  bool get isRejected => status == ConversationStatus.rejected;
  bool get isAiChat => type == ConversationType.aiChat;
  bool get isGroup => type == ConversationType.group;

  IconData get typeIcon {
    switch (type) {
      case ConversationType.transferApproval:
        return _transferIcon;
      case ConversationType.purchaseApproval:
        return _purchaseIcon;
      case ConversationType.expenseApproval:
        return _expenseIcon;
      case ConversationType.aiChat:
        return _aiIcon;
      case ConversationType.group:
        return _groupIcon;
      case ConversationType.general:
        return _generalIcon;
    }
  }

  String get typeLabel {
    switch (type) {
      case ConversationType.transferApproval:
        return 'Traslado';
      case ConversationType.purchaseApproval:
        return 'Compra de Materiales';
      case ConversationType.expenseApproval:
        return 'Gasto';
      case ConversationType.aiChat:
        return 'Asistente IA';
      case ConversationType.group:
        return 'Grupo';
      case ConversationType.general:
        return 'General';
    }
  }

  String get statusLabel {
    switch (status) {
      case ConversationStatus.open:
        return 'Abierto';
      case ConversationStatus.pending:
        return 'Pendiente';
      case ConversationStatus.approved:
        return 'Aprobado';
      case ConversationStatus.rejected:
        return 'Rechazado';
      case ConversationStatus.closed:
        return 'Cerrado';
    }
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    final rawRequestData = json['request_data'];

    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      type: _parseType(json['type'] as String),
      status: _parseStatus(json['status'] as String),
      createdBy: json['created_by'] as String,
      assignedTo: json['assigned_to'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      metadata: rawMetadata is Map ? Map<String, dynamic>.from(rawMetadata) : const {},
      creatorName: json['creator_name'] as String?,
      creatorRole: json['creator_role'] as String?,
      assignedName: json['assigned_name'] as String?,
      assignedRole: json['assigned_role'] as String?,
      otherParticipantName: json['other_participant_name'] as String?,
      otherParticipantRole: json['other_participant_role'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: (json['unread_count'] as int?) ?? 0,
      approvalId: json['approval_id'] as String?,
      requestType: json['request_type'] as String?,
      approvalStatus: json['approval_status'] as String?,
      requestData: rawRequestData is Map ? Map<String, dynamic>.from(rawRequestData) : null,
      participantCount: (json['participant_count'] as int?) ?? 0,
    );
  }

  static ConversationType _parseType(String value) {
    switch (value) {
      case 'transfer_approval':
        return ConversationType.transferApproval;
      case 'purchase_approval':
        return ConversationType.purchaseApproval;
      case 'expense_approval':
        return ConversationType.expenseApproval;
      case 'ai_chat':
        return ConversationType.aiChat;
      case 'group':
        return ConversationType.group;
      default:
        return ConversationType.general;
    }
  }

  static String typeToString(ConversationType type) {
    switch (type) {
      case ConversationType.transferApproval:
        return 'transfer_approval';
      case ConversationType.purchaseApproval:
        return 'purchase_approval';
      case ConversationType.expenseApproval:
        return 'expense_approval';
      case ConversationType.aiChat:
        return 'ai_chat';
      case ConversationType.group:
        return 'group';
      case ConversationType.general:
        return 'general';
    }
  }

  static ConversationStatus _parseStatus(String value) {
    switch (value) {
      case 'open':
        return ConversationStatus.open;
      case 'pending':
        return ConversationStatus.pending;
      case 'approved':
        return ConversationStatus.approved;
      case 'rejected':
        return ConversationStatus.rejected;
      case 'closed':
        return ConversationStatus.closed;
      default:
        return ConversationStatus.open;
    }
  }
}

const IconData _transferIcon = Icons.swap_horiz_rounded;
const IconData _purchaseIcon = Icons.shopping_cart_rounded;
const IconData _expenseIcon = Icons.receipt_long_rounded;
const IconData _generalIcon = Icons.chat_bubble_outline_rounded;
const IconData _aiIcon = Icons.auto_awesome_rounded;
const IconData _groupIcon = Icons.groups_rounded;
