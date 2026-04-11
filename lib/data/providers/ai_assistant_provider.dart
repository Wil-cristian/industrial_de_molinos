import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/entities/activity.dart';
import '../datasources/ai_assistant_datasource.dart';
import '../datasources/activities_datasource.dart';
import '../datasources/calendar_events_datasource.dart';
import '../datasources/ai_action_logger.dart';
import '../datasources/ai_capabilities.dart';
import '../datasources/ai_action_executor.dart';
import '../../core/utils/colombia_time.dart';

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
  String? _cachedSystemPrompt;

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
      timestamp: ColombiaTime.now(),
    );

    // Agregar placeholder de carga del asistente
    final loadingMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      content: '',
      timestamp: ColombiaTime.now(),
      isLoading: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, loadingMsg],
      isProcessing: true,
      error: null,
    );

    try {
      // Verificar si es consulta de calendario/actividades
      final calendarContext = await _buildCalendarContext(text.trim());
      final enrichedMessage = calendarContext != null
          ? '$calendarContext\n\nPregunta del usuario: ${text.trim()}'
          : text.trim();

      // Construir system prompt solo en el primer mensaje de la sesion
      final systemPrompt = await _getSystemPrompt();

      final response = await AiAssistantDatasource.sendMessage(
        message: enrichedMessage,
        conversationHistory: _buildHistory(),
        systemPrompt: systemPrompt,
      );

      // Parsear si la respuesta contiene una accion propuesta
      if (response.success) {
        final action = AiActionParser.parseAction(response.response);
        if (action != null) {
          final cleanText = AiActionParser.getTextWithoutAction(
            response.response,
          );
          final actionConfirmation = ActionConfirmation(
            actionType: action['type'] as String? ?? '',
            summary: action['summary'] as String? ?? '',
            data: action,
            confirmed: false,
          );
          _replaceLoadingWithAction(
            loadingMsg.id,
            cleanText,
            actionConfirmation,
          );
          return;
        }
      }

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
      timestamp: ColombiaTime.now(),
    );

    final loadingMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      content: '',
      timestamp: ColombiaTime.now(),
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

  /// Construye contexto del calendario si el mensaje es relevante
  Future<String?> _buildCalendarContext(String message) async {
    final lower = message.toLowerCase();
    final calendarKeywords = [
      'hoy',
      'mañana',
      'semana',
      'calendario',
      'actividad',
      'vence',
      'vencimiento',
      'pendiente',
      'factura',
      'produccion',
      'producción',
      'envio',
      'envío',
      'cotizacion',
      'cotización',
      'compra',
      'agenda',
      'programado',
      'fecha',
      'tengo para',
      'que hay',
      'que tengo',
    ];

    final isCalendarQuery = calendarKeywords.any((k) => lower.contains(k));
    if (!isCalendarQuery) return null;

    try {
      final events = await CalendarEventsDatasource.loadAllEvents();
      final now = ColombiaTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final weekEnd = today.add(const Duration(days: 7));
      final df = DateFormat('dd/MM/yyyy');

      // Eventos de hoy
      final todayEvents = events
          .where(
            (e) =>
                e.date.year == today.year &&
                e.date.month == today.month &&
                e.date.day == today.day,
          )
          .toList();

      // Eventos vencidos
      final overdueEvents = events
          .where((e) => e.isOverdue && e.date.isBefore(today))
          .toList();

      // Eventos de esta semana
      final weekEvents = events
          .where((e) => !e.date.isBefore(tomorrow) && e.date.isBefore(weekEnd))
          .toList();

      // Cargar actividades manuales
      final activities = await ActivitiesDatasource.getActivities();
      final todayActivities = activities.where((a) {
        final d = a.dueDate ?? a.startDate;
        return d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
      }).toList();
      final overdueActivities = activities.where((a) {
        final d = a.dueDate ?? a.startDate;
        return d.isBefore(today) &&
            a.status != ActivityStatus.completed &&
            a.status != ActivityStatus.cancelled;
      }).toList();

      final buf = StringBuffer();
      buf.writeln('[CONTEXTO DEL CALENDARIO - ${df.format(now)}]');

      if (overdueEvents.isNotEmpty || overdueActivities.isNotEmpty) {
        buf.writeln('\n--- VENCIDOS ---');
        for (final e in overdueEvents) {
          buf.writeln(
            '- ${e.sourceLabel}: ${e.title} (${df.format(e.date)})${e.subtitle != null ? ' - ${e.subtitle}' : ''}',
          );
        }
        for (final a in overdueActivities) {
          buf.writeln(
            '- Actividad: ${a.title} (${df.format(a.dueDate ?? a.startDate)})',
          );
        }
      }

      if (todayEvents.isNotEmpty || todayActivities.isNotEmpty) {
        buf.writeln('\n--- HOY ---');
        for (final e in todayEvents) {
          buf.writeln(
            '- ${e.sourceLabel}: ${e.title}${e.subtitle != null ? ' - ${e.subtitle}' : ''}',
          );
        }
        for (final a in todayActivities) {
          buf.writeln('- Actividad: ${a.title} (${a.typeLabel})');
        }
      }

      if (weekEvents.isNotEmpty) {
        buf.writeln('\n--- PROXIMOS 7 DIAS ---');
        for (final e in weekEvents) {
          buf.writeln(
            '- ${e.sourceLabel}: ${e.title} (${df.format(e.date)})${e.subtitle != null ? ' - ${e.subtitle}' : ''}',
          );
        }
      }

      if (todayEvents.isEmpty &&
          todayActivities.isEmpty &&
          overdueEvents.isEmpty &&
          overdueActivities.isEmpty &&
          weekEvents.isEmpty) {
        buf.writeln('No hay eventos pendientes registrados.');
      }

      buf.writeln(
        '\n[Responde en español de forma concisa y util. Si el usuario pide cambiar una fecha, indica que debe hacerlo desde el modulo correspondiente (Facturas, Produccion, etc.)]',
      );

      return buf.toString();
    } catch (e) {
      return null; // Si falla, enviar mensaje normal sin contexto
    }
  }

  /// Reemplaza el mensaje de carga con la respuesta real
  void _replaceLoadingMessage(String loadingId, AiAssistantResponse response) {
    final updatedMessages = state.messages.map((m) {
      if (m.id == loadingId) {
        return ChatMessage(
          id: m.id,
          role: ChatRole.assistant,
          content: response.success ? response.response : '❌ ${response.error}',
          timestamp: ColombiaTime.now(),
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

  /// Reemplaza el mensaje de carga con respuesta que contiene accion propuesta
  void _replaceLoadingWithAction(
    String loadingId,
    String text,
    ActionConfirmation confirmation,
  ) {
    final updatedMessages = state.messages.map((m) {
      if (m.id == loadingId) {
        return ChatMessage(
          id: m.id,
          role: ChatRole.assistant,
          content: text,
          timestamp: ColombiaTime.now(),
          isLoading: false,
          actionConfirmation: confirmation,
        );
      }
      return m;
    }).toList();

    state = state.copyWith(
      messages: updatedMessages,
      isProcessing: false,
      error: null,
    );
  }

  /// Devuelve el system prompt cacheado (se construye solo una vez por sesion)
  Future<String?> _getSystemPrompt() async {
    if (_cachedSystemPrompt != null) return _cachedSystemPrompt;
    _cachedSystemPrompt = await _buildSystemPrompt();
    return _cachedSystemPrompt;
  }

  /// Construye el system prompt con capacidades y acciones frecuentes del usuario
  Future<String?> _buildSystemPrompt() async {
    try {
      final recentActions = await AiActionLogger.getRecentActions(limit: 10);
      final frequentActions = await AiActionLogger.getFrequentActions(limit: 5);
      return AiCapabilities.buildSystemPrompt(
        recentActions: recentActions.cast<Map<String, dynamic>>(),
        frequentActions: frequentActions.cast<Map<String, dynamic>>(),
      );
    } catch (_) {
      return AiCapabilities.buildSystemPrompt();
    }
  }

  /// Construye el historial de conversación para enviar al backend.
  /// Solo envía los últimos 10 mensajes (texto, no loading).
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
        .take(10)
        .toList()
        .reversed
        .toList();
  }

  /// Confirma y ejecuta la accion propuesta por la IA
  Future<void> confirmAction(String messageId, BuildContext context) async {
    final msg = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => throw StateError('Message not found'),
    );
    final confirmation = msg.actionConfirmation;
    if (confirmation == null) return;

    final result = await AiActionExecutor.execute(confirmation.data, context);

    // Marcar confirmacion y agregar respuesta de resultado
    final updated = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(
          actionConfirmation: ActionConfirmation(
            actionType: confirmation.actionType,
            summary: confirmation.summary,
            data: confirmation.data,
            confirmed: true,
          ),
        );
      }
      return m;
    }).toList();

    final resultMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.assistant,
      content: result.success ? '✅ ${result.message}' : '❌ ${result.message}',
      timestamp: ColombiaTime.now(),
    );

    state = state.copyWith(messages: [...updated, resultMsg]);
  }

  /// Descarta la accion propuesta por la IA
  void dismissAction(String messageId) {
    final updated = state.messages.map((m) {
      if (m.id == messageId) {
        final conf = m.actionConfirmation;
        if (conf != null) {
          return m.copyWith(
            actionConfirmation: ActionConfirmation(
              actionType: conf.actionType,
              summary: conf.summary,
              data: conf.data,
              confirmed: true,
            ),
          );
        }
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }
}
