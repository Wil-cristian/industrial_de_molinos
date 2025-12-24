import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/quotations_provider.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/quick_actions_button.dart';

class QuotationsPage extends ConsumerStatefulWidget {
  const QuotationsPage({super.key});

  @override
  ConsumerState<QuotationsPage> createState() => _QuotationsPageState();
}

class _QuotationsPageState extends ConsumerState<QuotationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _filterStatus = 'Todas';

  // Los datos vienen del provider, ya no hardcodeados
  List<Map<String, dynamic>> get _quotations {
    final state = ref.watch(quotationsProvider);
    return state.quotations.map((q) => {
      'id': q.id,
      'number': q.number,
      'date': q.date,
      'validUntil': q.validUntil,
      'customer': q.customerName,
      'customerRuc': q.customerId, // Usamos customerId como RUC
      'description': q.notes.isNotEmpty ? q.notes.split('\n').first : 'Cotización ${q.number}',
      'status': q.status,
      'materialsCost': q.materialsCost,
      'laborCost': q.laborCost,
      'indirectCosts': q.indirectCosts,
      'profitMargin': q.profitMargin,
      'total': q.total,
      'weight': q.totalWeight,
      'notes': q.notes,
      'items': q.items.map((item) => {
        'name': item.name,
        'type': item.type,
        'productCode': item.materialType,
        'quantity': item.quantity,
        'totalWeight': item.totalWeight,
        'totalPrice': item.totalPrice,
      }).toList(),
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredQuotations {
    return _quotations.where((q) {
      final matchesSearch = _searchQuery.isEmpty ||
          q['number'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          q['customer'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          q['description'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesFilter = _filterStatus == 'Todas' || q['status'] == _filterStatus;
      
      return matchesSearch && matchesFilter;
    }).toList();
  }

  // Estadísticas
  int get _totalQuotations => _quotations.length;
  int get _pendingQuotations => _quotations.where((q) => q['status'] == 'Enviada' || q['status'] == 'Borrador').length;
  int get _approvedQuotations => _quotations.where((q) => q['status'] == 'Aprobada').length;
  double get _totalApprovedValue => _quotations
      .where((q) => q['status'] == 'Aprobada')
      .fold(0.0, (sum, q) => sum + (q['total'] as double? ?? 0.0));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0: _filterStatus = 'Todas'; break;
          case 1: _filterStatus = 'Borrador'; break;
          case 2: _filterStatus = 'Enviada'; break;
          case 3: _filterStatus = 'Aprobada'; break;
          case 4: _filterStatus = 'Rechazada'; break;
        }
      });
    });
    // Cargar cotizaciones desde Supabase
    Future.microtask(() => ref.read(quotationsProvider.notifier).loadQuotations());
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
      body: Stack(
        children: [
          Row(
            children: [
              const AppSidebar(currentRoute: '/quotations'),
              Expanded(
                child: Column(
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
                      tabs: [
                        Tab(text: 'Todas ($_totalQuotations)'),
                        Tab(text: 'Borrador (${_quotations.where((q) => q['status'] == 'Borrador').length})'),
                        Tab(text: 'Enviadas (${_quotations.where((q) => q['status'] == 'Enviada').length})'),
                        Tab(text: 'Aprobadas ($_approvedQuotations)'),
                        Tab(text: 'Rechazadas (${_quotations.where((q) => q['status'] == 'Rechazada').length})'),
                      ],
                    ),
                  ),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
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
                                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                                    const SizedBox(height: 16),
                                    Text('Error: ${quotationsState.error}', style: TextStyle(color: Colors.red[700])),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () => ref.read(quotationsProvider.notifier).loadQuotations(),
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
                                    separatorBuilder: (_, __) => const Divider(height: 1),
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
              ),
            ],
          ),
          const QuickActionsButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/quotations/new'),
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva Cotización', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
            onPressed: () => context.go('/'),
            tooltip: 'Volver al menú',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cotizaciones',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gestiona tus cotizaciones de molinos y componentes',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Botones de acción
          OutlinedButton.icon(
            onPressed: () {
              // Exportar cotizaciones
            },
            icon: const Icon(Icons.download),
            label: const Text('Exportar'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => context.go('/quotations/new'),
            icon: const Icon(Icons.add),
            label: const Text('Nueva Cotización'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard(
            'Total Cotizaciones',
            _totalQuotations.toString(),
            Icons.description,
            Colors.blue,
            'Este mes',
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(
            'Pendientes',
            _pendingQuotations.toString(),
            Icons.hourglass_empty,
            Colors.orange,
            'Por responder',
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(
            'Aprobadas',
            _approvedQuotations.toString(),
            Icons.check_circle,
            Colors.green,
            'Listas para producción',
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard(
            'Valor Aprobado',
            Helpers.formatCurrency(_totalApprovedValue),
            Icons.monetization_on,
            AppTheme.primaryColor,
            'Total vendido',
          )),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
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
    final isExpired = validUntil.isBefore(DateTime.now()) && status != 'Aprobada' && status != 'Rechazada';

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
              child: Icon(
                _getStatusIcon(status),
                color: statusColor,
              ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                const PopupMenuItem(value: 'view', child: ListTile(
                  leading: Icon(Icons.visibility),
                  title: Text('Ver detalle'),
                  contentPadding: EdgeInsets.zero,
                )),
                if (quotation['status'] == 'Borrador' || quotation['status'] == 'Enviada')
                  const PopupMenuItem(value: 'edit', child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Editar'),
                    contentPadding: EdgeInsets.zero,
                  )),
                const PopupMenuItem(value: 'duplicate', child: ListTile(
                  leading: Icon(Icons.copy),
                  title: Text('Duplicar'),
                  contentPadding: EdgeInsets.zero,
                )),
                const PopupMenuItem(value: 'pdf', child: ListTile(
                  leading: Icon(Icons.picture_as_pdf),
                  title: Text('Generar PDF'),
                  contentPadding: EdgeInsets.zero,
                )),
                if (quotation['status'] == 'Borrador')
                  const PopupMenuItem(value: 'send', child: ListTile(
                    leading: Icon(Icons.send, color: Colors.blue),
                    title: Text('Enviar al cliente', style: TextStyle(color: Colors.blue)),
                    contentPadding: EdgeInsets.zero,
                  )),
                if (quotation['status'] == 'Enviada' || quotation['status'] == 'Borrador')
                  const PopupMenuItem(value: 'approve', child: ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Aprobar y crear venta', style: TextStyle(color: Colors.green)),
                    contentPadding: EdgeInsets.zero,
                  )),
                if (quotation['status'] == 'Enviada' || quotation['status'] == 'Borrador')
                  const PopupMenuItem(value: 'reject', child: ListTile(
                    leading: Icon(Icons.cancel, color: Colors.orange),
                    title: Text('Rechazar', style: TextStyle(color: Colors.orange)),
                    contentPadding: EdgeInsets.zero,
                  )),
                const PopupMenuDivider(),
                if (quotation['status'] != 'Aprobada')
                  const PopupMenuItem(value: 'delete', child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Eliminar', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  )),
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
              Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
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
      case 'Borrador': return Colors.grey;
      case 'Enviada': return Colors.blue;
      case 'Aprobada': return Colors.green;
      case 'Rechazada': return Colors.red;
      case 'Vencida': return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Borrador': return Icons.edit_note;
      case 'Enviada': return Icons.send;
      case 'Aprobada': return Icons.check_circle;
      case 'Rechazada': return Icons.cancel;
      case 'Vencida': return Icons.schedule;
      default: return Icons.description;
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
      case 'delete':
        _confirmDelete(quotation);
        break;
    }
  }

  void _sendQuotation(Map<String, dynamic> quotation) async {
    try {
      await ref.read(quotationsProvider.notifier).updateStatus(
        quotation['id'],
        'Enviada',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cotización ${quotation['number']} enviada al cliente'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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
            _buildApprovalInfo(Icons.receipt_long, 'Se creará una factura automáticamente'),
            _buildApprovalInfo(Icons.inventory, 'Se descontará el stock de los productos'),
            _buildApprovalInfo(Icons.lock, 'La cotización no podrá ser editada'),
            const SizedBox(height: 20),
            TextField(
              controller: seriesController,
              decoration: const InputDecoration(
                labelText: 'Serie de Factura',
                hintText: 'Ej: FAC, A, B',
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
            label: const Text('Aprobar y Crear Venta', style: TextStyle(color: Colors.white)),
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
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[700]))),
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
            Text('Creando factura y actualizando stock', 
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );

    try {
      final result = await ref.read(quotationsProvider.notifier).approveAndCreateInvoice(
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
            label: const Text('Rechazar', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  void _rejectQuotation(Map<String, dynamic> quotation, String reason) async {
    try {
      await ref.read(quotationsProvider.notifier).reject(
        quotation['id'],
        reason.isEmpty ? null : reason,
      );

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
          SnackBar(
            content: Text('Error: $e'),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isTotal ? AppTheme.primaryColor : Colors.grey[700],
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            Helpers.formatCurrency(value),
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? AppTheme.primaryColor : Colors.grey[800],
            ),
          ),
        ],
      ),
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
        content: Text('¿Estás seguro de eliminar la cotización ${quotation['number']}?\n\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Eliminar de la base de datos usando el provider
              final success = await ref.read(quotationsProvider.notifier).deleteQuotation(quotation['id']);
              
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Cotización ${quotation['number']} eliminada'),
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
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
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

class _QuotationDetailDialogState extends State<_QuotationDetailDialog> with SingleTickerProviderStateMixin {
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
      case 'Borrador': return Colors.grey;
      case 'Enviada': return Colors.blue;
      case 'Aprobada': return Colors.green;
      case 'Rechazada': return Colors.red;
      case 'Vencida': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quotation;
    final statusColor = _getStatusColor(q['status']);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 950,
        height: 750,
        child: Column(
          children: [
            // Header con tabs
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.description, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    q['number'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      q['status'],
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                q['description'],
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Helpers.formatCurrency(q['total']),
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${Helpers.formatNumber(q['weight'])} kg',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                      Tab(icon: Icon(Icons.person), text: 'Vista Cliente'),
                      Tab(icon: Icon(Icons.business), text: 'Vista Empresa'),
                    ],
                  ),
                ],
              ),
            ),
            // Contenido de tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildClientView(q),
                  _buildEnterpriseView(q),
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
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
                        'Cliente: ${q['customer']}  |  Fecha: ${Helpers.formatDate(q['date'])}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Generando PDF de ${q['number']}...'), backgroundColor: AppTheme.primaryColor),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Generar PDF'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check),
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

  // ==========================================
  // VISTA CLIENTE - Simple, solo productos
  // ==========================================
  Widget _buildClientView(Map<String, dynamic> q) {
    final items = q['items'] as List<dynamic>? ?? [];
    
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: 700,
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
                // Header empresa con logo
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
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
                                colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.7)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.precision_manufacturing, size: 50, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('INDUSTRIAL DE MOLINOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1a365d))),
                          Text('E IMPORTACIONES S.A.S.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1a365d))),
                          SizedBox(height: 4),
                          Text('NIT: 901946675-1', style: TextStyle(color: Colors.grey)),
                          Text('Vrd la playita - Supía, Caldas', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text('Tel: 3217551145 - 3136446632', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('COTIZACIÓN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        Text(q['number'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Fecha: ${Helpers.formatDate(q['date'])}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text('Válida: ${Helpers.formatDate(q['validUntil'])}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                // Cliente
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CLIENTE', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(q['customer'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('RUC: ${q['customerRuc'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Tabla de productos (VISTA SIMPLE - solo nombres)
                const Text('PRODUCTOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 40, child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Expanded(child: Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            SizedBox(width: 100, child: Text('Precio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                      ...items.map((item) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.grey[200]!)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 40, child: Text('${item['quantity']}', style: const TextStyle(fontSize: 13))),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Text('Código: ${item['productCode']}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Text(
                                'S/ ${Helpers.formatNumber(item['totalPrice'] * item['quantity'])}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Resumen para cliente
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 250,
                      child: Column(
                        children: [
                          _buildTotalRow('Subtotal materiales', q['materialsCost']),
                          _buildTotalRow('Mano de Obra', q['laborCost']),
                          _buildTotalRow('Otros Costos', q['indirectCosts']),
                          const Divider(),
                          _buildTotalRow('TOTAL', q['total'], isTotal: true),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Notas
                if ((q['notes'] as String?)?.isNotEmpty == true)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text('Condiciones', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700])),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(q['notes'], style: TextStyle(fontSize: 12, color: Colors.grey[700])),
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
                                child: Icon(Icons.business, color: Colors.orange[800]),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DOCUMENTO INTERNO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('${q['number']} - Desglose de materiales', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('USO INTERNO', style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Cliente: ${q['customer']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                // Desglose por producto
                ...items.map((item) => _buildProductBreakdown(item)),
                const SizedBox(height: 24),
                const Divider(thickness: 2),
                const SizedBox(height: 16),
                // Resumen de costos
                const Text('RESUMEN DE COSTOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                      _buildCostDetailRow('Materiales', q['materialsCost'], Icons.inventory_2),
                      _buildCostDetailRow('Mano de Obra', q['laborCost'], Icons.engineering),
                      _buildCostDetailRow('Costos Indirectos', q['indirectCosts'], Icons.receipt_long),
                      const Divider(thickness: 2),
                      _buildCostDetailRow('Subtotal', q['materialsCost'] + q['laborCost'] + q['indirectCosts'], Icons.calculate, isBold: true),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.trending_up, color: Colors.green[700], size: 20),
                                const SizedBox(width: 8),
                                Text('Margen (${q['profitMargin']}%)', style: TextStyle(color: Colors.green[700])),
                              ],
                            ),
                            Text(
                              'S/ ${Helpers.formatNumber((q['materialsCost'] + q['laborCost'] + q['indirectCosts']) * q['profitMargin'] / 100)}',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                            ),
                          ],
                        ),
                      ),
                      const Divider(thickness: 2),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.payments, size: 24),
                                SizedBox(width: 8),
                                Text('TOTAL COTIZACIÓN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            Text(
                              Helpers.formatCurrency(q['total']),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.primaryColor),
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
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
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

  Widget _buildProductBreakdown(Map<String, dynamic> item) {
    final components = item['components'] as List<dynamic>? ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header del producto
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(Icons.precision_manufacturing, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Código: ${item['productCode']} | Cantidad: ${item['quantity']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('S/ ${Helpers.formatNumber(item['totalPrice'])}', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    Text('${Helpers.formatNumber(item['totalWeight'])} kg', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          // Componentes
          if (components.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey[100],
              child: const Row(
                children: [
                  SizedBox(width: 30, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text('Componente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text('Material', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text('Dimensiones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  SizedBox(width: 60, child: Text('Peso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                  SizedBox(width: 80, child: Text('Precio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                ],
              ),
            ),
            ...components.map((comp) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  SizedBox(width: 30, child: Text('${comp['quantity']}×', style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
                  Expanded(flex: 2, child: Text(comp['name'], style: const TextStyle(fontSize: 12))),
                  Expanded(flex: 2, child: Text(comp['material'], style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                  Expanded(flex: 2, child: Text(comp['dimensions'], style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                  SizedBox(width: 60, child: Text('${Helpers.formatNumber(comp['weight'])} kg', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                  SizedBox(width: 80, child: Text('S/ ${Helpers.formatNumber(comp['price'])}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
                ],
              ),
            )),
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
          Text(label, style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 13,
          )),
          Text(
            'S/ ${Helpers.formatNumber(value)}',
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

  Widget _buildCostDetailRow(String label, double value, IconData icon, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
          Text(
            'S/ ${Helpers.formatNumber(value)}',
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}