enum MessageType {
  text,
  approvalRequest,
  approvalResponse,
  system,
  aiRequest,
  aiResponse,
}

class ConversationMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final MessageType messageType;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final bool isRead;

  // Campos extra del join
  final String? senderName;
  final String? senderRole;

  const ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.messageType,
    this.metadata = const {},
    required this.createdAt,
    this.isRead = false,
    this.senderName,
    this.senderRole,
  });

  bool get isSystem => messageType == MessageType.system || messageType == MessageType.approvalResponse;
  bool get isAi => messageType == MessageType.aiRequest || messageType == MessageType.aiResponse;

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return ConversationMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      messageType: _parseMessageType(json['message_type'] as String),
      metadata: rawMetadata is Map ? Map<String, dynamic>.from(rawMetadata) : const {},
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      senderName: json['sender_name'] as String?,
      senderRole: json['sender_role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'message_type': _messageTypeToString(messageType),
      'metadata': metadata,
    };
  }

  static MessageType _parseMessageType(String value) {
    switch (value) {
      case 'approval_request':
        return MessageType.approvalRequest;
      case 'approval_response':
        return MessageType.approvalResponse;
      case 'system':
        return MessageType.system;
      case 'ai_request':
        return MessageType.aiRequest;
      case 'ai_response':
        return MessageType.aiResponse;
      default:
        return MessageType.text;
    }
  }

  static String _messageTypeToString(MessageType type) {
    switch (type) {
      case MessageType.approvalRequest:
        return 'approval_request';
      case MessageType.approvalResponse:
        return 'approval_response';
      case MessageType.system:
        return 'system';
      case MessageType.aiRequest:
        return 'ai_request';
      case MessageType.aiResponse:
        return 'ai_response';
      case MessageType.text:
        return 'text';
    }
  }
}
