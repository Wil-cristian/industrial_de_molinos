import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../domain/entities/conversation_message.dart';

class MessageBubble extends StatefulWidget {
  final ConversationMessage message;
  final bool isMe;
  final bool showSender;
  final int index;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSender = true,
    this.index = 0,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.medium,
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standardDecelerate,
    ));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.standard),
    );
    // Stagger basado en index para la carga inicial
    Future.delayed(Duration(milliseconds: 30 * widget.index.clamp(0, 10)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Mensaje del sistema (aprobación, rechazo, etc.)
    if (widget.message.isSystem) {
      return _buildSystemMessage(context);
    }

    final isAiResponse = widget.message.messageType == MessageType.aiResponse;
    final isMe = isAiResponse ? false : widget.isMe;
    final bubbleColor = isAiResponse
        ? const Color(0xFFF3E5F5)
        : isMe
            ? colors.primaryContainer
            : colors.surfaceContainerLowest;
    final textColor = isAiResponse
        ? const Color(0xFF6A1B9A)
        : isMe
            ? colors.onPrimaryContainer
            : colors.onSurface;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: alignment,
            children: [
              // Nombre del remitente
              if (widget.showSender && !isMe)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xs,
                    bottom: AppSpacing.xxs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAiResponse) ...[
                        const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF8E24AA)),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        isAiResponse ? 'Asistente IA' : (widget.message.senderName ?? 'Usuario'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isAiResponse ? const Color(0xFF8E24AA) : colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              // Burbuja
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _formatTime(widget.message.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textColor.withOpacity(0.5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final content = widget.message.content;
    final isApproved = content.contains('✅');
    final isRejected = content.contains('❌');

    final Color bgColor;
    final Color textColor;
    final IconData icon;
    if (isApproved) {
      bgColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
      icon = Icons.check_circle_rounded;
    } else if (isRejected) {
      bgColor = const Color(0xFFFFEBEE);
      textColor = const Color(0xFFC62828);
      icon = Icons.cancel_rounded;
    } else {
      bgColor = colors.surfaceContainerHighest.withOpacity(0.5);
      textColor = colors.onSurfaceVariant;
      icon = Icons.info_outline_rounded;
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.sm,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppShapes.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: textColor),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    content,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateFormat('h:mm a').format(local);
  }
}
