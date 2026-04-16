import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/datasources/shipments_datasource.dart';
import '../../data/providers/shipments_provider.dart';
import '../../domain/entities/shipment_order.dart';
import '../widgets/shipment_form_dialog.dart';
import '../widgets/shipment_print_preview.dart';
import '../../core/utils/colombia_time.dart';

class ShipmentsPage extends ConsumerStatefulWidget {
  const ShipmentsPage({super.key});

  @override
  ConsumerState<ShipmentsPage> createState() => _ShipmentsPageState();
}

class _ShipmentsPageState extends ConsumerState<ShipmentsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(shipmentsProvider.notifier).setTab(_tabController.index);
      }
    });
    Future.microtask(() => ref.read(shipmentsProvider.notifier).loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shipmentsProvider);
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isCompact),
            if (!state.isLoading) _buildSummaryCards(state, isCompact),
            _buildTabBar(isCompact),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFutureDeliveriesTab(state, isCompact),
                        _buildRemisionesTab(state, isCompact),
                        _buildHistoryTab(state, isCompact),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader(bool isCompact) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 16 : 24,
        20,
        isCompact ? 16 : 24,
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 8 : 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(isCompact ? 10 : 12),
            ),
            child: Icon(
              Icons.local_shipping,
              color: const Color(0xFF1565C0),
              size: isCompact ? 22 : 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remisiones y Entregas',
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B2838),
                  ),
                ),
                if (!isCompact)
                  Text(
                    'Envíos, remisiones y seguimiento de entregas',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref.read(shipmentsProvider.notifier).loadAll(),
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Actualizar',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SUMMARY CARDS
  // ═══════════════════════════════════════════════════════════
  Widget _buildSummaryCards(ShipmentsState state, bool isCompact) {
    final overdueCount = state.futureDeliveries
        .where((d) => d.isOverdue)
        .length;

    final cards = <_SummaryData>[
      _SummaryData(
        'En Producción',
        '${state.futureInProduction}',
        Icons.factory,
        const Color(0xFFFF9800),
      ),
      _SummaryData(
        'Listas Envío',
        '${state.futureReady}',
        Icons.check_circle,
        const Color(0xFF4CAF50),
      ),
      if (overdueCount > 0)
        _SummaryData(
          'Atrasadas',
          '$overdueCount',
          Icons.warning_amber_rounded,
          const Color(0xFFC62828),
        ),
      _SummaryData(
        'En Ruta',
        '${(state.summaryCounts['despachada'] ?? 0) + (state.summaryCounts['en_transito'] ?? 0)}',
        Icons.local_shipping,
        const Color(0xFF2196F3),
      ),
      _SummaryData(
        'Remisiones',
        '${state.summaryCounts['total'] ?? 0}',
        Icons.description,
        const Color(0xFF9C27B0),
      ),
    ];

    if (isCompact) {
      // Mobile: horizontal scrollable compact chips
      return SizedBox(
        height: 60,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final c = cards[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.color.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icon, color: c.color, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        c.value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: c.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.label,
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map(
              (c) =>
                  _buildSummaryCard(c.label, c.value, c.icon, c.color, false),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isCompact,
  ) {
    return Container(
      width: isCompact ? null : 170.0,
      constraints: isCompact ? const BoxConstraints(minWidth: 100) : null,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 14,
        vertical: isCompact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB BAR
  // ═══════════════════════════════════════════════════════════
  Widget _buildTabBar(bool isCompact) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        isCompact ? 16 : 24,
        8,
        isCompact ? 16 : 24,
        0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: isCompact,
        labelColor: const Color(0xFF1565C0),
        unselectedLabelColor: Colors.grey[600],
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(10),
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 16),
                SizedBox(width: 6),
                Text('Entregas Futuras'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.description, size: 16),
                SizedBox(width: 6),
                Text('Remisiones'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 16),
                SizedBox(width: 6),
                Text('Historial'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 1: ENTREGAS FUTURAS
  // ═══════════════════════════════════════════════════════════
  Widget _buildFutureDeliveriesTab(ShipmentsState state, bool isCompact) {
    final deliveries = state.futureDeliveries;
    if (deliveries.isEmpty) {
      return _buildEmptyState(
        icon: Icons.schedule,
        title: 'Sin entregas futuras',
        subtitle:
            'Las órdenes de producción vinculadas a facturas aparecerán aquí',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 12 : 24,
        12,
        isCompact ? 12 : 24,
        24,
      ),
      itemCount: deliveries.length,
      itemBuilder: (context, index) =>
          _buildFutureDeliveryCard(deliveries[index]),
    );
  }

  Widget _buildFutureDeliveryCard(FutureDelivery delivery) {
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (delivery.isCompleted) {
      statusColor = const Color(0xFF4CAF50);
      statusLabel = 'COMPLETADA';
      statusIcon = Icons.check_circle;
    } else if (delivery.isOverdue) {
      statusColor = const Color(0xFFC62828);
      statusLabel = 'ATRASADA';
      statusIcon = Icons.warning;
    } else {
      statusColor = const Color(0xFFFF9800);
      statusLabel = 'En proceso';
      statusIcon = Icons.autorenew;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: delivery.isOverdue
              ? const Color(0xFFFFCDD2)
              : const Color(0xFFE0E0E0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    delivery.productionOrderCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    delivery.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Contenido
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cliente + Factura
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        delivery.customerName,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        delivery.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Barra de progreso
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: delivery.progress,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            delivery.isCompleted
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF2196F3),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${delivery.completedStages}/${delivery.totalStages}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Fechas + Acción
                Row(
                  children: [
                    if (delivery.deliveryDate != null) ...[
                      Icon(
                        Icons.event,
                        size: 14,
                        color: delivery.isOverdue
                            ? const Color(0xFFC62828)
                            : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Entrega: ${_dateFormat.format(delivery.deliveryDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: delivery.isOverdue
                              ? const Color(0xFFC62828)
                              : Colors.grey[600],
                          fontWeight: delivery.isOverdue
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (delivery.isOverdue) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC62828),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${ColombiaTime.now().difference(delivery.deliveryDate!).inDays}d atraso',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                    const Spacer(),
                    Text(
                      'Cant: ${delivery.quantity.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (delivery.isCompleted) ...[
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: () =>
                            _openCreateShipmentFromDelivery(delivery),
                        icon: const Icon(Icons.local_shipping, size: 16),
                        label: const Text('Crear Envío'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 2: REMISIONES
  // ═══════════════════════════════════════════════════════════
  Widget _buildRemisionesTab(ShipmentsState state, bool isCompact) {
    final shipments = state.filteredShipments;

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 12 : 24,
            12,
            isCompact ? 12 : 24,
            8,
          ),
          child: isCompact
              ? Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Buscar...',
                                hintStyle: const TextStyle(fontSize: 13),
                                prefixIcon: const Icon(Icons.search, size: 18),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE0E0E0),
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              style: const TextStyle(fontSize: 13),
                              onChanged: (v) => ref
                                  .read(shipmentsProvider.notifier)
                                  .setSearch(v),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: state.filterStatus,
                              isDense: true,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'todos',
                                  child: Text('Todos'),
                                ),
                                DropdownMenuItem(
                                  value: 'borrador',
                                  child: Text('Borrador'),
                                ),
                                DropdownMenuItem(
                                  value: 'despachada',
                                  child: Text('Despachada'),
                                ),
                                DropdownMenuItem(
                                  value: 'entregada',
                                  child: Text('Entregada'),
                                ),
                                DropdownMenuItem(
                                  value: 'anulada',
                                  child: Text('Anulada'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  ref
                                      .read(shipmentsProvider.notifier)
                                      .setFilter(v);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          heroTag: 'newRemision',
                          onPressed: () => _openCreateShipment(),
                          backgroundColor: const Color(0xFF4CAF50),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openCreateShipment(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva Remisión'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: state.filterStatus,
                          isDense: true,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'todos',
                              child: Text('Todos'),
                            ),
                            DropdownMenuItem(
                              value: 'borrador',
                              child: Text('Borrador'),
                            ),
                            DropdownMenuItem(
                              value: 'despachada',
                              child: Text('Despachada'),
                            ),
                            DropdownMenuItem(
                              value: 'entregada',
                              child: Text('Entregada'),
                            ),
                            DropdownMenuItem(
                              value: 'anulada',
                              child: Text('Anulada'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              ref.read(shipmentsProvider.notifier).setFilter(v);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar...',
                            hintStyle: const TextStyle(fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE0E0E0),
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: const TextStyle(fontSize: 13),
                          onChanged: (v) =>
                              ref.read(shipmentsProvider.notifier).setSearch(v),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        // Lista
        Expanded(
          child: shipments.isEmpty
              ? _buildEmptyState(
                  icon: Icons.description,
                  title: 'Sin remisiones',
                  subtitle: 'Crea tu primera remisión con el botón +',
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 12 : 24,
                    4,
                    isCompact ? 12 : 24,
                    24,
                  ),
                  itemCount: shipments.length,
                  itemBuilder: (context, index) =>
                      _buildShipmentCard(shipments[index], isCompact),
                ),
        ),
      ],
    );
  }

  Widget _buildShipmentCard(ShipmentOrder shipment, bool isCompact) {
    final statusColors = {
      ShipmentStatus.borrador: const Color(0xFFFF9800),
      ShipmentStatus.despachada: const Color(0xFF2196F3),
      ShipmentStatus.enTransito: const Color(0xFF00BCD4),
      ShipmentStatus.entregada: const Color(0xFF4CAF50),
      ShipmentStatus.anulada: const Color(0xFFC62828),
    };
    final color = statusColors[shipment.status] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: isCompact
            ? _buildShipmentCardCompact(shipment, color)
            : _buildShipmentCardDesktop(shipment, color),
      ),
    );
  }

  Widget _buildShipmentCardDesktop(ShipmentOrder shipment, Color color) {
    return Row(
      children: [
        // Código
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            shipment.code,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Fecha
        Text(
          _dateFormat.format(shipment.dispatchDate),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(width: 14),
        // Cliente
        Expanded(
          child: Text(
            shipment.customerName,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Factura
        if (shipment.invoiceFullNumber != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              shipment.invoiceFullNumber!,
              style: const TextStyle(fontSize: 10, color: Color(0xFF1565C0)),
            ),
          ),
          const SizedBox(width: 10),
        ],
        // Items
        Text(
          '${shipment.totalItems} ítems',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(width: 14),
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            shipment.statusLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Acciones
        ..._buildShipmentActions(shipment),
      ],
    );
  }

  Widget _buildShipmentCardCompact(ShipmentOrder shipment, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                shipment.code,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _dateFormat.format(shipment.dispatchDate),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                shipment.statusLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          shipment.customerName,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${shipment.totalItems} ítems',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const Spacer(),
            ..._buildShipmentActions(shipment),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildShipmentActions(ShipmentOrder shipment) {
    final actions = <Widget>[];

    if (shipment.status == ShipmentStatus.borrador) {
      actions.add(
        _actionButton(
          Icons.edit,
          'Editar',
          const Color(0xFFFF9800),
          () => _openEditShipment(shipment),
        ),
      );
    }

    // Imprimir siempre disponible
    actions.add(
      _actionButton(
        Icons.print,
        'Imprimir',
        const Color(0xFF1565C0),
        () => ShipmentPrintService.printShipment(shipment),
      ),
    );

    if (shipment.status == ShipmentStatus.borrador) {
      actions.add(
        _actionButton(
          Icons.local_shipping,
          'Despachar',
          const Color(0xFF4CAF50),
          () => _confirmDispatch(shipment),
        ),
      );
      actions.add(
        _actionButton(
          Icons.cancel,
          'Anular',
          const Color(0xFFC62828),
          () => _confirmCancel(shipment),
        ),
      );
    }

    if (shipment.status == ShipmentStatus.despachada ||
        shipment.status == ShipmentStatus.enTransito) {
      actions.add(
        _actionButton(
          Icons.check_circle,
          'Confirmar entrega',
          const Color(0xFF4CAF50),
          () => _confirmDelivery(shipment),
        ),
      );
    }

    return actions;
  }

  Widget _actionButton(
    IconData icon,
    String tooltip,
    Color color,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TAB 3: HISTORIAL
  // ═══════════════════════════════════════════════════════════
  Widget _buildHistoryTab(ShipmentsState state, bool isCompact) {
    final history = state.historyShipments;
    if (history.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'Sin historial',
        subtitle: 'Los envíos entregados y anulados aparecerán aquí',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 12 : 24,
        12,
        isCompact ? 12 : 24,
        24,
      ),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final s = history[index];
        final isDelivered = s.status == ShipmentStatus.entregada;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDelivered
                  ? const Color(0xFFC8E6C9)
                  : const Color(0xFFFFCDD2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isDelivered ? Icons.check_circle : Icons.cancel,
                color: isDelivered
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFC62828),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          s.code,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.customerName,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${s.totalItems} ítems • ${_dateFormat.format(s.dispatchDate)}'
                      '${s.deliveredAt != null ? ' → ${_dateFormat.format(s.deliveredAt!)}' : ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (s.receivedBy != null)
                      Text(
                        'Recibió: ${s.receivedBy}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ShipmentPrintService.printShipment(s),
                icon: const Icon(Icons.print, size: 18),
                tooltip: 'Reimprimir',
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACCIONES / DIALOGS
  // ═══════════════════════════════════════════════════════════
  void _openCreateShipment() {
    final notifier = ref.read(shipmentsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShipmentFormDialog(
        onSave: (order) async {
          final ok = await notifier.createShipment(order);
          if (ok) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Remisión creada'),
                backgroundColor: Color(0xFF43A047),
              ),
            );
          }
        },
      ),
    );
  }

  void _openCreateShipmentFromDelivery(FutureDelivery delivery) async {
    // Pre-cargar ítems desde la OP
    final items = await ShipmentsDataSource.getItemsFromProductionOrder(
      delivery.productionOrderId,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShipmentFormDialog(
        initialInvoiceId: delivery.invoiceId,
        initialProductionOrderId: delivery.productionOrderId,
        initialCustomerName: delivery.customerName,
        initialInvoiceNumber: delivery.invoiceNumber,
        initialItems: items.isNotEmpty ? items : null,
        onSave: (order) async {
          final notifier2 = ref.read(shipmentsProvider.notifier);
          final ok = await notifier2.createShipment(order);
          if (ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Remisión creada desde producción'),
                backgroundColor: Color(0xFF43A047),
              ),
            );
          }
        },
      ),
    );
  }

  void _openEditShipment(ShipmentOrder shipment) {
    final notifier = ref.read(shipmentsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ShipmentFormDialog(
        existingShipment: shipment,
        onSave: (order) async {
          final ok = await notifier.updateShipment(order);
          if (ok) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Remisión actualizada'),
                backgroundColor: Color(0xFF43A047),
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDispatch(ShipmentOrder shipment) {
    final notifier = ref.read(shipmentsProvider.notifier);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Despachar'),
        content: Text('¿Despachar remisión ${shipment.code}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await notifier.dispatchShipment(shipment.id);
            },
            child: const Text('Despachar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelivery(ShipmentOrder shipment) {
    final notifier = ref.read(shipmentsProvider.notifier);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Entrega'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Confirmar entrega de ${shipment.code}?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Recibido por',
                hintText: 'Nombre de quien recibe',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await notifier.confirmDelivery(
                shipment.id,
                receivedBy: controller.text.trim().isNotEmpty
                    ? controller.text.trim()
                    : null,
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(ShipmentOrder shipment) {
    final notifier = ref.read(shipmentsProvider.notifier);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular Remisión'),
        content: Text(
          '¿Anular la remisión ${shipment.code}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await notifier.cancelShipment(shipment.id);
            },
            child: const Text('Anular'),
          ),
        ],
      ),
    );
  }
}

class _SummaryData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryData(this.label, this.value, this.icon, this.color);
}
