import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../data/datasources/purchase_orders_datasource.dart';
import '../../data/datasources/supplier_materials_datasource.dart';
import '../../data/providers/quotations_provider.dart';
import '../../data/providers/suppliers_provider.dart';
import '../../data/providers/invoices_provider.dart';
import '../../data/providers/customers_provider.dart';
import '../../data/providers/composite_products_provider.dart';
import '../../core/utils/print_service.dart';

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
            'customerRuc': () {
              final customers = ref.read(customersProvider).customers;
              try {
                return customers
                    .firstWhere((c) => c.id == q.customerId)
                    .documentNumber;
              } catch (_) {
                return '';
              }
            }(),
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
                    'productId': item.productId,
                    'components': () {
                      if (item.productId == null) {
                        return <Map<String, dynamic>>[];
                      }
                      final cpState = ref.read(compositeProductsProvider);
                      try {
                        final product = cpState.products.firstWhere(
                          (p) => p.id == item.productId,
                        );
                        return product.components
                            .map<Map<String, dynamic>>(
                              (c) => {
                                'quantity': c.quantity,
                                'name': c.materialName ?? 'Material',
                                'material': c.materialCode?.isNotEmpty == true
                                    ? c.materialCode!
                                    : c.dimensionsDescription,
                                'totalWeight': c.totalWeight,
                                'totalPrice': c.totalPrice,
                                'totalCost': c.totalCostPrice,
                                'unitSalePrice': c.weightPerUnit > 0
                                    ? c.pricePerUnit / c.weightPerUnit
                                    : 0.0,
                                'unitCostPrice': c.weightPerUnit > 0
                                    ? c.costPricePerUnit / c.weightPerUnit
                                    : 0.0,
                                'totalProfit': c.profit,
                              },
                            )
                            .toList();
                      } catch (_) {
                        return <Map<String, dynamic>>[];
                      }
                    }(),
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
    // Cargar productos compuestos (para mostrar componentes en detalle)
    Future.microtask(
      () => ref.read(compositeProductsProvider.notifier).loadProducts(),
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
                        hintText: 'Buscar por número, cliente o descripción...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),
                  // Lista de cotizaciones
                  Expanded(
                    child: quotationsState.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : quotationsState.error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error: ${quotationsState.error}',
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => ref
                                      .read(quotationsProvider.notifier)
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filteredQuotations.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final quotation = _filteredQuotations[index];
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
      builder: (context) => _ApproveQuotationDialog(
        quotation: quotation,
        seriesController: seriesController,
        onApprove: (series) {
          Navigator.pop(context);
          _approveQuotation(quotation, series);
        },
      ),
    );
  }

  void _approveQuotation(Map<String, dynamic> quotation, String series) async {
    // Capturar el root navigator para cerrar el dialog correctamente
    // (showDialog usa rootNavigator por defecto, pero Navigator.pop(context)
    // busca el navigator más cercano que en StatefulShellRoute es un sub-navigator)
    final rootNav = Navigator.of(context, rootNavigator: true);

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

      if (mounted) rootNav.pop(); // Cerrar loading del root navigator

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
              onPressed: () => context.go('/invoices'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) rootNav.pop(); // Cerrar loading del root navigator
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
    try {
      // Usar RPC segura con blindaje anti-fraude
      final result = await ref
          .read(quotationsProvider.notifier)
          .annulQuotation(quotation['id'], reason: reason);

      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: No se pudo anular la cotización.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Verificar si fue BLOQUEADA por el blindaje
      if (result?['blocked'] == true && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.shield, color: Colors.red[700], size: 28),
                const SizedBox(width: 8),
                const Text('Anulación Bloqueada'),
              ],
            ),
            content: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, color: Colors.red[700], size: 40),
                  const SizedBox(height: 12),
                  Text(
                    result?['reason'] ?? 'No se puede anular esta cotización.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[800], fontSize: 13),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        return;
      }

      if (mounted && result?['success'] == true) {
        final invoiceAnnulled = result?['invoice_annulled'] == true;
        final invoiceResult = result?['invoice_result'];

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cotización ${quotation['number']} anulada ✓'),
                Text('Motivo: $reason', style: const TextStyle(fontSize: 12)),
                if (invoiceAnnulled)
                  Text(
                    '✓ Factura ${invoiceResult?['invoice_number'] ?? ''} también anulada',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: invoiceAnnulled ? 6 : 3),
          ),
        );

        // Refrescar facturas si se anuló alguna
        if (invoiceAnnulled) {
          ref.read(invoicesProvider.notifier).refresh();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al anular: $e'),
            backgroundColor: Colors.red,
          ),
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
    PrintService.printQuotation(quotation);
  }

  void _confirmDelete(Map<String, dynamic> quotation) {
    // Solo permitir eliminar borradores
    if (quotation['status'] != 'Borrador') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solo se pueden eliminar cotizaciones en estado Borrador. '
            'Estado actual: ${quotation['status']}. Use "Anular" en su lugar.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

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
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);

              // Eliminar de la base de datos usando el provider
              final success = await ref
                  .read(quotationsProvider.notifier)
                  .deleteQuotation(quotation['id']);

              if (mounted) {
                if (success) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Cotización ${quotation['number']} eliminada',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
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

  // Stock check state
  List<Map<String, dynamic>>? _stockData;
  bool _loadingStock = true;
  bool _creatingOrders = false;
  List<String>? _createdOrderNumbers;
  String? _orderError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStock();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStock() async {
    final id = widget.quotation['id']?.toString() ?? '';
    if (id.isEmpty) {
      if (mounted) setState(() => _loadingStock = false);
      return;
    }
    try {
      final data = await InventoryDataSource.checkQuotationStock(id);
      if (mounted) {
        setState(() {
          _stockData = data;
          _loadingStock = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStock = false);
    }
  }

  bool get _allStockOk =>
      _stockData == null || _stockData!.every((m) => m['has_stock'] == true);

  List<Map<String, dynamic>> get _missingMaterials =>
      _stockData?.where((m) => m['has_stock'] != true).toList() ?? [];

  Future<void> _createPurchaseOrders() async {
    final missing = _missingMaterials;
    if (missing.isEmpty) return;
    setState(() {
      _creatingOrders = true;
      _orderError = null;
    });
    try {
      final quotNum = widget.quotation['number']?.toString() ?? '';
      final orders = await PurchaseOrdersDataSource.createFromShortage(
        missingMaterials: missing,
        quotationNumber: quotNum,
      );
      if (mounted) {
        setState(() {
          _creatingOrders = false;
          _createdOrderNumbers = orders.map((o) => o.orderNumber).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _creatingOrders = false;
          _orderError = e.toString();
        });
      }
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
        return Icons.warning;
      default:
        return Icons.description;
    }
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
            // ── HEADER COMPACTO con tabs inline (igual que facturas) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: headerColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(q['status']),
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    q['number'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(q['status']),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      q['status'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildHeaderTab('Resumen', Icons.bar_chart, 0),
                  _buildHeaderTab('Vista Cliente', Icons.person, 1),
                  _buildHeaderTab('Empresa', Icons.business, 2),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Helpers.formatCurrency(
                          (q['total'] as num?)?.toDouble() ?? 0,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${Helpers.formatNumber((q['weight'] as num?)?.toDouble() ?? 0)} kg',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            // ── CONTENIDO TABS ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildResumenTab(q),
                  _buildClientView(q),
                  _buildEnterpriseView(q),
                ],
              ),
            ),
            // ── FOOTER ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    'Cliente: ${q['customer']}  •  Fecha: ${Helpers.formatDate(q['date'])}  •  Válida: ${Helpers.formatDate(q['validUntil'])}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Generando PDF de ${q['number']}...'),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.picture_as_pdf,
                      size: 16,
                      color: Colors.blue[600],
                    ),
                    label: Text(
                      'Generar PDF',
                      style: TextStyle(color: Colors.blue[600], fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blue[300]!),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: headerColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Cerrar', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTab(String label, IconData icon, int index) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.animateTo(index)),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.white38 : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white54,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // TAB 1: RESUMEN (nuevo - igual que Detalle en FAC)
  // ══════════════════════════════════════════════
  Widget _buildResumenTab(Map<String, dynamic> q) {
    final items = q['items'] as List<dynamic>? ?? [];
    final total = (q['total'] as num?)?.toDouble() ?? 0;
    final materialsCost = (q['materialsCost'] as num?)?.toDouble() ?? 0;
    final laborCost = (q['laborCost'] as num?)?.toDouble() ?? 0;
    final indirectCosts = (q['indirectCosts'] as num?)?.toDouble() ?? 0;
    final subtotal = materialsCost + laborCost + indirectCosts;
    final profitMargin = (q['profitMargin'] as num?)?.toDouble() ?? 20;
    final profitAmount = total - subtotal;
    final weight = (q['weight'] as num?)?.toDouble() ?? 0;

    return Container(
      color: const Color(0xFFF1F4F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 4 tarjetas resumen
            Row(
              children: [
                _buildSummaryCard(
                  'Subtotal',
                  subtotal,
                  Icons.receipt_outlined,
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  'Ganancia',
                  profitAmount,
                  Icons.trending_up,
                  Colors.green,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  'Margen',
                  profitMargin,
                  Icons.percent,
                  Colors.purple,
                  isPercent: true,
                ),
                const SizedBox(width: 12),
                _buildSummaryCard(
                  'TOTAL',
                  total,
                  Icons.payments,
                  Colors.teal,
                  isHighlight: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izq: cliente + items
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Tarjeta cliente
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF1e293b),
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q['customer'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'NIT/CC: ${q['customerRuc']?.toString().isNotEmpty == true ? q['customerRuc'] : 'N/A'}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Fecha: ${Helpers.formatDate(q['date'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'Válida: ${Helpers.formatDate(q['validUntil'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Items
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.table_chart, size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Detalle',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${items.length} items',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            if (items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: Text(
                                    'Sin items',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ...items.map((i) {
                                final tPrice =
                                    (i['totalPrice'] as num?)?.toDouble() ?? 0;
                                final tCost =
                                    (i['totalCost'] as num?)?.toDouble() ?? 0;
                                final tProfit = tPrice - tCost;
                                final tWeight =
                                    (i['totalWeight'] as num?)?.toDouble() ?? 0;
                                final comps =
                                    i['components'] as List<dynamic>? ?? [];
                                return Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.grey[100]!,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              comps.isNotEmpty
                                                  ? Icons.settings
                                                  : Icons.inventory_2,
                                              size: 16,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  i['name'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  'Costo: ${Helpers.formatCurrency(tCost)}  •  ${Helpers.formatNumber(tWeight)} kg'
                                                  '${comps.isNotEmpty ? '  •  ${comps.length} mat.' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                Helpers.formatCurrency(tPrice),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                '+${Helpers.formatCurrency(tProfit)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.green[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Sub-materiales del producto
                                    if (comps.isNotEmpty)
                                      ...comps.map((c) {
                                        final cw =
                                            (c['totalWeight'] as num?)
                                                ?.toDouble() ??
                                            0;
                                        final cp =
                                            (c['totalPrice'] as num?)
                                                ?.toDouble() ??
                                            0;
                                        return Container(
                                          padding: const EdgeInsets.only(
                                            left: 60,
                                            right: 16,
                                            top: 6,
                                            bottom: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey[100]!,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.subdirectory_arrow_right,
                                                size: 14,
                                                color: Colors.grey[400],
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${c['quantity']}× ${c['name'] ?? ''}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if ((c['material']
                                                      ?.toString()
                                                      .isNotEmpty ??
                                                  false))
                                                Text(
                                                  '(${c['material']})',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[500],
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              const Spacer(),
                                              Text(
                                                '${Helpers.formatNumber(cw)} kg  •  ${Helpers.formatCurrency(cp)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Columna der: análisis financiero
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.analytics, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Análisis Financiero',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildFinRow(
                          'Materiales',
                          materialsCost,
                          color: Colors.orange[700],
                        ),
                        _buildFinRow(
                          'Mano de Obra',
                          laborCost,
                          color: Colors.orange[700],
                        ),
                        _buildFinRow(
                          'Costos Indirectos',
                          indirectCosts,
                          color: Colors.orange[700],
                        ),
                        const Divider(),
                        _buildFinRow(
                          'Costo Total',
                          subtotal,
                          isTotal: true,
                          color: Colors.red[700],
                        ),
                        const SizedBox(height: 8),
                        _buildFinRow(
                          'Ganancia (${profitMargin.toStringAsFixed(0)}%)',
                          profitAmount,
                          color: Colors.green[700],
                        ),
                        const Divider(),
                        _buildFinRow(
                          'TOTAL',
                          total,
                          isTotal: true,
                          color: const Color(0xFF1e293b),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.scale,
                                color: Colors.blue[700],
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Peso Total: ${Helpers.formatNumber(weight)} kg',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Panel de stock
                        _buildStockPanel(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // PANEL DE STOCK EN RESUMEN TAB
  // ═══════════════════════════════════════════
  Widget _buildStockPanel() {
    if (_loadingStock) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Verificando stock...', style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (_createdOrderNumbers != null && _createdOrderNumbers!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 18),
                const SizedBox(width: 8),
                Text(
                  'Órdenes de Compra creadas:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ..._createdOrderNumbers!.map(
              (n) => Padding(
                padding: const EdgeInsets.only(left: 26, top: 2),
                child: Text(
                  '• $n',
                  style: TextStyle(fontSize: 12, color: Colors.green[700]),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_orderError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Text(
          'Error: $_orderError',
          style: TextStyle(fontSize: 12, color: Colors.red[700]),
        ),
      );
    }

    if (_stockData == null || _stockData!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 16),
            SizedBox(width: 8),
            Text('Sin materiales a verificar', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    final missing = _missingMaterials;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _allStockOk ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _allStockOk ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _allStockOk ? Icons.inventory_2 : Icons.warning_amber,
                color: _allStockOk ? Colors.green[700] : Colors.orange[700],
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _allStockOk
                    ? 'Stock suficiente'
                    : '${missing.length} material(es) sin stock',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _allStockOk ? Colors.green[800] : Colors.orange[800],
                  fontSize: 13,
                ),
              ),
              if (!_allStockOk) ...[
                const Spacer(),
                _creatingOrders
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: _createPurchaseOrders,
                        icon: const Icon(Icons.add_shopping_cart, size: 14),
                        label: const Text(
                          'Crear OC',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange[700],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
              ],
            ],
          ),
          if (!_allStockOk) ...[
            const SizedBox(height: 10),
            ...missing.take(6).map((m) {
              final need = (m['required_quantity'] as num?)?.toDouble() ?? 0;
              final have = (m['available_quantity'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.remove_circle_outline,
                      size: 14,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        m['material_name']?.toString() ?? 'Material',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      'Necesita: ${need.toStringAsFixed(1)} | Hay: ${have.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 11, color: Colors.red[700]),
                    ),
                  ],
                ),
              );
            }),
            if (missing.length > 6)
              Text(
                '... +${missing.length - 6} más',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    double value,
    IconData icon,
    MaterialColor color, {
    bool isHighlight = false,
    bool isPercent = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHighlight ? color.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isHighlight ? Colors.white70 : color.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isHighlight ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isPercent
                  ? '${value.toStringAsFixed(1)}%'
                  : Helpers.formatCurrency(value),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isHighlight ? Colors.white : color.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinRow(
    String label,
    double value, {
    bool isTotal = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 14 : 13,
              color: Colors.grey[700],
            ),
          ),
          Text(
            Helpers.formatCurrency(value),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 14 : 13,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
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
                                    Icon(
                                      Icons.verified,
                                      color: headerColor,
                                      size: 48,
                                    ),
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
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    'lib/photo/logo_empresa.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            headerColor,
                                            headerColor.withOpacity(0.8),
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.precision_manufacturing,
                                        color: Colors.white,
                                        size: 36,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Industrial de Molinos',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const Text(
                                'NIT: 901946675-1',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
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
                                  Text(
                                    'CLIENTE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[400],
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    q['customer'],
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111418),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'NIT/CC: ${q['customerRuc'] ?? 'N/A'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildDateRow(
                                  'Fecha:',
                                  Helpers.formatDate(q['date']),
                                ),
                                const SizedBox(height: 8),
                                _buildDateRow(
                                  'Válida:',
                                  Helpers.formatDate(q['validUntil']),
                                ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Descripción',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      'Cant.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Filas de productos
                            ...items.map(
                              (item) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 18,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Colors.grey[100]!),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            'Código: ${item['productCode'] ?? 'N/A'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        '${item['quantity']}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[700],
                                          fontSize: 15,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        '\$ ${Helpers.formatNumber((item['totalPrice'] ?? 0) * (item['quantity'] ?? 1))}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                                _buildTotalRow(
                                  'Subtotal materiales',
                                  q['materialsCost'] ?? 0,
                                ),
                                _buildTotalRow(
                                  'Mano de Obra',
                                  q['laborCost'] ?? 0,
                                ),
                                _buildTotalRow(
                                  'Otros Costos',
                                  q['indirectCosts'] ?? 0,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(thickness: 1),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'TOTAL',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '\$ ${Helpers.formatNumber(q['total'] ?? 0)}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: headerColor,
                                      ),
                                    ),
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
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
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
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
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
                ...items.map(
                  (item) =>
                      _buildProductBreakdown(item, q['profitMargin'] ?? 0),
                ),
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
                                Icon(
                                  Icons.shopping_cart,
                                  size: 18,
                                  color: Colors.red[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'COSTOS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildCostDetailRow(
                              'Costo Materiales',
                              q['materialCostPrice'] ??
                                  (q['materialsCost'] ?? 0) * 0.6,
                              Icons.inventory_2,
                            ),
                            _buildCostDetailRow(
                              'Mano de Obra',
                              q['laborCost'] ?? 0,
                              Icons.engineering,
                            ),
                            _buildCostDetailRow(
                              'Costos Indirectos',
                              q['indirectCosts'] ?? 0,
                              Icons.receipt_long,
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Costo Total',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  Helpers.formatCurrency(
                                    (q['materialCostPrice'] ??
                                            (q['materialsCost'] ?? 0) * 0.6) +
                                        (q['laborCost'] ?? 0) +
                                        (q['indirectCosts'] ?? 0),
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700],
                                  ),
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
                                Icon(
                                  Icons.sell,
                                  size: 18,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'VENTAS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildCostDetailRow(
                              'Venta Materiales',
                              q['materialsCost'] ?? 0,
                              Icons.inventory_2,
                            ),
                            if ((q['discount'] ?? 0) > 0)
                              _buildCostDetailRow(
                                'Descuento',
                                -(q['discount'] ?? 0),
                                Icons.discount,
                              ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Cotización',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  Helpers.formatCurrency(q['total'] ?? 0),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                    fontSize: 16,
                                  ),
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
                                Icon(
                                  Icons.trending_up,
                                  size: 18,
                                  color: Colors.blue[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'GANANCIAS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final totalCost =
                                    (q['materialCostPrice'] ??
                                        (q['materialsCost'] ?? 0) * 0.6) +
                                    (q['laborCost'] ?? 0) +
                                    (q['indirectCosts'] ?? 0);
                                final totalSale = q['total'] ?? 0;
                                final netProfit = totalSale - totalCost;
                                final markup = totalCost > 0
                                    ? (netProfit / totalCost * 100)
                                    : 0;

                                return Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.payments,
                                              size: 16,
                                              color: Colors.blue[600],
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('Ganancia Neta'),
                                          ],
                                        ),
                                        Text(
                                          Helpers.formatCurrency(netProfit),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: netProfit >= 0
                                                ? Colors.blue[700]
                                                : Colors.red[700],
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.percent,
                                              size: 16,
                                              color: Colors.purple[600],
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('Markup Total'),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: markup >= 0
                                                ? Colors.purple[100]
                                                : Colors.red[100],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '${markup.toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: markup >= 0
                                                  ? Colors.purple[700]
                                                  : Colors.red[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
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

  Widget _buildProductBreakdown(
    Map<String, dynamic> item,
    double quotationProfitMargin,
  ) {
    final components = item['components'] as List<dynamic>? ?? [];
    final qty = item['quantity'] as int? ?? 1;
    final totalWeight = (item['totalWeight'] as num?)?.toDouble() ?? 0;
    final totalSalePrice = (item['totalPrice'] as num?)?.toDouble() ?? 0;

    // Usar totalCost almacenado (siempre correcto para recetas y materiales)
    final totalCost = (item['totalCost'] as num?)?.toDouble() ?? 0;

    // Calcular precios por kg desde los totales (funciona para recetas y materiales)
    // Para recetas: totalPrice = unitPrice*qty, totalWeight = weight*qty
    //   → totalPrice/totalWeight = precio de venta por kg real
    // Para materiales: totalPrice = weight*pricePerKg
    //   → totalPrice/totalWeight = pricePerKg
    double unitSalePrice = totalWeight > 0
        ? totalSalePrice / totalWeight
        : (item['unitSalePrice'] as num?)?.toDouble() ??
              (item['pricePerKg'] as num?)?.toDouble() ??
              0;

    double unitCostPrice = totalWeight > 0 && totalCost > 0
        ? totalCost / totalWeight
        : 0;

    // Si no tenemos costo pero tenemos margen, calcularlo desde venta
    if (unitCostPrice == 0 && quotationProfitMargin > 0 && unitSalePrice > 0) {
      unitCostPrice = unitSalePrice / (1 + quotationProfitMargin / 100);
    }

    // Ganancia: usar valor almacenado o calcular desde totales
    final totalProfit =
        (item['totalProfit'] as num?)?.toDouble() ??
        (totalSalePrice - totalCost);
    final profitMargin = totalCost > 0
        ? ((totalProfit / totalCost) * 100)
        : quotationProfitMargin;

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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
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
                      child: Icon(
                        Icons.precision_manufacturing,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? 'Producto',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Código: ${item['productCode'] ?? 'N/A'} | Cantidad: $qty | Peso: ${Helpers.formatNumber(totalWeight)} kg',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Helpers.formatCurrency(totalSalePrice),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        Text(
                          'Total Venta',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
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
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 16,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Helpers.formatCurrency(unitCostPrice),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Compra/kg',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      // Venta/kg
                      Expanded(
                        child: Column(
                          children: [
                            Icon(
                              Icons.sell_outlined,
                              size: 16,
                              color: Colors.green[700],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Helpers.formatCurrency(unitSalePrice),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Venta/kg',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      // Ganancia Total
                      Expanded(
                        child: Column(
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 16,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${Helpers.formatCurrency(totalProfit)} (${profitMargin.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Ganancia Total',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      // Costo Total
                      Expanded(
                        child: Column(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 16,
                              color: Colors.red[700],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Helpers.formatCurrency(totalCost),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Costo Total',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
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
          // Componentes del producto
          if (components.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const SizedBox(
                    width: 30,
                    child: Text(
                      'Qty',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Componente',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Expanded(
                    flex: 2,
                    child: Text(
                      'Material',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      'Compra/kg',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.orange[700],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      'Venta/kg',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.green[700],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      'Ganancia',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.blue[700],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(
                    width: 80,
                    child: Text(
                      'Total Venta',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            ...components.take(10).map((comp) {
              final compWeight =
                  (comp['totalWeight'] ?? comp['weight'] ?? 0) as num;
              final compTotalSale =
                  (comp['totalPrice'] ?? comp['price'] ?? 0) as num;
              final compSalePrice =
                  (comp['unitSalePrice'] ??
                          comp['pricePerKg'] ??
                          (compWeight > 0 ? compTotalSale / compWeight : 0))
                      as num;

              // Calcular costo del componente usando el margen
              var compCostPrice =
                  (comp['unitCostPrice'] ?? comp['costPrice'] ?? 0) as num;
              if (compCostPrice == 0 &&
                  quotationProfitMargin > 0 &&
                  compSalePrice > 0) {
                compCostPrice =
                    compSalePrice / (1 + quotationProfitMargin / 100);
              }

              final compTotalCost = compCostPrice * compWeight;
              final compTotalProfit =
                  (comp['totalProfit'] ?? (compTotalSale - compTotalCost))
                      as num;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${comp['quantity']}×',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        comp['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        comp['material'] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        Helpers.formatCurrency(compCostPrice.toDouble()),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange[700],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        Helpers.formatCurrency(compSalePrice.toDouble()),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        Helpers.formatCurrency(compTotalProfit.toDouble()),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        Helpers.formatCurrency(compTotalSale.toDouble()),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
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

// ──────────────────────────────────────────────────────────────────
// Diálogo de aprobación con verificación de stock consolidado
// ──────────────────────────────────────────────────────────────────
class _ApproveQuotationDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> quotation;
  final TextEditingController seriesController;
  final void Function(String series) onApprove;

  const _ApproveQuotationDialog({
    required this.quotation,
    required this.seriesController,
    required this.onApprove,
  });

  @override
  ConsumerState<_ApproveQuotationDialog> createState() =>
      _ApproveQuotationDialogState();
}

class _ApproveQuotationDialogState
    extends ConsumerState<_ApproveQuotationDialog> {
  List<Map<String, dynamic>>? _stockData;
  bool _loading = true;
  String? _error;

  // Para creación de órdenes de compra
  bool _creatingOrders = false;
  List<String>? _createdOrderNumbers;
  // Cada elemento: {'material_id': ..., 'material_name': ...}
  List<Map<String, dynamic>>? _materialsWithoutSupplier;
  String? _orderError;

  @override
  void initState() {
    super.initState();
    _loadStockCheck();
  }

  Future<void> _loadStockCheck() async {
    try {
      final data = await InventoryDataSource.checkQuotationStock(
        widget.quotation['id'],
      );
      if (mounted) {
        setState(() {
          _stockData = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool get _allStockAvailable {
    if (_stockData == null) return true;
    return _stockData!.every((m) => m['has_stock'] == true);
  }

  int get _insufficientCount {
    if (_stockData == null) return 0;
    return _stockData!.where((m) => m['has_stock'] != true).length;
  }

  String _fmtQty(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// Obtener lista de materiales faltantes (has_stock == false)
  List<Map<String, dynamic>> get _missingMaterials {
    if (_stockData == null) return [];
    return _stockData!.where((m) => m['has_stock'] != true).toList();
  }

  /// Crear órdenes de compra para materiales faltantes
  Future<void> _createPurchaseOrders() async {
    final missing = _missingMaterials;
    if (missing.isEmpty) return;

    setState(() {
      _creatingOrders = true;
      _orderError = null;
    });

    try {
      final quotNum = widget.quotation['quotation_number'] ?? '';
      final orders = await PurchaseOrdersDataSource.createFromShortage(
        missingMaterials: missing,
        quotationNumber: quotNum,
      );

      // Detectar materiales sin proveedor
      // Materiales que no tienen entrada en supplier_materials
      final materialsWithOrders = <String>{};
      for (final order in orders) {
        for (final item in order.items) {
          materialsWithOrders.add(item.materialId);
        }
      }
      final withoutSupplier = missing
          .where(
            (m) =>
                m['material_id'] != null &&
                !materialsWithOrders.contains(m['material_id']),
          )
          .map<Map<String, dynamic>>(
            (m) => {
              'material_id': m['material_id'],
              'material_name': m['material_name']?.toString() ?? 'Material',
            },
          )
          .toList();

      if (mounted) {
        setState(() {
          _creatingOrders = false;
          _createdOrderNumbers = orders.map((o) => o.orderNumber).toList();
          _materialsWithoutSupplier = withoutSupplier.isNotEmpty
              ? withoutSupplier
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _creatingOrders = false;
          _orderError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName =
        widget.quotation['client_name'] ??
        widget.quotation['clients']?['name'] ??
        'Cliente';
    final quotNum = widget.quotation['quotation_number'] ?? '';

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.approval, color: Colors.blue[700]),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Aprobar Cotización', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info de la cotización
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$quotNum — $clientName',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: \$ ${Helpers.formatNumber(widget.quotation['total'] ?? 0)}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stock check section
              Row(
                children: [
                  Icon(Icons.inventory_2, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 6),
                  Text(
                    'Verificación de Stock',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text(
                          'Verificando stock de materiales...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No se pudo verificar stock: $_error\nPuede aprobar de todas formas.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_stockData != null && _stockData!.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'No se encontraron materiales con receta.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                )
              else if (_stockData != null) ...[
                // Summary badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _allStockAvailable
                        ? Colors.green[50]
                        : Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _allStockAvailable
                          ? Colors.green[300]!
                          : Colors.red[300]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _allStockAvailable
                            ? Icons.check_circle
                            : Icons.warning_amber,
                        size: 16,
                        color: _allStockAvailable
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _allStockAvailable
                              ? 'Todos los materiales disponibles (${_stockData!.length})'
                              : '$_insufficientCount de ${_stockData!.length} materiales con stock insuficiente',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _allStockAvailable
                                ? Colors.green[800]
                                : Colors.red[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Material list
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: _stockData!.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (context, index) {
                      final m = _stockData![index];
                      final hasStock = m['has_stock'] == true;
                      final requiredQty =
                          (m['required_qty'] as num?)?.toDouble() ?? 0;
                      final available =
                          (m['available_stock'] as num?)?.toDouble() ?? 0;
                      final shortage = (m['shortage'] as num?)?.toDouble() ?? 0;
                      final unit = m['unit'] ?? 'KG';
                      final sources = m['source_items'] ?? '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              hasStock ? Icons.check_circle : Icons.cancel,
                              size: 16,
                              color: hasStock ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m['material_name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (sources.toString().isNotEmpty)
                                    Text(
                                      'Usado en: $sources',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Required / Available
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${_fmtQty(requiredQty)} $unit',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: hasStock
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                      ),
                                    ),
                                    Text(
                                      ' / ${_fmtQty(available)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                                if (!hasStock)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Faltan ${_fmtQty(shortage)}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),
              // Info bullets
              _buildInfoRow(
                Icons.receipt_long,
                'Se creará una factura automáticamente',
              ),
              _buildInfoRow(
                Icons.inventory,
                'El stock se descontará del inventario',
              ),
              _buildInfoRow(
                Icons.lock,
                'La cotización pasará a estado "Aprobada"',
              ),

              const SizedBox(height: 16),
              // Series input
              TextField(
                controller: widget.seriesController,
                decoration: InputDecoration(
                  labelText: 'Serie de Factura',
                  hintText: 'FAC',
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),

              // Warning + botón Pedir Materiales si stock insuficiente
              if (!_loading && !_allStockAvailable) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: Colors.amber[800],
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Hay materiales con stock insuficiente. '
                              'Puede aprobar de todas formas, pero el inventario '
                              'quedará con valores negativos.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Resultado de creación de órdenes
                      if (_createdOrderNumbers != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Colors.green[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _createdOrderNumbers!.length == 1
                                          ? 'Orden de compra creada: ${_createdOrderNumbers!.first}'
                                          : '${_createdOrderNumbers!.length} órdenes creadas: ${_createdOrderNumbers!.join(", ")}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_materialsWithoutSupplier != null &&
                                  _materialsWithoutSupplier!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.orange[300]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.person_off,
                                            size: 14,
                                            color: Colors.orange[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Sin proveedor asignado:',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange[800],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ..._materialsWithoutSupplier!.map(
                                        (m) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  m['material_name'] ??
                                                      'Material',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.orange[900],
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              SizedBox(
                                                height: 26,
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _assignSupplier(m),
                                                  icon: const Icon(
                                                    Icons.add_business,
                                                    size: 12,
                                                  ),
                                                  label: const Text(
                                                    'Asignar proveedor',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.orange[800],
                                                    side: BorderSide(
                                                      color:
                                                          Colors.orange[400]!,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else if (_orderError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error,
                                size: 16,
                                color: Colors.red[700],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Error creando órdenes: $_orderError',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Botón para crear órdenes de compra
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _creatingOrders
                                ? null
                                : _createPurchaseOrders,
                            icon: _creatingOrders
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.shopping_cart, size: 16),
                            label: Text(
                              _creatingOrders
                                  ? 'Creando órdenes...'
                                  : 'Pedir $_insufficientCount Material${_insufficientCount > 1 ? "es" : ""} Faltante${_insufficientCount > 1 ? "s" : ""}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Se creará una orden de compra por cada proveedor con los materiales faltantes',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _loading
              ? null
              : () => widget.onApprove(widget.seriesController.text),
          icon: const Icon(Icons.check),
          label: const Text('Aprobar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo para asignar un proveedor a un material sin proveedor.
  /// Tras asignar, elimina ese material de la lista _materialsWithoutSupplier.
  Future<void> _assignSupplier(Map<String, dynamic> material) async {
    final materialId = material['material_id'] as String?;
    final materialName = material['material_name'] as String? ?? 'Material';
    if (materialId == null) return;

    // Cargar proveedores si aún no se han cargado
    final suppliersNotifier = ref.read(suppliersProvider.notifier);
    if (ref.read(suppliersProvider).suppliers.isEmpty) {
      await suppliersNotifier.loadSuppliers();
    }
    final suppliers = ref.read(suppliersProvider).suppliers;

    if (!mounted) return;
    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay proveedores disponibles')),
      );
      return;
    }

    String? selectedSupplierId;
    final priceController = TextEditingController(text: '0');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: Text(
            'Asignar proveedor a $materialName',
            style: const TextStyle(fontSize: 15),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Proveedor',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: suppliers
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocalState(() {
                    selectedSupplierId = v;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Precio unitario (S/)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: selectedSupplierId == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedSupplierId == null || !mounted) return;

    try {
      final price = double.tryParse(priceController.text) ?? 0;
      await SupplierMaterialsDataSource.upsert(
        supplierId: selectedSupplierId!,
        materialId: materialId,
        unitPrice: price,
        isPreferred: true,
      );
      // Remover de la lista de materiales sin proveedor
      setState(() {
        _materialsWithoutSupplier = _materialsWithoutSupplier
            ?.where((m) => m['material_id'] != materialId)
            .toList();
        if (_materialsWithoutSupplier?.isEmpty ?? false) {
          _materialsWithoutSupplier = null;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proveedor asignado a $materialName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al asignar proveedor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
