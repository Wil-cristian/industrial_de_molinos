import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/quotations_provider.dart';

class QuotationsPage extends ConsumerStatefulWidget {
  const QuotationsPage({super.key});

  @override
  ConsumerState<QuotationsPage> createState() => _QuotationsPageState();
}

class _QuotationsPageState extends ConsumerState<QuotationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _filterStatus = 'Todas';

  // Los datos vienen del provider, ya no hardcodeados
  List<Map<String, dynamic>> get _quotations {
    final state = ref.watch(quotationsProvider);
    return state.quotations
        .map(
          (q) => {
            'id': q.id,
            'number': q.number,
            'date': q.date,
            'validUntil': q.validUntil,
            'customer': q.customerName,
            'customerRuc': q.customerId, // Usamos customerId como RUC
            'description': q.notes.isNotEmpty
                ? q.notes.split('\n').first
                : 'Cotización ${q.number}',
            'status': q.status,
            'materialsCost': q.materialsCost,
            'laborCost': q.laborCost,
            'indirectCosts': q.indirectCosts,
            'profitMargin': q.profitMargin,
            'total': q.total,
            'weight': q.totalWeight,
            'notes': q.notes,
            'items': q.items
                .map(
                  (item) => {
                    'name': item.name,
                    'type': item.type,
                    'productCode': item.materialType,
                    'quantity': item.quantity,
                    'totalWeight': item.totalWeight,
                    'totalPrice': item.totalPrice,
                    'totalCost': item.totalCost,
                    'pricePerKg': item.pricePerKg,
                    'costPerKg': item.costPerKg,
                    'unitSalePrice': item.pricePerKg,
                    'unitCostPrice': item.costPerKg,
                    'totalProfit': item.totalProfit,
                    'profitMargin': item.profitMargin,
                  },
                )
                .toList(),
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> get _filteredQuotations {
    return _quotations.where((q) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          q['number'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          q['customer'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          q['description'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      final matchesFilter =
          _filterStatus == 'Todas' || q['status'] == _filterStatus;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  // Estadísticas
  int get _totalQuotations => _quotations.length;
  int get _pendingQuotations => _quotations
      .where((q) => q['status'] == 'Enviada' || q['status'] == 'Borrador')
      .length;
  int get _approvedQuotations =>
      _quotations.where((q) => q['status'] == 'Aprobada').length;
  double get _totalApprovedValue => _quotations
      .where((q) => q['status'] == 'Aprobada')
      .fold(0.0, (sum, q) => sum + (q['total'] as double? ?? 0.0));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _filterStatus = 'Todas';
            break;
          case 1:
            _filterStatus = 'Borrador';
            break;
          case 2:
            _filterStatus = 'Enviada';
            break;
          case 3:
            _filterStatus = 'Aprobada';
            break;
          case 4:
            _filterStatus = 'Rechazada';
            break;
          case 5:
            _filterStatus = 'Anulada';
            break;
        }
      });
    });
    // Cargar cotizaciones desde Supabase
    Future.microtask(
      () => ref.read(quotationsProvider.notifier).loadQuotations(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quotationsState = ref.watch(quotationsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header
          _buildHeader(),
          // Stats Cards
          _buildStatsCards(),
          // Tabs y Lista
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                labelColor: AppTheme.primaryColor,
                                unselectedLabelColor: Colors.grey[600],
                                indicatorColor: AppTheme.primaryColor,
                                isScrollable: true,
                                tabs: [
                                  Tab(text: 'Todas ($_totalQuotations)'),
                                  Tab(
                                    text:
                                        'Borrador (${_quotations.where((q) => q['status'] == 'Borrador').length})',
                                  ),
                                  Tab(
                                    text:
                                        'Enviadas (${_quotations.where((q) => q['status'] == 'Enviada').length})',
                                  ),
                                  Tab(text: 'Aprobadas ($_approvedQuotations)'),
                                  Tab(
                                    text:
                                        'Rechazadas (${_quotations.where((q) => q['status'] == 'Rechazada').length})',
                                  ),
                                  Tab(
                                    text:
                                        'Anuladas (${_quotations.where((q) => q['status'] == 'Anulada').length})',
                                  ),
                                ],
                              ),
                            ),
                            // Search Bar
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: TextField(
                                onChanged: (value) =>
                                    setState(() => _searchQuery = value),
                                decoration: InputDecoration(
                                  hintText:
                                      'Buscar por número, cliente o descripción...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                              ),
                            ),
                            // Lista de cotizaciones
                            Expanded(
                              child: quotationsState.isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : quotationsState.error != null
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 48,
                                            color: Colors.red[300],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Error: ${quotationsState.error}',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            onPressed: () => ref
                                                .read(
                                                  quotationsProvider.notifier,
                                                )
                                                .loadQuotations(),
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('Reintentar'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _filteredQuotations.isEmpty
                                  ? _buildEmptyState()
                                  : ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      itemCount: _filteredQuotations.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final quotation =
                                            _filteredQuotations[index];
                                        return _buildQuotationItem(quotation);
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            onPressed: () => context.go('/'),
            tooltip: 'Volver al menú',
            visualDensity: VisualDensity.compact,
          ),
          Text(
            'Cotizaciones',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Gestión de cotizaciones',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const Spacer(),
          // Botones de acción
          OutlinedButton.icon(
            onPressed: () {
              // Exportar cotizaciones
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Exportar'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => context.go('/quotations/new'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nueva Cotización'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total',
              _totalQuotations.toString(),
              Icons.description,
              Colors.blue,
              'Este mes',
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _buildStatCard(
              'Pendientes',
              _pendingQuotations.toString(),
              Icons.hourglass_empty,
              Colors.orange,
              'Por responder',
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _buildStatCard(
              'Aprobadas',
              _approvedQuotations.toString(),
              Icons.check_circle,
              Colors.green,
              'Listas',
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _buildStatCard(
              'Valor',
              Helpers.formatCurrency(_totalApprovedValue),
              Icons.monetization_on,
              AppTheme.primaryColor,
              'Total',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationItem(Map<String, dynamic> quotation) {
    final status = quotation['status'] as String;
    final statusColor = _getStatusColor(status);
    final date = quotation['date'] as DateTime;
    final validUntil = quotation['validUntil'] as DateTime;
    final isExpired =
        validUntil.isBefore(DateTime.now()) &&
        status != 'Aprobada' &&
        status != 'Rechazada';

    return InkWell(
      onTap: () {
        // Ver detalle de cotización
        _showQuotationDetail(quotation);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // Icono de estado
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getStatusIcon(status), color: statusColor),
            ),
            const SizedBox(width: 16),
            // Info principal
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        quotation['number'],
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isExpired ? 'Vencida' : status,
                          style: TextStyle(
                            color: isExpired ? Colors.red : statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quotation['description'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Cliente
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quotation['customer'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Fecha: ${Helpers.formatDate(date)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            // Peso
            SizedBox(
              width: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${Helpers.formatNumber(quotation['weight'])} kg',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Peso total',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Total
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Helpers.formatCurrency(quotation['total']),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    'Válida hasta: ${Helpers.formatDate(validUntil)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isExpired ? Colors.red : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Acciones
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[400]),
              onSelected: (value) => _handleAction(value, quotation),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: ListTile(
                    leading: Icon(Icons.visibility),
                    title: Text('Ver detalle'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (quotation['status'] == 'Borrador' ||
                    quotation['status'] == 'Enviada')
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Editar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: ListTile(
                    leading: Icon(Icons.copy),
                    title: Text('Duplicar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf),
                    title: Text('Generar PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (quotation['status'] == 'Borrador')
                  const PopupMenuItem(
                    value: 'send',
                    child: ListTile(
                      leading: Icon(Icons.send, color: Colors.blue),
                      title: Text(
                        'Enviar al cliente',
                        style: TextStyle(color: Colors.blue),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (quotation['status'] == 'Enviada' ||
                    quotation['status'] == 'Borrador')
                  const PopupMenuItem(
                    value: 'approve',
                    child: ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text(
                        'Aprobar y crear venta',
                        style: TextStyle(color: Colors.green),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (quotation['status'] == 'Enviada' ||
                    quotation['status'] == 'Borrador')
                  const PopupMenuItem(
                    value: 'reject',
                    child: ListTile(
                      leading: Icon(Icons.cancel, color: Colors.orange),
                      title: Text(
                        'Rechazar',
                        style: TextStyle(color: Colors.orange),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                // Opción de anular disponible para cualquier estado excepto ya anulada
                if (quotation['status'] != 'Anulada')
                  const PopupMenuItem(
                    value: 'cancel',
                    child: ListTile(
                      leading: Icon(Icons.block, color: Colors.red),
                      title: Text(
                        'Anular cotización',
                        style: TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuDivider(),
                if (quotation['status'] != 'Aprobada')
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text(
                        'Eliminar',
                        style: TextStyle(color: Colors.red),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No hay cotizaciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No se encontraron resultados para "$_searchQuery"'
                    : 'Crea tu primera cotización',
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/quotations/new'),
                icon: const Icon(Icons.add),
                label: const Text('Nueva Cotización'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Borrador':
        return Colors.grey;
      case 'Enviada':
        return Colors.blue;
      case 'Aprobada':
        return Colors.green;
      case 'Rechazada':
        return Colors.orange;
      case 'Anulada':
        return Colors.red[800]!;
      case 'Vencida':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Borrador':
        return Icons.edit_note;
      case 'Enviada':
        return Icons.send;
      case 'Aprobada':
        return Icons.check_circle;
      case 'Rechazada':
        return Icons.cancel;
      case 'Anulada':
        return Icons.block;
      case 'Vencida':
        return Icons.schedule;
      default:
        return Icons.description;
    }
  }

  void _handleAction(String action, Map<String, dynamic> quotation) {
    switch (action) {
      case 'view':
        _showQuotationDetail(quotation);
        break;
      case 'edit':
        context.go('/quotations/edit/${quotation['id']}');
        break;
      case 'duplicate':
        _duplicateQuotation(quotation);
        break;
      case 'pdf':
        _generatePdf(quotation);
        break;
      case 'send':
        _sendQuotation(quotation);
        break;
      case 'approve':
        _showApproveDialog(quotation);
        break;
      case 'reject':
        _showRejectDialog(quotation);
        break;
      case 'cancel':
        _showCancelDialog(quotation);
        break;
      case 'delete':
        _confirmDelete(quotation);
        break;
    }
  }

  void _sendQuotation(Map<String, dynamic> quotation) async {
    try {
      await ref
          .read(quotationsProvider.notifier)
          .updateStatus(quotation['id'], 'Enviada');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cotización ${quotation['number']} enviada al cliente',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showApproveDialog(Map<String, dynamic> quotation) {
    final seriesController = TextEditingController(text: 'FAC');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            const Text('Aprobar Cotización'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Al aprobar la cotización ${quotation['number']}:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildApprovalInfo(
              Icons.receipt_long,
              'Se creará un recibo de caja automáticamente',
            ),
            _buildApprovalInfo(
              Icons.inventory,
              'Se descontará el stock de los productos',
            ),
            _buildApprovalInfo(
              Icons.lock,
              'La cotización no podrá ser editada',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: seriesController,
              decoration: const InputDecoration(
                labelText: 'Serie de Recibo',
                hintText: 'Ej: REC, RC',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _approveQuotation(quotation, seriesController.text);
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text(
              'Aprobar y Crear Recibo',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  void _approveQuotation(Map<String, dynamic> quotation, String series) async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Procesando aprobación...'),
            SizedBox(height: 8),
            Text(
              'Creando factura y actualizando stock',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await ref
          .read(quotationsProvider.notifier)
          .approveAndCreateInvoice(
            quotation['id'],
            series.isEmpty ? 'FAC' : series,
          );

      if (mounted) Navigator.pop(context); // Cerrar loading

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Factura ${result['invoice_number']} creada exitosamente'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Ver Ventas',
              textColor: Colors.white,
              onPressed: () => context.go('/sales'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Cerrar loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error al aprobar: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showRejectDialog(Map<String, dynamic> quotation) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('Rechazar Cotización'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de rechazar la cotización ${quotation['number']}?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo del rechazo (opcional)',
                hintText: 'Ej: Cliente decidió no proceder, precio muy alto...',
                prefixIcon: Icon(Icons.comment),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _rejectQuotation(quotation, reasonController.text);
            },
            icon: const Icon(Icons.cancel, color: Colors.white),
            label: const Text(
              'Rechazar',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  void _rejectQuotation(Map<String, dynamic> quotation, String reason) async {
    try {
      await ref
          .read(quotationsProvider.notifier)
          .reject(quotation['id'], reason.isEmpty ? null : reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cotización ${quotation['number']} rechazada'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCancelDialog(Map<String, dynamic> quotation) {
    final reasonController = TextEditingController();
    final wasApproved = quotation['status'] == 'Aprobada';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('Anular Cotización'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wasApproved)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[800]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡COTIZACIÓN APROBADA!',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Esta cotización ya fue aprobada y puede tener una factura asociada. '
                            'Revise las facturas relacionadas después de anular.',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción anulará la cotización ${quotation['number']} de forma permanente.',
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Estado actual: ${quotation['status']}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo de anulación *',
                hintText:
                    'Ej: Error en los datos, duplicada, solicitud del cliente...',
                prefixIcon: Icon(Icons.comment),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor ingrese el motivo de anulación'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _cancelQuotation(quotation, reasonController.text.trim());
            },
            icon: const Icon(Icons.block, color: Colors.white),
            label: const Text('Anular', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _cancelQuotation(Map<String, dynamic> quotation, String reason) async {
    final wasApproved = quotation['status'] == 'Aprobada';

    try {
      // Usar 'Anulada' - requiere ejecutar: ALTER TYPE quotation_status ADD VALUE IF NOT EXISTS 'Anulada';
      await ref
          .read(quotationsProvider.notifier)
          .updateStatus(quotation['id'], 'Anulada');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cotización ${quotation['number']} anulada'),
                Text('Motivo: $reason', style: const TextStyle(fontSize: 12)),
                if (wasApproved)
                  const Text(
                    '⚠️ Esta cotización estaba aprobada. Revise las facturas asociadas.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: wasApproved ? 6 : 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showQuotationDetail(Map<String, dynamic> quotation) {
    showDialog(
      context: context,
      builder: (context) => _QuotationDetailDialog(quotation: quotation),
    );
  }

  void _duplicateQuotation(Map<String, dynamic> quotation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cotización ${quotation['number']} duplicada'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _generatePdf(Map<String, dynamic> quotation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generando PDF de ${quotation['number']}...'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> quotation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cotización'),
        content: Text(
          '¿Estás seguro de eliminar la cotización ${quotation['number']}?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Eliminar de la base de datos usando el provider
              final success = await ref
                  .read(quotationsProvider.notifier)
                  .deleteQuotation(quotation['id']);

              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Cotización ${quotation['number']} eliminada',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Error al eliminar la cotización'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// DIÁLOGO DE DETALLE DE COTIZACIÓN
// ============================================
class _QuotationDetailDialog extends StatefulWidget {
  final Map<String, dynamic> quotation;

  const _QuotationDetailDialog({required this.quotation});

  @override
  State<_QuotationDetailDialog> createState() => _QuotationDetailDialogState();
}

class _QuotationDetailDialogState extends State<_QuotationDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Borrador':
        return Colors.grey;
      case 'Enviada':
        return Colors.blue;
      case 'Aprobada':
        return Colors.green;
      case 'Rechazada':
        return Colors.orange;
      case 'Anulada':
        return Colors.red[800]!;
      case 'Vencida':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quotation;
    final screenHeight = MediaQuery.of(context).size.height;
    const headerColor = Color(0xFF1e293b);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 1100,
        height: screenHeight * 0.9,
        child: Column(
          children: [
            // Header compacto con fondo oscuro
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: headerColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q['number'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Cotización ${q['number']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(q['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(q['status'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Helpers.formatCurrency(q['total']), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('${Helpers.formatNumber(q['weight'])} kg', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            // Tabs
            Container(
              color: headerColor,
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  _buildTab('Vista Cliente', Icons.person, 0),
                  const SizedBox(width: 8),
                  _buildTab('Vista Empresa', Icons.business, 1),
                ],
              ),
            ),
            // Contenido de tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildClientView(q), _buildEnterpriseView(q)],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Cliente: ${q['customer']}  •  Fecha: ${Helpers.formatDate(q['date'])}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildFooterButton('Generar PDF', Icons.picture_as_pdf, Colors.blue[600]!, () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Generando PDF de ${q['number']}...'), backgroundColor: AppTheme.primaryColor),
                        );
                      }),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1e293b),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Cerrar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, int index) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.animateTo(index)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  // ==========================================
  // VISTA CLIENTE - Diseño espacioso moderno
  // ==========================================
  Widget _buildClientView(Map<String, dynamic> q) {
    final items = q['items'] as List<dynamic>? ?? [];
    const headerColor = Color(0xFF1e293b);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Barra de acento superior
              Container(
                width: double.infinity,
                height: 8,
                decoration: const BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
              // Contenido con scroll
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Título + Logo
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.verified, color: headerColor, size: 48),
                                    const SizedBox(width: 16),
                                    const Text(
                                      'COTIZACIÓN',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF111418),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  q['number'],
                                  style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          // Logo empresa
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12)],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'lib/photo/logo_empresa.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [headerColor, headerColor.withOpacity(0.8)]),
                                      ),
                                      child: const Icon(Icons.precision_manufacturing, color: Colors.white, size: 36),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text('Industrial de Molinos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const Text('NIT: 901946675-1', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Sección Cliente
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CLIENTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.5)),
                                  const SizedBox(height: 10),
                                  Text(q['customer'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111418))),
                                  const SizedBox(height: 4),
                                  Text('NIT/CC: ${q['customerRuc'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildDateRow('Fecha:', Helpers.formatDate(q['date'])),
                                const SizedBox(height: 8),
                                _buildDateRow('Válida:', Helpers.formatDate(q['validUntil'])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Tabla de productos
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            // Header de tabla
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(flex: 3, child: Text('Descripción', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey))),
                                  SizedBox(width: 80, child: Text('Cant.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]), textAlign: TextAlign.center)),
                                  SizedBox(width: 120, child: Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]), textAlign: TextAlign.right)),
                                ],
                              ),
                            ),
                            // Filas de productos
                            ...items.map((item) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[100]!))),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                        Text('Código: ${item['productCode'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text('${item['quantity']}', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700], fontSize: 15), textAlign: TextAlign.center),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text('\$ ${Helpers.formatNumber((item['totalPrice'] ?? 0) * (item['quantity'] ?? 1))}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.right),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Totales
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 320,
                            child: Column(
                              children: [
                                _buildTotalRow('Subtotal materiales', q['materialsCost'] ?? 0),
                                _buildTotalRow('Mano de Obra', q['laborCost'] ?? 0),
                                _buildTotalRow('Otros Costos', q['indirectCosts'] ?? 0),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(thickness: 1)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TOTAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text('\$ ${Helpers.formatNumber(q['total'] ?? 0)}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: headerColor)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Nota de validez
                      Text(
                        'Esta cotización es válida hasta ${Helpers.formatDate(q['validUntil'])}.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  // ==========================================
  // VISTA EMPRESA - Con desglose de materiales
  // ==========================================
  Widget _buildEnterpriseView(Map<String, dynamic> q) {
    final items = q['items'] as List<dynamic>? ?? [];

    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: 800,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header documento interno con logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'lib/photo/logo_empresa.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.business,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DOCUMENTO INTERNO',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${q['number']} - Desglose de materiales',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'USO INTERNO',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cliente: ${q['customer']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                // Desglose por producto
                ...items.map((item) => _buildProductBreakdown(item, q['profitMargin'] ?? 0)),
                const SizedBox(height: 24),
                const Divider(thickness: 2),
                const SizedBox(height: 16),
                // Resumen de costos y análisis de ganancias
                const Text(
                  'ANÁLISIS FINANCIERO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      // Sección de Costos
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shopping_cart, size: 18, color: Colors.red[700]),
                                const SizedBox(width: 8),
                                Text('COSTOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700], fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildCostDetailRow('Costo Materiales', q['materialCostPrice'] ?? (q['materialsCost'] ?? 0) * 0.6, Icons.inventory_2),
                            _buildCostDetailRow('Mano de Obra', q['laborCost'] ?? 0, Icons.engineering),
                            _buildCostDetailRow('Costos Indirectos', q['indirectCosts'] ?? 0, Icons.receipt_long),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Costo Total', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  Helpers.formatCurrency((q['materialCostPrice'] ?? (q['materialsCost'] ?? 0) * 0.6) + (q['laborCost'] ?? 0) + (q['indirectCosts'] ?? 0)),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Sección de Ventas
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.sell, size: 18, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                Text('VENTAS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700], fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildCostDetailRow('Venta Materiales', q['materialsCost'] ?? 0, Icons.inventory_2),
                            if ((q['discount'] ?? 0) > 0)
                              _buildCostDetailRow('Descuento', -(q['discount'] ?? 0), Icons.discount),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Cotización', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  Helpers.formatCurrency(q['total'] ?? 0),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700], fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Sección de Ganancias
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.trending_up, size: 18, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Text('GANANCIAS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700], fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Builder(builder: (context) {
                              final totalCost = (q['materialCostPrice'] ?? (q['materialsCost'] ?? 0) * 0.6) + (q['laborCost'] ?? 0) + (q['indirectCosts'] ?? 0);
                              final totalSale = q['total'] ?? 0;
                              final netProfit = totalSale - totalCost;
                              final markup = totalCost > 0 ? (netProfit / totalCost * 100) : 0;
                              
                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.payments, size: 16, color: Colors.blue[600]),
                                          const SizedBox(width: 8),
                                          const Text('Ganancia Neta'),
                                        ],
                                      ),
                                      Text(
                                        Helpers.formatCurrency(netProfit),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: netProfit >= 0 ? Colors.blue[700] : Colors.red[700],
                                          fontSize: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.percent, size: 16, color: Colors.purple[600]),
                                          const SizedBox(width: 8),
                                          const Text('Markup Total'),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: markup >= 0 ? Colors.purple[100] : Colors.red[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${markup.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: markup >= 0 ? Colors.purple[700] : Colors.red[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Peso total
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.scale, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Peso Total: ${Helpers.formatNumber(q['weight'])} kg',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductBreakdown(Map<String, dynamic> item, double quotationProfitMargin) {
    final components = item['components'] as List<dynamic>? ?? [];
    final qty = item['quantity'] as int? ?? 1;
    final totalWeight = (item['totalWeight'] as num?)?.toDouble() ?? 0;
    final totalSalePrice = (item['totalPrice'] as num?)?.toDouble() ?? 0;
    
    // Calcular precios por kg basándose en los datos disponibles
    // Si no hay unitCostPrice/unitSalePrice, los calculamos del totalPrice y margen
    double unitSalePrice = (item['unitSalePrice'] as num?)?.toDouble() ?? 
                           (item['pricePerKg'] as num?)?.toDouble() ?? 
                           (totalWeight > 0 ? totalSalePrice / totalWeight : 0);
    
    // Calcular costo usando el margen de la cotización si no está disponible
    // Fórmula: Costo = Venta / (1 + margen/100)
    double unitCostPrice = (item['unitCostPrice'] as num?)?.toDouble() ?? 
                           (item['costPrice'] as num?)?.toDouble() ?? 0;
    
    // Si no tenemos costo pero tenemos margen, calcularlo
    if (unitCostPrice == 0 && quotationProfitMargin > 0 && unitSalePrice > 0) {
      unitCostPrice = unitSalePrice / (1 + quotationProfitMargin / 100);
    }
    
    // Calcular totales y ganancia
    final totalCost = unitCostPrice * totalWeight;
    final totalProfit = (item['totalProfit'] as num?)?.toDouble() ?? (totalSalePrice - totalCost);
    final profitMargin = totalCost > 0 ? ((totalProfit / totalCost) * 100) : quotationProfitMargin;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header del producto - Información principal
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.precision_manufacturing, color: AppTheme.primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'Producto',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Código: ${item['productCode'] ?? 'N/A'} | Cantidad: $qty | Peso: ${Helpers.formatNumber(totalWeight)} kg',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Helpers.formatCurrency(totalSalePrice),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
                        ),
                        Text('Total Venta', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Fila de métricas de precios
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      // Compra/kg
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 16, color: Colors.orange[700]),
                            const SizedBox(height: 4),
                            Text(
                              Helpers.formatCurrency(unitCostPrice),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[700], fontSize: 13),
                            ),
                            Text('Compra/kg', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      // Venta/kg
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.sell_outlined, size: 16, color: Colors.green[700]),
                            const SizedBox(height: 4),
                            Text(
                              Helpers.formatCurrency(unitSalePrice),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700], fontSize: 13),
                            ),
                            Text('Venta/kg', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      // Ganancia Total
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.trending_up, size: 16, color: Colors.blue[700]),
                            const SizedBox(height: 4),
                            Text(
                              '${Helpers.formatCurrency(totalProfit)} (${profitMargin.toStringAsFixed(1)}%)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700], fontSize: 13),
                            ),
                            Text('Ganancia Total', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      // Costo Total
                      Expanded(
                        child: Column(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.red[700]),
                            const SizedBox(height: 4),
                            Text(
                              Helpers.formatCurrency(totalCost),
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700], fontSize: 13),
                            ),
                            Text('Costo Total', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Componentes del producto
          if (components.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const SizedBox(width: 30, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  const Expanded(flex: 2, child: Text('Componente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  const Expanded(flex: 2, child: Text('Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  SizedBox(width: 70, child: Text('Compra/kg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.orange[700]), textAlign: TextAlign.right)),
                  SizedBox(width: 70, child: Text('Venta/kg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green[700]), textAlign: TextAlign.right)),
                  SizedBox(width: 70, child: Text('Ganancia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue[700]), textAlign: TextAlign.right)),
                  const SizedBox(width: 80, child: Text('Total Venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                ],
              ),
            ),
            ...components.take(10).map((comp) {
              final compWeight = (comp['totalWeight'] ?? comp['weight'] ?? 0) as num;
              final compTotalSale = (comp['totalPrice'] ?? comp['price'] ?? 0) as num;
              final compSalePrice = (comp['unitSalePrice'] ?? comp['pricePerKg'] ?? (compWeight > 0 ? compTotalSale / compWeight : 0)) as num;
              
              // Calcular costo del componente usando el margen
              var compCostPrice = (comp['unitCostPrice'] ?? comp['costPrice'] ?? 0) as num;
              if (compCostPrice == 0 && quotationProfitMargin > 0 && compSalePrice > 0) {
                compCostPrice = compSalePrice / (1 + quotationProfitMargin / 100);
              }
              
              final compTotalCost = compCostPrice * compWeight;
              final compTotalProfit = (comp['totalProfit'] ?? (compTotalSale - compTotalCost)) as num;
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text('${comp['quantity']}×', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(comp['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(comp['material'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        Helpers.formatCurrency(compCostPrice.toDouble()),
                        style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        Helpers.formatCurrency(compSalePrice.toDouble()),
                        style: TextStyle(fontSize: 11, color: Colors.green[700]),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        Helpers.formatCurrency(compTotalProfit.toDouble()),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.blue[700]),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        Helpers.formatCurrency(compTotalSale.toDouble()),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (components.length > 10)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.grey[100],
                child: Center(
                  child: Text(
                    '... y ${components.length - 10} componentes más',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 13,
            ),
          ),
          Text(
            '\$ ${Helpers.formatNumber(value)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 13,
              color: isTotal ? AppTheme.primaryColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostDetailRow(
    String label,
    double value,
    IconData icon, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          Text(
            '\$ ${Helpers.formatNumber(value)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
