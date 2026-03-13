import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/helpers.dart';
import '../../data/providers/composite_products_provider.dart';
import '../../data/providers/employees_provider.dart';
import '../../data/providers/production_orders_provider.dart';
import '../../domain/entities/composite_product.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/production_order.dart';

class ProductionOrdersPage extends ConsumerStatefulWidget {
  const ProductionOrdersPage({super.key});

  @override
  ConsumerState<ProductionOrdersPage> createState() =>
      _ProductionOrdersPageState();
}

class _ProductionOrdersPageState extends ConsumerState<ProductionOrdersPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(productionOrdersProvider.notifier).loadOrders();
      await ref.read(compositeProductsProvider.notifier).loadProducts();
      await ref
          .read(employeesProvider.notifier)
          .loadEmployees(activeOnly: true);
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
      body: Column(
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
                          SizedBox(width: 420, child: _buildOrdersList(state)),
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = orders[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openOrderDetailDialog(order),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _OrderCardContent(order: order),
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

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = orders[index];
        final selected = state.selectedOrderId == order.id;

        return Material(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.55)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => ref
                .read(productionOrdersProvider.notifier)
                .selectOrder(order.id),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: _OrderCardContent(order: order),
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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildOrderHeader(order),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Componentes y Materiales (BOM)',
          icon: Icons.inventory_2,
          child: order.materials.isEmpty
              ? const Text('La OP no tiene materiales vinculados')
              : Column(
                  children: order.materials
                      .map(
                        (m) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.chevron_right),
                          title: Text(m.materialName),
                          subtitle: Text(
                            '${m.requiredQuantity.toStringAsFixed(2)} ${m.unit} • Pendiente: ${m.pendingQuantity.toStringAsFixed(2)} ${m.unit}',
                          ),
                          trailing: Text(
                            Helpers.formatCurrency(m.estimatedCost),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        _buildSectionCard(
          title: 'Flujo de Procesos en Cadena',
          icon: Icons.account_tree,
          trailing: OutlinedButton.icon(
            onPressed: () => _openStageDialog(order: order),
            icon: const Icon(Icons.add),
            label: const Text('Agregar etapa'),
          ),
          child: order.stages.isEmpty
              ? const Text('Sin etapas configuradas')
              : Column(
                  children: order.stages
                      .map(
                        (stage) => _StageTile(
                          stage: stage,
                          onEdit: () =>
                              _openStageDialog(order: order, stage: stage),
                          onDelete: () => _deleteStage(order.id, stage.id),
                        ),
                      )
                      .toList(),
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

    return Container(
      padding: const EdgeInsets.all(16),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.productCode} • ${order.productName}',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _InfoText('Cantidad', order.quantity.toStringAsFixed(2)),
              _InfoText('Entrega', Helpers.formatDate(order.dueDate)),
              _InfoText(
                'Etapas',
                '${order.completedStages}/${order.stages.length}',
              ),
              _InfoText(
                'Costo material estimado',
                Helpers.formatCurrency(order.estimatedMaterialCost),
              ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.all(16),
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
    await ref
        .read(productionOrdersProvider.notifier)
        .updateOrderStatus(orderId, status);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Estado actualizado a: $status')));
  }

  void _deleteStage(String orderId, String stageId) async {
    await ref
        .read(productionOrdersProvider.notifier)
        .deleteStage(orderId: orderId, stageId: stageId);
  }

  void _openCreateOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreateProductionOrderDialog(),
    );
  }

  void _openStageDialog({
    required ProductionOrder order,
    ProductionStage? stage,
  }) {
    showDialog(
      context: context,
      builder: (context) => _EditStageDialog(order: order, stage: stage),
    );
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
        Text(order.productName, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    final productsState = ref.watch(compositeProductsProvider);
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width < 700 ? width * 0.92 : 650.0;

    return AlertDialog(
      title: const Text('Nueva Orden de Produccion'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
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
                        DropdownMenuItem(
                          value: 'urgente',
                          child: Text('Urgente'),
                        ),
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
                children: _templates.map((process) {
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
                        }
                      });
                    },
                  );
                }).toList(),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_isSaving ? 'Creando...' : 'Crear OP'),
        ),
      ],
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
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
            processChain: _selectedProcesses,
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
    final employees = ref.watch(employeesProvider).activeEmployees;
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width < 700 ? width * 0.92 : 620.0;

    return AlertDialog(
      title: Text(_isEditing ? 'Editar etapa' : 'Nueva etapa'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
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
                  DropdownMenuItem(
                    value: 'pendiente',
                    child: Text('Pendiente'),
                  ),
                  DropdownMenuItem(
                    value: 'en_proceso',
                    child: Text('En proceso'),
                  ),
                  DropdownMenuItem(
                    value: 'bloqueada',
                    child: Text('Bloqueada'),
                  ),
                  DropdownMenuItem(
                    value: 'completada',
                    child: Text('Completada'),
                  ),
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
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : () => _save(employees),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
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
          );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context);
  }
}

class _StageTile extends StatelessWidget {
  final ProductionStage stage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StageTile({
    required this.stage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 480;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: cs.surfaceContainerHighest.withOpacity(0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCompact)
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    stage.sequenceOrder.toString(),
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stage.processName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
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
                      child: Text(
                        stage.sequenceOrder.toString(),
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stage.processName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _StatusChip(status: stage.status),
                    const Spacer(),
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
                ),
              ],
            ),
          const SizedBox(height: 4),
          Text('Mesa: ${stage.workstation}'),
          Text(
            'Empleado: ${stage.assignedEmployeeName ?? 'Sin asignar'} • Horas: ${stage.actualHours.toStringAsFixed(1)}/${stage.estimatedHours.toStringAsFixed(1)}',
          ),
          if (stage.resources.isNotEmpty)
            Text('Recursos: ${stage.resources.join(', ')}'),
          if (stage.report != null && stage.report!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Informe: ${stage.report!}'),
            ),
        ],
      ),
    );
  }
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
