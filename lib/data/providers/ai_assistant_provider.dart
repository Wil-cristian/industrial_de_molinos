import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/chat_message.dart';
import '../datasources/ai_assistant_datasource.dart';

const _uuid = Uuid();

/// Provider global del asistente IA
final aiAssistantProvider =
    NotifierProvider<AiAssistantNotifier, AiAssistantState>(() {
      return AiAssistantNotifier();
    });

/// Estado del asistente IA
class AiAssistantState {
  final List<ChatMessage> messages;
  final bool isProcessing;
  final bool isRecording;
  final String? error;

  const AiAssistantState({
    this.messages = const [],
    this.isProcessing = false,
    this.isRecording = false,
    this.error,
  });

  AiAssistantState copyWith({
    List<ChatMessage>? messages,
    bool? isProcessing,
    bool? isRecording,
    String? error,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isProcessing: isProcessing ?? this.isProcessing,
      isRecording: isRecording ?? this.isRecording,
      error: error,
    );
  }
}

class AiAssistantNotifier extends Notifier<AiAssistantState> {
  @override
  AiAssistantState build() {
    return const AiAssistantState();
  }

  /// Envía un mensaje de texto al asistente
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isProcessing) return;

    // Agregar mensaje del usuario
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    // Agregar placeholder de carga del asistente
    final loadingMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isLoading: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, loadingMsg],
      isProcessing: true,
      error: null,
    );

    try {
      final response = await AiAssistantDatasource.sendMessage(
        message: text.trim(),
        conversationHistory: _buildHistory(),
      );

      _replaceLoadingMessage(loadingMsg.id, response);
    } catch (e) {
      _replaceLoadingMessage(
        loadingMsg.id,
        AiAssistantResponse.error('Error inesperado: $e'),
      );
    }
  }

  /// Envía audio grabado al asistente
  Future<void> sendAudio(Uint8List audioBytes) async {
    if (state.isProcessing) return;

    // Mensaje placeholder "Transcribiendo audio..."
    final audioMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: '🎤 Mensaje de voz...',
      timestamp: DateTime.now(),
    );

    final loadingMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isLoading: true,
    );

    state = state.copyWith(
      messages: [...state.messages, audioMsg, loadingMsg],
      isProcessing: true,
      isRecording: false,
      error: null,
    );

    try {
      final response = await AiAssistantDatasource.sendAudio(
        audioBytes: audioBytes,
        conversationHistory: _buildHistory(),
      );

      // Actualizar mensaje del usuario con transcripción real
      if (response.transcription != null) {
        final updatedMessages = state.messages.map((m) {
          if (m.id == audioMsg.id) {
            return ChatMessage(
              id: m.id,
              role: m.role,
              content: response.transcription!,
              timestamp: m.timestamp,
              audioTranscription: response.transcription,
            );
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updatedMessages);
      }

      _replaceLoadingMessage(loadingMsg.id, response);
    } catch (e) {
      _replaceLoadingMessage(
        loadingMsg.id,
        AiAssistantResponse.error('Error inesperado: $e'),
      );
    }
  }

  void setRecording(bool recording) {
    state = state.copyWith(isRecording: recording);
  }

  void clearChat() {
    state = const AiAssistantState();
  }

  /// Reemplaza el mensaje de carga con la respuesta real
  void _replaceLoadingMessage(String loadingId, AiAssistantResponse response) {
    final updatedMessages = state.messages.map((m) {
      if (m.id == loadingId) {
        return ChatMessage(
          id: m.id,
          role: ChatRole.assistant,
          content: response.success ? response.response : '❌ ${response.error}',
          timestamp: DateTime.now(),
          isLoading: false,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(
      messages: updatedMessages,
      isProcessing: false,
      error: response.error,
    );
  }

  /// Construye el historial de conversación para enviar al backend.
  /// Solo envía los últimos 20 mensajes (texto, no loading).
  List<Map<String, String>> _buildHistory() {
    return state.messages
        .where((m) => !m.isLoading && m.content.isNotEmpty)
        .map((m) {
          return {
            'role': m.role == ChatRole.user ? 'user' : 'assistant',
            'content': m.content,
          };
        })
        .toList()
        .reversed
        .take(20)
        .toList()
        .reversed
        .toList();
  }
}
