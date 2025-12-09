import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';

class QuotationsPage extends StatefulWidget {
  const QuotationsPage({super.key});

  @override
  State<QuotationsPage> createState() => _QuotationsPageState();
}

class _QuotationsPageState extends State<QuotationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _filterStatus = 'Todas';

  // Datos de ejemplo
  final List<Map<String, dynamic>> _quotations = [
    {
      'id': '1',
      'number': 'COT-2024-001',
      'date': DateTime(2024, 12, 5),
      'validUntil': DateTime(2024, 12, 20),
      'customer': 'Minera San Martín S.A.',
      'description': 'Molino de bolas 4x6 pies',
      'status': 'Aprobada',
      'materialsCost': 12500.0,
      'laborCost': 3500.0,
      'indirectCosts': 1200.0,
      'profitMargin': 25.0,
      'total': 21500.0,
      'weight': 2850.0,
    },
    {
      'id': '2',
      'number': 'COT-2024-002',
      'date': DateTime(2024, 12, 7),
      'validUntil': DateTime(2024, 12, 22),
      'customer': 'Procesadora de Minerales del Norte',
      'description': 'Molino de bolas 3x4 pies + repuestos',
      'status': 'Enviada',
      'materialsCost': 8200.0,
      'laborCost': 2200.0,
      'indirectCosts': 800.0,
      'profitMargin': 20.0,
      'total': 13440.0,
      'weight': 1450.0,
    },
    {
      'id': '3',
      'number': 'COT-2024-003',
      'date': DateTime(2024, 12, 9),
      'validUntil': DateTime(2024, 12, 24),
      'customer': 'Cementos Pacífico',
      'description': 'Cilindro y tapas para molino 5x8',
      'status': 'Borrador',
      'materialsCost': 18500.0,
      'laborCost': 5500.0,
      'indirectCosts': 2100.0,
      'profitMargin': 22.0,
      'total': 31842.0,
      'weight': 4200.0,
    },
    {
      'id': '4',
      'number': 'COT-2024-004',
      'date': DateTime(2024, 11, 25),
      'validUntil': DateTime(2024, 12, 10),
      'customer': 'Industrias Metalúrgicas Sur',
      'description': 'Reparación de molino - cambio de tapas',
      'status': 'Vencida',
      'materialsCost': 4500.0,
      'laborCost': 1800.0,
      'indirectCosts': 600.0,
      'profitMargin': 18.0,
      'total': 8142.0,
      'weight': 980.0,
    },
    {
      'id': '5',
      'number': 'COT-2024-005',
      'date': DateTime(2024, 12, 1),
      'validUntil': DateTime(2024, 12, 16),
      'customer': 'Minera Los Andes',
      'description': 'Molino de bolas 6x10 pies industrial',
      'status': 'Rechazada',
      'materialsCost': 35000.0,
      'laborCost': 12000.0,
      'indirectCosts': 4500.0,
      'profitMargin': 30.0,
      'total': 66950.0,
      'weight': 8500.0,
    },
  ];

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
      .fold(0.0, (sum, q) => sum + (q['total'] as double));

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    child: _filteredQuotations.isEmpty
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
                const PopupMenuDivider(),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey[300]),
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
      case 'delete':
        _confirmDelete(quotation);
        break;
    }
  }

  void _showQuotationDetail(Map<String, dynamic> quotation) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description, color: AppTheme.primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quotation['number'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          quotation['description'],
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              // Detalles
              _buildDetailRow('Cliente', quotation['customer']),
              _buildDetailRow('Fecha', Helpers.formatDate(quotation['date'])),
              _buildDetailRow('Válida hasta', Helpers.formatDate(quotation['validUntil'])),
              _buildDetailRow('Estado', quotation['status']),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              // Costos
              Text('Desglose de Costos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
              const SizedBox(height: 12),
              _buildCostRow('Materiales', quotation['materialsCost']),
              _buildCostRow('Mano de Obra', quotation['laborCost']),
              _buildCostRow('Costos Indirectos', quotation['indirectCosts']),
              const Divider(),
              _buildCostRow('Subtotal', quotation['materialsCost'] + quotation['laborCost'] + quotation['indirectCosts']),
              _buildCostRow('Margen (${quotation['profitMargin']}%)', 
                (quotation['materialsCost'] + quotation['laborCost'] + quotation['indirectCosts']) * quotation['profitMargin'] / 100),
              const Divider(thickness: 2),
              _buildCostRow('TOTAL', quotation['total'], isTotal: true),
              const SizedBox(height: 8),
              _buildDetailRow('Peso Total', '${Helpers.formatNumber(quotation['weight'])} kg'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Cerrar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/quotations/edit/${quotation['id']}');
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
        content: Text('¿Estás seguro de eliminar la cotización ${quotation['number']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _quotations.removeWhere((q) => q['id'] == quotation['id']);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cotización eliminada'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
