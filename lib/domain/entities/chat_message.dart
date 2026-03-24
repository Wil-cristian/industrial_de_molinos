/// Mensaje de chat entre el usuario y el asistente IA
class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final bool isLoading;
  final String? audioTranscription;
  final ActionConfirmation? actionConfirmation;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isLoading = false,
    this.audioTranscription,
    this.actionConfirmation,
  });

  ChatMessage copyWith({
    String? content,
    bool? isLoading,
    ActionConfirmation? actionConfirmation,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      isLoading: isLoading ?? this.isLoading,
      audioTranscription: audioTranscription,
      actionConfirmation: actionConfirmation ?? this.actionConfirmation,
    );
  }
}

enum ChatRole { user, assistant, system }

/// Cuando el asistente propone una acción que requiere confirmación
class ActionConfirmation {
  final String actionType; // crear_factura, registrar_pago, etc.
  final String summary;
  final Map<String, dynamic> data;
  final bool confirmed;

  const ActionConfirmation({
    required this.actionType,
    required this.summary,
    required this.data,
    this.confirmed = false,
  });
}
