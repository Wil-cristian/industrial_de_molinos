import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/providers/ai_assistant_provider.dart';
import '../../domain/entities/chat_message.dart';

/// Botón flotante + overlay estilo Siri para el asistente IA.
/// Se coloca dentro de un Stack en el shell principal.
/// El botón se puede arrastrar y se adhiere al borde más cercano.
class AiAssistantFab extends StatefulWidget {
  const AiAssistantFab({super.key});

  @override
  State<AiAssistantFab> createState() => _AiAssistantFabState();
}

class _AiAssistantFabState extends State<AiAssistantFab> {
  static const _btnSize = 56.0;
  static const _margin = 12.0;

  // null = aún no inicializado, se coloca abajo-derecha por defecto
  double? _left;
  double? _top;
  bool _dragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Posición inicial: abajo-derecha
    if (_left == null || _top == null) {
      final size = MediaQuery.of(context).size;
      _left = size.width - _btnSize - 20;
      _top = size.height - _btnSize - 24;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final size = MediaQuery.of(context).size;
    setState(() {
      _dragging = true;
      _left = (_left! + d.delta.dx).clamp(
        _margin,
        size.width - _btnSize - _margin,
      );
      _top = (_top! + d.delta.dy).clamp(
        _margin,
        size.height - _btnSize - _margin,
      );
    });
  }

  void _onPanEnd(DragEndDetails _) {
    // Snap al borde horizontal más cercano
    final size = MediaQuery.of(context).size;
    final center = _left! + _btnSize / 2;
    setState(() {
      _dragging = false;
      _left = center < size.width / 2
          ? _margin
          : size.width - _btnSize - _margin;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_left == null || _top == null) return const SizedBox.shrink();
    // Clamp por si la ventana cambió de tamaño
    final size = MediaQuery.of(context).size;
    final left = _left!.clamp(_margin, size.width - _btnSize - _margin);
    final top = _top!.clamp(_margin, size.height - _btnSize - _margin);
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: AnimatedContainer(
          duration: _dragging
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: _AiFab(),
        ),
      ),
    );
  }
}

class _AiFab extends StatefulWidget {
  @override
  State<_AiFab> createState() => _AiFabState();
}

class _AiFabState extends State<_AiFab> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _open() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar asistente',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const _AiOverlay(),
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Transform.scale(scale: _pulseAnim.value, child: child);
      },
      child: GestureDetector(
        onTap: _open,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cs.primary, cs.tertiary],
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

// ─── Overlay oscuro estilo Siri ───────────────────────

class _AiOverlay extends ConsumerStatefulWidget {
  const _AiOverlay();

  @override
  ConsumerState<_AiOverlay> createState() => _AiOverlayState();
}

class _AiOverlayState extends ConsumerState<_AiOverlay>
    with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _numberController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _numberFocusNode = FocusNode();
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _showNumberInput = false;
  String _numberInputLabel = '';
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  static const _quickSuggestions = [
    '¿Cómo va la caja hoy?',
    '¿Cuánto nos deben?',
    'Resumen del mes',
    'Stock bajo',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _numberController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _numberFocusNode.dispose();
    _recorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? text]) async {
    final msg = text ?? _textController.text;
    if (msg.trim().isEmpty) return;
    _textController.clear();
    setState(() => _showNumberInput = false);
    await ref.read(aiAssistantProvider.notifier).sendMessage(msg);
    _scrollToBottom();
  }

  void _sendNumberValue() {
    final val = _numberController.text.trim();
    if (val.isEmpty) return;
    _numberController.clear();
    _sendMessage(val);
  }

  void _openNumberInput(String label) {
    setState(() {
      _showNumberInput = true;
      _numberInputLabel = label;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _numberFocusNode.requestFocus();
    });
  }

  Future<void> _toggleRecording() async {
    _isRecording ? await _stopRecording() : await _startRecording();
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
          if (_recordingSeconds >= 60) _stopRecording();
        });
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    ref.listen<AiAssistantState>(aiAssistantProvider, (_, __) {
      _scrollToBottom();
    });

    final hasMessages = state.messages.isNotEmpty;
    // Panel crece según haya mensajes, hasta el 70% de la pantalla
    final panelMaxH = screenH * 0.7;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // ── Fondo oscuro ──
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),

          // ── Panel inferior ──
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: _SlideUpPanel(
              child: Container(
                constraints: BoxConstraints(maxHeight: panelMaxH),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 32,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Drag handle ──
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 4),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // ── Header ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [cs.primary, cs.tertiary],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Asistente',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (hasMessages)
                            _HeaderAction(
                              icon: Icons.delete_outline,
                              tooltip: 'Limpiar',
                              onTap: () {
                                ref
                                    .read(aiAssistantProvider.notifier)
                                    .clearChat();
                              },
                            ),
                          _HeaderAction(
                            icon: Icons.close,
                            tooltip: 'Cerrar',
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // ── Mensajes o sugerencias ──
                    if (hasMessages)
                      Flexible(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shrinkWrap: true,
                          itemCount: state.messages.length,
                          itemBuilder: (context, i) {
                            return _Bubble(message: state.messages[i]);
                          },
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _quickSuggestions.map((s) {
                            return ActionChip(
                              label: Text(
                                s,
                                style: const TextStyle(fontSize: 12),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _sendMessage(s),
                            );
                          }).toList(),
                        ),
                      ),

                    // ── Quick replies ──
                    _buildQuickReplies(cs, tt, state),

                    // ── Number input ──
                    if (_showNumberInput) _buildNumberInput(cs, tt, state),

                    // ── Indicador de grabación ──
                    if (_isRecording)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        color: cs.errorContainer.withOpacity(0.2),
                        child: Row(
                          children: [
                            _PulsingDot(color: cs.error),
                            const SizedBox(width: 8),
                            Text(
                              'Grabando… ${_recordingSeconds}s',
                              style: tt.bodySmall?.copyWith(color: cs.error),
                            ),
                            const Spacer(),
                            Text(
                              'Máx. 60s',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Input bar ──
                    _buildInputBar(cs, tt, state),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick reply buttons ──────────────────────────────
  Widget _buildQuickReplies(
    ColorScheme cs,
    TextTheme tt,
    AiAssistantState state,
  ) {
    if (state.isProcessing || state.messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final lastMsg = state.messages.last;
    if (lastMsg.role != ChatRole.assistant ||
        lastMsg.isLoading ||
        lastMsg.content.isEmpty) {
      return const SizedBox.shrink();
    }

    final replies = _parseQuickReplies(lastMsg.content);
    if (replies.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: replies.map((qr) {
          if (qr.isNumberInput) {
            return ActionChip(
              avatar: Icon(Icons.dialpad_rounded, size: 15, color: cs.primary),
              label: Text(
                qr.label,
                style: TextStyle(fontSize: 12, color: cs.primary),
              ),
              side: BorderSide(color: cs.primary.withOpacity(0.4)),
              backgroundColor: cs.primary.withOpacity(0.06),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onPressed: () => _openNumberInput(qr.label),
            );
          }
          return FilledButton.tonal(
            onPressed: () => _sendMessage(qr.value),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(0, 32),
              textStyle: const TextStyle(fontSize: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(qr.label),
          );
        }).toList(),
      ),
    );
  }

  // ── Number input field ──────────────────────────────
  Widget _buildNumberInput(
    ColorScheme cs,
    TextTheme tt,
    AiAssistantState state,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _numberController,
              focusNode: _numberFocusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendNumberValue(),
              style: tt.bodyMedium,
              decoration: InputDecoration(
                hintText: _numberInputLabel,
                hintStyle: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withOpacity(0.5),
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 4),
                  child: Text(
                    '\$',
                    style: tt.titleSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                filled: true,
                fillColor: cs.primary.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _sendNumberValue,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Enviar', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _showNumberInput = false),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ColorScheme cs, TextTheme tt, AiAssistantState state) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(
          children: [
            // Micrófono
            if (!kIsWeb)
              GestureDetector(
                onTap: state.isProcessing ? null : _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? cs.error.withOpacity(0.15)
                        : cs.surfaceContainerHighest,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: _isRecording ? cs.error : cs.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            if (!kIsWeb) const SizedBox(width: 8),

            // Campo de texto
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: !state.isProcessing && !_isRecording,
                textInputAction: TextInputAction.send,
                maxLines: 3,
                minLines: 1,
                onSubmitted: (_) => _sendMessage(),
                style: tt.bodyMedium,
                decoration: InputDecoration(
                  hintText: _isRecording ? 'Grabando…' : 'Pregunta algo…',
                  hintStyle: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Enviar
            GestureDetector(
              onTap: state.isProcessing || _isRecording
                  ? null
                  : () => _sendMessage(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: state.isProcessing || _isRecording
                      ? null
                      : LinearGradient(colors: [cs.primary, cs.tertiary]),
                  color: state.isProcessing || _isRecording
                      ? cs.onSurface.withOpacity(0.12)
                      : null,
                ),
                child: state.isProcessing
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : Icon(
                        Icons.arrow_upward_rounded,
                        color: state.isProcessing || _isRecording
                            ? cs.onSurface.withOpacity(0.3)
                            : Colors.white,
                        size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Quick reply model & parser ───────────────────────

class _QuickReply {
  final String label;
  final String value;
  final bool isNumberInput;

  const _QuickReply({
    required this.label,
    required this.value,
    this.isNumberInput = false,
  });
}

/// Parsea la respuesta del asistente y extrae opciones de respuesta rápida
List<_QuickReply> _parseQuickReplies(String content) {
  final replies = <_QuickReply>[];
  final lower = content.toLowerCase();

  void addIfNew(String label, String value, {bool isNum = false}) {
    if (!replies.any((r) => r.value == value && r.label == label)) {
      replies.add(
        _QuickReply(label: label, value: value, isNumberInput: isNum),
      );
    }
  }

  // ═══ 1. Confirmación explícita ═══
  if (lower.contains('¿confirmo esta acción') ||
      lower.contains('¿confirmo') ||
      lower.contains('¿confirmas') ||
      lower.contains('confirma para proceder') ||
      lower.contains('confirmar esta acción') ||
      lower.contains('¿deseas confirmar') ||
      lower.contains('¿procedemos') ||
      lower.contains('¿procedo')) {
    addIfNew('✅ Sí, confirmo', 'Sí, confirmo');
    addIfNew('❌ Cancelar', 'No, cancelar');
    return replies;
  }

  // ═══ 2. Formato estructurado: "• Opción" (viñetas) ═══
  final bulletRe = RegExp(
    r'[•\-]\s+([A-ZÁÉÍÓÚÑ][a-záéíóúñü\s\w]{2,40})\s*$',
    multiLine: true,
  );
  final bulletMatches = bulletRe.allMatches(content).toList();
  if (bulletMatches.isNotEmpty) {
    for (final m in bulletMatches) {
      final opt = m.group(1)!.trim();
      // No agregar si es parte del mapa de la app o descripción larga
      if (opt.length < 40 && !opt.contains(':')) {
        addIfNew(opt, opt);
      }
    }
  }

  // ═══ 3. "Ingresa el valor:" ═══
  if (RegExp(
    r'\*?\*?[Ii]ngresa\s+el\s+valor',
    caseSensitive: false,
  ).hasMatch(content)) {
    addIfNew('💲 Ingresar valor', '', isNum: true);
  }

  // ═══ 4. Extraer "X o Y" del texto libre ═══
  final orPatterns = [
    RegExp(
      r'(?:una?\s+)([a-záéíóúñü\s]{3,30}?)(?:\s*\([^)]+\))?\s+o\s+(?:una?\s+)([a-záéíóúñü\s]{3,30}?)(?:\s*\([^)]+\))?(?:\s*[.,?])',
      caseSensitive: false,
    ),
    RegExp(
      r'si\s+es\s+([a-záéíóúñü\s]{3,30}?)\s+o\s+([a-záéíóúñü\s]{3,30}?)(?:\s*[.,?;y]|\s+y\s)',
      caseSensitive: false,
    ),
  ];

  for (final re in orPatterns) {
    for (final match in re.allMatches(content)) {
      var a = match.group(1)?.trim() ?? '';
      var b = match.group(2)?.trim() ?? '';
      if (a.length > 2 && a.length < 35 && b.length > 2 && b.length < 35) {
        addIfNew(_capitalize(a), _capitalize(a));
        addIfNew(_capitalize(b), _capitalize(b));
      }
    }
  }

  // ═══ 5. Opciones numeradas "1. Texto" ═══
  final numberedRe = RegExp(r'(\d+)\.\s*[¿]?(.+?)(?:\n|$)');
  for (final match in numberedRe.allMatches(content)) {
    final q = match.group(2)?.trim() ?? '';
    if (q.isEmpty || q.length > 60) continue;

    // Si la línea parece una opción corta (no pregunta), agregarla directamente
    if (!q.contains('?') && q.length < 40) {
      addIfNew(q, q);
      continue;
    }

    // "X o Y" dentro de la línea
    final lineOr = RegExp(
      r'(?:como\s+)?(?:una?\s+)?([a-záéíóúñü\s]{3,30}?)\s+o\s+(?:una?\s+)?([a-záéíóúñü\s]{3,30}?)(?:\s*[.,?]|$)',
      caseSensitive: false,
    );
    final lineMatch = lineOr.firstMatch(q);
    if (lineMatch != null) {
      addIfNew(
        _capitalize(lineMatch.group(1)!.trim()),
        _capitalize(lineMatch.group(1)!.trim()),
      );
      addIfNew(
        _capitalize(lineMatch.group(2)!.trim()),
        _capitalize(lineMatch.group(2)!.trim()),
      );
      continue;
    }

    // Pregunta numérica
    if (RegExp(
      r'precio|monto|valor|cu[áa]nto|costo|tarifa|cantidad',
      caseSensitive: false,
    ).hasMatch(q)) {
      addIfNew('💲 Ingresar valor', '', isNum: true);
    }
  }

  // ═══ 6. Preguntas de precio/monto en texto libre ═══
  if (RegExp(
    r'cu[áa]l\s+es\s+el\s+precio|precio\s+unitario|cu[áa]nto\s+(cuesta|vale|cobra)',
    caseSensitive: false,
  ).hasMatch(lower)) {
    addIfNew('💲 Ingresar precio', '', isNum: true);
  }
  if (RegExp(
    r'cu[áa]nto\s+(pagó|pago|fue\s+el\s+monto)|monto\s+del\s+pago|valor\s+del',
    caseSensitive: false,
  ).hasMatch(lower)) {
    addIfNew('💲 Ingresar monto', '', isNum: true);
  }

  // ═══ 7. Contexto: Inventario/materiales ═══
  if (RegExp(
    r'inventario|material|stock|materia prima|producto terminado',
    caseSensitive: false,
  ).hasMatch(lower)) {
    if (lower.contains('entrada') ||
        lower.contains('agregar stock') ||
        lower.contains('salida') ||
        lower.contains('consumo')) {
      addIfNew(
        '📦 Entrada de inventario',
        'Entrada de inventario, agregar stock',
      );
      addIfNew('📤 Salida / Consumo', 'Salida de inventario, consumo');
    }
    if (lower.contains('materia prima') ||
        lower.contains('producto terminado')) {
      addIfNew('🔩 Materia prima', 'Es materia prima');
      addIfNew('📦 Producto terminado', 'Es producto terminado');
    }
  }

  // ═══ 8. Contexto: Proveedor ═══
  if (lower.contains('proveedor') &&
      RegExp(
        r'(?:hay|algún|cuál|qué)\s+proveedor|proveedor.{0,15}(?:relacionado|asociado)|si\s+hay',
        caseSensitive: false,
      ).hasMatch(lower)) {
    addIfNew('🏭 Sí, hay proveedor', 'Sí hay proveedor');
    addIfNew('🚫 Sin proveedor', 'No hay proveedor');
  }

  // ═══ 9. Contexto: Método de pago ═══
  if (lower.contains('método de pago') ||
      lower.contains('forma de pago') ||
      lower.contains('cómo pag')) {
    addIfNew('💵 Efectivo', 'Efectivo');
    addIfNew('🏦 Transferencia', 'Transferencia');
    addIfNew('💳 Tarjeta', 'Tarjeta');
    addIfNew('📝 Crédito', 'Crédito');
  }

  // ═══ 10. Sí/No genérico ═══
  if (!replies.any((r) => r.value == 'Sí') &&
      !replies.any((r) => r.value == 'Sí, confirmo')) {
    if (RegExp(
      r'¿[Mm]e puedes|¿[Pp]uedes confirmar|confirma\s+(si|estos|por favor)|¿[Dd]eseas|¿[Qq]uieres|¿[Tt]e gustaría|¿[Nn]ecesitas',
      caseSensitive: false,
    ).hasMatch(content)) {
      addIfNew('👍 Sí', 'Sí');
      addIfNew('👎 No', 'No');
    }
  }

  // ═══ 11. "Algo más" → sugerencias ═══
  if (lower.contains('algo más') ||
      lower.contains('algo mas') ||
      lower.contains('ayude con algo') ||
      lower.contains('puedo ayudarte')) {
    addIfNew('📊 Resumen del negocio', '¿Cómo va el negocio?');
    addIfNew('💰 Cuentas por cobrar', '¿Cuánto nos deben?');
    addIfNew('📦 Stock bajo', '¿Qué materiales están bajos de stock?');
  }

  return replies;
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

// ─── Slide-up animation wrapper ───────────────────────

class _SlideUpPanel extends StatefulWidget {
  final Widget child;
  const _SlideUpPanel({required this.child});

  @override
  State<_SlideUpPanel> createState() => _SlideUpPanelState();
}

class _SlideUpPanelState extends State<_SlideUpPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _slide, child: widget.child);
  }
}

// ─── Chat bubble (compacto) ───────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isUser = message.role == ChatRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cs.primary, cs.tertiary]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 13,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
              ),
              child: message.isLoading
                  ? _TypingDots(color: cs.onSurfaceVariant)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.audioTranscription != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic,
                                  size: 12,
                                  color: isUser
                                      ? cs.onPrimary.withOpacity(0.7)
                                      : cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Voz',
                                  style: tt.labelSmall?.copyWith(
                                    color: isUser
                                        ? cs.onPrimary.withOpacity(0.7)
                                        : cs.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SelectableText(
                          message.content,
                          style: tt.bodySmall?.copyWith(
                            color: isUser ? cs.onPrimary : cs.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Typing dots animation ───────────────────────────

class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 16,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) {
              final delay = i * 0.25;
              final t = (_ctrl.value - delay).clamp(0.0, 1.0);
              final y = -3.0 * (1 - (2 * t - 1) * (2 * t - 1));
              return Transform.translate(
                offset: Offset(0, y),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─── Pulsing recording dot ────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.5 + 0.5 * _ctrl.value),
          ),
        );
      },
    );
  }
}

// ─── Header icon button ──────────────────────────────

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(32, 32),
      ),
    );
  }
}
