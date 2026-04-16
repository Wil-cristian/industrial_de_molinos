import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../domain/entities/conversation.dart';

class ConversationList extends StatelessWidget {
  final List<Conversation> conversations;
  final Conversation? selected;
  final void Function(Conversation) onSelect;
  final VoidCallback? onNewRequest;
  final bool isLoading;

  const ConversationList({
    super.key,
    required this.conversations,
    this.selected,
    required this.onSelect,
    this.onNewRequest,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.sm, AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.forum_rounded, color: colors.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Conversaciones',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: onNewRequest,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nueva'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  minimumSize: const Size(0, 36),
                  textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              filled: true,
              fillColor: colors.surfaceContainerHighest.withOpacity(0.4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppShapes.xl),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppShapes.xl),
                borderSide: BorderSide.none,
              ),
            ),
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Lista
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : conversations.isEmpty
                  ? _buildEmpty(theme, colors)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        return _ConversationTile(
                          conversation: conversations[index],
                          isSelected: selected?.id == conversations[index].id,
                          onTap: () => onSelect(conversations[index]),
                          index: index,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme, ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 56,
              color: colors.onSurfaceVariant.withOpacity(0.3),
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              'Sin conversaciones',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Crea una nueva conversación\npara empezar',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final int index;

  const _ConversationTile({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.index,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.medium,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.standard),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standardDecelerate,
    ));
    Future.delayed(Duration(milliseconds: 40 * widget.index.clamp(0, 12)), () {
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
    final c = widget.conversation;

    final statusColor = _getStatusColor(c.status);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colors.primaryContainer.withOpacity(0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppShapes.md),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppShapes.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppShapes.md),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      // Ícono tipo
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppShapes.md),
                        ),
                        child: Icon(c.typeIcon, size: 20, color: statusColor),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Texto
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c.isGroup ? c.title : (c.otherParticipantName ?? c.title),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: c.unreadCount > 0
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (c.lastMessageAt != null)
                                  Text(
                                    _formatTime(c.lastMessageAt!),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onSurfaceVariant.withOpacity(0.5),
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                // Status chip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(AppShapes.xs),
                                  ),
                                  child: Text(
                                    c.statusLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: statusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (c.isGroup) ...[
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    '${c.participantCount} miembros',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onSurfaceVariant.withOpacity(0.55),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: AppSpacing.xs),
                                // Preview mensaje
                                Expanded(
                                  child: Text(
                                    c.lastMessage ?? c.creatorName ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                                // Badge unread
                                if (c.unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${c.unreadCount}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colors.onPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('dd/MM').format(local);
  }
}
