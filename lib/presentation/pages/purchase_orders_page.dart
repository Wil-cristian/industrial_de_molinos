import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../data/datasources/supplier_materials_datasource.dart';
import '../../data/providers/purchase_orders_provider.dart';
import '../../data/providers/suppliers_provider.dart';
import '../../data/providers/providers.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/cash_movement.dart';
import '../../domain/entities/purchase_order.dart';
import '../../core/utils/colombia_time.dart';

class PurchaseOrdersPage extends ConsumerStatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  ConsumerState<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends ConsumerState<PurchaseOrdersPage> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(purchaseOrdersProvider.notifier).loadOrders();
      ref.read(suppliersProvider.notifier).loadSuppliers();
      ref.read(inventoryProvider.notifier).loadMaterials();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(purchaseOrdersProvider);
    final orders = _statusFilter == null
        ? state.orders
        : state.orders.where((o) => o.status.name == _statusFilter).toList();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final pendingCount = state.orders
                      .where(
                        (o) =>
                            o.status == PurchaseOrderStatus.borrador ||
                            o.status == PurchaseOrderStatus.enviada,
                      )
                      .length
                      .toString();
                  final totalDebt = Formatters.currency(
                    state.orders
                        .where(
                          (o) =>
                              o.paymentStatus != PaymentStatus.pagada &&
                              o.status != PurchaseOrderStatus.cancelada,
                        )
                        .fold(0.0, (sum, o) => sum + o.balance),
                  );

                  if (constraints.maxWidth < 600) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${state.orders.length} órdenes de compra',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            _buildQuickStat(
                              'Pendientes',
                              pendingCount,
                              AppColors.warning,
                              Icons.pending_actions,
                            ),
                            const SizedBox(width: 8),
                            _buildQuickStat(
                              'Total Adeudado',
                              totalDebt,
                              AppColors.danger,
                              Icons.money_off,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _showCreateOrderDialog(),
                            icon: const Icon(Icons.add_shopping_cart, size: 18),
                            label: const Text('Nueva Orden'),
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Text(
                        '${state.orders.length} órdenes de compra',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      _buildQuickStat(
                        'Pendientes',
                        pendingCount,
                        AppColors.warning,
                        Icons.pending_actions,
                      ),
                      const SizedBox(width: 12),
                      _buildQuickStat(
                        'Total Adeudado',
                        totalDebt,
                        AppColors.danger,
                        Icons.money_off,
                      ),
                      const SizedBox(width: 16),
                      FilledButton.icon(
                        onPressed: () => _showCreateOrderDialog(),
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('Nueva Orden'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              // Filtros
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildFilterChip('Todas', null),
                  _buildFilterChip('Borrador', 'borrador'),
                  _buildFilterChip('Enviadas', 'enviada'),
                  _buildFilterChip('Recibidas', 'recibida'),
                  _buildFilterChip('Canceladas', 'cancelada'),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(purchaseOrdersProvider.notifier).loadOrders(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Lista
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.danger.withOpacity(0.6),
                      ),
                      const SizedBox(height: 8),
                      Text('Error: ${state.error}'),
                      TextButton(
                        onPressed: () => ref
                            .read(purchaseOrdersProvider.notifier)
                            .loadOrders(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : orders.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: orders.length,
                  itemBuilder: (context, index) =>
                      _buildOrderCard(orders[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String? status) {
    final isSelected = _statusFilter == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _statusFilter = status),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay órdenes de compra',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea una orden para solicitar materiales a tus proveedores',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(PurchaseOrder order) {
    final statusColor = _getStatusColor(order.status);
    final paymentColor = _getPaymentColor(order.paymentStatus);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOrderDetailDialog(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono estado
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getStatusIcon(order.status),
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          order.orderNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.status.display,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.supplierName ?? 'Sin proveedor',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${order.itemCount} ítems • ${Formatters.dateShort(order.createdAt)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Total y pago
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(order.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: paymentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.paymentStatus.display,
                      style: TextStyle(
                        color: paymentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (order.balance > 0)
                    Text(
                      'Debe: ${Formatters.currency(order.balance)}',
                      style: TextStyle(color: AppColors.danger, fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================
  // DIÁLOGO: Crear nueva orden
  // ============================
  void _showCreateOrderDialog() {
    String? selectedSupplierId;
    String? notes;
    DateTime? expectedDate;

    showDialog(
      context: context,
      builder: (ctx) {
        final suppState = ref.read(suppliersProvider);
        final suppliers = suppState.suppliers;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.add_shopping_cart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8),
                Text('Nueva Orden de Compra'),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSupplierId,
                    decoration: const InputDecoration(
                      labelText: 'Proveedor *',
                      prefixIcon: Icon(Icons.local_shipping),
                    ),
                    isExpanded: true,
                    items: suppliers
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedSupplierId = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                    onChanged: (v) => notes = v,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      expectedDate != null
                          ? Formatters.dateShort(expectedDate!)
                          : 'Fecha esperada de entrega',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: ColombiaTime.now().add(
                            const Duration(days: 7),
                          ),
                          firstDate: ColombiaTime.now(),
                          lastDate: ColombiaTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setDialogState(() => expectedDate = picked);
                        }
                      },
                      child: const Text('Seleccionar'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: selectedSupplierId == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        try {
                          final orderNumber = await ref
                              .read(purchaseOrdersProvider.notifier)
                              .generateOrderNumber();

                          final order = PurchaseOrder(
                            id: '',
                            orderNumber: orderNumber,
                            supplierId: selectedSupplierId!,
                            notes: notes,
                            expectedDate: expectedDate,
                            createdAt: ColombiaTime.now(),
                            updatedAt: ColombiaTime.now(),
                          );

                          final created = await ref
                              .read(purchaseOrdersProvider.notifier)
                              .createOrder(order);

                          if (created != null && mounted) {
                            _showOrderDetailDialog(created);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        }
                      },
                child: const Text('Crear Orden'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================
  // DIÁLOGO: Detalle de orden
  // ============================
  void _showOrderDetailDialog(PurchaseOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => _OrderDetailDialog(
        order: order,
        onRefresh: () {
          ref.read(purchaseOrdersProvider.notifier).loadOrders();
        },
      ),
    );
  }

  Widget _buildQuickStat(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.borrador:
        return const Color(0xFF9E9E9E);
      case PurchaseOrderStatus.enviada:
        return AppColors.info;
      case PurchaseOrderStatus.parcial:
        return AppColors.warning;
      case PurchaseOrderStatus.recibida:
        return AppColors.success;
      case PurchaseOrderStatus.cancelada:
        return AppColors.danger;
    }
  }

  Color _getPaymentColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pendiente:
        return AppColors.warning;
      case PaymentStatus.parcial:
        return AppColors.info;
      case PaymentStatus.pagada:
        return AppColors.success;
    }
  }

  IconData _getStatusIcon(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.borrador:
        return Icons.edit_note;
      case PurchaseOrderStatus.enviada:
        return Icons.send;
      case PurchaseOrderStatus.parcial:
        return Icons.inventory;
      case PurchaseOrderStatus.recibida:
        return Icons.check_circle;
      case PurchaseOrderStatus.cancelada:
        return Icons.cancel;
    }
  }
}

// ====================================
// WIDGET: Detalle de Orden (Dialog)
// ====================================
class _OrderDetailDialog extends ConsumerStatefulWidget {
  final PurchaseOrder order;
  final VoidCallback onRefresh;

  const _OrderDetailDialog({required this.order, required this.onRefresh});

  @override
  ConsumerState<_OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends ConsumerState<_OrderDetailDialog> {
  late PurchaseOrder _order;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  Future<void> _refreshOrder() async {
    final state = ref.read(purchaseOrdersProvider);
    final updated = state.orders.where((o) => o.id == _order.id);
    if (updated.isNotEmpty) {
      setState(() => _order = updated.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read current state (no reactive watch in dialog)
    final state = ref.read(purchaseOrdersProvider);
    final current = state.orders.where((o) => o.id == _order.id);
    if (current.isNotEmpty && current.first != _order) {
      _order = current.first;
    }

    final statusColor = _getStatusColor(_order.status);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.receipt_long, color: statusColor),
          const SizedBox(width: 8),
          Text(_order.orderNumber),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _order.status.display,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info de la orden
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Proveedor',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _order.supplierName ?? '—',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fecha',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          Formatters.dateShort(_order.createdAt),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Entrega esperada',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _order.expectedDate != null
                              ? Formatters.dateShort(_order.expectedDate!)
                              : '—',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Acciones
            Row(
              children: [
                const Text(
                  'Ítems del pedido',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                if (_order.status.isEditable)
                  TextButton.icon(
                    onPressed: _showAddItemDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar Material'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Lista de ítems
            Expanded(
              child: _order.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 40,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sin ítems — agrega materiales a esta orden',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _order.items.length,
                      itemBuilder: (ctx, i) => _buildItemTile(_order.items[i]),
                    ),
            ),
            const Divider(),
            // Totales
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTotalRow('Subtotal', _order.subtotal),
                        if (_order.taxAmount > 0)
                          _buildTotalRow('IVA', _order.taxAmount),
                        if (_order.discountAmount > 0)
                          _buildTotalRow('Descuento', -_order.discountAmount),
                        const Divider(),
                        _buildTotalRow('Total', _order.total, isBold: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTotalRow(
                          'Pagado',
                          _order.amountPaid,
                          color: AppColors.success,
                        ),
                        _buildTotalRow(
                          'Pendiente',
                          _order.balance,
                          color: AppColors.danger,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Acciones según estado
        if (_order.status == PurchaseOrderStatus.borrador) ...[
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(purchaseOrdersProvider.notifier)
                  .deleteOrder(_order.id);
              widget.onRefresh();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
          FilledButton.icon(
            onPressed: _order.items.isEmpty
                ? null
                : () async {
                    await ref
                        .read(purchaseOrdersProvider.notifier)
                        .updateStatus(_order.id, PurchaseOrderStatus.enviada);
                    widget.onRefresh();
                    await _refreshOrder();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Orden enviada'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Enviar'),
          ),
        ],
        if (_order.status.canReceive) ...[
          FilledButton.icon(
            onPressed: () async {
              await ref
                  .read(purchaseOrdersProvider.notifier)
                  .updateStatus(_order.id, PurchaseOrderStatus.recibida);
              widget.onRefresh();
              await _refreshOrder();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Orden recibida — Stock actualizado'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Marcar Recibida'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
          ),
        ],
        if (_order.balance > 0 &&
            _order.status != PurchaseOrderStatus.cancelada)
          OutlinedButton.icon(
            onPressed: () => _showPaymentDialog(),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Pagar'),
          ),
        if (_order.status != PurchaseOrderStatus.cancelada &&
            _order.status != PurchaseOrderStatus.recibida)
          TextButton(
            onPressed: () async {
              await ref
                  .read(purchaseOrdersProvider.notifier)
                  .updateStatus(_order.id, PurchaseOrderStatus.cancelada);
              widget.onRefresh();
              await _refreshOrder();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cancelar Orden'),
          ),
        if (_order.status == PurchaseOrderStatus.cancelada)
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar Orden'),
                  content: Text(
                    '¿Eliminar permanentemente ${_order.orderNumber}?\n'
                    'Esta acción no se puede deshacer.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('No'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      child: const Text('Sí, Eliminar'),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                Navigator.pop(context);
                await ref
                    .read(purchaseOrdersProvider.notifier)
                    .deleteOrder(_order.id);
                widget.onRefresh();
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Eliminar'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildItemTile(PurchaseOrderItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.inventory,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          item.materialName ?? 'Material',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        subtitle: Text(
          '${item.quantity} ${item.unit} × ${Formatters.currency(item.unitPrice)}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Formatters.currency(item.subtotal),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (_order.status.isEditable) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.edit,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => _showEditItemDialog(item),
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 16, color: AppColors.danger),
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await ref
                      .read(purchaseOrdersProvider.notifier)
                      .deleteItem(item.id, _order.id);
                  await _refreshOrder();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color ?? Theme.of(context).colorScheme.onSurface,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          Text(
            Formatters.currency(amount),
            style: TextStyle(
              color: color ?? Theme.of(context).colorScheme.onSurface,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================
  // DIÁLOGO: Agregar ítem
  // ============================
  void _showAddItemDialog() async {
    String? selectedMaterialId;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: '0');
    String unit = 'UND';
    bool showAllMaterials = false;

    // Cargar materiales vinculados al proveedor
    final supplierMats = await SupplierMaterialsDataSource.getBySupplier(
      _order.supplierId,
    );
    final supplierMaterialIds = supplierMats.map((sm) => sm.materialId).toSet();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final materialsState = ref.read(inventoryProvider);
        final allMaterials = materialsState.materials;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Materiales del proveedor (vinculados)
            final linkedMaterials = allMaterials
                .where((m) => supplierMaterialIds.contains(m.id))
                .toList();
            // Materiales no vinculados
            final otherMaterials = allMaterials
                .where((m) => !supplierMaterialIds.contains(m.id))
                .toList();

            // Construir lista de items para el dropdown
            final List<DropdownMenuItem<String>> dropdownItems = [];

            if (linkedMaterials.isNotEmpty) {
              // Header para materiales del proveedor
              dropdownItems.add(
                DropdownMenuItem(
                  enabled: false,
                  value: '__header_linked__',
                  child: Text(
                    '── Materiales del proveedor ──',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );

              for (final m in linkedMaterials) {
                final sm = supplierMats.firstWhere((s) => s.materialId == m.id);
                dropdownItems.add(
                  DropdownMenuItem(
                    value: m.id,
                    child: Row(
                      children: [
                        Icon(Icons.star, size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${m.code} — ${m.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          Formatters.currency(sm.effectivePrice),
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }

            if (showAllMaterials && otherMaterials.isNotEmpty) {
              dropdownItems.add(
                DropdownMenuItem(
                  enabled: false,
                  value: '__header_other__',
                  child: Text(
                    '── Otros materiales ──',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );

              for (final m in otherMaterials) {
                dropdownItems.add(
                  DropdownMenuItem(
                    value: m.id,
                    child: Text(
                      '${m.code} — ${m.name}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.add_circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: 8),
                  Text('Agregar Material'),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (linkedMaterials.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.warning,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Este proveedor no tiene materiales vinculados. '
                                'Vincula materiales desde Materiales o selecciona uno abajo.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Selector de material
                    DropdownButtonFormField<String>(
                      value: selectedMaterialId,
                      decoration: const InputDecoration(
                        labelText: 'Material *',
                        prefixIcon: Icon(Icons.inventory),
                      ),
                      isExpanded: true,
                      items: linkedMaterials.isEmpty
                          ? allMaterials
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m.id,
                                    child: Text(
                                      '${m.code} — ${m.name}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList()
                          : dropdownItems,
                      onChanged: (v) async {
                        if (v == null || v.startsWith('__header')) return;
                        setDialogState(() => selectedMaterialId = v);
                        // Buscar precio del proveedor para este material
                        final material = allMaterials.firstWhere(
                          (m) => m.id == v,
                        );
                        unit = material.unit;

                        // Intentar obtener precio de supplier_materials
                        final sm = supplierMats.where((s) => s.materialId == v);
                        if (sm.isNotEmpty) {
                          priceCtrl.text = sm.first.effectivePrice
                              .toStringAsFixed(2);
                        } else {
                          final price = await ref
                              .read(supplierMaterialsProvider.notifier)
                              .getPrice(_order.supplierId, v);
                          if (price != null) {
                            priceCtrl.text = price.toStringAsFixed(2);
                          } else if (material.costPrice > 0) {
                            priceCtrl.text = material.costPrice.toStringAsFixed(
                              2,
                            );
                          }
                        }
                        setDialogState(() {});
                      },
                    ),
                    // Botón para mostrar todos los materiales
                    if (linkedMaterials.isNotEmpty && !showAllMaterials)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          onPressed: () =>
                              setDialogState(() => showAllMaterials = true),
                          icon: const Icon(Icons.expand_more, size: 16),
                          label: Text(
                            'Mostrar todos los materiales (${otherMaterials.length})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            decoration: InputDecoration(
                              labelText: 'Cantidad ($unit)',
                              prefixIcon: const Icon(Icons.numbers),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Precio Unitario (\$)',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Preview subtotal
                    if (selectedMaterialId != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:'),
                            Text(
                              Formatters.currency(
                                (double.tryParse(qtyCtrl.text) ?? 0) *
                                    (double.tryParse(priceCtrl.text) ?? 0),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: selectedMaterialId == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          final qty = double.tryParse(qtyCtrl.text) ?? 1;
                          final price = double.tryParse(priceCtrl.text) ?? 0;

                          final item = PurchaseOrderItem(
                            id: '',
                            orderId: _order.id,
                            materialId: selectedMaterialId!,
                            quantity: qty,
                            unit: unit,
                            unitPrice: price,
                            subtotal: qty * price,
                            createdAt: ColombiaTime.now(),
                            updatedAt: ColombiaTime.now(),
                          );

                          await ref
                              .read(purchaseOrdersProvider.notifier)
                              .addItem(item);
                          await _refreshOrder();
                        },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================
  // DIÁLOGO: Editar ítem
  // ============================
  void _showEditItemDialog(PurchaseOrderItem item) {
    final qtyCtrl = TextEditingController(
      text: item.quantity.toStringAsFixed(2),
    );
    final priceCtrl = TextEditingController(
      text: item.unitPrice.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('Editar: ${item.materialName ?? "Ítem"}'),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cantidad (${item.unit})',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio Unitario (\$)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text(
                        Formatters.currency(
                          (double.tryParse(qtyCtrl.text) ?? 0) *
                              (double.tryParse(priceCtrl.text) ?? 0),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final updated = item.copyWith(
                  quantity: double.tryParse(qtyCtrl.text) ?? item.quantity,
                  unitPrice: double.tryParse(priceCtrl.text) ?? item.unitPrice,
                );
                await ref
                    .read(purchaseOrdersProvider.notifier)
                    .updateItem(updated);
                await _refreshOrder();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // DIÁLOGO: Registrar pago a proveedor
  // ============================
  void _showPaymentDialog() {
    final amountCtrl = TextEditingController(
      text: _order.balance.toStringAsFixed(2),
    );
    String? selectedAccountId;
    bool isCredit = false;

    // Cargar cuentas
    final cashState = ref.read(dailyCashProvider);
    if (cashState.accounts.isEmpty ||
        cashState.accounts.first.id.startsWith('default-')) {
      ref.read(dailyCashProvider.notifier).load();
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final accounts = ref
                .read(dailyCashProvider)
                .accounts
                .where((a) => a.isActive && !a.id.startsWith('default-'))
                .toList();
            final amount = double.tryParse(amountCtrl.text) ?? 0;
            final selectedAccount = selectedAccountId != null
                ? accounts.where((a) => a.id == selectedAccountId).firstOrNull
                : null;

            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.payments_outlined, color: Color(0xFFFF5722)),
                  SizedBox(width: 8),
                  Text('Pagar a Proveedor'),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info del proveedor y deuda
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Orden ${_order.orderNumber} — ${_order.supplierName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Pendiente: ${Formatters.currency(_order.balance)}',
                                  style: TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Monto a pagar
                    TextField(
                      controller: amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Monto a pagar',
                        prefixIcon: Icon(Icons.attach_money),
                        helperText: 'Puedes hacer abonos parciales',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Opción Crédito (fiado - no descuenta de cuenta)
                    CheckboxListTile(
                      value: isCredit,
                      onChanged: (v) => setDialogState(() {
                        isCredit = v ?? false;
                        if (isCredit) selectedAccountId = null;
                      }),
                      title: const Text('Registrar como crédito (fiado)'),
                      subtitle: const Text(
                        'No descuenta de ninguna cuenta',
                        style: TextStyle(fontSize: 11),
                      ),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),

                    if (!isCredit) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Pagar desde:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Lista de cuentas
                      if (accounts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.warning,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No se encontraron cuentas. Ve a Caja para configurar.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...accounts.map(
                          (account) => RadioListTile<String>(
                            value: account.id,
                            groupValue: selectedAccountId,
                            onChanged: (v) =>
                                setDialogState(() => selectedAccountId = v),
                            title: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _parseColor(account.color),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(account.name),
                              ],
                            ),
                            subtitle: Text(
                              '${account.type == AccountType.bank ? "Banco" : "Efectivo"} — Saldo: ${Formatters.currency(account.balance)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],

                    // Warning si el saldo es insuficiente
                    if (!isCredit &&
                        selectedAccount != null &&
                        amount > selectedAccount.balance)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: AppColors.warning,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Saldo insuficiente en ${selectedAccount.name} '
                                '(${Formatters.currency(selectedAccount.balance)})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed:
                      (amount <= 0 || (!isCredit && selectedAccountId == null))
                      ? null
                      : () async {
                          Navigator.pop(ctx);

                          final payAmount =
                              double.tryParse(amountCtrl.text) ?? 0;
                          if (payAmount <= 0) return;

                          final method = isCredit
                              ? 'credito'
                              : (selectedAccount?.type == AccountType.bank
                                    ? 'transferencia'
                                    : 'efectivo');

                          // 1. Registrar pago en la orden
                          await ref
                              .read(purchaseOrdersProvider.notifier)
                              .registerPayment(
                                _order.id,
                                payAmount,
                                method,
                                accountId: selectedAccountId,
                                supplierName: _order.supplierName,
                              );

                          // 2. Si NO es crédito, crear movimiento de gasto en caja
                          if (!isCredit && selectedAccountId != null) {
                            await ref
                                .read(dailyCashProvider.notifier)
                                .addExpense(
                                  accountId: selectedAccountId!,
                                  amount: payAmount,
                                  description:
                                      'Pago OC ${_order.orderNumber} — ${_order.supplierName}',
                                  category: MovementCategory.consumibles,
                                  personName: _order.supplierName,
                                  reference: _order.orderNumber,
                                );
                          }

                          await _refreshOrder();
                          widget.onRefresh();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isCredit
                                      ? '📝 Crédito de ${Formatters.currency(payAmount)} registrado'
                                      : '✅ Pago de ${Formatters.currency(payAmount)} desde ${selectedAccount?.name ?? ""}',
                                ),
                                backgroundColor: isCredit
                                    ? AppColors.warning
                                    : AppColors.success,
                              ),
                            );
                          }
                        },
                  icon: Icon(isCredit ? Icons.credit_score : Icons.payments),
                  label: Text(isCredit ? 'Registrar Crédito' : 'Pagar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF9E9E9E);
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF9E9E9E);
    }
  }

  Color _getStatusColor(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.borrador:
        return const Color(0xFF9E9E9E);
      case PurchaseOrderStatus.enviada:
        return AppColors.info;
      case PurchaseOrderStatus.parcial:
        return AppColors.warning;
      case PurchaseOrderStatus.recibida:
        return AppColors.success;
      case PurchaseOrderStatus.cancelada:
        return AppColors.danger;
    }
  }
}
