import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/responsive/responsive_helper.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_motion.dart';
import '../../data/providers/chat_provider.dart';
import '../widgets/chat/conversation_list.dart';
import '../widgets/chat/chat_detail.dart';
import '../widgets/chat/new_request_sheet.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  bool _showDetail = false; // solo para mobile

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: AppMotion.medium,
      vsync: this,
    )..forward();
    // Cargar conversaciones
    Future.microtask(() {
      ref.read(chatProvider.notifier).loadConversations();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final chatState = ref.watch(chatProvider);

    return FadeTransition(
      opacity: _fadeController,
      child: isMobile
          ? _buildMobileLayout(chatState)
          : _buildDesktopLayout(chatState),
    );
  }

  // ===================== DESKTOP/TABLET — MASTER-DETAIL =====================

  Widget _buildDesktopLayout(ChatState chatState) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        // Panel izquierdo — lista de conversaciones
        SizedBox(
          width: 340,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                right: BorderSide(
                  color: colors.outlineVariant.withOpacity(0.3),
                ),
              ),
            ),
            child: ConversationList(
              conversations: chatState.conversations,
              selected: chatState.selectedConversation,
              isLoading: chatState.isLoadingConversations,
              onSelect: (c) => ref.read(chatProvider.notifier).selectConversation(c),
              onNewRequest: () => NewRequestSheet.show(context),
            ),
          ),
        ),
        // Panel derecho — detalle de conversación
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.medium,
            child: chatState.selectedConversation != null
                ? ChatDetail(
                    key: ValueKey(chatState.selectedConversation!.id),
                    conversation: chatState.selectedConversation!,
                  )
                : _buildEmptyDetail(theme, colors),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDetail(ThemeData theme, ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forum_rounded,
              size: 36,
              color: colors.primary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Selecciona una conversación',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'o crea una nueva solicitud',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== MOBILE — STACKED =====================

  Widget _buildMobileLayout(ChatState chatState) {
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      transitionBuilder: (child, animation) {
        final isDetail = child is ChatDetail;
        final slide = Tween<Offset>(
          begin: Offset(isDetail ? 1 : -1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: AppMotion.standardDecelerate,
        ));
        return SlideTransition(
          position: slide,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _showDetail && chatState.selectedConversation != null
          ? ChatDetail(
              key: ValueKey('detail_${chatState.selectedConversation!.id}'),
              conversation: chatState.selectedConversation!,
              onBack: () {
                ref.read(chatProvider.notifier).clearSelection();
                setState(() => _showDetail = false);
              },
            )
          : ConversationList(
              key: const ValueKey('list'),
              conversations: chatState.conversations,
              isLoading: chatState.isLoadingConversations,
              onSelect: (c) {
                ref.read(chatProvider.notifier).selectConversation(c);
                setState(() => _showDetail = true);
              },
              onNewRequest: () => NewRequestSheet.show(context),
            ),
    );
  }
}
