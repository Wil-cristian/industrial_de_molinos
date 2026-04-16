import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/conversation_message.dart';
import '../../domain/entities/approval_request.dart';
import '../datasources/chat_datasource.dart';
import '../datasources/ai_assistant_datasource.dart';
import '../datasources/ai_capabilities.dart';

// ===================== STATE =====================

class ChatState {
  final List<Conversation> conversations;
  final Conversation? selectedConversation;
  final List<ConversationMessage> messages;
  final ApprovalRequest? currentApproval;
  final bool isLoadingConversations;
  final bool isLoadingMessages;
  final bool isSending;
  final int pendingCount;
  final int unreadCount;
  final String? error;

  const ChatState({
    this.conversations = const [],
    this.selectedConversation,
    this.messages = const [],
    this.currentApproval,
    this.isLoadingConversations = false,
    this.isLoadingMessages = false,
    this.isSending = false,
    this.pendingCount = 0,
    this.unreadCount = 0,
    this.error,
  });

  ChatState copyWith({
    List<Conversation>? conversations,
    Conversation? selectedConversation,
    List<ConversationMessage>? messages,
    ApprovalRequest? currentApproval,
    bool? isLoadingConversations,
    bool? isLoadingMessages,
    bool? isSending,
    int? pendingCount,
    int? unreadCount,
    String? error,
    bool clearSelected = false,
    bool clearApproval = false,
    bool clearError = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      selectedConversation: clearSelected ? null : (selectedConversation ?? this.selectedConversation),
      messages: messages ?? this.messages,
      currentApproval: clearApproval ? null : (currentApproval ?? this.currentApproval),
      isLoadingConversations: isLoadingConversations ?? this.isLoadingConversations,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isSending: isSending ?? this.isSending,
      pendingCount: pendingCount ?? this.pendingCount,
      unreadCount: unreadCount ?? this.unreadCount,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Conversaciones filtradas por tipo
  List<Conversation> get pendingConversations =>
      conversations.where((c) => c.status == ConversationStatus.pending).toList();

  List<Conversation> get resolvedConversations =>
      conversations.where((c) => c.status == ConversationStatus.approved || c.status == ConversationStatus.rejected).toList();
}

// ===================== PROVIDERS =====================

/// Lightweight provider for badge count – auto-fetches pending approvals.
/// Invalidate after resolving an approval to refresh.
final chatPendingCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ChatDatasource.getPendingCount();
});

/// Provider para listar usuarios disponibles para chat
final chatUsersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ChatDatasource.getChatUsers();
});

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

class ChatNotifier extends Notifier<ChatState> {
  RealtimeChannel? _conversationsChannel;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _approvalsChannel;

  @override
  ChatState build() {
    ref.onDispose(_disposeChannels);
    return const ChatState();
  }

  void _disposeChannels() {
    if (_conversationsChannel != null) {
      ChatDatasource.unsubscribe(_conversationsChannel!);
      _conversationsChannel = null;
    }
    if (_messagesChannel != null) {
      ChatDatasource.unsubscribe(_messagesChannel!);
      _messagesChannel = null;
    }
    if (_approvalsChannel != null) {
      ChatDatasource.unsubscribe(_approvalsChannel!);
      _approvalsChannel = null;
    }
  }

  // ===================== CARGA INICIAL =====================

  Future<void> loadConversations() async {
    final selectedId = state.selectedConversation?.id;

    state = state.copyWith(isLoadingConversations: true, clearError: true);
    try {
      final conversations = await ChatDatasource.getConversations();
      final pendingCount = await ChatDatasource.getPendingCount();
      final unreadCount = await ChatDatasource.getUnreadCount();
      final updatedSelected = selectedId == null
          ? null
          : conversations.where((c) => c.id == selectedId).firstOrNull;

      state = state.copyWith(
        conversations: conversations,
        selectedConversation: updatedSelected,
        pendingCount: pendingCount,
        unreadCount: unreadCount,
        isLoadingConversations: false,
        clearSelected: selectedId != null && updatedSelected == null,
      );

      _subscribeToConversations();

      if (updatedSelected != null && state.messages.isEmpty) {
        await refreshSelectedConversation();
      }
    } catch (e) {
      AppLogger.error('Error cargando conversaciones', e);
      state = state.copyWith(
        isLoadingConversations: false,
        error: 'Error cargando conversaciones',
      );
    }
  }

  // ===================== SELECCIÓN =====================

  Future<void> selectConversation(Conversation conversation) async {
    state = state.copyWith(
      selectedConversation: conversation,
      isLoadingMessages: true,
      messages: [],
      clearApproval: true,
    );

    // Cargar mensajes
    final messages = await ChatDatasource.getMessages(conversation.id);

    // Cargar solicitud de aprobación si aplica
    ApprovalRequest? approval;
    if (conversation.type != ConversationType.general &&
        conversation.type != ConversationType.aiChat &&
        conversation.type != ConversationType.group) {
      approval = await ChatDatasource.getApprovalRequest(conversation.id);
    }

    // Marcar como leídos
    await ChatDatasource.markMessagesAsRead(conversation.id);

    state = state.copyWith(
      messages: messages,
      currentApproval: approval,
      isLoadingMessages: false,
    );

    // Suscribirse a mensajes de esta conversación
    _subscribeToMessages(conversation.id);

    // Actualizar conteo de no leídos
    _refreshCounts();
  }

  void clearSelection() {
    if (_messagesChannel != null) {
      ChatDatasource.unsubscribe(_messagesChannel!);
      _messagesChannel = null;
    }
    state = state.copyWith(
      clearSelected: true,
      messages: [],
      clearApproval: true,
    );
  }

  Future<void> refreshSelectedConversation() async {
    final selected = state.selectedConversation;
    if (selected == null) return;

    final updated = state.conversations.where((c) => c.id == selected.id).firstOrNull ?? selected;
    final messages = await ChatDatasource.getMessages(updated.id);

    ApprovalRequest? approval;
    if (updated.type != ConversationType.general &&
        updated.type != ConversationType.aiChat &&
        updated.type != ConversationType.group) {
      approval = await ChatDatasource.getApprovalRequest(updated.id);
    }

    state = state.copyWith(
      selectedConversation: updated,
      messages: messages.isNotEmpty ? messages : state.messages,
      currentApproval: approval,
      isLoadingMessages: false,
    );

    _subscribeToMessages(updated.id);
  }

  // ===================== ENVIAR MENSAJE =====================

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || state.selectedConversation == null) return;

    state = state.copyWith(isSending: true);
    final msg = await ChatDatasource.sendMessage(
      state.selectedConversation!.id,
      content.trim(),
    );

    if (msg != null) {
      final exists = state.messages.any((m) => m.id == msg.id);
      if (!exists) {
        state = state.copyWith(
          messages: [...state.messages, msg],
          isSending: false,
        );
      } else {
        state = state.copyWith(isSending: false);
      }
      await loadConversations();
    } else {
      state = state.copyWith(
        isSending: false,
        error: 'Error enviando mensaje',
      );
    }
  }

  // ===================== CHAT DIRECTO =====================

  /// Crear o reabrir conversación directa con otro usuario
  Future<String?> createDirectChat({
    required String toUserId,
    required String message,
  }) async {
    final conversationId = await ChatDatasource.createDirectConversation(
      toUserId: toUserId,
      message: message,
    );

    if (conversationId != null) {
      await loadConversations();
      // Auto-seleccionar la conversación creada
      final created = state.conversations.where((c) => c.id == conversationId).firstOrNull;
      if (created != null) {
        await selectConversation(created);
      }
    }
    return conversationId;
  }

  // ===================== CHAT IA =====================

  /// Crear o abrir conversación individual con IA
  Future<String?> createAiChat() async {
    final conversationId = await ChatDatasource.createAiChat();
    if (conversationId != null) {
      await loadConversations();
      final created = state.conversations.where((c) => c.id == conversationId).firstOrNull;
      if (created != null) {
        await selectConversation(created);
      }
    }
    return conversationId;
  }

  /// Enviar pregunta a IA dentro de una conversación (individual o como 3er participante)
  Future<void> askAi(String question) async {
    if (question.trim().isEmpty || state.selectedConversation == null) return;

    final conversationId = state.selectedConversation!.id;
    final safeQuestion = question.trim();
    final currentUser = Supabase.instance.client.auth.currentUser;

    final optimisticMessage = ConversationMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: currentUser?.id ?? '',
      content: safeQuestion,
      messageType: MessageType.aiRequest,
      createdAt: DateTime.now(),
      isRead: true,
      senderName: currentUser?.email,
    );

    state = state.copyWith(
      isSending: true,
      messages: [...state.messages, optimisticMessage],
      clearError: true,
    );

    final history = state.messages
        .where((m) => m.messageType == MessageType.text ||
            m.messageType == MessageType.aiRequest ||
            m.messageType == MessageType.aiResponse)
        .map((m) => {
              'role': m.messageType == MessageType.aiResponse ? 'assistant' : 'user',
              'content': m.content,
            })
        .toList()
        .cast<Map<String, String>>();

    final systemPrompt = AiCapabilities.buildSystemPrompt();
    final aiResult = await AiAssistantDatasource.sendMessage(
      message: safeQuestion,
      conversationHistory: history,
      systemPrompt: systemPrompt,
    );

    if (aiResult.success && aiResult.response.isNotEmpty) {
      await ChatDatasource.sendAiMessage(
        conversationId: conversationId,
        question: safeQuestion,
        aiResponse: aiResult.response,
      );

      final messages = await ChatDatasource.getMessages(conversationId);
      state = state.copyWith(messages: messages, isSending: false);
      await loadConversations();
    } else {
      state = state.copyWith(
        isSending: false,
        error: aiResult.error ?? 'Error al consultar la IA',
      );
    }
  }

  // ===================== CHAT GRUPAL =====================

  /// Crear chat grupal (agrega a todos los usuarios activos)
  Future<String?> createGroupChat({
    required String title,
    String? description,
  }) async {
    final conversationId = await ChatDatasource.createGroupChat(
      title: title,
      description: description,
    );
    if (conversationId != null) {
      await loadConversations();
      final created = state.conversations.where((c) => c.id == conversationId).firstOrNull;
      if (created != null) {
        await selectConversation(created);
      }
    }
    return conversationId;
  }

  // ===================== SOLICITUDES =====================

  Future<String?> createTransferRequest({
    required String fromAccountId,
    required String fromAccountName,
    required String toAccountId,
    required String toAccountName,
    required double amount,
    required String reason,
    required String assignedTo,
  }) async {
    final requestData = {
      'from_account_id': fromAccountId,
      'from_account_name': fromAccountName,
      'to_account_id': toAccountId,
      'to_account_name': toAccountName,
      'amount': amount,
      'reason': reason,
    };

    final title = 'Traslado $fromAccountName → $toAccountName';
    final message = 'Solicitud de traslado de \$${_formatNumber(amount)} '
        'de $fromAccountName a $toAccountName.\nRazón: $reason';

    final conversationId = await ChatDatasource.createApprovalRequest(
      title: title,
      conversationType: 'transfer_approval',
      requestType: 'transfer',
      requestData: requestData,
      message: message,
      assignedTo: assignedTo,
    );

    if (conversationId != null) {
      await loadConversations();
    }
    return conversationId;
  }

  Future<String?> createPurchaseRequest({
    required List<Map<String, dynamic>> materials,
    required String supplier,
    required double totalEstimated,
    required String assignedTo,
    String urgency = 'normal',
  }) async {
    final requestData = {
      'materials': materials,
      'supplier': supplier,
      'total_estimated': totalEstimated,
      'urgency': urgency,
    };

    final materialNames = materials.map((m) => m['name'] as String).join(', ');
    final title = 'Compra: $materialNames';
    final message = 'Solicitud de compra de materiales a $supplier.\n'
        'Materiales: $materialNames\n'
        'Total estimado: \$${_formatNumber(totalEstimated)}';

    final conversationId = await ChatDatasource.createApprovalRequest(
      title: title,
      conversationType: 'purchase_approval',
      requestType: 'material_purchase',
      requestData: requestData,
      message: message,
      assignedTo: assignedTo,
    );

    if (conversationId != null) {
      await loadConversations();
    }
    return conversationId;
  }

  Future<String?> createExpenseRequest({
    required String description,
    required double amount,
    required String category,
    required String assignedTo,
  }) async {
    final requestData = {
      'description': description,
      'amount': amount,
      'category': category,
    };

    final title = 'Gasto: $description';
    final message = 'Solicitud de aprobación de gasto.\n'
        'Descripción: $description\n'
        'Monto: \$${_formatNumber(amount)}\n'
        'Categoría: $category';

    final conversationId = await ChatDatasource.createApprovalRequest(
      title: title,
      conversationType: 'expense_approval',
      requestType: 'expense',
      requestData: requestData,
      message: message,
      assignedTo: assignedTo,
    );

    if (conversationId != null) {
      await loadConversations();
    }
    return conversationId;
  }

  // ===================== APROBACIÓN / RECHAZO =====================

  Future<bool> approveRequest({String? notes}) async {
    if (state.selectedConversation == null) return false;

    final success = await ChatDatasource.resolveApprovalRequest(
      conversationId: state.selectedConversation!.id,
      status: 'approved',
      notes: notes,
    );

    if (success) {
      await _refreshAfterResolve();
    }
    return success;
  }

  Future<bool> rejectRequest({String? notes}) async {
    if (state.selectedConversation == null) return false;

    final success = await ChatDatasource.resolveApprovalRequest(
      conversationId: state.selectedConversation!.id,
      status: 'rejected',
      notes: notes,
    );

    if (success) {
      await _refreshAfterResolve();
    }
    return success;
  }

  Future<void> _refreshAfterResolve() async {
    // Recargar conversaciones y la seleccionada
    await loadConversations();
    // Invalidar badge count para que sidebars/navbars se actualicen
    ref.invalidate(chatPendingCountProvider);
    if (state.selectedConversation != null) {
      // Re-seleccionar para actualizar mensajes y approval
      final updated = state.conversations.where(
        (c) => c.id == state.selectedConversation!.id,
      ).firstOrNull;
      if (updated != null) {
        await selectConversation(updated);
      }
    }
  }

  // ===================== REALTIME =====================

  void _subscribeToConversations() {
    if (_conversationsChannel != null) {
      ChatDatasource.unsubscribe(_conversationsChannel!);
    }
    _conversationsChannel = ChatDatasource.subscribeToConversations(
      onConversationChanged: () async {
        await loadConversations();
      },
    );
    if (_approvalsChannel != null) {
      ChatDatasource.unsubscribe(_approvalsChannel!);
    }
    _approvalsChannel = ChatDatasource.subscribeToApprovals(
      onApprovalChanged: () => loadConversations(),
    );
  }

  void _subscribeToMessages(String conversationId) {
    if (_messagesChannel != null) {
      ChatDatasource.unsubscribe(_messagesChannel!);
    }
    _messagesChannel = ChatDatasource.subscribeToMessages(
      conversationId: conversationId,
      onNewMessage: (msg) {
        // No agregar duplicados
        if (!state.messages.any((m) => m.id == msg.id)) {
          state = state.copyWith(
            messages: [...state.messages, msg],
          );
          ChatDatasource.markMessagesAsRead(conversationId);
          loadConversations();
        }
      },
    );
  }

  Future<void> _refreshCounts() async {
    final pendingCount = await ChatDatasource.getPendingCount();
    final unreadCount = await ChatDatasource.getUnreadCount();
    state = state.copyWith(
      pendingCount: pendingCount,
      unreadCount: unreadCount,
    );
  }

  // ===================== UTILS =====================

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
    }
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }
}
