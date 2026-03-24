import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/logger.dart';
import '../../data/datasources/invoices_datasource.dart';
import '../../domain/entities/invoice.dart';
import 'delivery_material_detail_page.dart';

class PendingDeliveriesPage extends ConsumerStatefulWidget {
  const PendingDeliveriesPage({super.key});

  @override
  ConsumerState<PendingDeliveriesPage> createState() =>
      _PendingDeliveriesPageState();
}

class _PendingDeliveriesPageState extends ConsumerState<PendingDeliveriesPage> {
  List<Invoice> _deliveries = [];
  bool _isLoading = true;
  // Controllers para costo de material editable por factura
  final Map<String, TextEditingController> _materialTotalControllers = {};
  final Map<String, TextEditingController> _materialPendingControllers = {};

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  @override
  void dispose() {
    for (final c in _materialTotalControllers.values) {
      c.dispose();
    }
    for (final c in _materialPendingControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _isLoading = true);
    try {
      final deliveries = await InvoicesDataSource.getPendingDeliveries();
      // Crear controllers para cada factura
      for (final d in deliveries) {
        _materialTotalControllers.putIfAbsent(
          d.id,
          () => TextEditingController(
            text: d.materialCostTotal > 0
                ? d.materialCostTotal.toStringAsFixed(0)
                : '',
          ),
        );
        _materialPendingControllers.putIfAbsent(
          d.id,
          () => TextEditingController(
            text: d.materialCostPending > 0
                ? d.materialCostPending.toStringAsFixed(0)
                : '',
          ),
        );
      }
      setState(() {
        _deliveries = deliveries;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error cargando entregas pendientes: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMaterialCosts(Invoice invoice) async {
    final total =
        double.tryParse(_materialTotalControllers[invoice.id]?.text ?? '') ?? 0;
    final pending =
        double.tryParse(_materialPendingControllers[invoice.id]?.text ?? '') ??
        0;
    try {
      await InvoicesDataSource.updateMaterialCosts(
        invoice.id,
        materialCostTotal: total,
        materialCostPending: pending,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Costos actualizados para ${invoice.fullNumber}'),
            backgroundColor: const Color(0xFF43A047),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error guardando costos: $e');
    }
  }

  // Totales
  double get _totalSale => _deliveries.fold(0.0, (s, d) => s + d.total);
  double get _totalPaid => _deliveries.fold(0.0, (s, d) => s + d.paidAmount);
  double get _totalPending =>
      _deliveries.fold(0.0, (s, d) => s + d.pendingAmount);
  double get _totalMaterialCost =>
      _deliveries.fold(0.0, (s, d) => s + d.materialCostTotal);
  double get _totalMaterialPending =>
      _deliveries.fold(0.0, (s, d) => s + d.materialCostPending);

  bool _isDeliveryOverdue(DateTime date) =>
      date.isBefore(DateTime.now().subtract(const Duration(hours: 12)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          if (!_isLoading) _buildSummaryCards(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _deliveries.isEmpty
                ? _buildEmptyState()
                : _buildDeliveriesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: Color(0xFF1565C0),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Entregas Pendientes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B2838),
                  ),
                ),
                Text(
                  '${_deliveries.length} trabajos con adelanto por entregar',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadDeliveries,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildSummaryCard(
            'Total Ventas',
            Helpers.formatCurrency(_totalSale),
            Icons.shopping_cart,
            const Color(0xFF1565C0),
          ),
          _buildSummaryCard(
            'Recibido',
            Helpers.formatCurrency(_totalPaid),
            Icons.check_circle,
            const Color(0xFF43A047),
          ),
          _buildSummaryCard(
            'Por Cobrar',
            Helpers.formatCurrency(_totalPending),
            Icons.pending_actions,
            const Color(0xFFE65100),
          ),
          _buildSummaryCard(
            'Material Total',
            Helpers.formatCurrency(_totalMaterialCost),
            Icons.inventory_2,
            const Color(0xFF6A1B9A),
          ),
          _buildSummaryCard(
            'Material por Comprar',
            Helpers.formatCurrency(_totalMaterialPending),
            Icons.shopping_bag,
            const Color(0xFFC62828),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    fontSize: 14,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No hay entregas pendientes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las ventas con adelanto aparecerán aquí',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: _deliveries.length,
      itemBuilder: (context, index) => _buildDeliveryCard(_deliveries[index]),
    );
  }

  Widget _buildDeliveryCard(Invoice invoice) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final paidPercent = invoice.total > 0
        ? (invoice.paidAmount / invoice.total)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header de la tarjeta
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
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
                    invoice.fullNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    invoice.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  dateFormat.format(invoice.issueDate),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (invoice.deliveryDate != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _isDeliveryOverdue(invoice.deliveryDate!)
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_shipping,
                          size: 12,
                          color: _isDeliveryOverdue(invoice.deliveryDate!)
                              ? const Color(0xFFC62828)
                              : const Color(0xFFE65100),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(invoice.deliveryDate!),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isDeliveryOverdue(invoice.deliveryDate!)
                                ? const Color(0xFFC62828)
                                : const Color(0xFFE65100),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Items del pedido
          if (invoice.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                children: invoice.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 6,
                          color: Color(0xFF90CAF9),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item.productName}${item.description != null && item.description!.isNotEmpty ? ' (${item.description})' : ''}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 2)} ${item.unit}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const Divider(height: 1),
          // Montos: pagado, pendiente, total
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Barra de progreso
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: paidPercent,
                    backgroundColor: const Color(0xFFFFCDD2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF43A047),
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildAmountColumn(
                      'Total Venta',
                      Helpers.formatCurrency(invoice.total),
                      const Color(0xFF1B2838),
                    ),
                    _buildAmountColumn(
                      'Adelanto Recibido',
                      Helpers.formatCurrency(invoice.paidAmount),
                      const Color(0xFF43A047),
                    ),
                    _buildAmountColumn(
                      'Por Cobrar',
                      Helpers.formatCurrency(invoice.pendingAmount),
                      const Color(0xFFE65100),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Campos editables de costo de material
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _buildMaterialCostField(
                    label: 'Costo Material Total',
                    controller: _materialTotalControllers[invoice.id]!,
                    color: const Color(0xFF6A1B9A),
                    icon: Icons.inventory_2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMaterialCostField(
                    label: 'Material por Comprar',
                    controller: _materialPendingControllers[invoice.id]!,
                    color: const Color(0xFFC62828),
                    icon: Icons.shopping_bag,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            DeliveryMaterialDetailPage(invoice: invoice),
                      ),
                    );
                    if (result == true) _loadDeliveries();
                  },
                  icon: const Icon(Icons.calculate),
                  color: const Color(0xFF6A1B9A),
                  tooltip: 'Calcular materiales',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF3E5F5),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _saveMaterialCosts(invoice),
                  icon: const Icon(Icons.save),
                  color: const Color(0xFF1565C0),
                  tooltip: 'Guardar costos',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE3F2FD),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialCostField({
    required String label,
    required TextEditingController controller,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 13, color: color),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 16, color: color),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 0,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: color, width: 2),
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
