import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/chat_provider.dart';
import '../../../data/providers/role_provider.dart';
import '../../../data/datasources/supabase_datasource.dart';
import '../../../domain/entities/conversation.dart';
import 'message_bubble.dart';
import 'approval_card.dart';

class ChatDetail extends ConsumerStatefulWidget {
  final Conversation conversation;
  final VoidCallback? onBack;

  const ChatDetail({
    super.key,
    required this.conversation,
    this.onBack,
  });

  @override
  ConsumerState<ChatDetail> createState() => _ChatDetailState();
}

class _ChatDetailState extends ConsumerState<ChatDetail> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppMotion.medium,
          curve: AppMotion.standardDecelerate,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final chatState = ref.watch(chatProvider);
    final roleState = ref.watch(roleProvider);
    final currentUserId = SupabaseDataSource.currentUser?.id;
    final canResolve = roleState.isAdmin || roleState.isDueno || roleState.isTecnico;

    // Scroll al fondo cuando hay nuevos mensajes
    if (chatState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Column(
      children: [
        // Header de la conversación
        _buildHeader(theme, colors),
        const Divider(height: 1),
        // Mensajes
        Expanded(
          child: chatState.isLoadingMessages
              ? const Center(child: CircularProgressIndicator.adaptive())
              : _buildMessageList(
                  theme, colors, chatState, currentUserId, canResolve),
        ),
        // Input
        if (widget.conversation.status != ConversationStatus.closed)
          _buildInput(theme, colors, chatState),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colors) {
    final c = widget.conversation;
    final statusColor = _getStatusColor(c.status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button (mobile)
          if (widget.onBack != null)
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size(36, 36),
              ),
            ),
          if (widget.onBack != null) const SizedBox(width: AppSpacing.xs),
          // Ícono tipo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppShapes.md),
            ),
            child: Icon(c.typeIcon, size: 20, color: statusColor),
          ),
          const SizedBox(width: AppSpacing.md),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.isGroup ? c.title : (c.otherParticipantName ?? c.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      c.isGroup
                          ? '${c.typeLabel} · ${c.participantCount} miembros'
                          : '${c.typeLabel} · ${c.statusLabel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(
    ThemeData theme,
    ColorScheme colors,
    ChatState chatState,
    String? currentUserId,
    bool canResolve,
  ) {
    final messages = chatState.messages;
    final approval = chatState.currentApproval;

    if (messages.isEmpty && approval == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                chatState.error != null ? Icons.error_outline_rounded : Icons.chat_bubble_outline_rounded,
                size: 42,
                color: colors.onSurfaceVariant.withOpacity(0.45),
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                chatState.error != null ? 'No se pudieron cargar los mensajes' : 'Aún no hay mensajes visibles',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                chatState.error ?? 'Escribe el primer mensaje para iniciar la conversación.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: messages.length + (approval != null ? 1 : 0),
      itemBuilder: (context, index) {
        // La approval card va al tope
        if (approval != null && index == 0) {
          return ApprovalCard(
            approval: approval,
            canResolve: canResolve,
            onApprove: (notes) async {
              final success = await ref.read(chatProvider.notifier).approveRequest(notes: notes);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Solicitud aprobada'),
                    backgroundColor: Color(0xFF2E7D32),
                  ),
                );
              }
            },
            onReject: (notes) async {
              final success = await ref.read(chatProvider.notifier).rejectRequest(notes: notes);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Solicitud rechazada'),
                    backgroundColor: Color(0xFFC62828),
                  ),
                );
              }
            },
          );
        }

        final msgIndex = approval != null ? index - 1 : index;
        final message = messages[msgIndex];
        final isMe = message.senderId == currentUserId;

        return MessageBubble(
          message: message,
          isMe: isMe,
          index: msgIndex,
        );
      },
    );
  }

  Widget _buildInput(ThemeData theme, ColorScheme colors, ChatState chatState) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(AppShapes.xl),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.sm,
                  ),
                ),
                style: theme.textTheme.bodyMedium,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (!widget.conversation.isAiChat) ...[
            IconButton(
              onPressed: chatState.isSending ? null : _askAiFromInput,
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF3E5F5),
                foregroundColor: const Color(0xFF8E24AA),
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppShapes.md),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          AnimatedContainer(
            duration: AppMotion.fast,
            child: IconButton.filled(
              onPressed: chatState.isSending ? null : _sendMessage,
              icon: chatState.isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      widget.conversation.isAiChat
                          ? Icons.auto_awesome_rounded
                          : Icons.send_rounded,
                      size: 20,
                    ),
              style: IconButton.styleFrom(
                backgroundColor: widget.conversation.isAiChat
                    ? const Color(0xFF8E24AA)
                    : colors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppShapes.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    if (widget.conversation.isAiChat) {
      ref.read(chatProvider.notifier).askAi(text);
    } else {
      ref.read(chatProvider.notifier).sendMessage(text);
    }
    _focusNode.requestFocus();
  }

  void _askAiFromInput() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    ref.read(chatProvider.notifier).askAi(text);
    _focusNode.requestFocus();
  }

  Color _getStatusColor(ConversationStatus status) {
    switch (status) {
      case ConversationStatus.pending:
        return const Color(0xFFF9A825);
      case ConversationStatus.approved:
        return AppColors.success;
      case ConversationStatus.rejected:
        return AppColors.danger;
      case ConversationStatus.open:
        return AppColors.info;
      case ConversationStatus.closed:
        return Colors.grey;
    }
  }
}
