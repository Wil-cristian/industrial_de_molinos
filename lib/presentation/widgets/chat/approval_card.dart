import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/approval_request.dart';

class ApprovalCard extends StatefulWidget {
  final ApprovalRequest approval;
  final bool canResolve;
  final void Function(String? notes)? onApprove;
  final void Function(String? notes)? onReject;

  const ApprovalCard({
    super.key,
    required this.approval,
    this.canResolve = false,
    this.onApprove,
    this.onReject,
  });

  @override
  State<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<ApprovalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  final _notesController = TextEditingController();
  bool _showNotes = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.mediumSlow,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.standardDecelerate),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final a = widget.approval;

    // Colores según estado
    Color cardColor;
    Color accentColor;
    IconData statusIcon;
    String statusLabel;

    switch (a.status) {
      case ApprovalStatus.pending:
        cardColor = const Color(0xFFFFF8E1);
        accentColor = const Color(0xFFF9A825);
        statusIcon = Icons.schedule_rounded;
        statusLabel = 'Pendiente';
        break;
      case ApprovalStatus.approved:
        cardColor = const Color(0xFFE8F5E9);
        accentColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Aprobado';
        break;
      case ApprovalStatus.rejected:
        cardColor = const Color(0xFFFFEBEE);
        accentColor = AppColors.danger;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'Rechazado';
        break;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        child: AnimatedContainer(
          duration: AppMotion.mediumSlow,
          curve: AppMotion.standard,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppShapes.lg),
            border: Border.all(
              color: accentColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(theme, accentColor, statusIcon, statusLabel),
              const Divider(height: 1, indent: AppSpacing.base, endIndent: AppSpacing.base),
              // Body según tipo
              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: _buildBody(theme, colors),
              ),
              // Notas del aprobador
              if (a.notes != null && a.notes!.isNotEmpty)
                _buildResolverNotes(theme, colors),
              // Botones de acción
              if (widget.canResolve && a.isPending)
                _buildActions(theme, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color accentColor, IconData icon, String label) {
    final a = widget.approval;
    final typeLabel = _getTypeLabel(a.requestType);
    final typeIcon = _getTypeIcon(a.requestType);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppShapes.sm),
            ),
            child: Icon(typeIcon, size: 20, color: accentColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(icon, size: 14, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _formatDate(a.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colors) {
    final a = widget.approval;
    switch (a.requestType) {
      case ApprovalRequestType.transfer:
        return _buildTransferBody(theme, colors, a);
      case ApprovalRequestType.materialPurchase:
        return _buildPurchaseBody(theme, colors, a);
      case ApprovalRequestType.expense:
        return _buildExpenseBody(theme, colors, a);
      case ApprovalRequestType.general:
        return _buildGeneralBody(theme, colors, a);
    }
  }

  Widget _buildTransferBody(ThemeData theme, ColorScheme colors, ApprovalRequest a) {
    return Column(
      children: [
        // De → A
        Row(
          children: [
            Expanded(
              child: _accountChip(
                theme, colors,
                icon: Icons.account_balance_wallet_rounded,
                label: a.fromAccountName ?? 'Origen',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Icon(Icons.arrow_forward_rounded, color: colors.primary, size: 20),
            ),
            Expanded(
              child: _accountChip(
                theme, colors,
                icon: Icons.account_balance_wallet_rounded,
                label: a.toAccountName ?? 'Destino',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Monto
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppShapes.sm),
          ),
          child: Column(
            children: [
              Text('Monto', style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              )),
              const SizedBox(height: 4),
              Text(
                '\$${_formatNumber(a.transferAmount ?? 0)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
        if (a.reason != null && a.reason!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _infoRow(theme, Icons.notes_rounded, 'Razón', a.reason!),
        ],
      ],
    );
  }

  Widget _buildPurchaseBody(ThemeData theme, ColorScheme colors, ApprovalRequest a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (a.supplier != null)
          _infoRow(theme, Icons.store_rounded, 'Proveedor', a.supplier!),
        const SizedBox(height: AppSpacing.sm),
        // Lista de materiales
        ...a.materials.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              Icon(Icons.inventory_2_rounded, size: 16, color: colors.primary.withOpacity(0.6)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${m['name']} × ${m['quantity']} ${m['unit'] ?? ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (m['estimated_price'] != null)
                Text(
                  '\$${_formatNumber((m['estimated_price'] as num).toDouble())}',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
            ],
          ),
        )),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppShapes.sm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Estimado', style: theme.textTheme.labelMedium),
              Text(
                '\$${_formatNumber(a.totalEstimated ?? 0)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
        if (a.urgency != null && a.urgency != 'normal') ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppShapes.xs),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.priority_high_rounded, size: 14, color: AppColors.danger),
                const SizedBox(width: 4),
                Text(
                  'Urgente',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExpenseBody(ThemeData theme, ColorScheme colors, ApprovalRequest a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(theme, Icons.description_rounded, 'Descripción', a.description ?? ''),
        const SizedBox(height: AppSpacing.sm),
        if (a.category != null)
          _infoRow(theme, Icons.category_rounded, 'Categoría', a.category!),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppShapes.sm),
          ),
          child: Column(
            children: [
              Text('Monto', style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              )),
              const SizedBox(height: 4),
              Text(
                '\$${_formatNumber(a.expenseAmount ?? 0)}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralBody(ThemeData theme, ColorScheme colors, ApprovalRequest a) {
    final desc = a.requestData['description'] as String? ?? '';
    return Text(desc, style: theme.textTheme.bodyMedium);
  }

  Widget _buildResolverNotes(ThemeData theme, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(AppShapes.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.comment_rounded, size: 14, color: colors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                widget.approval.notes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.base),
      child: Column(
        children: [
          // Toggle notas
          if (!_showNotes)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _showNotes = true),
                icon: const Icon(Icons.add_comment_rounded, size: 16),
                label: const Text('Agregar nota'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.onSurfaceVariant,
                  textStyle: theme.textTheme.labelSmall,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                ),
              ),
            ),
          if (_showNotes) ...[
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Nota opcional...',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppShapes.sm),
                ),
              ),
              maxLines: 2,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => widget.onReject?.call(
                    _notesController.text.isEmpty ? null : _notesController.text,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Rechazar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppShapes.sm),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => widget.onApprove?.call(
                    _notesController.text.isEmpty ? null : _notesController.text,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Aprobar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppShapes.sm),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================== HELPERS =====================

  Widget _accountChip(ThemeData theme, ColorScheme colors, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppShapes.sm),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
        const SizedBox(width: AppSpacing.sm),
        Text('$label: ', style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
        Expanded(
          child: Text(value, style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          )),
        ),
      ],
    );
  }

  String _getTypeLabel(ApprovalRequestType type) {
    switch (type) {
      case ApprovalRequestType.transfer:
        return 'SOLICITUD DE TRASLADO';
      case ApprovalRequestType.materialPurchase:
        return 'COMPRA DE MATERIALES';
      case ApprovalRequestType.expense:
        return 'APROBACIÓN DE GASTO';
      case ApprovalRequestType.general:
        return 'SOLICITUD GENERAL';
    }
  }

  IconData _getTypeIcon(ApprovalRequestType type) {
    switch (type) {
      case ApprovalRequestType.transfer:
        return Icons.swap_horiz_rounded;
      case ApprovalRequestType.materialPurchase:
        return Icons.shopping_cart_rounded;
      case ApprovalRequestType.expense:
        return Icons.receipt_long_rounded;
      case ApprovalRequestType.general:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    return DateFormat('dd/MM').format(local);
  }

  String _formatNumber(double value) {
    final intVal = value.toInt();
    return intVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }
}
