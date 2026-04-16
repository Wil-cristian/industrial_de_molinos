import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/conversation_message.dart';
import '../../domain/entities/approval_request.dart';
import 'supabase_datasource.dart';

class ChatDatasource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  // ===================== CONVERSACIONES =====================

  /// Obtener todas las conversaciones (vista con info extra)
  static Future<List<Conversation>> getConversations() async {
    try {
      final response = await _client
          .from('v_chat_conversations')
          .select()
          .order('updated_at', ascending: false);
      return response
          .map<Conversation>(
            (json) => Conversation.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList();
    } catch (e) {
      AppLogger.error('Error cargando conversaciones', e);
      return [];
    }
  }

  /// Obtener conversaciones pendientes (para badge)
  static Future<int> getPendingCount() async {
    try {
      final response = await _client
          .from('chat_conversations')
          .select('id')
          .eq('status', 'pending');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Obtener total de mensajes no leídos
  static Future<int> getUnreadCount() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 0;
      final response = await _client
          .from('chat_messages')
          .select('id')
          .neq('sender_id', userId)
          .eq('is_read', false);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // ===================== MENSAJES =====================

  /// Obtener mensajes de una conversación
  static Future<List<ConversationMessage>> getMessages(String conversationId) async {
    try {
      final response = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .order('id', ascending: true);

      final rows = response
          .map<Map<String, dynamic>>((json) => Map<String, dynamic>.from(json))
          .toList();

      final senderIds = rows
          .map((row) => row['sender_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> profilesByUserId = {};
      if (senderIds.isNotEmpty) {
        final profiles = await _client
            .from('user_profiles')
            .select('user_id, display_name, role')
            .inFilter('user_id', senderIds);
        profilesByUserId = {
          for (final p in profiles)
            (p['user_id'] as String): Map<String, dynamic>.from(p as Map),
        };
      }

      return rows.map<ConversationMessage>((row) {
        final profile = profilesByUserId[row['sender_id'] as String? ?? ''];
        return ConversationMessage.fromJson({
          ...row,
          'sender_name': profile?['display_name'],
          'sender_role': profile?['role'],
        });
      }).toList();
    } catch (e) {
      AppLogger.error('Error cargando mensajes', e);
      // Fallback sin join
      try {
        final response = await _client
            .from('chat_messages')
            .select()
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true)
            .order('id', ascending: true);
        return response
            .map<ConversationMessage>(
              (json) => ConversationMessage.fromJson(
                Map<String, dynamic>.from(json),
              ),
            )
            .toList();
      } catch (e2) {
        AppLogger.error('Error cargando mensajes (fallback)', e2);
        return [];
      }
    }
  }

  /// Enviar un mensaje de texto
  static Future<ConversationMessage?> sendMessage(String conversationId, String content) async {
    try {
      final userId = _client.auth.currentUser!.id;
      final response = await _client
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': content,
            'message_type': 'text',
          })
          .select()
          .single();
      return ConversationMessage.fromJson(response);
    } catch (e) {
      AppLogger.error('Error enviando mensaje', e);
      return null;
    }
  }

  /// Marcar mensajes como leídos
  static Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      await _client
          .from('chat_messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);
    } catch (e) {
      AppLogger.error('Error marcando mensajes como leídos', e);
    }
  }

  // ===================== SOLICITUDES DE APROBACIÓN =====================

  /// Crear solicitud de aprobación completa (conversación + solicitud + mensaje)
  static Future<String?> createApprovalRequest({
    required String title,
    required String conversationType, // transfer_approval, purchase_approval, expense_approval
    required String requestType,      // transfer, material_purchase, expense, general
    required Map<String, dynamic> requestData,
    required String message,
    String? assignedTo,
  }) async {
    try {
      final response = await _client.rpc('create_approval_request', params: {
        'p_title': title,
        'p_type': conversationType,
        'p_request_type': requestType,
        'p_request_data': requestData,
        'p_message': message,
        'p_assigned_to': assignedTo,
      });
      return response as String?;
    } catch (e) {
      AppLogger.error('Error creando solicitud de aprobación', e);
      return null;
    }
  }

  /// Obtener solicitud de aprobación por conversación
  static Future<ApprovalRequest?> getApprovalRequest(String conversationId) async {
    try {
      final response = await _client
          .from('approval_requests')
          .select()
          .eq('conversation_id', conversationId)
          .maybeSingle();
      if (response == null) return null;
      return ApprovalRequest.fromJson(response);
    } catch (e) {
      AppLogger.error('Error cargando solicitud', e);
      return null;
    }
  }

  /// Aprobar o rechazar solicitud
  static Future<bool> resolveApprovalRequest({
    required String conversationId,
    required String status, // 'approved' o 'rejected'
    String? notes,
  }) async {
    try {
      await _client.rpc('resolve_approval_request', params: {
        'p_conversation_id': conversationId,
        'p_status': status,
        'p_notes': notes,
      });
      return true;
    } catch (e) {
      AppLogger.error('Error resolviendo solicitud', e);
      return false;
    }
  }

  // ===================== USUARIOS PARA CHAT =====================

  /// Listar usuarios disponibles para chatear (todos menos el actual)
  static Future<List<Map<String, dynamic>>> getChatUsers() async {
    try {
      final response = await _client.rpc('list_chat_users');
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      AppLogger.error('Error listando usuarios para chat', e);
      return [];
    }
  }

  /// Crear conversación directa (o reusar existente) y enviar primer mensaje
  static Future<String?> createDirectConversation({
    required String toUserId,
    required String message,
  }) async {
    try {
      final response = await _client.rpc('create_direct_conversation', params: {
        'p_to_user': toUserId,
        'p_message': message,
      });
      return response as String?;
    } catch (e) {
      AppLogger.error('Error creando conversación directa', e);
      return null;
    }
  }

  // ===================== CHAT IA =====================

  /// Crear o reusar conversación 1-on-1 con IA
  static Future<String?> createAiChat() async {
    try {
      final response = await _client.rpc('create_ai_chat');
      return response as String?;
    } catch (e) {
      AppLogger.error('Error creando chat IA', e);
      return null;
    }
  }

  /// Enviar pregunta a IA y guardar request+response en la conversación
  static Future<ConversationMessage?> sendAiMessage({
    required String conversationId,
    required String question,
    required String aiResponse,
  }) async {
    try {
      final response = await _client.rpc('send_ai_message', params: {
        'p_conversation_id': conversationId,
        'p_content': aiResponse,
        'p_user_message': question,
      });
      // Returns the ai_response message id
      if (response != null) {
        // Fetch the actual AI response message
        final msg = await _client
            .from('chat_messages')
            .select()
            .eq('id', response as String)
            .single();
        return ConversationMessage.fromJson(msg);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error enviando mensaje IA', e);
      return null;
    }
  }

  // ===================== CHAT GRUPAL =====================

  /// Crear chat grupal (agrega a todos los usuarios activos)
  static Future<String?> createGroupChat({
    required String title,
    String? description,
  }) async {
    try {
      final response = await _client.rpc('create_group_chat', params: {
        'p_title': title,
        'p_description': description,
      });
      return response as String?;
    } catch (e) {
      AppLogger.error('Error creando chat grupal', e);
      return null;
    }
  }

  // ===================== REALTIME =====================

  /// Suscripción a nuevos mensajes
  static RealtimeChannel subscribeToMessages({
    required String conversationId,
    required void Function(ConversationMessage) onNewMessage,
  }) {
    return _client
        .channel('chat_messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            try {
              final msg = ConversationMessage.fromJson(payload.newRecord);
              onNewMessage(msg);
            } catch (e) {
              AppLogger.error('Error en realtime message', e);
            }
          },
        )
        .subscribe();
  }

  /// Suscripción a cambios en conversaciones (para actualizar lista)
  static RealtimeChannel subscribeToConversations({
    required void Function() onConversationChanged,
  }) {
    return _client
        .channel('chat_conversations_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_conversations',
          callback: (_) => onConversationChanged(),
        )
        .subscribe();
  }

  /// Suscripción a cambios en approval_requests
  static RealtimeChannel subscribeToApprovals({
    required void Function() onApprovalChanged,
  }) {
    return _client
        .channel('approval_requests_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'approval_requests',
          callback: (_) => onApprovalChanged(),
        )
        .subscribe();
  }

  /// Cancelar suscripción
  static Future<void> unsubscribe(RealtimeChannel channel) async {
    await _client.removeChannel(channel);
  }
}
