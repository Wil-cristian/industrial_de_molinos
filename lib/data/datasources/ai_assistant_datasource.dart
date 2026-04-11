import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/logger.dart';
import 'supabase_datasource.dart';

/// Servicio que comunica la app con la Edge Function ai-assistant.
class AiAssistantDatasource {
  static const _functionName = 'ai-assistant';

  /// Envía un mensaje de texto al asistente.
  /// [conversationHistory] son los mensajes previos en formato
  /// `[{role: 'user'|'assistant', content: '...'}]`
  static Future<AiAssistantResponse> sendMessage({
    required String message,
    List<Map<String, String>> conversationHistory = const [],
    String? systemPrompt,
  }) async {
    return _callFunction(
      body: {
        'message': message,
        'conversation_history': conversationHistory,
        if (systemPrompt != null) 'system_prompt': systemPrompt,
      },
    );
  }

  /// Envía un audio grabado al asistente para transcripción + respuesta.
  static Future<AiAssistantResponse> sendAudio({
    required Uint8List audioBytes,
    List<Map<String, String>> conversationHistory = const [],
  }) async {
    final base64Audio = base64Encode(audioBytes);
    return _callFunction(
      body: {
        'audio_base64': base64Audio,
        'conversation_history': conversationHistory,
      },
    );
  }

  static Future<AiAssistantResponse> _callFunction({
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await SupabaseDataSource.client.functions.invoke(
        _functionName,
        body: body,
      );

      if (response.status != 200) {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? 'Error desconocido')
            : 'Error ${response.status}';
        return AiAssistantResponse.error(errorMsg.toString());
      }

      final data = response.data as Map<String, dynamic>;
      return AiAssistantResponse(
        response: data['response'] as String? ?? '',
        transcription: data['transcription'] as String?,
      );
    } on FunctionException catch (e) {
      AppLogger.error('Edge Function error', e);
      return AiAssistantResponse.error(
        'Error del servidor: ${e.reasonPhrase ?? e.toString()}',
      );
    } catch (e) {
      AppLogger.error('AI Assistant error', e);
      return AiAssistantResponse.error('Error de conexión: $e');
    }
  }

  /// Verifica si el servicio está disponible (Supabase conectado).
  static bool get isAvailable => SupabaseDataSource.isAuthenticated;
}

/// Respuesta del asistente IA.
class AiAssistantResponse {
  final String response;
  final String? transcription;
  final String? error;

  bool get success => error == null;

  AiAssistantResponse({required this.response, this.transcription, this.error});

  AiAssistantResponse.error(String errorMessage)
    : response = '',
      transcription = null,
      error = errorMessage;
}
