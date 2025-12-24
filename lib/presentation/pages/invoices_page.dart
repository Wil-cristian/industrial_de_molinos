import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../domain/entities/invoice.dart';
import '../../data/providers/invoices_provider.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/quick_actions_button.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedStatus = 'Todos';
  DateTimeRange? _dateRange;

  // Los datos vienen del provider
  List<Map<String, dynamic>> get _invoices {
    final state = ref.watch(invoicesProvider);
    return state.invoices.map((inv) => {
      'id': inv.id,
      'number': '${inv.series}-${inv.number}',
      'customer': inv.customerName,
      'customerId': inv.customerId,
      'customerRuc': inv.customerDocument,
      'date': inv.issueDate,
      'dueDate': inv.dueDate,
      'items': inv.items.length,
      'subtotal': inv.subtotal,
      'tax': inv.taxAmount,
      'total': inv.total,
      'paid': inv.paidAmount,
      'status': _mapStatus(inv.status),
      'paymentMethod': inv.paymentMethod?.name,
      'notes': inv.notes,
      'products': inv.items.map((item) => {
        'name': item.productName,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'total': item.total,
      }).toList(),
    }).toList();
  }

  String _mapStatus(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return 'Borrador';
      case InvoiceStatus.issued: return 'Pendiente';
      case InvoiceStatus.paid: return 'Pagada';
      case InvoiceStatus.partial: return 'Parcial';
      case InvoiceStatus.cancelled: return 'Anulada';
      case InvoiceStatus.overdue: return 'Vencida';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Cargar facturas desde Supabase
    Future.microtask(() => ref.read(invoicesProvider.notifier).refresh());
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
      body: Stack(
        children: [
          Row(
            children: [
              const AppSidebar(currentRoute: '/invoices'),
              Expanded(
                child: Column(
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
              ),
            ],
          ),
          const QuickActionsButton(),
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
    final amountController = TextEditingController(text: pending.toStringAsFixed(2));
    final referenceController = TextEditingController();
    String selectedMethod = 'Efectivo';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
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
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Monto a pagar',
                    border: OutlineInputBorder(),
                    prefixText: 'S/ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedMethod,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Efectivo', 'Transferencia', 'Yape', 'Plin', 'Tarjeta']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) => setDialogState(() => selectedMethod = value ?? 'Efectivo'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: referenceController,
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
                      onPressed: () async {
                        final amount = double.tryParse(amountController.text) ?? 0;
                        if (amount <= 0 || amount > pending) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Monto inválido'), backgroundColor: Colors.red),
                          );
                          return;
                        }
                        
                        Navigator.pop(context);
                        
                        // Convertir método de pago
                        PaymentMethod method;
                        switch (selectedMethod) {
                          case 'Transferencia': method = PaymentMethod.transfer; break;
                          case 'Yape': method = PaymentMethod.yape; break;
                          case 'Plin': method = PaymentMethod.plin; break;
                          case 'Tarjeta': method = PaymentMethod.card; break;
                          default: method = PaymentMethod.cash;
                        }
                        
                        final success = await ref.read(invoicesProvider.notifier).registerPayment(
                          invoice['id'],
                          amount,
                          method,
                        );
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Pago registrado exitosamente' : 'Error al registrar pago'),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        }
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
    showDialog(
      context: context,
      builder: (context) => _InvoicePreviewDialog(invoice: invoice, initialTab: isClientVersion ? 0 : 1),
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

// ============================================
// DIÁLOGO DE PREVISUALIZACIÓN DE FACTURA
// ============================================
class _InvoicePreviewDialog extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final int initialTab;

  const _InvoicePreviewDialog({required this.invoice, this.initialTab = 0});

  @override
  State<_InvoicePreviewDialog> createState() => _InvoicePreviewDialogState();
}

class _InvoicePreviewDialogState extends State<_InvoicePreviewDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pagada': return Colors.green;
      case 'Pendiente': return Colors.orange;
      case 'Parcial': return Colors.blue;
      case 'Vencida': return Colors.red;
      case 'Anulada': return Colors.grey;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final statusColor = _getStatusColor(inv['status']);
    
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
                        const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    inv['number'],
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
                                      inv['status'],
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                inv['customer'],
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Helpers.formatCurrency(inv['total']),
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${inv['items']} items',
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
                      Tab(icon: Icon(Icons.person), text: 'Recibo Cliente'),
                      Tab(icon: Icon(Icons.business), text: 'Recibo Empresa'),
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
                  _buildClientView(inv),
                  _buildEnterpriseView(inv),
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
                        'Fecha: ${Helpers.formatDate(inv['date'])}  |  Vence: ${Helpers.formatDate(inv['dueDate'])}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Preparando impresión...'), backgroundColor: Colors.blue),
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Imprimir'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enviando por correo...'), backgroundColor: Colors.green),
                          );
                        },
                        icon: const Icon(Icons.email),
                        label: const Text('Enviar'),
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
  // RECIBO CLIENTE - Simple
  // ==========================================
  Widget _buildClientView(Map<String, dynamic> inv) {
    final products = inv['products'] as List<dynamic>? ?? [];
    
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
                    // Logo
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('RECIBO DE CAJA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        Text(inv['number'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Fecha: ${Helpers.formatDate(inv['date'])}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                          Text(inv['customer'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('NIT/CC: ${inv['customerRuc'] ?? 'N/A'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('MÉTODO DE PAGO', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(inv['paymentMethod'] ?? 'Pendiente', style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Tabla de productos simple
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
                            SizedBox(width: 90, child: Text('P.Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                            SizedBox(width: 90, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                          ],
                        ),
                      ),
                      ...products.map((prod) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.grey[200]!)),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 40, child: Text('${prod['quantity']}', style: const TextStyle(fontSize: 13))),
                            Expanded(child: Text(prod['name'], style: const TextStyle(fontSize: 13))),
                            SizedBox(width: 90, child: Text('S/ ${Helpers.formatNumber(prod['unitPrice'])}', style: const TextStyle(fontSize: 13), textAlign: TextAlign.right)),
                            SizedBox(width: 90, child: Text('S/ ${Helpers.formatNumber(prod['total'])}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), textAlign: TextAlign.right)),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Totales
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 250,
                      child: Column(
                        children: [
                          _buildTotalRow('Subtotal', inv['subtotal']),
                          _buildTotalRow('IGV (18%)', inv['tax']),
                          const Divider(),
                          _buildTotalRow('TOTAL', inv['total'], isTotal: true),
                          if ((inv['paid'] as double) > 0)
                            _buildTotalRow('Pagado', inv['paid'], color: Colors.green),
                          if ((inv['total'] as double) - (inv['paid'] as double) > 0)
                            _buildTotalRow('Pendiente', (inv['total'] as double) - (inv['paid'] as double), color: Colors.orange),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Footer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.email, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text('industriasdemolinosasfact@gmail.com', style: TextStyle(fontSize: 12, color: Colors.blue[700])),
                      const Spacer(),
                      Text('GRACIAS POR SU COMPRA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700], fontSize: 12)),
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
  // RECIBO EMPRESA - Detallado con materiales
  // ==========================================
  Widget _buildEnterpriseView(Map<String, dynamic> inv) {
    final products = inv['products'] as List<dynamic>? ?? [];
    
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
                // Header documento interno
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Logo
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
                            Text('${inv['number']} - Detalle completo', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                Text('Cliente: ${inv['customer']}  |  NIT: ${inv['customerRuc'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                // Desglose de productos con materiales
                const Text('DETALLE DE PRODUCTOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                ...products.map((prod) => _buildProductBreakdown(prod)),
                const SizedBox(height: 24),
                const Divider(thickness: 2),
                const SizedBox(height: 16),
                // Resumen de costos
                const Text('RESUMEN FINANCIERO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                      _buildCostDetailRow('Subtotal productos', inv['subtotal'], Icons.inventory_2),
                      _buildCostDetailRow('IGV (18%)', inv['tax'], Icons.receipt),
                      const Divider(thickness: 2),
                      _buildCostDetailRow('TOTAL FACTURA', inv['total'], Icons.payments, isBold: true),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (inv['paid'] as double) >= (inv['total'] as double) ? Colors.green[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  (inv['paid'] as double) >= (inv['total'] as double) ? Icons.check_circle : Icons.warning,
                                  color: (inv['paid'] as double) >= (inv['total'] as double) ? Colors.green[700] : Colors.orange[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pagado: S/ ${Helpers.formatNumber(inv['paid'])}',
                                  style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if ((inv['total'] as double) - (inv['paid'] as double) > 0)
                              Text(
                                'Pendiente: S/ ${Helpers.formatNumber((inv['total'] as double) - (inv['paid'] as double))}',
                                style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Notas
                if ((inv['notes'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note, color: Colors.amber[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('NOTAS:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber[800], fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(inv['notes'], style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductBreakdown(Map<String, dynamic> prod) {
    final components = prod['components'] as List<dynamic>? ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${prod['quantity']}×', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (prod['type'] != null)
                        Text('Tipo: ${prod['type']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('S/ ${Helpers.formatNumber(prod['total'])}', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 16)),
                    Text('P.U: S/ ${Helpers.formatNumber(prod['unitPrice'])}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          // Detalles del producto
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (prod['material'] != null)
                  _buildDetailItem(Icons.layers, 'Material', prod['material']),
                if (prod['dimensions'] != null)
                  _buildDetailItem(Icons.straighten, 'Dimensiones', prod['dimensions']),
                if (prod['weight'] != null)
                  _buildDetailItem(Icons.scale, 'Peso', prod['weight']),
                if (components.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_tree, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text('Componentes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[700])),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...components.map((comp) => Padding(
                          padding: const EdgeInsets.only(left: 22, top: 2),
                          child: Text('• $comp', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 13,
            color: color,
          )),
          Text(
            'S/ ${Helpers.formatNumber(value)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 13,
              color: color ?? (isTotal ? AppTheme.primaryColor : Colors.black),
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
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
              color: isBold ? AppTheme.primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }
}
