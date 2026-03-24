import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/responsive/responsive_helper.dart';
import '../../data/providers/ai_assistant_provider.dart';
import '../../domain/entities/chat_message.dart';

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key});

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage>
    with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // Sugerencias rápidas para el usuario
  static const _quickSuggestions = [
    '¿Cómo va la caja hoy?',
    '¿Cuánto nos deben los clientes?',
    'Resumen del mes',
    '¿Qué materiales hay bajo stock?',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? text]) async {
    final msg = text ?? _textController.text;
    if (msg.trim().isEmpty) return;

    _textController.clear();
    _focusNode.requestFocus();

    await ref.read(aiAssistantProvider.notifier).sendMessage(msg);
    _scrollToBottom();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/ai_assistant_recording.wav';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
        });

        ref.read(aiAssistantProvider.notifier).setRecording(true);

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _recordingSeconds++);
          // Máximo 60 segundos
          if (_recordingSeconds >= 60) _stopRecording();
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Se necesita permiso de micrófono'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      ref.read(aiAssistantProvider.notifier).setRecording(false);

      if (path != null) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          await ref.read(aiAssistantProvider.notifier).sendAudio(bytes);
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() => _isRecording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssistantProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isMobile = ResponsiveHelper.isMobile(context);

    // Auto-scroll cuando llegan nuevos mensajes
    ref.listen<AiAssistantState>(aiAssistantProvider, (_, __) {
      _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Asistente IA'),
          ],
        ),
        actions: [
          if (state.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Limpiar chat',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('¿Limpiar conversación?'),
                    content: const Text('Se borrarán todos los mensajes.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () {
                          ref.read(aiAssistantProvider.notifier).clearChat();
                          Navigator.pop(ctx);
                        },
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ─── Mensajes ───
          Expanded(
            child: state.messages.isEmpty
                ? _buildEmptyState(cs, tt, isMobile)
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 24,
                      vertical: 16,
                    ),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      return _ChatBubble(
                        message: state.messages[index],
                        isMobile: isMobile,
                      );
                    },
                  ),
          ),

          // ─── Indicador de grabación ───
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: cs.errorContainer.withOpacity(0.3),
              child: Row(
                children: [
                  _PulsingDot(color: cs.error),
                  const SizedBox(width: 10),
                  Text(
                    'Grabando... ${_recordingSeconds}s',
                    style: tt.bodyMedium?.copyWith(color: cs.error),
                  ),
                  const Spacer(),
                  Text(
                    'Máx. 60s',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),

          // ─── Input ───
          _buildInputBar(cs, tt, state, isMobile),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, TextTheme tt, bool isMobile) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Asistente Industrial',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pregúntame sobre clientes, facturas, inventario,\ncaja diaria o pídeme que realice acciones.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _quickSuggestions.map((s) {
                return ActionChip(
                  avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(s, style: const TextStyle(fontSize: 13)),
                  onPressed: () => _sendMessage(s),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(
    ColorScheme cs,
    TextTheme tt,
    AiAssistantState state,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 8 : 16,
        8,
        isMobile ? 8 : 16,
        isMobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Botón de micrófono
            if (!kIsWeb) // Solo en plataformas nativas
              _RecordButton(
                isRecording: _isRecording,
                isProcessing: state.isProcessing,
                onTap: _toggleRecording,
                color: _isRecording ? cs.error : cs.primary,
              ),
            const SizedBox(width: 8),
            // Campo de texto
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: !state.isProcessing && !_isRecording,
                textInputAction: TextInputAction.send,
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: _isRecording
                      ? 'Grabando audio...'
                      : 'Escribe tu mensaje...',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                ),
                style: tt.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            // Botón enviar
            IconButton.filled(
              onPressed: state.isProcessing || _isRecording
                  ? null
                  : () => _sendMessage(),
              icon: state.isProcessing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                disabledBackgroundColor: cs.onSurface.withOpacity(0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chat Bubble Widget ───────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMobile;

  const _ChatBubble({required this.message, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isUser = message.role == ChatRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _AvatarBubble(
              icon: Icons.auto_awesome,
              gradient: [cs.primary, cs.tertiary],
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: isMobile ? 300 : 600),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: message.isLoading
                  ? _TypingIndicator(color: cs.onSurfaceVariant)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.audioTranscription != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic,
                                  size: 14,
                                  color: isUser
                                      ? cs.onPrimary.withOpacity(0.7)
                                      : cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Transcripción de voz',
                                  style: tt.labelSmall?.copyWith(
                                    color: isUser
                                        ? cs.onPrimary.withOpacity(0.7)
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SelectableText(
                          message.content,
                          style: tt.bodyMedium?.copyWith(
                            color: isUser ? cs.onPrimary : cs.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _AvatarBubble(
              icon: Icons.person,
              color: cs.secondaryContainer,
              iconColor: cs.onSecondaryContainer,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Small Widgets ────────────────────────────────────

class _AvatarBubble extends StatelessWidget {
  final IconData icon;
  final List<Color>? gradient;
  final Color? color;
  final Color? iconColor;

  const _AvatarBubble({
    required this.icon,
    this.gradient,
    this.color,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: gradient != null ? LinearGradient(colors: gradient!) : null,
        color: gradient == null ? color : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 16, color: iconColor ?? Colors.white),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final Color color;
  const _TypingIndicator({required this.color});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final delay = i * 0.2;
          final t = ((_controller.value + delay) % 1.0);
          final scale = 0.5 + 0.5 * (t < 0.5 ? t * 2 : 2 - t * 2);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.4 + _controller.value * 0.6),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final bool isProcessing;
  final VoidCallback onTap;
  final Color color;

  const _RecordButton({
    required this.isRecording,
    required this.isProcessing,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isRecording ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
            color: isRecording ? color : color.withOpacity(0.3),
            width: isRecording ? 2 : 1,
          ),
        ),
        child: Icon(
          isRecording ? Icons.stop_rounded : Icons.mic_rounded,
          color: isProcessing ? color.withOpacity(0.3) : color,
          size: 22,
        ),
      ),
    );
  }
}
