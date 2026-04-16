import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/helpers.dart';
import '../../core/utils/weight_calculator.dart';
import '../../data/providers/assets_provider.dart';
import '../../data/providers/composite_products_provider.dart';
import '../../data/providers/employees_provider.dart';
import '../../data/providers/inventory_provider.dart';
import '../../data/providers/invoices_provider.dart';
import '../../data/providers/production_orders_provider.dart';
import '../../domain/entities/composite_product.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/material.dart' as mat;
import '../../domain/entities/invoice.dart';
import '../../domain/entities/production_order.dart';
import '../../core/utils/colombia_time.dart';

class ProductionOrdersPage extends ConsumerStatefulWidget {
  const ProductionOrdersPage({super.key});

  @override
  ConsumerState<ProductionOrdersPage> createState() =>
      _ProductionOrdersPageState();
}

class _ProductionOrdersPageState extends ConsumerState<ProductionOrdersPage> {
  bool _bomExpanded = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(productionOrdersProvider.notifier).loadOrders();
      await ref.read(compositeProductsProvider.notifier).loadProducts();
      await ref
          .read(employeesProvider.notifier)
          .loadEmployees(activeOnly: true);
      ref.read(inventoryProvider.notifier).loadMaterials();
      ref.read(assetsProvider.notifier).loadAssets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productionOrdersProvider);
    final selectedOrder = state.selectedOrder;
    final cs = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 24,
                20,
                isCompact ? 16 : 24,
                16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCompact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.factory, color: cs.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ordenes de Produccion',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Flujo en cadena: componentes, procesos, tareas, recursos e informes',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _openCreateOrderDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Nueva OP'),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.factory, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ordenes de Produccion',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Flujo en cadena: componentes, procesos, tareas, recursos e informes',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => _openCreateOrderDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Nueva OP'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  if (isCompact)
                    Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Buscar OP o producto',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) => ref
                              .read(productionOrdersProvider.notifier)
                              .setSearchQuery(value),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: state.selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'todos',
                              child: Text('Todos'),
                            ),
                            DropdownMenuItem(
                              value: 'planificada',
                              child: Text('Planificada'),
                            ),
                            DropdownMenuItem(
                              value: 'en_proceso',
                              child: Text('En proceso'),
                            ),
                            DropdownMenuItem(
                              value: 'pausada',
                              child: Text('Pausada'),
                            ),
                            DropdownMenuItem(
                              value: 'completada',
                              child: Text('Completada'),
                            ),
                            DropdownMenuItem(
                              value: 'cancelada',
                              child: Text('Cancelada'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            ref
                                .read(productionOrdersProvider.notifier)
                                .setSelectedStatus(value);
                          },
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => ref
                                .read(productionOrdersProvider.notifier)
                                .loadOrders(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Actualizar'),
                          ),
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 280,
                          child: TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              labelText: 'Buscar OP o producto',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (value) => ref
                                .read(productionOrdersProvider.notifier)
                                .setSearchQuery(value),
                          ),
                        ),
                        SizedBox(
                          width: 210,
                          child: DropdownButtonFormField<String>(
                            value: state.selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Estado',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'todos',
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem(
                                value: 'planificada',
                                child: Text('Planificada'),
                              ),
                              DropdownMenuItem(
                                value: 'en_proceso',
                                child: Text('En proceso'),
                              ),
                              DropdownMenuItem(
                                value: 'pausada',
                                child: Text('Pausada'),
                              ),
                              DropdownMenuItem(
                                value: 'completada',
                                child: Text('Completada'),
                              ),
                              DropdownMenuItem(
                                value: 'cancelada',
                                child: Text('Cancelada'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              ref
                                  .read(productionOrdersProvider.notifier)
                                  .setSelectedStatus(value);
                            },
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => ref
                              .read(productionOrdersProvider.notifier)
                              .loadOrders(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualizar'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                  ? _buildErrorState(state.error!)
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 1100;

                        if (!isWide) {
                          return _buildMobileList(state);
                        }

                        return Row(
                          children: [
                            SizedBox(
                              width: 420,
                              child: _buildOrdersList(state),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: selectedOrder == null
                                  ? _buildNoSelection()
                                  : _buildOrderDetail(selectedOrder),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: Colors.red),
            const SizedBox(height: 10),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.read(productionOrdersProvider.notifier).loadOrders(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList(ProductionOrdersState state) {
    final orders = state.filteredOrders;
    if (orders.isEmpty) {
      return _buildNoOrders();
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      onReorder: (oldIndex, newIndex) {
        ref
            .read(productionOrdersProvider.notifier)
            .reorderOrders(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final order = orders[index];
        return Padding(
          key: ValueKey(order.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openOrderDetailDialog(order),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _OrderCardContent(order: order)),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (order.status != 'completada' &&
                            order.status != 'cancelada')
                          _OrderQuickAction(
                            icon: order.status == 'pausada'
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            tooltip: order.status == 'pausada'
                                ? 'Reanudar'
                                : 'Pausar',
                            color: order.status == 'pausada'
                                ? Colors.green
                                : Colors.orange,
                            onTap: () {
                              final newStatus = order.status == 'pausada'
                                  ? 'en_proceso'
                                  : 'pausada';
                              ref
                                  .read(productionOrdersProvider.notifier)
                                  .updateOrderStatus(order.id, newStatus);
                            },
                          ),
                        _OrderQuickAction(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Eliminar',
                          color: Colors.red,
                          onTap: () => _confirmDeleteOrder(order),
                        ),
                      ],
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrdersList(ProductionOrdersState state) {
    final orders = state.filteredOrders;
    if (orders.isEmpty) {
      return _buildNoOrders();
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      onReorder: (oldIndex, newIndex) {
        ref
            .read(productionOrdersProvider.notifier)
            .reorderOrders(oldIndex, newIndex);
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final order = orders[index];
        final selected = state.selectedOrderId == order.id;

        return Padding(
          key: ValueKey(order.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: selected
                ? Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.55)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ref
                  .read(productionOrdersProvider.notifier)
                  .selectOrder(order.id),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Order number badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Card content
                    Expanded(child: _OrderCardContent(order: order)),
                    const SizedBox(width: 4),
                    // Action buttons column
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pause / Resume button
                        if (order.status != 'completada' &&
                            order.status != 'cancelada')
                          _OrderQuickAction(
                            icon: order.status == 'pausada'
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            tooltip: order.status == 'pausada'
                                ? 'Reanudar'
                                : 'Pausar',
                            color: order.status == 'pausada'
                                ? Colors.green
                                : Colors.orange,
                            onTap: () {
                              final newStatus = order.status == 'pausada'
                                  ? 'en_proceso'
                                  : 'pausada';
                              ref
                                  .read(productionOrdersProvider.notifier)
                                  .updateOrderStatus(order.id, newStatus);
                            },
                          ),
                        const SizedBox(height: 2),
                        // Delete button
                        _OrderQuickAction(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Eliminar',
                          color: Colors.red,
                          onTap: () => _confirmDeleteOrder(order),
                        ),
                      ],
                    ),
                    // Drag handle
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoOrders() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.precision_manufacturing_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 10),
            Text(
              'No hay ordenes de produccion',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Crea una nueva OP desde un producto compuesto para heredar BOM y flujo de procesos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openCreateOrderDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Crear primera OP'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSelection() {
    return Center(
      child: Text(
        'Selecciona una OP para ver su mesa de trabajo',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildOrderDetail(ProductionOrder order) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return ListView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      children: [
        _buildOrderHeader(order),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Componentes y Materiales (BOM) (${order.materials.length})',
          icon: Icons.inventory_2,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: AnimatedRotation(
                  turns: _bomExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more),
                ),
                tooltip: _bomExpanded ? 'Contraer lista' : 'Expandir lista',
                onPressed: () => setState(() => _bomExpanded = !_bomExpanded),
              ),
              if (isMobile)
                IconButton(
                  onPressed: () => _openAddBomMaterialDialog(order),
                  icon: const Icon(Icons.add),
                  tooltip: 'Agregar material',
                )
              else
                OutlinedButton.icon(
                  onPressed: () => _openAddBomMaterialDialog(order),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar material'),
                ),
            ],
          ),
          child: AnimatedCrossFade(
            firstChild: order.materials.isEmpty
                ? const Text('La OP no tiene materiales vinculados')
                : _buildBomList(order),
            secondChild: Text(
              '${order.materials.length} materiales — toca para expandir',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            crossFadeState: _bomExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ),
        const SizedBox(height: 12),
        _KpiCards(order: order),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Flujo de Procesos en Cadena',
          icon: Icons.account_tree,
          trailing: isMobile
              ? IconButton(
                  onPressed: () => _openStageDialog(order: order),
                  icon: const Icon(Icons.add),
                  tooltip: 'Agregar etapa',
                )
              : OutlinedButton.icon(
                  onPressed: () => _openStageDialog(order: order),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar etapa'),
                ),
          child: order.stages.isEmpty
              ? const Text('Sin etapas configuradas')
              : _ProcessChainBoard(
                  stages: order.stages,
                  onEditStage: (stage) =>
                      _openStageDialog(order: order, stage: stage),
                  onDeleteStage: (stage) => _deleteStage(order.id, stage.id),
                ),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Mesa de Trabajo',
          icon: Icons.engineering,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cada etapa puede tener empleado asignado, recursos (maquinas/herramientas) e informe tecnico.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: order.stages.map((stage) {
                  final assignee =
                      stage.assignedEmployeeName?.isNotEmpty == true
                      ? stage.assignedEmployeeName
                      : 'Sin asignar';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withOpacity(0.45),
                    ),
                    child: Text(
                      'E${stage.sequenceOrder}: ${stage.processName} • $assignee',
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderHeader(ProductionOrder order) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.code,
                      style:
                          (isMobile
                                  ? Theme.of(context).textTheme.titleMedium
                                  : Theme.of(context).textTheme.titleLarge)
                              ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.productCode} • ${order.productName}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: isMobile ? 13 : null,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: isMobile ? 10 : 16,
            runSpacing: 6,
            children: [
              _InfoText('Cantidad', order.quantity.toStringAsFixed(2)),
              _InfoText('Entrega', Helpers.formatDate(order.dueDate)),
              _InfoText(
                'Etapas',
                '${order.completedStages}/${order.stages.length}',
              ),
              _InfoText(
                isMobile ? 'Costo est.' : 'Costo material estimado',
                Helpers.formatCurrency(order.estimatedMaterialCost),
              ),
              _PriorityBadge(priority: order.priority),
            ],
          ),
          // Factura vinculada
          if (order.invoiceId != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.receipt_long,
                    size: 16,
                    color: Color(0xFF1565C0),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Factura vinculada',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _unlinkInvoice(order.id),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: order.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _changeOrderStatus(order.id, 'planificada'),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Planificada'),
              ),
              OutlinedButton.icon(
                onPressed: () => _changeOrderStatus(order.id, 'en_proceso'),
                icon: const Icon(Icons.play_arrow),
                label: const Text('En proceso'),
              ),
              OutlinedButton.icon(
                onPressed: () => _changeOrderStatus(order.id, 'pausada'),
                icon: const Icon(Icons.pause),
                label: const Text('Pausada'),
              ),
              FilledButton.icon(
                onPressed: () => _changeOrderStatus(order.id, 'completada'),
                icon: const Icon(Icons.check),
                label: const Text('Completar'),
              ),
              if (order.invoiceId == null)
                OutlinedButton.icon(
                  onPressed: () => _showLinkInvoiceDialog(order),
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Vincular Factura'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1565C0),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PriorityDropdown(
                current: order.priority,
                onChanged: (p) => _changePriority(order.id, p),
              ),
              OutlinedButton.icon(
                onPressed: () => _showDelayDialog(order),
                icon: const Icon(Icons.event, size: 18),
                label: const Text('Retrasar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE65100),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _confirmDeleteOrder(order),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Eliminar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 500;
              if (!compact || trailing == null) {
                return Row(
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (trailing != null) trailing,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: trailing),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  void _changeOrderStatus(String orderId, String status) async {
    try {
      await ref
          .read(productionOrdersProvider.notifier)
          .updateOrderStatus(orderId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado a: $status'),
          backgroundColor: const Color(0xFF43A047),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cambiar estado: $e'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  void _changePriority(String orderId, String priority) async {
    try {
      await ref
          .read(productionOrdersProvider.notifier)
          .updatePriority(orderId, priority);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prioridad actualizada a: $priority'),
          backgroundColor: const Color(0xFF43A047),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  void _showDelayDialog(ProductionOrder order) async {
    final currentDue =
        order.dueDate ?? ColombiaTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDue.add(const Duration(days: 7)),
      firstDate: ColombiaTime.now(),
      lastDate: ColombiaTime.now().add(const Duration(days: 365)),
      helpText: 'Nueva fecha de entrega',
      confirmText: 'Guardar',
      cancelText: 'Cancelar',
    );
    if (picked == null || !mounted) return;
    try {
      await ref
          .read(productionOrdersProvider.notifier)
          .updateDueDate(order.id, picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Fecha de entrega actualizada a: ${Helpers.formatDate(picked)}',
          ),
          backgroundColor: const Color(0xFF43A047),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }

  void _confirmDeleteOrder(ProductionOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.delete_forever,
              color: Color(0xFFC62828),
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text('Eliminar Orden'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEF9A9A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Color(0xFFC62828)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Se eliminará la OP ${order.code} con todas sus etapas, '
                      'materiales y tareas de empleados asociadas.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFC62828),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Producto: ${order.productName}\n'
              'Estado: ${order.status}\n'
              'Etapas: ${order.completedStages}/${order.stages.length}',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(productionOrdersProvider.notifier)
                    .deleteOrder(order.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('OP ${order.code} eliminada'),
                    backgroundColor: const Color(0xFF43A047),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al eliminar: $e'),
                    backgroundColor: const Color(0xFFC62828),
                  ),
                );
              }
            },
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
          ),
        ],
      ),
    );
  }

  void _showLinkInvoiceDialog(ProductionOrder order) {
    final invoicesState = ref.read(invoicesProvider);
    // Filtrar facturas activas (emitidas o parcialmente pagadas)
    final available = invoicesState.invoices
        .where(
          (inv) =>
              inv.status != InvoiceStatus.cancelled &&
              inv.status != InvoiceStatus.draft,
        )
        .toList();

    String? selectedId;
    final searchCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchCtrl.text.toLowerCase();
          final filtered = query.isEmpty
              ? available
              : available
                    .where(
                      (inv) =>
                          inv.fullNumber.toLowerCase().contains(query) ||
                          inv.customerName.toLowerCase().contains(query),
                    )
                    .toList();

          return AlertDialog(
            title: const Text('Vincular Factura a OP'),
            content: SizedBox(
              width: 400,
              height: 350,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'Buscar factura o cliente...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Sin facturas disponibles'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final inv = filtered[i];
                              final isSelected = selectedId == inv.id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: const Color(0xFFE3F2FD),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                leading: const Icon(
                                  Icons.receipt_long,
                                  size: 20,
                                ),
                                title: Text(
                                  inv.fullNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  '${inv.customerName} • ${Helpers.formatCurrency(inv.total)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () =>
                                    setDialogState(() => selectedId = inv.id),
                              );
                            },
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
                onPressed: selectedId == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final ok = await ref
                            .read(productionOrdersProvider.notifier)
                            .linkInvoice(order.id, selectedId!);
                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Factura vinculada a la OP'),
                              backgroundColor: Color(0xFF43A047),
                            ),
                          );
                        }
                      },
                child: const Text('Vincular'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _unlinkInvoice(String orderId) async {
    final ok = await ref
        .read(productionOrdersProvider.notifier)
        .unlinkInvoice(orderId);
    if (ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Factura desvinculada')));
    }
  }

  void _deleteStage(String orderId, String stageId) async {
    await ref
        .read(productionOrdersProvider.notifier)
        .deleteStage(orderId: orderId, stageId: stageId);
  }

  // ── BOM helpers ───────────────────────────────────────────────────

  Widget _buildBomList(ProductionOrder order) {
    final allMaterials = ref.watch(inventoryProvider).materials;
    final stockMap = <String, mat.Material>{};
    for (final m in allMaterials) {
      stockMap[m.id] = m;
    }

    return Column(
      children: order.materials.map((m) {
        final inv = stockMap[m.materialId];
        final stock = inv?.stock ?? 0;
        final required = m.requiredQuantity;
        final hasEnough = stock >= required;
        final missing = (required - stock)
            .clamp(0.0, double.infinity)
            .toDouble();

        final hasPiece = m.pieceTitle != null && m.pieceTitle!.isNotEmpty;
        final hasDims = m.dimensions != null && m.dimensions!.isNotEmpty;
        final isMobileBom = MediaQuery.sizeOf(context).width < 430;

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            hasEnough ? Icons.check_circle : Icons.warning_amber_rounded,
            color: hasEnough ? Colors.green : Colors.red.shade700,
            size: 22,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasPiece)
                          Text(
                            m.pieceTitle!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        Text(
                          m.materialName,
                          style: TextStyle(
                            fontSize: hasPiece ? 12 : 14,
                            color: hasPiece
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : null,
                          ),
                        ),
                        if (hasDims)
                          Text(
                            m.dimensions!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isMobileBom)
                    _buildStockBadge(hasEnough, stock, missing, m.unit),
                ],
              ),
              if (isMobileBom)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _buildStockBadge(hasEnough, stock, missing, m.unit),
                ),
            ],
          ),
          subtitle: Text(
            isMobileBom
                ? 'Req: ${required.toStringAsFixed(required % 1 == 0 ? 0 : 2)} ${m.unit} • '
                      'Pend: ${m.pendingQuantity.toStringAsFixed(m.pendingQuantity % 1 == 0 ? 0 : 2)} • '
                      '${Helpers.formatCurrency(m.estimatedCost)}'
                : 'Requerido: ${required.toStringAsFixed(2)} ${m.unit} • '
                      'Pendiente: ${m.pendingQuantity.toStringAsFixed(2)} ${m.unit} • '
                      '${Helpers.formatCurrency(m.estimatedCost)}',
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red.shade400,
              size: 20,
            ),
            tooltip: 'Eliminar material',
            onPressed: () => _confirmRemoveBomMaterial(order.id, m),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStockBadge(
    bool hasEnough,
    double stock,
    double missing,
    String unit,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: hasEnough
            ? Colors.green.withOpacity(0.12)
            : Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        hasEnough
            ? 'Stock: ${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 2)} $unit'
            : 'Faltan ${missing.toStringAsFixed(missing % 1 == 0 ? 0 : 2)} $unit',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: hasEnough ? Colors.green.shade800 : Colors.red.shade800,
        ),
      ),
    );
  }

  void _confirmRemoveBomMaterial(String orderId, ProductionOrderMaterial m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar material'),
        content: Text('¿Eliminar "${m.materialName}" del BOM de esta OP?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(productionOrdersProvider.notifier)
                  .removeMaterialFromOrder(
                    orderId: orderId,
                    materialRowId: m.id,
                  );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _openAddBomMaterialDialog(ProductionOrder order) {
    if (MediaQuery.sizeOf(context).width < 600) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _AddBomMaterialDialog(order: order),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => _AddBomMaterialDialog(order: order),
      );
    }
  }

  void _openCreateOrderDialog(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 600) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const _CreateProductionOrderDialog(),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => const _CreateProductionOrderDialog(),
      );
    }
  }

  void _openStageDialog({
    required ProductionOrder order,
    ProductionStage? stage,
  }) {
    if (MediaQuery.sizeOf(context).width < 600) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _EditStageDialog(order: order, stage: stage),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => _EditStageDialog(order: order, stage: stage),
      );
    }
  }

  void _openOrderDetailDialog(ProductionOrder order) {
    ref.read(productionOrdersProvider.notifier).selectOrder(order.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: _buildOrderDetail(order),
        ),
      ),
    );
  }
}

class _OrderCardContent extends StatelessWidget {
  final ProductionOrder order;

  const _OrderCardContent({required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.code,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            _StatusChip(status: order.status),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                order.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _PriorityBadge(priority: order.priority),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _TagText('Cant: ${order.quantity.toStringAsFixed(2)}'),
            _TagText('Etapas: ${order.completedStages}/${order.stages.length}'),
            _TagText('Entrega: ${Helpers.formatDate(order.dueDate)}'),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: order.progress,
          minHeight: 6,
          borderRadius: BorderRadius.circular(99),
        ),
      ],
    );
  }
}

class _OrderQuickAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _OrderQuickAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _CreateProductionOrderDialog extends ConsumerStatefulWidget {
  const _CreateProductionOrderDialog();

  @override
  ConsumerState<_CreateProductionOrderDialog> createState() =>
      _CreateProductionOrderDialogState();
}

class _CreateProductionOrderDialogState
    extends ConsumerState<_CreateProductionOrderDialog> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();
  final _customProcessCtrl = TextEditingController();

  CompositeProduct? _selectedProduct;
  DateTime? _dueDate;
  String _priority = 'media';
  bool _isSaving = false;

  final List<String> _selectedProcesses = [
    'Corte',
    'Torno',
    'Soldadura',
    'Armado',
  ];

  /// Employee assigned per process name (null = sin asignar)
  final Map<String, String?> _processEmployeeMap = {};

  static const List<String> _templates = [
    'Corte',
    'Torno',
    'Soldadura',
    'Armado',
    'Pintura',
    'Control Calidad',
    'Empaque',
  ];

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _customProcessCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.read(compositeProductsProvider);
    final employees = ref.read(employeesProvider).activeEmployees;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final dialogWidth = width < 700 ? width * 0.92 : 650.0;

    final formContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<CompositeProduct>(
          value: _selectedProduct,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Producto *',
            border: OutlineInputBorder(),
          ),
          items: productsState.products
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text('${p.code} • ${p.name}'),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedProduct = value),
        ),
        const SizedBox(height: 10),
        if (isMobile) ...[
          TextField(
            controller: _qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _priority,
            decoration: const InputDecoration(
              labelText: 'Prioridad',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'baja', child: Text('Baja')),
              DropdownMenuItem(value: 'media', child: Text('Media')),
              DropdownMenuItem(value: 'alta', child: Text('Alta')),
              DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _priority = value);
            },
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Prioridad',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'baja', child: Text('Baja')),
                    DropdownMenuItem(value: 'media', child: Text('Media')),
                    DropdownMenuItem(value: 'alta', child: Text('Alta')),
                    DropdownMenuItem(value: 'urgente', child: Text('Urgente')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _priority = value);
                  },
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                _dueDate == null
                    ? 'Sin fecha compromiso'
                    : 'Entrega: ${Helpers.formatDate(_dueDate)}',
              ),
            ),
            TextButton.icon(
              onPressed: _pickDueDate,
              icon: const Icon(Icons.event),
              label: const Text('Fecha entrega'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notas',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Cadena de procesos',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._templates.map((process) {
              final selected = _selectedProcesses.contains(process);
              return FilterChip(
                selected: selected,
                label: Text(process),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedProcesses.add(process);
                    } else {
                      _selectedProcesses.remove(process);
                      _processEmployeeMap.remove(process);
                    }
                  });
                },
              );
            }),
            // Procesos personalizados (no están en _templates)
            ..._selectedProcesses.where((p) => !_templates.contains(p)).map((
              process,
            ) {
              return Chip(
                label: Text(process),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() {
                    _selectedProcesses.remove(process);
                    _processEmployeeMap.remove(process);
                  });
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customProcessCtrl,
                decoration: const InputDecoration(
                  labelText: 'Agregar proceso personalizado',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final value = _customProcessCtrl.text.trim();
                if (value.isEmpty) return;
                if (_selectedProcesses.contains(value)) return;
                setState(() {
                  _selectedProcesses.add(value);
                  _customProcessCtrl.clear();
                });
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
        // -- Asignación de empleados por proceso --
        if (_selectedProcesses.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Asignar empleados (opcional)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_selectedProcesses.length, (i) {
            final process = _selectedProcesses[i];
            final empId = _processEmployeeMap[process];
            final dropdown = DropdownButtonFormField<String?>(
              value: empId,
              isExpanded: true,
              isDense: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                hintText: 'Sin asignar',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'Sin asignar',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                ...employees.map(
                  (e) => DropdownMenuItem<String?>(
                    value: e.id,
                    child: Text(
                      e.fullName,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _processEmployeeMap[process] = value;
                });
              },
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. $process',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        dropdown,
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            process,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(flex: 3, child: dropdown),
                      ],
                    ),
            );
          }),
        ],
      ],
    );

    final cancelBtn = TextButton(
      onPressed: _isSaving ? null : () => Navigator.pop(context),
      child: const Text('Cancelar'),
    );
    final saveBtn = FilledButton.icon(
      onPressed: _isSaving ? null : _save,
      icon: _isSaving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save),
      label: Text(_isSaving ? 'Creando...' : 'Crear OP'),
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nueva Orden de Produccion')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: formContent,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [cancelBtn, const SizedBox(width: 8), saveBtn],
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Nueva Orden de Produccion'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(child: formContent),
      ),
      actions: [cancelBtn, saveBtn],
    );
  }

  Future<void> _pickDueDate() async {
    final now = ColombiaTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      initialDate: _dueDate ?? now,
    );
    if (selected != null) {
      setState(() => _dueDate = selected);
    }
  }

  Future<void> _save() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona un producto')));
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cantidad invalida')));
      return;
    }

    if (_selectedProcesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes definir al menos una etapa')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final employees = ref.read(employeesProvider).activeEmployees;
    final chain = _selectedProcesses.map((process) {
      final empId = _processEmployeeMap[process];
      String? empName;
      if (empId != null) {
        for (final e in employees) {
          if (e.id == empId) {
            empName = e.fullName;
            break;
          }
        }
      }
      return ProcessChainItem(
        processName: process,
        employeeId: empId,
        employeeName: empName,
      );
    }).toList();

    final success = await ref
        .read(productionOrdersProvider.notifier)
        .createOrder(
          ProductionOrderCreationInput(
            product: _selectedProduct!,
            quantity: qty,
            dueDate: _dueDate,
            priority: _priority,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            processChain: chain,
          ),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orden de produccion creada')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo crear la OP')));
  }
}

class _EditStageDialog extends ConsumerStatefulWidget {
  final ProductionOrder order;
  final ProductionStage? stage;

  const _EditStageDialog({required this.order, this.stage});

  @override
  ConsumerState<_EditStageDialog> createState() => _EditStageDialogState();
}

class _EditStageDialogState extends ConsumerState<_EditStageDialog> {
  late final TextEditingController _processCtrl;
  late final TextEditingController _workstationCtrl;
  late final TextEditingController _estimatedCtrl;
  late final TextEditingController _actualCtrl;
  late final TextEditingController _resourcesCtrl;
  late final TextEditingController _reportCtrl;
  late final TextEditingController _notesCtrl;

  String _status = 'pendiente';
  String? _employeeId;
  bool _isSaving = false;

  List<String> _selectedMaterialIds = [];
  List<String> _selectedAssetIds = [];

  bool get _isEditing => widget.stage != null;

  @override
  void initState() {
    super.initState();
    final stage = widget.stage;

    _processCtrl = TextEditingController(text: stage?.processName ?? '');
    _workstationCtrl = TextEditingController(text: stage?.workstation ?? '');
    _estimatedCtrl = TextEditingController(
      text: stage != null ? stage.estimatedHours.toString() : '2',
    );
    _actualCtrl = TextEditingController(
      text: stage != null ? stage.actualHours.toString() : '0',
    );
    _resourcesCtrl = TextEditingController(
      text: stage?.resources.join(', ') ?? '',
    );
    _reportCtrl = TextEditingController(text: stage?.report ?? '');
    _notesCtrl = TextEditingController(text: stage?.notes ?? '');
    _status = stage?.status ?? 'pendiente';
    _employeeId = stage?.assignedEmployeeId;
    _selectedMaterialIds = List<String>.from(stage?.materialIds ?? []);
    _selectedAssetIds = List<String>.from(stage?.assetIds ?? []);
  }

  @override
  void dispose() {
    _processCtrl.dispose();
    _workstationCtrl.dispose();
    _estimatedCtrl.dispose();
    _actualCtrl.dispose();
    _resourcesCtrl.dispose();
    _reportCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.read(employeesProvider).activeEmployees;
    final allMaterials = ref.watch(inventoryProvider).materials;
    final allAssets = ref.watch(assetsProvider).assets;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final dialogWidth = width < 700 ? width * 0.92 : 620.0;

    final formContent = Column(
      children: [
        TextField(
          controller: _processCtrl,
          decoration: const InputDecoration(
            labelText: 'Proceso *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _workstationCtrl,
          decoration: const InputDecoration(
            labelText: 'Mesa de trabajo / estacion *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        if (isMobile) ...[
          TextField(
            controller: _estimatedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Horas estimadas',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _actualCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Horas reales',
              border: OutlineInputBorder(),
            ),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _estimatedCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Horas estimadas',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _actualCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Horas reales',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _status,
          decoration: const InputDecoration(
            labelText: 'Estado',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
            DropdownMenuItem(value: 'en_proceso', child: Text('En proceso')),
            DropdownMenuItem(value: 'bloqueada', child: Text('Bloqueada')),
            DropdownMenuItem(value: 'completada', child: Text('Completada')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _status = value);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String?>(
          value: _employeeId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Empleado asignado',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin asignar'),
            ),
            ...employees.map(
              (e) => DropdownMenuItem<String?>(
                value: e.id,
                child: Text(e.fullName),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _employeeId = value),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _resourcesCtrl,
          decoration: const InputDecoration(
            labelText: 'Recursos (separados por coma)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        // ── Materiales ──
        _buildMultiSelectSection(
          context,
          title: 'Materiales',
          icon: Icons.inventory_2_outlined,
          selectedIds: _selectedMaterialIds,
          items: allMaterials,
          idOf: (m) => m.id,
          labelOf: (m) => '${m.name} (${m.category})',
          onAdd: (id) => setState(() => _selectedMaterialIds.add(id)),
          onRemove: (id) => setState(() => _selectedMaterialIds.remove(id)),
        ),
        const SizedBox(height: 14),
        // ── Activos (maquinaria/herramientas) ──
        _buildMultiSelectSection(
          context,
          title: 'Activos / Maquinaria',
          icon: Icons.precision_manufacturing_outlined,
          selectedIds: _selectedAssetIds,
          items: allAssets.where((a) => a.status == 'activo').toList(),
          idOf: (a) => a.id,
          labelOf: (a) {
            final parts = [a.name];
            if (a.brand != null) parts.add(a.brand!);
            if (a.model != null) parts.add(a.model!);
            return parts.join(' - ');
          },
          onAdd: (id) => setState(() => _selectedAssetIds.add(id)),
          onRemove: (id) => setState(() => _selectedAssetIds.remove(id)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _reportCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Informe tecnico',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notas de la etapa',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );

    final cancelBtn = TextButton(
      onPressed: _isSaving ? null : () => Navigator.pop(context),
      child: const Text('Cancelar'),
    );
    final saveBtn = FilledButton.icon(
      onPressed: _isSaving ? null : () => _save(employees),
      icon: _isSaving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save),
      label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Editar etapa' : 'Nueva etapa'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: formContent,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [cancelBtn, const SizedBox(width: 8), saveBtn],
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(_isEditing ? 'Editar etapa' : 'Nueva etapa'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(child: formContent),
      ),
      actions: [cancelBtn, saveBtn],
    );
  }

  Widget _buildMultiSelectSection<T extends Object>(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<String> selectedIds,
    required List<T> items,
    required String Function(T) idOf,
    required String Function(T) labelOf,
    required void Function(String) onAdd,
    required void Function(String) onRemove,
  }) {
    final cs = Theme.of(context).colorScheme;
    final availableItems = items
        .where((item) => !selectedIds.contains(idOf(item)))
        .toList();
    final selectedItems = items
        .where((item) => selectedIds.contains(idOf(item)))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            Text(
              '${selectedIds.length} seleccionados',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (selectedItems.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: selectedItems
                .map(
                  (item) => Chip(
                    label: Text(
                      labelOf(item),
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => onRemove(idOf(item)),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: items.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No hay $title disponibles. Créalos desde el módulo correspondiente.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : availableItems.isEmpty
              ? Text(
                  'Todos los $title han sido seleccionados',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Autocomplete<T>(
                      optionsBuilder: (textEditingValue) {
                        final query = textEditingValue.text
                            .toLowerCase()
                            .trim();
                        if (query.isEmpty) return availableItems;
                        return availableItems
                            .where(
                              (item) =>
                                  labelOf(item).toLowerCase().contains(query),
                            )
                            .toList();
                      },
                      displayStringForOption: (item) => labelOf(item),
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Buscar $title...',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 200,
                                maxWidth: constraints.maxWidth,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final item = options.elementAt(index);
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      labelOf(item),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    onTap: () => onSelected(item),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      onSelected: (item) {
                        onAdd(idOf(item));
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _save(List<Employee> employees) async {
    final process = _processCtrl.text.trim();
    final workstation = _workstationCtrl.text.trim();

    if (process.isEmpty || workstation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proceso y mesa de trabajo son obligatorios'),
        ),
      );
      return;
    }

    final estimated = double.tryParse(_estimatedCtrl.text.trim()) ?? 0;
    final actual = double.tryParse(_actualCtrl.text.trim()) ?? 0;
    final resources = _resourcesCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() => _isSaving = true);

    Employee? selectedEmployee;
    if (_employeeId != null) {
      for (final employee in employees) {
        if (employee.id == _employeeId) {
          selectedEmployee = employee;
          break;
        }
      }
    }

    try {
      if (_isEditing) {
        final updatedStage = widget.stage!.copyWith(
          processName: process,
          workstation: workstation,
          estimatedHours: estimated,
          actualHours: actual,
          status: _status,
          assignedEmployeeId: _employeeId,
          assignedEmployeeName: selectedEmployee?.fullName,
          resources: resources,
          materialIds: _selectedMaterialIds,
          assetIds: _selectedAssetIds,
          report: _reportCtrl.text.trim().isEmpty
              ? null
              : _reportCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );

        await ref
            .read(productionOrdersProvider.notifier)
            .updateStage(updatedStage);
      } else {
        await ref
            .read(productionOrdersProvider.notifier)
            .createStage(
              orderId: widget.order.id,
              processName: process,
              workstation: workstation,
              estimatedHours: estimated,
              actualHours: actual,
              status: _status,
              assignedEmployeeId: _employeeId,
              resources: resources,
              materialIds: _selectedMaterialIds,
              assetIds: _selectedAssetIds,
              report: _reportCtrl.text.trim().isEmpty
                  ? null
                  : _reportCtrl.text.trim(),
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
            );
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar etapa: $e'),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
  }
}

class _StageTile extends ConsumerWidget {
  final ProductionStage stage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StageTile({
    required this.stage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final allMaterials = ref.watch(inventoryProvider).materials;
    final allAssets = ref.watch(assetsProvider).assets;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 480;
    final isDone = stage.status == 'completada';
    final isInProgress = stage.status == 'en_proceso';
    final processIcon = _iconForProcess(stage.processName);

    final Color leftRail = isDone
        ? const Color(0xFF2E7D32)
        : (isInProgress ? const Color(0xFF1565C0) : cs.outlineVariant);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cs.surfaceContainerHighest.withOpacity(0.42),
        border: Border.all(
          color: isInProgress
              ? cs.primary.withOpacity(0.32)
              : cs.outlineVariant,
          width: isInProgress ? 1.1 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: 4,
                height: isCompact ? 86 : 74,
                margin: const EdgeInsets.only(right: 10, top: 2),
                decoration: BoxDecoration(
                  color: leftRail,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isCompact)
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: cs.primaryContainer,
                            child: Icon(
                              processIcon,
                              size: 14,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              stage.processName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '#${stage.sequenceOrder}',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isInProgress) const _PulsingIndicator(),
                          if (isInProgress) const SizedBox(width: 8),
                          _StatusChip(status: stage.status),
                          IconButton(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit, size: 18),
                            tooltip: 'Editar etapa',
                          ),
                          IconButton(
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            tooltip: 'Eliminar etapa',
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: cs.primaryContainer,
                                child: Icon(
                                  processIcon,
                                  size: 14,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  stage.processName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '#${stage.sequenceOrder}',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (isInProgress) const _PulsingIndicator(),
                              if (isInProgress) const SizedBox(width: 8),
                              _StatusChip(status: stage.status),
                              const Spacer(),
                              IconButton(
                                onPressed: onEdit,
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Editar etapa',
                              ),
                              IconButton(
                                onPressed: onDelete,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                tooltip: 'Eliminar etapa',
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Mesa: ${stage.workstation}',
                      style: isCompact ? const TextStyle(fontSize: 12) : null,
                    ),
                    if (isCompact) ...[
                      Text(
                        stage.assignedEmployeeName ?? 'Sin asignar',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Horas: ${stage.actualHours.toStringAsFixed(1)}/${stage.estimatedHours.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ] else
                      Text(
                        'Empleado: ${stage.assignedEmployeeName ?? 'Sin asignar'} • Horas: ${stage.actualHours.toStringAsFixed(1)}/${stage.estimatedHours.toStringAsFixed(1)}',
                      ),
                    if (stage.resources.isNotEmpty)
                      Text('Recursos: ${stage.resources.join(', ')}'),
                    if (stage.materialIds.isNotEmpty)
                      _buildAssociationRow(
                        Icons.inventory_2_outlined,
                        stage.materialIds
                            .map((id) {
                              final m = allMaterials
                                  .where((mat) => mat.id == id)
                                  .toList();
                              return m.isNotEmpty
                                  ? m.first.name
                                  : 'Material...';
                            })
                            .join(', '),
                        cs,
                      ),
                    if (stage.assetIds.isNotEmpty)
                      _buildAssociationRow(
                        Icons.precision_manufacturing_outlined,
                        stage.assetIds
                            .map((id) {
                              final a = allAssets
                                  .where((ast) => ast.id == id)
                                  .toList();
                              return a.isNotEmpty ? a.first.name : 'Activo...';
                            })
                            .join(', '),
                        cs,
                      ),
                    if (stage.report != null && stage.report!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Informe: ${stage.report!}'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssociationRow(IconData icon, String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPI mini cards ─────────────────────────────────────────────────────────
class _KpiCards extends StatelessWidget {
  final ProductionOrder order;
  const _KpiCards({required this.order});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = order.daysUntilDue;
    final efficiency = order.efficiencyRatio;

    String daysLabel;
    Color daysColor;
    IconData daysIcon;
    if (days == null) {
      daysLabel = 'Sin fecha';
      daysColor = cs.onSurfaceVariant;
      daysIcon = Icons.event_busy;
    } else if (days < 0) {
      daysLabel = '${(-days)}d vencida';
      daysColor = cs.error;
      daysIcon = Icons.warning_amber_rounded;
    } else if (days == 0) {
      daysLabel = 'Vence hoy';
      daysColor = Colors.orange;
      daysIcon = Icons.today;
    } else {
      daysLabel = '${days}d restantes';
      daysColor = days <= 3 ? Colors.orange : const Color(0xFF2E7D32);
      daysIcon = Icons.schedule;
    }

    String effLabel;
    Color effColor;
    IconData effIcon;
    if (efficiency == null) {
      effLabel = 'Sin datos';
      effColor = cs.onSurfaceVariant;
      effIcon = Icons.speed;
    } else {
      final pct = (efficiency * 100).round();
      effLabel = '$pct% efic.';
      effColor = efficiency >= 1.0
          ? const Color(0xFF2E7D32)
          : const Color(0xFFB71C1C);
      effIcon = efficiency >= 1.0 ? Icons.trending_up : Icons.trending_down;
    }

    final chips = [
      _KpiChip(
        icon: Icons.donut_large,
        label: '${(order.progress * 100).round()}%',
        sublabel: 'Avance',
        color: order.progress >= 1.0 ? const Color(0xFF2E7D32) : cs.primary,
      ),
      _KpiChip(
        icon: daysIcon,
        label: daysLabel,
        sublabel: 'Plazo',
        color: daysColor,
      ),
      _KpiChip(
        icon: effIcon,
        label: effLabel,
        sublabel: 'Eficiencia',
        color: effColor,
      ),
      _KpiChip(
        icon: Icons.attach_money,
        label: Helpers.formatCurrency(order.estimatedMaterialCost),
        sublabel: 'Costo mat.',
        color: cs.tertiary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 500) {
          final chipWidth = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map((c) => SizedBox(width: chipWidth, child: c))
                .toList(),
          );
        }
        return Row(
          children: [
            for (int i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: chips[i]),
            ],
          ],
        );
      },
    );
  }
}

class _KpiChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  const _KpiChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.88, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Process chain board ──────────────────────────────────────────────────────
class _ProcessChainBoard extends StatelessWidget {
  final List<ProductionStage> stages;
  final ValueChanged<ProductionStage> onEditStage;
  final ValueChanged<ProductionStage> onDeleteStage;

  const _ProcessChainBoard({
    required this.stages,
    required this.onEditStage,
    required this.onDeleteStage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completed = stages.where((s) => s.status == 'completada').length;
    final progress = stages.isEmpty ? 0.0 : completed / stages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primaryContainer.withOpacity(0.45),
                cs.tertiaryContainer.withOpacity(0.30),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.route, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cadena productiva: $completed/${stages.length} etapas completadas',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWideTimeline = constraints.maxWidth >= 920;
            final isMobileTimeline = constraints.maxWidth < 500;

            Widget timelineRow() {
              return Row(
                children: List.generate(stages.length, (index) {
                  final stage = stages[index];
                  final normalized = stage.status.toLowerCase();
                  final isDone = normalized == 'completada';
                  final isProgress = normalized == 'en_proceso';
                  final nodeBg = isDone
                      ? const Color(0xFFC8E6C9)
                      : (isProgress
                            ? const Color(0xFFBBDEFB)
                            : cs.surfaceContainerHighest);
                  final nodeFg = isDone
                      ? const Color(0xFF1B5E20)
                      : (isProgress
                            ? const Color(0xFF0D47A1)
                            : cs.onSurfaceVariant);

                  return Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: nodeBg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: nodeFg.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _iconForProcess(stage.processName),
                              size: 15,
                              color: nodeFg,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isWideTimeline
                                    ? 150
                                    : (isMobileTimeline ? 80 : 120),
                              ),
                              child: Text(
                                stage.processName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: nodeFg,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (index < stages.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOut,
                            width: isWideTimeline
                                ? 34
                                : (isMobileTimeline ? 14 : 24),
                            height: 3,
                            decoration: BoxDecoration(
                              color: (isDone || isProgress)
                                  ? const Color(0xFF90CAF9)
                                  : cs.outline.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
              );
            }

            if (isWideTimeline) {
              return timelineRow();
            }

            return ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Colors.white,
                  Colors.white,
                  Colors.white.withOpacity(0),
                ],
                stops: const [0.0, 0.85, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: timelineRow(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        ...List.generate(stages.length, (index) {
          final stage = stages[index];
          return TweenAnimationBuilder<double>(
            key: ValueKey(stage.id),
            tween: Tween<double>(begin: 0.96, end: 1),
            duration: Duration(milliseconds: 220 + (index * 40)),
            curve: Curves.easeOutCubic,
            builder: (context, scale, child) => Opacity(
              opacity: scale,
              child: Transform.scale(scale: scale, child: child),
            ),
            child: _StageTile(
              stage: stage,
              onEdit: () => onEditStage(stage),
              onDelete: () => onDeleteStage(stage),
            ),
          );
        }),
      ],
    );
  }
}

class _PulsingIndicator extends StatefulWidget {
  const _PulsingIndicator();

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.35,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        final value = _opacity.value;
        return Transform.scale(
          scale: 0.92 + (value * 0.12),
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.25 * value),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

IconData _iconForProcess(String processName) {
  final p = processName.toLowerCase();
  if (p.contains('corte')) return Icons.content_cut;
  if (p.contains('torno')) return Icons.settings;
  if (p.contains('solda')) return Icons.bolt;
  if (p.contains('armad')) return Icons.handyman;
  if (p.contains('calidad') || p.contains('inspe')) return Icons.verified;
  if (p.contains('pint')) return Icons.format_paint;
  if (p.contains('empaque')) return Icons.inventory_2;
  return Icons.precision_manufacturing;
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final normalized = status.toLowerCase();

    Color bg;
    Color fg;
    String label;

    switch (normalized) {
      case 'en_proceso':
        bg = const Color(0xFFBBDEFB);
        fg = const Color(0xFF0D47A1);
        label = 'En proceso';
        break;
      case 'pausada':
      case 'bloqueada':
        bg = const Color(0xFFFFE0B2);
        fg = const Color(0xFFE65100);
        label = normalized == 'bloqueada' ? 'Bloqueada' : 'Pausada';
        break;
      case 'completada':
        bg = const Color(0xFFC8E6C9);
        fg = const Color(0xFF1B5E20);
        label = 'Completada';
        break;
      case 'cancelada':
        bg = const Color(0xFFFFCDD2);
        fg = const Color(0xFFB71C1C);
        label = 'Cancelada';
        break;
      default:
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        label = 'Planificada';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TagText extends StatelessWidget {
  final String text;

  const _TagText(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _InfoText extends StatelessWidget {
  final String label;
  final String value;

  const _InfoText(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (
      Color bg,
      Color fg,
      IconData icon,
      String label,
    ) = switch (priority) {
      'urgente' => (
        const Color(0xFFFFCDD2),
        const Color(0xFFB71C1C),
        Icons.bolt,
        'Urgente',
      ),
      'alta' => (
        const Color(0xFFFFF3E0),
        const Color(0xFFE65100),
        Icons.arrow_upward,
        'Alta',
      ),
      'media' => (
        const Color(0xFFE3F2FD),
        const Color(0xFF0D47A1),
        Icons.remove,
        'Media',
      ),
      'baja' => (
        const Color(0xFFE8F5E9),
        const Color(0xFF1B5E20),
        Icons.arrow_downward,
        'Baja',
      ),
      _ => (
        const Color(0xFFE3F2FD),
        const Color(0xFF0D47A1),
        Icons.remove,
        'Media',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityDropdown extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;

  const _PriorityDropdown({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      tooltip: 'Cambiar prioridad',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color(current).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: 18, color: _color(current)),
            const SizedBox(width: 6),
            Text(
              'Prioridad: ${_label(current)}',
              style: TextStyle(
                fontSize: 13,
                color: _color(current),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: _color(current)),
          ],
        ),
      ),
      itemBuilder: (_) => [
        _item('urgente', Icons.bolt, const Color(0xFFB71C1C)),
        _item('alta', Icons.arrow_upward, const Color(0xFFE65100)),
        _item('media', Icons.remove, const Color(0xFF0D47A1)),
        _item('baja', Icons.arrow_downward, const Color(0xFF1B5E20)),
      ],
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            _label(value),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          if (value == current) ...[
            const Spacer(),
            const Icon(Icons.check, size: 18),
          ],
        ],
      ),
    );
  }

  String _label(String p) => switch (p) {
    'urgente' => 'Urgente',
    'alta' => 'Alta',
    'media' => 'Media',
    'baja' => 'Baja',
    _ => 'Media',
  };

  Color _color(String p) => switch (p) {
    'urgente' => const Color(0xFFB71C1C),
    'alta' => const Color(0xFFE65100),
    'media' => const Color(0xFF0D47A1),
    'baja' => const Color(0xFF1B5E20),
    _ => const Color(0xFF0D47A1),
  };
}

// ── Dialog para agregar material al BOM ─────────────────────────────

class _AddBomMaterialDialog extends ConsumerStatefulWidget {
  final ProductionOrder order;
  const _AddBomMaterialDialog({required this.order});

  @override
  ConsumerState<_AddBomMaterialDialog> createState() =>
      _AddBomMaterialDialogState();
}

class _AddBomMaterialDialogState extends ConsumerState<_AddBomMaterialDialog>
    with SingleTickerProviderStateMixin {
  mat.Material? _selectedMaterial;
  final _titleController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _costController = TextEditingController(text: '0');

  // Weight calc fields
  late TabController _tabController;
  final _outerDiameterCtrl = TextEditingController(text: '1');
  final _thicknessCtrl = TextEditingController(text: '1/4');
  final _lengthCmCtrl = TextEditingController();
  final _widthCmCtrl = TextEditingController();
  final _calcQtyCtrl = TextEditingController(text: '1');
  String _calcType = 'cylinder'; // cylinder, rectangular_plate, shaft
  double _calculatedWeight = 0;
  double _calculatedCost = 0;
  static const double _density = 7.85;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    _outerDiameterCtrl.dispose();
    _thicknessCtrl.dispose();
    _lengthCmCtrl.dispose();
    _widthCmCtrl.dispose();
    _calcQtyCtrl.dispose();
    super.dispose();
  }

  double _inchFractionToMm(String value) {
    if (value.isEmpty) return 0;
    double total = 0;
    for (final part in value.trim().split(' ')) {
      if (part.contains('/')) {
        final f = part.split('/');
        if (f.length == 2) {
          total += (double.tryParse(f[0]) ?? 0) / (double.tryParse(f[1]) ?? 1);
        }
      } else {
        total += double.tryParse(part) ?? 0;
      }
    }
    return total * 25.4;
  }

  void _recalculate() {
    double weight = 0;
    final qty = double.tryParse(_calcQtyCtrl.text) ?? 1;
    final largoCm = double.tryParse(_lengthCmCtrl.text) ?? 0;
    final largoMm = largoCm * 10;

    switch (_calcType) {
      case 'cylinder':
        final outerD = _inchFractionToMm(_outerDiameterCtrl.text);
        final thickness = _inchFractionToMm(_thicknessCtrl.text);
        if (outerD > 0 && thickness > 0 && largoMm > 0) {
          weight = WeightCalculator.calculateCylinderWeight(
            outerDiameter: outerD,
            thickness: thickness,
            length: largoMm,
            density: _density,
          );
        }
      case 'rectangular_plate':
        final anchoCm = double.tryParse(_widthCmCtrl.text) ?? 0;
        final thickness = _inchFractionToMm(_thicknessCtrl.text);
        if (largoCm > 0 && anchoCm > 0 && thickness > 0) {
          weight = WeightCalculator.calculateRectangularPlateWeight(
            width: largoCm * 10,
            height: anchoCm * 10,
            thickness: thickness,
            density: _density,
          );
        }
      case 'shaft':
        final diameter = _inchFractionToMm(_outerDiameterCtrl.text);
        if (diameter > 0 && largoMm > 0) {
          weight = WeightCalculator.calculateShaftWeight(
            diameter: diameter,
            length: largoMm,
            density: _density,
          );
        }
    }

    setState(() {
      _calculatedWeight = weight * qty;
      _calculatedCost =
          _calculatedWeight * (_selectedMaterial?.effectiveCostPrice ?? 0);
    });
  }

  String _buildDimensions() {
    switch (_calcType) {
      case 'cylinder':
        return 'Tubo Ø${_outerDiameterCtrl.text}"×${_thicknessCtrl.text}"×${_lengthCmCtrl.text}cm';
      case 'rectangular_plate':
        return 'Lámina ${_lengthCmCtrl.text}×${_widthCmCtrl.text}cm×${_thicknessCtrl.text}"';
      case 'shaft':
        return 'Eje Ø${_outerDiameterCtrl.text}"×${_lengthCmCtrl.text}cm';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allMaterials = ref.watch(inventoryProvider).materials;
    final existingIds = widget.order.materials.map((m) => m.materialId).toSet();
    final available = allMaterials
        .where((m) => !existingIds.contains(m.id))
        .toList();
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    // Shared form content (between mobile and desktop)
    final formFields = <Widget>[
      // Título de la pieza
      TextField(
        controller: _titleController,
        decoration: const InputDecoration(
          labelText: 'Nombre de la pieza (opcional)',
          hintText: 'Ej: Tapa superior, Eje principal, Brida...',
          prefixIcon: Icon(Icons.label_outline),
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),

      // Material search
      if (available.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'No hay materiales disponibles para agregar.',
            textAlign: TextAlign.center,
          ),
        )
      else ...[
        Autocomplete<mat.Material>(
          displayStringForOption: (m) => '${m.name} (${m.code})',
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.toLowerCase().trim();
            if (query.isEmpty) return available.take(20);
            return available.where(
              (m) =>
                  m.name.toLowerCase().contains(query) ||
                  m.code.toLowerCase().contains(query),
            );
          },
          onSelected: (m) {
            setState(() {
              _selectedMaterial = m;
              _costController.text = m.effectivePrice.toStringAsFixed(2);
              final cat = m.category.toLowerCase();
              if (cat.contains('tubo') || cat.contains('tuberia')) {
                _calcType = 'cylinder';
              } else if (cat.contains('lam') ||
                  cat.contains('plat') ||
                  cat.contains('placa')) {
                _calcType = 'rectangular_plate';
              } else if (cat.contains('eje') || cat.contains('barra')) {
                _calcType = 'shaft';
              }
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Buscar material',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 250,
                    maxWidth: isMobile
                        ? MediaQuery.sizeOf(context).width - 32
                        : 490,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final m = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(m.name),
                        subtitle: Text(
                          '${m.code} • Stock: ${m.stock.toStringAsFixed(m.stock % 1 == 0 ? 0 : 2)} ${m.unit}',
                        ),
                        trailing: Text(
                          Helpers.formatCurrency(m.effectivePrice),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => onSelected(m),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],

      // Rest of form only if material selected
      if (_selectedMaterial != null) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_selectedMaterial!.name} — Stock: ${_selectedMaterial!.stock.toStringAsFixed(_selectedMaterial!.stock % 1 == 0 ? 0 : 2)} ${_selectedMaterial!.unit} — ${_selectedMaterial!.category}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.edit, size: 16), text: 'Directo'),
            Tab(icon: Icon(Icons.calculate, size: 16), text: 'Calcular Peso'),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            return _tabController.index == 0
                ? _buildDirectTab()
                : _buildCalcTab();
          },
        ),
      ],
    ];

    // Action buttons
    final cancelBtn = TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Cancelar'),
    );
    final addBtn = _selectedMaterial != null
        ? FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar'),
          )
        : const SizedBox.shrink();

    // ── Mobile: fullscreen Scaffold ──
    if (isMobile) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agregar material al BOM')),
        body: ListView(padding: const EdgeInsets.all(16), children: formFields),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [cancelBtn, const SizedBox(width: 8), addBtn],
            ),
          ),
        ),
      );
    }

    // ── Desktop: constrained Dialog ──
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Agregar material al BOM',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...formFields.where((w) => w is! AnimatedBuilder),
              if (_selectedMaterial != null)
                Flexible(
                  child: AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      return _tabController.index == 0
                          ? _buildDirectTab()
                          : _buildCalcTab();
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [cancelBtn, const SizedBox(width: 8), addBtn],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectTab() {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMobile) ...[
          TextField(
            controller: _qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cantidad requerida',
              suffixText: _selectedMaterial!.unit,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Costo estimado',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Cantidad requerida',
                    suffixText: _selectedMaterial!.unit,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _costController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Costo estimado',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCalcTab() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type selector
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTypeChip('cylinder', 'Tubo', Icons.panorama_horizontal),
              _buildTypeChip(
                'rectangular_plate',
                'Lámina',
                Icons.crop_landscape,
              ),
              _buildTypeChip('shaft', 'Eje', Icons.horizontal_rule),
            ],
          ),
          const SizedBox(height: 12),

          // Dimension fields
          _buildCalcDimensionFields(),
          const SizedBox(height: 10),

          // Quantity
          Row(
            children: [
              const SizedBox(
                width: 90,
                child: Text('Cantidad', style: TextStyle(fontSize: 12)),
              ),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _calcQtyCtrl,
                  decoration: InputDecoration(
                    hintText: '1',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalculate(),
                ),
              ),
              const Spacer(),
              Text(
                'Costo: \$ ${_selectedMaterial?.effectiveCostPrice.toStringAsFixed(2) ?? '0'}/KG',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Result box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _calculatedWeight > 0
                  ? Colors.green.withOpacity(0.08)
                  : Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _calculatedWeight > 0
                    ? Colors.green.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peso Total',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${_calculatedWeight.toStringAsFixed(3)} KG',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _calculatedWeight > 0
                            ? Colors.green.shade700
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Costo Total',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      Helpers.formatCurrency(_calculatedCost),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _calculatedWeight > 0
                            ? Colors.green.shade700
                            : Colors.grey,
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

  Widget _buildTypeChip(String type, String label, IconData icon) {
    final selected = _calcType == type;
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (v) {
        if (v) setState(() => _calcType = type);
        _recalculate();
      },
    );
  }

  Widget _buildCalcInchField(String label, TextEditingController ctrl) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: '0',
              suffixText: '"',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _recalculate(),
          ),
        ),
      ],
    );
  }

  Widget _buildCalcCmField(String label, TextEditingController ctrl) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: '0',
              suffixText: 'cm',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _recalculate(),
          ),
        ),
      ],
    );
  }

  Widget _buildCalcDimensionFields() {
    switch (_calcType) {
      case 'cylinder':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalcInchField('Ø Exterior', _outerDiameterCtrl),
            const SizedBox(height: 8),
            _buildCalcInchField('Espesor', _thicknessCtrl),
            const SizedBox(height: 8),
            _buildCalcCmField('Largo', _lengthCmCtrl),
          ],
        );
      case 'rectangular_plate':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalcCmField('Largo', _lengthCmCtrl),
            const SizedBox(height: 8),
            _buildCalcCmField('Ancho', _widthCmCtrl),
            const SizedBox(height: 8),
            _buildCalcInchField('Espesor', _thicknessCtrl),
          ],
        );
      case 'shaft':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCalcInchField('Diámetro', _outerDiameterCtrl),
            const SizedBox(height: 8),
            _buildCalcCmField('Largo', _lengthCmCtrl),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _save() {
    final m = _selectedMaterial;
    if (m == null) return;

    final isCalcMode = _tabController.index == 1;
    final double qty;
    final double cost;
    String? dimensions;

    if (isCalcMode) {
      if (_calculatedWeight <= 0) return;
      qty = _calculatedWeight;
      cost = _calculatedCost;
      dimensions = _buildDimensions();
    } else {
      qty = double.tryParse(_qtyController.text) ?? 1;
      cost = double.tryParse(_costController.text) ?? 0;
      if (qty <= 0) return;
    }

    final title = _titleController.text.trim();

    ref
        .read(productionOrdersProvider.notifier)
        .addMaterialToOrder(
          orderId: widget.order.id,
          materialId: m.id,
          materialName: m.name,
          materialCode: m.code,
          requiredQuantity: qty,
          unit: isCalcMode ? 'KG' : m.unit,
          estimatedCost: cost,
          pieceTitle: title.isNotEmpty ? title : null,
          dimensions: dimensions,
        );
    Navigator.pop(context);
  }
}
