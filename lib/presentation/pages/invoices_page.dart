import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../domain/entities/invoice.dart';
import '../widgets/receipt_preview.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedStatus = 'Todos';
  DateTimeRange? _dateRange;

  // Datos de ejemplo
  final List<Map<String, dynamic>> _invoices = [
    {
      'id': '1',
      'number': 'F001-00045',
      'customer': 'Juan Pérez García',
      'customerId': '1',
      'date': DateTime.now().subtract(const Duration(days: 1)),
      'dueDate': DateTime.now().add(const Duration(days: 29)),
      'items': 5,
      'subtotal': 1050.85,
      'tax': 189.15,
      'total': 1240.00,
      'paid': 1240.00,
      'status': 'Pagada',
      'paymentMethod': 'Efectivo',
    },
    {
      'id': '2',
      'number': 'F001-00044',
      'customer': 'María García López',
      'customerId': '2',
      'date': DateTime.now().subtract(const Duration(days: 2)),
      'dueDate': DateTime.now().add(const Duration(days: 28)),
      'items': 12,
      'subtotal': 754.24,
      'tax': 135.76,
      'total': 890.00,
      'paid': 0.0,
      'status': 'Pendiente',
      'paymentMethod': null,
    },
    {
      'id': '3',
      'number': 'F001-00043',
      'customer': 'Distribuidora El Sol SAC',
      'customerId': '4',
      'date': DateTime.now().subtract(const Duration(days: 3)),
      'dueDate': DateTime.now().add(const Duration(days: 27)),
      'items': 45,
      'subtotal': 12542.37,
      'tax': 2257.63,
      'total': 14800.00,
      'paid': 7400.00,
      'status': 'Parcial',
      'paymentMethod': 'Transferencia',
    },
    {
      'id': '4',
      'number': 'F001-00042',
      'customer': 'Carlos Rodríguez',
      'customerId': '3',
      'date': DateTime.now().subtract(const Duration(days: 5)),
      'dueDate': DateTime.now().subtract(const Duration(days: 5)),
      'items': 3,
      'subtotal': 423.73,
      'tax': 76.27,
      'total': 500.00,
      'paid': 0.0,
      'status': 'Vencida',
      'paymentMethod': null,
    },
    {
      'id': '5',
      'number': 'F001-00041',
      'customer': 'Ana Torres Mendoza',
      'customerId': '5',
      'date': DateTime.now().subtract(const Duration(days: 7)),
      'dueDate': DateTime.now().add(const Duration(days: 23)),
      'items': 8,
      'subtotal': 1864.41,
      'tax': 335.59,
      'total': 2200.00,
      'paid': 2200.00,
      'status': 'Pagada',
      'paymentMethod': 'Yape',
    },
    {
      'id': '6',
      'number': 'F001-00040',
      'customer': 'Distribuidora El Sol SAC',
      'customerId': '4',
      'date': DateTime.now().subtract(const Duration(days: 10)),
      'dueDate': DateTime.now().add(const Duration(days: 20)),
      'items': 67,
      'subtotal': 21186.44,
      'tax': 3813.56,
      'total': 25000.00,
      'paid': 25000.00,
      'status': 'Pagada',
      'paymentMethod': 'Transferencia',
    },
    {
      'id': '7',
      'number': 'B001-00023',
      'customer': 'Cliente Mostrador',
      'customerId': null,
      'date': DateTime.now().subtract(const Duration(hours: 3)),
      'dueDate': null,
      'items': 2,
      'subtotal': 42.37,
      'tax': 7.63,
      'total': 50.00,
      'paid': 50.00,
      'status': 'Pagada',
      'paymentMethod': 'Efectivo',
    },
  ];

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

  List<Map<String, dynamic>> get _filteredInvoices {
    return _invoices.where((invoice) {
      final matchesSearch = invoice['number'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          invoice['customer'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      bool matchesStatus = true;
      if (_selectedStatus != 'Todos') {
        matchesStatus = invoice['status'] == _selectedStatus;
      }

      bool matchesDate = true;
      if (_dateRange != null) {
        final invoiceDate = invoice['date'] as DateTime;
        matchesDate = invoiceDate.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
            invoiceDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }

      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  double get _totalVentas => _invoices.fold(0.0, (sum, inv) => sum + (inv['total'] as double));
  double get _totalCobrado => _invoices.fold(0.0, (sum, inv) => sum + (inv['paid'] as double));
  double get _totalPendiente => _totalVentas - _totalCobrado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
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
                            'Ventas',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_invoices.length} documentos emitidos',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    // Stats rápidas
                    _buildQuickStat('Ventas del Mes', Formatters.currency(_totalVentas), Colors.blue, Icons.trending_up),
                    const SizedBox(width: 12),
                    _buildQuickStat('Cobrado', Formatters.currency(_totalCobrado), Colors.green, Icons.check_circle),
                    const SizedBox(width: 12),
                    _buildQuickStat('Por Cobrar', Formatters.currency(_totalPendiente), Colors.orange, Icons.schedule),
                    const SizedBox(width: 24),
                    FilledButton.icon(
                      onPressed: () => context.go('/invoices/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva Venta'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Tabs y filtros
                Row(
                  children: [
                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicator: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey[600],
                        tabs: const [
                          Tab(text: '  Recibos de Caja Menor  '),
                          Tab(text: '  Boletas  '),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Búsqueda
                    Expanded(
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Buscar por número o cliente...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Filtro de estado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          items: ['Todos', 'Pagada', 'Pendiente', 'Parcial', 'Vencida', 'Anulada']
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedStatus = value!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Filtro de fecha
                    OutlinedButton.icon(
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: _dateRange,
                        );
                        if (range != null) {
                          setState(() => _dateRange = range);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(_dateRange == null 
                          ? 'Fecha' 
                          : '${Formatters.date(_dateRange!.start)} - ${Formatters.date(_dateRange!.end)}'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    if (_dateRange != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _dateRange = null),
                        tooltip: 'Limpiar filtro de fecha',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Lista de recibos de caja menor
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInvoicesList(_filteredInvoices.where((i) => i['number'].toString().startsWith('F')).toList()),
                _buildInvoicesList(_filteredInvoices.where((i) => i['number'].toString().startsWith('B')).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesList(List<Map<String, dynamic>> invoices) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No hay documentos',
              style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Los documentos emitidos aparecerán aquí',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
              dataRowMinHeight: 60,
              dataRowMaxHeight: 70,
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Documento', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Vencimiento', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Pagado', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: invoices.map((invoice) => _buildInvoiceRow(invoice)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildInvoiceRow(Map<String, dynamic> invoice) {
    Color statusColor;
    IconData statusIcon;
    switch (invoice['status']) {
      case 'Pagada':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Pendiente':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'Parcial':
        statusColor = Colors.blue;
        statusIcon = Icons.pie_chart;
        break;
      case 'Vencida':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      case 'Anulada':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    final total = invoice['total'] as double;
    final paid = invoice['paid'] as double;
    final pending = total - paid;

    return DataRow(
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                invoice['number'],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${invoice['items']} items',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            invoice['customer'],
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        DataCell(
          Text(Formatters.date(invoice['date'])),
        ),
        DataCell(
          invoice['dueDate'] != null
              ? Text(
                  Formatters.date(invoice['dueDate']),
                  style: TextStyle(
                    color: (invoice['dueDate'] as DateTime).isBefore(DateTime.now()) && invoice['status'] != 'Pagada'
                        ? Colors.red
                        : Colors.grey[700],
                  ),
                )
              : Text('-', style: TextStyle(color: Colors.grey[400])),
        ),
        DataCell(
          Text(
            Formatters.currency(total),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                Formatters.currency(paid),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: paid > 0 ? Colors.green[700] : Colors.grey[500],
                ),
              ),
              if (pending > 0)
                Text(
                  'Debe: ${Formatters.currency(pending)}',
                  style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  invoice['status'],
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        DataCell(
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[400]),
            onSelected: (value) => _handleInvoiceAction(value, invoice),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility, size: 18), SizedBox(width: 8), Text('Ver detalle')])),
              const PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print, size: 18), SizedBox(width: 8), Text('Imprimir')])),
              const PopupMenuItem(value: 'email', child: Row(children: [Icon(Icons.email, size: 18), SizedBox(width: 8), Text('Enviar por email')])),
              if (invoice['status'] != 'Pagada' && invoice['status'] != 'Anulada') ...[
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'payment', child: Row(children: [Icon(Icons.payment, size: 18, color: Colors.green), SizedBox(width: 8), Text('Registrar pago', style: TextStyle(color: Colors.green))])),
              ],
              if (invoice['status'] != 'Anulada') ...[
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'cancel', child: Row(children: [Icon(Icons.cancel, size: 18, color: Colors.red), SizedBox(width: 8), Text('Anular', style: TextStyle(color: Colors.red))])),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _handleInvoiceAction(String action, Map<String, dynamic> invoice) {
    switch (action) {
      case 'view':
        _showInvoiceDetails(invoice);
        break;
      case 'print':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imprimiendo ${invoice['number']}...'), backgroundColor: Colors.blue),
        );
        break;
      case 'email':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enviando ${invoice['number']} por email...'), backgroundColor: Colors.blue),
        );
        break;
      case 'payment':
        _showPaymentDialog(invoice);
        break;
      case 'cancel':
        _confirmCancelInvoice(invoice);
        break;
    }
  }

  void _showInvoiceDetails(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 700,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice['number'],
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          Formatters.dateLong(invoice['date']),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(invoice['status']),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              // Cliente
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cliente', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(invoice['customer'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Método de Pago', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(invoice['paymentMethod'] ?? 'Sin pago', style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Resumen de montos
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildAmountRow('Subtotal', invoice['subtotal']),
                    const SizedBox(height: 8),
                    _buildAmountRow('IGV (18%)', invoice['tax']),
                    const Divider(),
                    _buildAmountRow('Total', invoice['total'], isTotal: true),
                    if ((invoice['paid'] as double) > 0) ...[
                      const SizedBox(height: 8),
                      _buildAmountRow('Pagado', invoice['paid'], color: Colors.green),
                    ],
                    if ((invoice['total'] as double) - (invoice['paid'] as double) > 0) ...[
                      const SizedBox(height: 8),
                      _buildAmountRow('Pendiente', (invoice['total'] as double) - (invoice['paid'] as double), color: Colors.orange),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Vista previa de recibo
              const Divider(),
              const SizedBox(height: 12),
              const Text('Ver Recibo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showReceiptPreview(invoice, isClientVersion: true);
                    },
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Recibo Cliente'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showReceiptPreview(invoice, isClientVersion: false);
                    },
                    icon: const Icon(Icons.description),
                    label: const Text('Recibo Empresa'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Acciones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimir'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.email),
                    label: const Text('Enviar'),
                  ),
                  if (invoice['status'] != 'Pagada' && invoice['status'] != 'Anulada') ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showPaymentDialog(invoice);
                      },
                      icon: const Icon(Icons.payment),
                      label: const Text('Registrar Pago'),
                    ),
                  ],
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color statusColor;
    switch (status) {
      case 'Pagada': statusColor = Colors.green; break;
      case 'Pendiente': statusColor = Colors.orange; break;
      case 'Parcial': statusColor = Colors.blue; break;
      case 'Vencida': statusColor = Colors.red; break;
      default: statusColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, {bool isTotal = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          fontSize: isTotal ? 16 : 14,
        )),
        Text(
          Formatters.currency(amount),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: isTotal ? 18 : 14,
            color: color ?? (isTotal ? AppTheme.primaryColor : Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  void _showPaymentDialog(Map<String, dynamic> invoice) {
    final pending = (invoice['total'] as double) - (invoice['paid'] as double);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payment, color: Colors.green),
                  const SizedBox(width: 12),
                  const Text('Registrar Pago', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              Text('Documento: ${invoice['number']}', style: TextStyle(color: Colors.grey[600])),
              Text('Pendiente: ${Formatters.currency(pending)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: pending.toStringAsFixed(2),
                decoration: const InputDecoration(
                  labelText: 'Monto a pagar',
                  border: OutlineInputBorder(),
                  prefixText: 'S/ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: 'Efectivo',
                decoration: const InputDecoration(
                  labelText: 'Método de pago',
                  border: OutlineInputBorder(),
                ),
                items: ['Efectivo', 'Transferencia', 'Yape', 'Plin', 'Tarjeta']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Referencia (opcional)',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Nro. de operación',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pago registrado exitosamente'), backgroundColor: Colors.green),
                      );
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCancelInvoice(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular documento'),
        content: Text('¿Está seguro de anular el documento ${invoice['number']}?\n\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Documento ${invoice['number']} anulado'), backgroundColor: Colors.red),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
  }

  void _showReceiptPreview(Map<String, dynamic> invoice, {required bool isClientVersion}) {
    // Convertir Map a Invoice para usar en los widgets de recibo
    final now = DateTime.now();
    final invoiceEntity = Invoice(
      id: invoice['id'] ?? '',
      type: InvoiceType.invoice,
      series: 'F001',
      number: invoice['number']?.toString().split('-').last ?? '0',
      customerId: invoice['customerId'] ?? '',
      customerName: invoice['customer'] ?? '',
      customerDocument: '',
      issueDate: invoice['date'] ?? now,
      dueDate: invoice['dueDate'],
      subtotal: (invoice['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (invoice['tax'] as num?)?.toDouble() ?? 0,
      discount: 0,
      total: (invoice['total'] as num?)?.toDouble() ?? 0,
      paidAmount: (invoice['paid'] as num?)?.toDouble() ?? 0,
      status: _getInvoiceStatus(invoice['status'] ?? ''),
      createdAt: now,
      updatedAt: now,
    );

    // Items de ejemplo (en producción se cargarían de la base de datos)
    final items = <InvoiceItem>[
      InvoiceItem(
        id: '1',
        invoiceId: invoiceEntity.id,
        productName: 'Productos varios',
        quantity: invoice['items'] ?? 1,
        unitPrice: invoiceEntity.subtotal / (invoice['items'] ?? 1),
        subtotal: invoiceEntity.subtotal,
        total: invoiceEntity.total,
      ),
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isClientVersion ? 'Recibo Cliente' : 'Recibo Empresa (Detallado)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isClientVersion ? Colors.blue : Colors.red,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _showReceiptPreview(invoice, isClientVersion: !isClientVersion);
                        },
                        icon: Icon(isClientVersion ? Icons.description : Icons.receipt_long),
                        label: Text(isClientVersion ? 'Ver Empresa' : 'Ver Cliente'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              // Vista previa del recibo
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isClientVersion
                        ? ReceiptPreviewClient(
                            invoice: invoiceEntity,
                            items: items,
                          )
                        : ReceiptPreviewEnterprise(
                            invoice: invoiceEntity,
                            items: items,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                    label: const Text('Cerrar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Función de impresión próximamente'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InvoiceStatus _getInvoiceStatus(String status) {
    switch (status) {
      case 'Pagada': return InvoiceStatus.paid;
      case 'Pendiente': return InvoiceStatus.issued;
      case 'Parcial': return InvoiceStatus.partial;
      case 'Vencida': return InvoiceStatus.overdue;
      case 'Anulada': return InvoiceStatus.cancelled;
      default: return InvoiceStatus.draft;
    }
  }
}
