import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/account.dart';
import '../../data/providers/invoices_provider.dart';
import '../../data/datasources/invoices_datasource.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/providers/composite_products_provider.dart';
import '../../core/utils/print_service.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});

  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedStatus = 'Todos';
  DateTimeRange? _dateRange;

  // Los datos vienen del provider
  List<Map<String, dynamic>> get _invoices {
    final state = ref.watch(invoicesProvider);
    return state.invoices
        .map(
          (inv) => {
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
            'products': inv.items
                .map(
                  (item) => {
                    'name': item.productName,
                    'quantity': item.quantity,
                    'unitPrice': item.unitPrice,
                    'total': item.total,
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

  String _mapStatus(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Borrador';
      case InvoiceStatus.issued:
        return 'Pendiente';
      case InvoiceStatus.paid:
        return 'Pagada';
      case InvoiceStatus.partial:
        return 'Parcial';
      case InvoiceStatus.cancelled:
        return 'Anulada';
      case InvoiceStatus.overdue:
        return 'Vencida';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Cargar facturas desde Supabase
    Future.microtask(() => ref.read(invoicesProvider.notifier).refresh());
    // Cargar productos compuestos (para mostrar sub-materiales en detalle)
    Future.microtask(
      () => ref.read(compositeProductsProvider.notifier).loadProducts(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    return _invoices.where((invoice) {
      final matchesSearch =
          invoice['number'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          invoice['customer'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      bool matchesStatus = true;
      if (_selectedStatus != 'Todos') {
        matchesStatus = invoice['status'] == _selectedStatus;
      }

      bool matchesDate = true;
      if (_dateRange != null) {
        final invoiceDate = invoice['date'] as DateTime;
        matchesDate =
            invoiceDate.isAfter(
              _dateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            invoiceDate.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }

      return matchesSearch && matchesStatus && matchesDate;
    }).toList();
  }

  // Filtrar facturas activas (excluir anuladas) para estadísticas
  List<Map<String, dynamic>> get _activeInvoices =>
      _invoices.where((inv) => inv['status'] != 'Anulada').toList();

  double get _totalVentas =>
      _activeInvoices.fold(0.0, (sum, inv) => sum + (inv['total'] as double));
  double get _totalCobrado =>
      _activeInvoices.fold(0.0, (sum, inv) => sum + (inv['paid'] as double));
  double get _totalPendiente => _totalVentas - _totalCobrado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header ultra compacto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Text(
                  'Recibos de Caja',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                // Stats compactas
                _buildQuickStat(
                  'Ventas',
                  Formatters.currency(_totalVentas),
                  Colors.blue,
                  Icons.trending_up,
                ),
                const SizedBox(width: 8),
                _buildQuickStat(
                  'Cobrado',
                  Formatters.currency(_totalCobrado),
                  Colors.green,
                  Icons.check_circle,
                ),
                const SizedBox(width: 8),
                _buildQuickStat(
                  'Pendiente',
                  Formatters.currency(_totalPendiente),
                  Colors.orange,
                  Icons.schedule,
                ),
                const SizedBox(width: 12),
                // Búsqueda compacta
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Buscar...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filtro estado
                SizedBox(
                  height: 36,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatus,
                        isDense: true,
                        items:
                            [
                                  'Todos',
                                  'Pagada',
                                  'Pendiente',
                                  'Parcial',
                                  'Vencida',
                                  'Anulada',
                                ]
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedStatus = value!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filtro fecha compacto
                SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
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
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(
                      _dateRange == null
                          ? 'Fecha'
                          : '${Formatters.date(_dateRange!.start)} - ${Formatters.date(_dateRange!.end)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                if (_dateRange != null) ...[
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      icon: const Icon(Icons.clear, size: 14),
                      onPressed: () => setState(() => _dateRange = null),
                      tooltip: 'Limpiar',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // Botón nueva venta
                SizedBox(
                  height: 36,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/invoices/new'),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nuevo', style: TextStyle(fontSize: 13)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista de recibos
          Expanded(child: _buildInvoicesList(_filteredInvoices)),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 1),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 8, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
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
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay documentos',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
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
                DataColumn(
                  label: Text(
                    'Documento',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Cliente',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Fecha',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Vencimiento',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Pagado',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Estado',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    '',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: invoices
                  .map((invoice) => _buildInvoiceRow(invoice))
                  .toList(),
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
        DataCell(Text(Formatters.date(invoice['date']))),
        DataCell(
          invoice['dueDate'] != null
              ? Text(
                  Formatters.date(invoice['dueDate']),
                  style: TextStyle(
                    color:
                        (invoice['dueDate'] as DateTime).isBefore(
                              DateTime.now(),
                            ) &&
                            invoice['status'] != 'Pagada'
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
              const PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 18),
                    SizedBox(width: 8),
                    Text('Ver detalle'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print, size: 18),
                    SizedBox(width: 8),
                    Text('Imprimir'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'email',
                child: Row(
                  children: [
                    Icon(Icons.email, size: 18),
                    SizedBox(width: 8),
                    Text('Enviar por email'),
                  ],
                ),
              ),
              if (invoice['status'] != 'Pagada' &&
                  invoice['status'] != 'Anulada') ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'payment',
                  child: Row(
                    children: [
                      Icon(Icons.payment, size: 18, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Registrar pago',
                        style: TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
              if (invoice['status'] != 'Anulada' &&
                  invoice['status'] != 'Pagada' &&
                  invoice['status'] != 'Parcial') ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Anular', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
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
        PrintService.printInvoice(invoice);
        break;
      case 'email':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enviando ${invoice['number']} por email...'),
            backgroundColor: Colors.blue,
          ),
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

  InvoiceStatus getInvoiceStatus(String status) {
    switch (status) {
      case 'Pagada':
        return InvoiceStatus.paid;
      case 'Pendiente':
        return InvoiceStatus.issued;
      case 'Parcial':
        return InvoiceStatus.partial;
      case 'Vencida':
        return InvoiceStatus.overdue;
      case 'Anulada':
        return InvoiceStatus.cancelled;
      default:
        return InvoiceStatus.draft;
    }
  }

  void _showInvoiceDetails(Map<String, dynamic> invoice) {
    showDialog(
      context: context,
      builder: (context) => _InvoiceFullDetailDialog(
        invoice: invoice,
        onPayment: () => _showPaymentDialog(invoice),
        onCancel: () => _confirmCancelInvoice(invoice),
        onRefresh: () => ref.read(invoicesProvider.notifier).refresh(),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color statusColor;
    switch (status) {
      case 'Pagada':
        statusColor = Colors.green;
        break;
      case 'Pendiente':
        statusColor = Colors.orange;
        break;
      case 'Parcial':
        statusColor = Colors.blue;
        break;
      case 'Vencida':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
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

  Widget _buildAmountRow(
    String label,
    double amount, {
    bool isTotal = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          Formatters.currency(amount),
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            fontSize: isTotal ? 18 : 14,
            color:
                color ?? (isTotal ? AppTheme.primaryColor : Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  void _showPaymentDialog(Map<String, dynamic> invoice) {
    final total = invoice['total'] as double;
    final paid = invoice['paid'] as double;
    final pending = total - paid;
    final amountController = TextEditingController(
      text: pending.toStringAsFixed(2),
    );
    final referenceController = TextEditingController();
    Account? selectedAccount;
    List<Account> accounts = [];
    List<Map<String, dynamic>> paymentHistory = [];
    bool loadingHistory = true;
    bool loadingAccounts = true;

    // Cargar cuentas
    AccountsDataSource.getAllAccounts(activeOnly: true)
        .then((loadedAccounts) {
          accounts = loadedAccounts;
          if (accounts.isNotEmpty) {
            // Seleccionar efectivo por defecto o la primera cuenta
            selectedAccount = accounts.firstWhere(
              (a) => a.type == AccountType.cash,
              orElse: () => accounts.first,
            );
          }
          loadingAccounts = false;
        })
        .catchError((e) {
          loadingAccounts = false;
        });

    // Cargar historial de pagos
    InvoicesDataSource.getPayments(invoice['id'])
        .then((payments) {
          paymentHistory = payments;
          loadingHistory = false;
        })
        .catchError((e) {
          loadingHistory = false;
        });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Refresh history
          if (loadingHistory) {
            InvoicesDataSource.getPayments(invoice['id'])
                .then((payments) {
                  setDialogState(() {
                    paymentHistory = payments;
                    loadingHistory = false;
                  });
                })
                .catchError((e) {
                  setDialogState(() => loadingHistory = false);
                });
          }

          // Cargar cuentas
          if (loadingAccounts) {
            AccountsDataSource.getAllAccounts(activeOnly: true)
                .then((loadedAccounts) {
                  setDialogState(() {
                    accounts = loadedAccounts;
                    if (accounts.isNotEmpty && selectedAccount == null) {
                      selectedAccount = accounts.firstWhere(
                        (a) => a.type == AccountType.cash,
                        orElse: () => accounts.first,
                      );
                    }
                    loadingAccounts = false;
                  });
                })
                .catchError((e) {
                  setDialogState(() => loadingAccounts = false);
                });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 480,
              constraints: const BoxConstraints(maxHeight: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.payment,
                            color: Colors.green[700],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Registrar Pago / Abono',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                invoice['number'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Resumen de cuenta
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total del recibo:',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      Formatters.currency(total),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Pagado:',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      Formatters.currency(paid),
                                      style: TextStyle(
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'PENDIENTE:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      Formatters.currency(pending),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Historial de pagos (si hay)
                          if (!loadingHistory && paymentHistory.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[200]!),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'HISTORIAL DE PAGOS',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[500],
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...paymentHistory.asMap().entries.map((
                                    entry,
                                  ) {
                                    final idx = entry.key;
                                    final payment = entry.value;
                                    final reference =
                                        payment['reference']?.toString() ?? '';
                                    final notes =
                                        payment['notes']?.toString() ?? '';
                                    final method =
                                        payment['method']?.toString() ?? '';
                                    final createdAt =
                                        payment['created_at']?.toString() ?? '';
                                    String dateStr =
                                        payment['payment_date']
                                            ?.toString()
                                            .split('T')[0] ??
                                        '';
                                    // Formatear hora si existe
                                    String timeStr = '';
                                    if (createdAt.contains('T')) {
                                      try {
                                        final dt = DateTime.parse(createdAt);
                                        timeStr =
                                            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                      } catch (_) {}
                                    }
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                  color: Colors.green[50],
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '${idx + 1}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green[700],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '$dateStr${timeStr.isNotEmpty ? '  $timeStr' : ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[50],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  method.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue[700],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                Formatters.currency(
                                                  payment['amount'] ?? 0,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (reference.isNotEmpty ||
                                              notes.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const SizedBox(width: 30),
                                                if (reference.isNotEmpty) ...[
                                                  Icon(
                                                    Icons.tag,
                                                    size: 12,
                                                    color: Colors.grey[400],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    reference,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ),
                                                ],
                                                if (reference.isNotEmpty &&
                                                    notes.isNotEmpty)
                                                  const SizedBox(width: 12),
                                                if (notes.isNotEmpty) ...[
                                                  Icon(
                                                    Icons.notes,
                                                    size: 12,
                                                    color: Colors.grey[400],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      notes,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[500],
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),

                          // Formulario de pago
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NUEVO ABONO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[500],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: amountController,
                                  decoration: InputDecoration(
                                    labelText: 'Monto a pagar',
                                    border: const OutlineInputBorder(),
                                    prefixText: '\$ ',
                                    suffixIcon: TextButton(
                                      onPressed: () => setDialogState(
                                        () => amountController.text = pending
                                            .toStringAsFixed(2),
                                      ),
                                      child: const Text('Pagar todo'),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                if (loadingAccounts)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                else if (accounts.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.warning,
                                          color: Colors.orange[700],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'No hay cuentas configuradas',
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  DropdownButtonFormField<String>(
                                    value: selectedAccount?.id,
                                    decoration: const InputDecoration(
                                      labelText: 'Cuenta destino',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: accounts
                                        .map(
                                          (account) => DropdownMenuItem(
                                            value: account.id,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  account.type ==
                                                          AccountType.cash
                                                      ? Icons.payments
                                                      : Icons.account_balance,
                                                  size: 18,
                                                  color:
                                                      account.type ==
                                                          AccountType.cash
                                                      ? Colors.green
                                                      : Colors.blue,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(account.name),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setDialogState(() {
                                          selectedAccount = accounts.firstWhere(
                                            (a) => a.id == value,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: referenceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Referencia (opcional)',
                                    border: OutlineInputBorder(),
                                    hintText: 'Ej: Nro. de operación',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Botones (fixed at bottom)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            final amount =
                                double.tryParse(amountController.text) ?? 0;
                            if (amount <= 0 || amount > pending) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Monto inválido'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (selectedAccount == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Seleccione una cuenta destino',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Guardar referencia al ScaffoldMessenger antes de cerrar el diálogo
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );
                            final accountId = selectedAccount!.id;
                            final accountType = selectedAccount!.type;

                            Navigator.pop(context);

                            // Convertir tipo de cuenta a método de pago
                            PaymentMethod method =
                                accountType == AccountType.cash
                                ? PaymentMethod.cash
                                : PaymentMethod.transfer;

                            final success = await ref
                                .read(invoicesProvider.notifier)
                                .registerPayment(
                                  invoice['id'],
                                  amount,
                                  method,
                                  accountId: accountId,
                                );

                            // Forzar refresh de la lista
                            if (success) {
                              await ref
                                  .read(invoicesProvider.notifier)
                                  .refresh();
                            }

                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Pago registrado exitosamente'
                                      : 'Error al registrar pago',
                                ),
                                backgroundColor: success
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmar Abono'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmCancelInvoice(Map<String, dynamic> invoice) {
    final messenger = ScaffoldMessenger.of(context);
    final invoiceId = invoice['id'] as String;
    final invoiceNumber = invoice['number'] ?? '';
    final status = invoice['status'] ?? 'Borrador';
    final paidAmount = (invoice['paid'] as num?)?.toDouble() ?? 0.0;
    final total = (invoice['total'] as num?)?.toDouble() ?? 0.0;

    // ═══════════════════════════════════════════════
    // BLINDAJE 1: Bloquear facturas pagadas/parciales
    // ═══════════════════════════════════════════════
    if (status == 'Pagada' || status == 'Parcial' || paidAmount > 0) {
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock, color: Colors.red[700], size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No se puede anular esta factura',
                            style: TextStyle(
                              color: Colors.red[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'La factura $invoiceNumber tiene pagos registrados '
                      'por \$${paidAmount.toStringAsFixed(2)} de un total de \$${total.toStringAsFixed(2)}.',
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Las facturas con pagos no pueden ser anuladas para '
                      'proteger la integridad contable del sistema.',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Si necesita corregir esta factura, contacte al administrador del sistema.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

    // ═══════════════════════════════════════════════
    // BLINDAJE 2: Factura ya está anulada
    // ═══════════════════════════════════════════════
    if (status == 'Anulada' || status == 'cancelled') {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Esta factura ya está anulada'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ═══════════════════════════════════════════════
    // ANULACIÓN PERMITIDA: Mostrar diálogo con motivo
    // ═══════════════════════════════════════════════
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('Anular Factura'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción anulará la factura $invoiceNumber de forma permanente '
                      'y se registrará en el historial de auditoría.',
                      style: TextStyle(color: Colors.orange[800], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Estado actual: $status  |  Total: \$${total.toStringAsFixed(2)}',
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Debe ingresar un motivo de anulación'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);

              try {
                // Usar anulación segura server-side
                final result = await InvoicesDataSource.secureCancelInvoice(
                  invoiceId,
                  reason: reasonController.text.trim(),
                );

                if (result['success'] == true) {
                  // Refrescar la lista
                  ref.read(invoicesProvider.notifier).refresh();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Factura ${result['invoice_number']} anulada correctamente ✓',
                          ),
                          if (result['inventory_reverted'] == true)
                            Text(
                              '✓ Inventario restaurado (${result['inventory_items']} items)',
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } else if (result['blocked'] == true) {
                  // Fue bloqueada por el servidor
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('🚫 ${result['reason']}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al anular: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
            icon: const Icon(Icons.block, color: Colors.white),
            label: const Text('Anular', style: TextStyle(color: Colors.white)),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _showReceiptPreview(
    Map<String, dynamic> invoice, {
    required bool isClientVersion,
  }) {
    showDialog(
      context: context,
      builder: (context) => _InvoicePreviewDialog(
        invoice: invoice,
        initialTab: isClientVersion ? 0 : 1,
      ),
    );
  }
}

// ============================================
// DIÁLOGO COMPLETO DE DETALLE DE FACTURA
// ============================================
class _InvoiceFullDetailDialog extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onPayment;
  final VoidCallback onCancel;
  final VoidCallback onRefresh;

  const _InvoiceFullDetailDialog({
    required this.invoice,
    required this.onPayment,
    required this.onCancel,
    required this.onRefresh,
  });

  @override
  State<_InvoiceFullDetailDialog> createState() =>
      _InvoiceFullDetailDialogState();
}

class _InvoiceFullDetailDialogState extends State<_InvoiceFullDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPaymentHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentHistory() async {
    try {
      final payments = await InvoicesDataSource.getPayments(
        widget.invoice['id'],
      );
      if (mounted) {
        setState(() {
          _paymentHistory = payments;
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pagada':
        return Colors.green;
      case 'Pendiente':
        return Colors.orange;
      case 'Parcial':
        return Colors.blue;
      case 'Vencida':
        return Colors.red;
      case 'Anulada':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Pagada':
        return Icons.check_circle;
      case 'Pendiente':
        return Icons.schedule;
      case 'Parcial':
        return Icons.timelapse;
      case 'Vencida':
        return Icons.warning;
      case 'Anulada':
        return Icons.block;
      default:
        return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final screenHeight = MediaQuery.of(context).size.height;
    const headerColor = Color(0xFF1e293b);
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final paid = (inv['paid'] as num?)?.toDouble() ?? 0;
    final pending = total - paid;
    final paymentProgress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 1100,
        height: screenHeight * 0.9,
        child: Column(
          children: [
            // ── HEADER COMPACTO ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: headerColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _getStatusIcon(inv['status']),
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        inv['number'],
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
                          color: _getStatusColor(inv['status']),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          inv['status'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Tabs inline
                      _buildHeaderTab('Detalle', Icons.info_outline, 0),
                      _buildHeaderTab('Recibo', Icons.receipt_long, 1),
                      _buildHeaderTab('Empresa', Icons.business, 2),
                      const Spacer(),
                      // Payment progress mini
                      if (inv['status'] != 'Anulada') ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Helpers.formatCurrency(total),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  paid > 0
                                      ? 'Pagado: ${Helpers.formatCurrency(paid)}'
                                      : 'Sin pagos',
                                  style: TextStyle(
                                    color: paid > 0
                                        ? Colors.green[300]
                                        : Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                                if (pending > 0) ...[
                                  Text(
                                    ' • ',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    'Debe: ${Helpers.formatCurrency(pending)}',
                                    style: TextStyle(
                                      color: Colors.orange[300],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
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
                  // Payment progress bar
                  if (inv['status'] != 'Anulada' && total > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: paymentProgress,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          paid >= total
                              ? Colors.green[400]!
                              : Colors.orange[400]!,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // ── CONTENIDO DE TABS ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDetailTab(inv),
                  _buildClientReceiptTab(inv),
                  _buildEnterpriseTab(inv),
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
                    'Emitida: ${Helpers.formatDate(inv['date'])}  •  Vence: ${Helpers.formatDate(inv['dueDate'])}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {
                      PrintService.printInvoice(inv);
                    },
                    icon: Icon(Icons.print, size: 16, color: Colors.blue[600]),
                    label: Text(
                      'Imprimir',
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
                  if (inv['status'] != 'Pagada' && inv['status'] != 'Anulada')
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onPayment();
                      },
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text(
                        'Registrar Pago',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                    ),
                  if (inv['status'] != 'Pagada' && inv['status'] != 'Anulada')
                    const SizedBox(width: 8),
                  if (inv['status'] != 'Anulada' &&
                      inv['status'] != 'Pagada' &&
                      inv['status'] != 'Parcial')
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onCancel();
                      },
                      icon: Icon(Icons.block, size: 16, color: Colors.red[400]),
                      label: Text(
                        'Anular',
                        style: TextStyle(color: Colors.red[400], fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red[300]!),
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
            width: 1,
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

  // ──────────────────────────────────────
  // TAB 1: DETALLE (resumen + pagos)
  // ──────────────────────────────────────
  Widget _buildDetailTab(Map<String, dynamic> inv) {
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final paid = (inv['paid'] as num?)?.toDouble() ?? 0;
    final pending = total - paid;
    final subtotal = (inv['subtotal'] as num?)?.toDouble() ?? 0;
    final tax = (inv['tax'] as num?)?.toDouble() ?? 0;
    final products = inv['products'] as List<dynamic>? ?? [];
    final paymentProgress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      color: const Color(0xFFF1F4F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── COLUMNA IZQUIERDA: Info + Productos ──
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
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.person,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv['customer'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'NIT: ${inv['customerRuc'] ?? 'N/A'}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 13,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  Helpers.formatDate(inv['date']),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.event,
                                  size: 13,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Vence: ${Helpers.formatDate(inv['dueDate'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tabla de productos
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
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.list_alt,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Productos (${products.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${inv['items'] ?? products.length} items',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Header tabla
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: Colors.grey[100],
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Producto',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  'Cant.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  'P. Unit.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...products.map((prod) {
                          final comps =
                              prod['components'] as List<dynamic>? ?? [];
                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[100]!,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            prod['name'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (comps.isNotEmpty)
                                            Text(
                                              '${comps.length} componentes',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        '${prod['quantity']}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        Helpers.formatCurrency(
                                          (prod['unitPrice'] as num?)
                                                  ?.toDouble() ??
                                              0,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        Helpers.formatCurrency(
                                          (prod['total'] as num?)?.toDouble() ??
                                              0,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Sub-componentes
                              ...comps.map(
                                (c) => Container(
                                  padding: const EdgeInsets.only(
                                    left: 32,
                                    right: 16,
                                    top: 5,
                                    bottom: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    border: Border(
                                      bottom: BorderSide(
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
                                      Expanded(
                                        child: Text(
                                          '${c['quantity']}× ${c['name'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                      if ((c['material']
                                              ?.toString()
                                              .isNotEmpty ??
                                          false))
                                        Text(
                                          c['material'].toString(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${Helpers.formatNumber((c['totalWeight'] as num?)?.toDouble() ?? 0)} kg',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        // Totales
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildSummaryRow('Subtotal', subtotal),
                              const SizedBox(height: 4),
                              _buildSummaryRow('IVA (19%)', tax),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Divider(),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TOTAL',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    Helpers.formatCurrency(total),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
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
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note, color: Colors.amber[700], size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NOTAS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[800],
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  inv['notes'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
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
            const SizedBox(width: 20),
            // ── COLUMNA DERECHA: Estado de pago ──
            SizedBox(
              width: 320,
              child: Column(
                children: [
                  // Estado de pago
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              paid >= total
                                  ? Icons.check_circle
                                  : Icons.account_balance_wallet,
                              color: paid >= total
                                  ? Colors.green[600]
                                  : AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Estado de Pago',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Progress circle
                        Center(
                          child: SizedBox(
                            width: 120,
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: CircularProgressIndicator(
                                    value: paymentProgress,
                                    strokeWidth: 10,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      paid >= total
                                          ? Colors.green[500]!
                                          : Colors.orange[400]!,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(paymentProgress * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: paid >= total
                                            ? Colors.green[700]
                                            : Colors.orange[700],
                                      ),
                                    ),
                                    Text(
                                      'pagado',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Desglose
                        _buildPaymentInfoRow(
                          'Total',
                          total,
                          AppTheme.primaryColor,
                          Icons.receipt,
                        ),
                        const SizedBox(height: 8),
                        _buildPaymentInfoRow(
                          'Pagado',
                          paid,
                          Colors.green[600]!,
                          Icons.check_circle_outline,
                        ),
                        const SizedBox(height: 8),
                        _buildPaymentInfoRow(
                          'Pendiente',
                          pending,
                          pending > 0
                              ? Colors.orange[600]!
                              : Colors.green[600]!,
                          Icons.hourglass_empty,
                        ),
                        if (inv['paymentMethod'] != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.payment,
                                  size: 14,
                                  color: Colors.blue[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Método: ${inv['paymentMethod']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Botón registrar pago
                        if (inv['status'] != 'Pagada' &&
                            inv['status'] != 'Anulada') ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onPayment();
                              },
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 18,
                              ),
                              label: const Text('Registrar Pago / Abono'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Historial de pagos
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Historial de Pagos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_loadingHistory)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (_paymentHistory.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.hourglass_empty,
                                  color: Colors.grey[300],
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sin pagos registrados',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._paymentHistory.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final payment = entry.value;
                            final amount =
                                (payment['amount'] as num?)?.toDouble() ?? 0;
                            final date =
                                payment['payment_date']?.toString().split(
                                  'T',
                                )[0] ??
                                '';
                            final method = payment['method']?.toString() ?? '';
                            final reference =
                                payment['reference']?.toString() ?? '';
                            final notes = payment['notes']?.toString() ?? '';
                            final createdAt =
                                payment['created_at']?.toString() ?? '';
                            String timeStr = '';
                            if (createdAt.contains('T')) {
                              try {
                                final dt = DateTime.parse(createdAt);
                                timeStr =
                                    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                              } catch (_) {}
                            }
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green[100]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${idx + 1}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    date,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey[700],
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (timeStr.isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    timeStr,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[50],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    method.isNotEmpty
                                                        ? method.toUpperCase()
                                                        : 'PAGO',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.blue[700],
                                                    ),
                                                  ),
                                                ),
                                                if (reference.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.tag,
                                                    size: 12,
                                                    color: Colors.grey[400],
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Flexible(
                                                    child: Text(
                                                      reference,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[500],
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        Helpers.formatCurrency(amount),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[700],
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (notes.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      margin: const EdgeInsets.only(left: 42),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.notes,
                                            size: 13,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              notes,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        if (_paymentHistory.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total abonado',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  Helpers.formatCurrency(
                                    _paymentHistory.fold(
                                      0.0,
                                      (sum, p) =>
                                          sum +
                                          ((p['amount'] as num?)?.toDouble() ??
                                              0),
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoRow(
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        Text(
          Helpers.formatCurrency(amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(
          Helpers.formatCurrency(value),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ──────────────────────────────────────
  // TAB 2: RECIBO CLIENTE
  // ──────────────────────────────────────
  Widget _buildClientReceiptTab(Map<String, dynamic> inv) {
    final products = inv['products'] as List<dynamic>? ?? [];
    const headerColor = Color(0xFF1e293b);
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final paid = (inv['paid'] as num?)?.toDouble() ?? 0;
    final subtotal = (inv['subtotal'] as num?)?.toDouble() ?? 0;
    final tax = (inv['tax'] as num?)?.toDouble() ?? 0;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          margin: const EdgeInsets.all(24),
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
              // Barra de acento
              Container(
                width: double.infinity,
                height: 6,
                decoration: const BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
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
                                      size: 36,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'RECIBO DE CAJA',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF111418),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '#${inv['number']}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
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
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Industrial de Molinos',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                'NIT: 901946675-1',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Cliente
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
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
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[400],
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    inv['customer'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111418),
                                    ),
                                  ),
                                  Text(
                                    'NIT/CC: ${inv['customerRuc'] ?? 'N/A'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildDateInfo(
                                  'Fecha:',
                                  Helpers.formatDate(inv['date']),
                                ),
                                const SizedBox(height: 6),
                                _buildDateInfo(
                                  'Vence:',
                                  Helpers.formatDate(inv['dueDate']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Tabla
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Descripción',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text(
                                      'Cant.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      'P. Unit.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...products.map(
                              (prod) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
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
                                      child: Text(
                                        prod['name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        '${prod['quantity']}',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        Helpers.formatCurrency(
                                          (prod['unitPrice'] as num?)
                                                  ?.toDouble() ??
                                              0,
                                        ),
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        Helpers.formatCurrency(
                                          (prod['total'] as num?)?.toDouble() ??
                                              0,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
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
                      const SizedBox(height: 32),
                      // Totales
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 300,
                            child: Column(
                              children: [
                                _buildSummaryRow('Subtotal', subtotal),
                                const SizedBox(height: 4),
                                _buildSummaryRow('IVA (19%)', tax),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
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
                                      Helpers.formatCurrency(total),
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: headerColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (paid > 0) ...[
                                  const SizedBox(height: 12),
                                  _buildPaymentSummaryRow(
                                    'Pagado',
                                    paid,
                                    Colors.green[600]!,
                                  ),
                                ],
                                if (total - paid > 0) ...[
                                  const SizedBox(height: 4),
                                  _buildPaymentSummaryRow(
                                    'Pendiente',
                                    total - paid,
                                    Colors.orange[600]!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Footer
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email,
                              size: 18,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'industriasdemolinosasfact@gmail.com',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '¡GRACIAS POR SU COMPRA!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
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

  Widget _buildDateInfo(String label, String value) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildPaymentSummaryRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          Helpers.formatCurrency(value),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────
  // TAB 3: VISTA EMPRESA
  // ──────────────────────────────────────
  Widget _buildEnterpriseTab(Map<String, dynamic> inv) {
    final products = inv['products'] as List<dynamic>? ?? [];
    final subtotal = (inv['subtotal'] as num?)?.toDouble() ?? 0;
    final tax = (inv['tax'] as num?)?.toDouble() ?? 0;
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final paid = (inv['paid'] as num?)?.toDouble() ?? 0;

    double totalCost = 0;
    for (var prod in products) {
      final qty = (prod['quantity'] as num?)?.toDouble() ?? 1;
      final costPrice =
          (prod['costPrice'] as num?)?.toDouble() ??
          (prod['unitCostPrice'] as num?)?.toDouble() ??
          0;
      totalCost += costPrice * qty;
    }
    final totalProfit = subtotal - totalCost;
    final profitMargin = totalCost > 0 ? ((totalProfit / totalCost) * 100) : 0;

    return Container(
      color: const Color(0xFFF1F4F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'lib/photo/logo_empresa.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.deepOrange,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.business,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DOCUMENTO INTERNO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          inv['number'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: Colors.orange[800],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'USO INTERNO',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Stats cards
            Row(
              children: [
                _buildMiniStat(
                  'Subtotal',
                  Helpers.formatCurrency(subtotal),
                  Icons.inventory_2,
                  Colors.blue,
                ),
                const SizedBox(width: 10),
                _buildMiniStat(
                  'IVA',
                  Helpers.formatCurrency(tax),
                  Icons.receipt,
                  Colors.purple,
                ),
                const SizedBox(width: 10),
                _buildMiniStat(
                  'Total',
                  Helpers.formatCurrency(total),
                  Icons.payments,
                  AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                _buildMiniStat(
                  'Pagado',
                  Helpers.formatCurrency(paid),
                  Icons.check_circle,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Cliente
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv['customer'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'NIT: ${inv['customerRuc'] ?? 'N/A'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(inv['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      inv['status'],
                      style: TextStyle(
                        color: _getStatusColor(inv['status']),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Detalle de productos con métricas
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.list_alt,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Detalle con Costos',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${products.length} items',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...products.map((prod) => _buildProductMetricsRow(prod)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Análisis financiero
            Container(
              padding: const EdgeInsets.all(16),
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
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Análisis Financiero',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (totalCost > 0) ...[
                    _buildFinanceSection('COSTOS', Colors.red, [
                      _buildFinanceLine(
                        'Costo de productos',
                        totalCost,
                        Colors.red,
                      ),
                    ]),
                    const SizedBox(height: 10),
                  ],
                  _buildFinanceSection('VENTAS', Colors.green, [
                    _buildFinanceLine(
                      'Subtotal productos',
                      subtotal,
                      Colors.green,
                    ),
                    _buildFinanceLine('IVA (19%)', tax, Colors.purple),
                  ]),
                  if (totalCost > 0) ...[
                    const SizedBox(height: 10),
                    _buildFinanceSection('GANANCIAS', Colors.blue, [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ganancia Neta',
                            style: TextStyle(fontSize: 13),
                          ),
                          Text(
                            Helpers.formatCurrency(totalProfit),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: totalProfit >= 0
                                  ? Colors.blue[700]
                                  : Colors.red[700],
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Markup', style: TextStyle(fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: profitMargin >= 0
                                  ? Colors.purple[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${profitMargin.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: profitMargin >= 0
                                    ? Colors.purple[700]
                                    : Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  // Total grande
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.08),
                          AppTheme.primaryColor.withOpacity(0.03),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.payments,
                              size: 22,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'TOTAL RECIBO',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          Helpers.formatCurrency(total),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Estado de pago
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: paid >= total
                          ? Colors.green[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              paid >= total
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: paid >= total
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pagado: ${Helpers.formatCurrency(paid)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (total - paid > 0)
                          Text(
                            'Pendiente: ${Helpers.formatCurrency(total - paid)}',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
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
    );
  }

  Widget _buildMiniStat(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductMetricsRow(Map<String, dynamic> prod) {
    final quantity = (prod['quantity'] as num?)?.toDouble() ?? 1;
    final total = (prod['total'] as num?)?.toDouble() ?? 0;
    final unitPrice =
        (prod['unitPrice'] as num?)?.toDouble() ?? (total / quantity);
    final costPrice =
        (prod['costPrice'] as num?)?.toDouble() ??
        (prod['unitCostPrice'] as num?)?.toDouble() ??
        0;
    final totalCost = costPrice * quantity;
    final profit = total - totalCost;
    final profitPct = totalCost > 0 ? ((profit / totalCost) * 100) : 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${prod['quantity']}×',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  prod['name'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                Helpers.formatCurrency(total),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          if (costPrice > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  _buildMetricChip(
                    'Costo',
                    Helpers.formatCurrency(costPrice),
                    Colors.orange,
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  _buildMetricChip(
                    'Venta',
                    Helpers.formatCurrency(unitPrice),
                    Colors.green,
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey[300],
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  _buildMetricChip(
                    'Ganancia',
                    '${Helpers.formatCurrency(profit)} (${profitPct.toStringAsFixed(0)}%)',
                    profit >= 0 ? Colors.blue : Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 11,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildFinanceSection(
    String title,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                title == 'COSTOS'
                    ? Icons.shopping_cart
                    : title == 'VENTAS'
                    ? Icons.sell
                    : Icons.trending_up,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFinanceLine(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ),
          Text(
            Helpers.formatCurrency(value),
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ============================================
// DIÁLOGO DE PREVISUALIZACIÓN DE RECIBO DE CAJA MENOR
// ============================================
class _InvoicePreviewDialog extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final int initialTab;

  const _InvoicePreviewDialog({required this.invoice, this.initialTab = 0});

  @override
  State<_InvoicePreviewDialog> createState() => _InvoicePreviewDialogState();
}

class _InvoicePreviewDialogState extends State<_InvoicePreviewDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pagada':
        return Colors.green;
      case 'Pendiente':
        return Colors.orange;
      case 'Parcial':
        return Colors.blue;
      case 'Vencida':
        return Colors.red;
      case 'Anulada':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
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
                  const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vista Previa del Recibo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(inv['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      inv['status'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                  _buildTab('Recibo Cliente', Icons.person, 0),
                  const SizedBox(width: 8),
                  _buildTab('Recibo Empresa', Icons.business, 1),
                ],
              ),
            ),
            // Contenido de tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildClientView(inv), _buildEnterpriseView(inv)],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fecha: ${Helpers.formatDate(inv['date'])}  •  Vence: ${Helpers.formatDate(inv['dueDate'])}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildFooterButton(
                        'Imprimir',
                        Icons.print,
                        Colors.blue[600]!,
                        () {
                          PrintService.printInvoice(widget.invoice);
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildFooterButton(
                        'Enviar',
                        Icons.email,
                        Colors.green[600]!,
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enviando por correo...'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1e293b),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
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
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white60,
              size: 18,
            ),
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

  Widget _buildFooterButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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
  // RECIBO CLIENTE - Diseño compacto moderno
  // ==========================================
  Widget _buildClientView(Map<String, dynamic> inv) {
    final products = inv['products'] as List<dynamic>? ?? [];
    const headerColor = Color(0xFF1e293b);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Barra de acento superior
              Container(
                width: double.infinity,
                height: 4,
                decoration: const BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
              // Contenido con scroll
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
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
                                      size: 28,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'RECIBO DE CAJA',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF111418),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  inv['number'],
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
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
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
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
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Industrial de Molinos',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                              const Text(
                                'NIT: 901946675-1',
                                style: TextStyle(
                                  fontSize: 10,
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
                                    inv['customer'],
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111418),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'NIT/CC: ${inv['customerRuc'] ?? 'N/A'}',
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
                                  Helpers.formatDate(inv['date']),
                                ),
                                const SizedBox(height: 8),
                                _buildDateRow(
                                  'Vence:',
                                  Helpers.formatDate(inv['dueDate']),
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
                            ...products.map(
                              (prod) => Container(
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
                                      child: Text(
                                        prod['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        '${prod['quantity']}',
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
                                        '\$${Helpers.formatNumber(prod['total'])}',
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
                                _buildTotalRow('Subtotal', inv['subtotal']),
                                _buildTotalRow('IVA (19%)', inv['tax']),
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
                                      '\$${Helpers.formatNumber(inv['total'])}',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: headerColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if ((inv['paid'] as double) > 0) ...[
                                  const SizedBox(height: 16),
                                  _buildTotalRow(
                                    'Pagado',
                                    inv['paid'],
                                    color: Colors.green[600],
                                  ),
                                ],
                                if ((inv['total'] as double) -
                                        (inv['paid'] as double) >
                                    0) ...[
                                  const SizedBox(height: 8),
                                  _buildTotalRow(
                                    'Pendiente',
                                    (inv['total'] as double) -
                                        (inv['paid'] as double),
                                    color: Colors.orange[600],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Nota de agradecimiento
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email,
                              size: 20,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'industriasdemolinosasfact@gmail.com',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[700],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '¡GRACIAS POR SU COMPRA!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
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

  Widget _buildTotalRow(String label, double value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: color ?? Colors.grey[600], fontSize: 14),
          ),
          Text(
            '\$${Helpers.formatNumber(value)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // RECIBO EMPRESA - ERP Style con detalles
  // ==========================================
  Widget _buildEnterpriseView(Map<String, dynamic> inv) {
    final products = inv['products'] as List<dynamic>? ?? [];
    final subtotal = (inv['subtotal'] as num?)?.toDouble() ?? 0;
    final tax = (inv['tax'] as num?)?.toDouble() ?? 0;
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final paid = (inv['paid'] as num?)?.toDouble() ?? 0;

    // Calcular costo total de productos
    double totalCost = 0;
    for (var prod in products) {
      final qty = (prod['quantity'] as num?)?.toDouble() ?? 1;
      final costPrice =
          (prod['costPrice'] as num?)?.toDouble() ??
          (prod['unitCostPrice'] as num?)?.toDouble() ??
          0;
      totalCost += costPrice * qty;
    }
    final totalProfit = subtotal - totalCost;
    final profitMargin = totalCost > 0 ? ((totalProfit / totalCost) * 100) : 0;

    return Container(
      color: const Color(0xFFF1F4F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con información y badges
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'lib/photo/logo_empresa.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.deepOrange,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.business,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DOCUMENTO INTERNO',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111418),
                          ),
                        ),
                        Text(
                          inv['number'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: Colors.orange[800],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'USO INTERNO',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tarjetas de resumen rápido
            Row(
              children: [
                _buildStatCard(
                  'Subtotal',
                  '\$${Helpers.formatNumber(subtotal)}',
                  Icons.inventory_2,
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'IVA (19%)',
                  '\$${Helpers.formatNumber(tax)}',
                  Icons.receipt,
                  Colors.purple,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Total',
                  '\$${Helpers.formatNumber(total)}',
                  Icons.payments,
                  AppTheme.primaryColor,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Pagado',
                  '\$${Helpers.formatNumber(paid)}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Información del cliente
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.grey[400]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CLIENTE',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inv['customer'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'NIT: ${inv['customerRuc'] ?? 'N/A'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(inv['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      inv['status'],
                      style: TextStyle(
                        color: _getStatusColor(inv['status']),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Detalle de productos
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.list_alt, color: AppTheme.primaryColor),
                        const SizedBox(width: 10),
                        const Text(
                          'Detalle de Productos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${products.length} producto(s)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Items
                  ...products.map((prod) => _buildProductDetailRow(prod)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Resumen financiero moderno con análisis de ganancias
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined),
                      const SizedBox(width: 10),
                      const Text(
                        'Análisis Financiero',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Sección de Costos
                  if (totalCost > 0) ...[
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
                          _buildCostLine(
                            'Costo de productos',
                            totalCost,
                            Colors.red,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                        _buildCostLine(
                          'Subtotal productos',
                          subtotal,
                          Colors.green,
                        ),
                        _buildCostLine('IVA (19%)', tax, Colors.purple),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Sección de Ganancias
                  if (totalCost > 0) ...[
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Ganancia Neta'),
                              Text(
                                Helpers.formatCurrency(totalProfit),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: totalProfit >= 0
                                      ? Colors.blue[700]
                                      : Colors.red[700],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Markup'),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: profitMargin >= 0
                                      ? Colors.purple[100]
                                      : Colors.red[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${profitMargin.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: profitMargin >= 0
                                        ? Colors.purple[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Total
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.1),
                          AppTheme.primaryColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.payments, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'TOTAL RECIBO',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          Helpers.formatCurrency(total),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Estado de pago
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: paid >= total
                          ? Colors.green[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              paid >= total
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color: paid >= total
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pagado: ${Helpers.formatCurrency(paid)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (total - paid > 0)
                          Text(
                            'Pendiente: ${Helpers.formatCurrency(total - paid)}',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, color: Colors.amber[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOTAS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            inv['notes'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
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
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetailRow(Map<String, dynamic> prod) {
    // Obtener precios de costo y venta
    final quantity = (prod['quantity'] as num?)?.toDouble() ?? 1;
    final total = (prod['total'] as num?)?.toDouble() ?? 0;
    final unitPrice =
        (prod['unitPrice'] as num?)?.toDouble() ?? (total / quantity);
    final costPrice =
        (prod['costPrice'] as num?)?.toDouble() ??
        (prod['unitCostPrice'] as num?)?.toDouble() ??
        0;
    final totalWeight = (prod['totalWeight'] as num?)?.toDouble() ?? quantity;

    // Calcular precios por kg si hay peso
    final salePerKg = totalWeight > 0 ? total / totalWeight : unitPrice;
    final costPerKg = totalWeight > 0 && costPrice > 0
        ? (costPrice * quantity) / totalWeight
        : costPrice;

    // Calcular ganancia
    final totalCost = costPrice * quantity;
    final profit = total - totalCost;
    final profitMargin = totalCost > 0 ? ((profit / totalCost) * 100) : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          // Fila principal: nombre y total
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${prod['quantity']}×',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prod['name'] ?? 'Producto',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (prod['type'] != null || totalWeight > 0)
                      Text(
                        '${prod['type'] ?? ''} ${totalWeight > 0 ? '• ${Helpers.formatNumber(totalWeight)} kg' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Helpers.formatCurrency(total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Total Venta',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
          // Fila de métricas detalladas
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
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
                        costPerKg > 0 ? Helpers.formatCurrency(costPerKg) : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Compra/kg',
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 35, color: Colors.grey[300]),
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
                        Helpers.formatCurrency(salePerKg),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Venta/kg',
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 35, color: Colors.grey[300]),
                // Ganancia
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 16,
                        color: profit >= 0 ? Colors.blue[700] : Colors.red[700],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        costPrice > 0
                            ? '${Helpers.formatCurrency(profit)} (${profitMargin.toStringAsFixed(1)}%)'
                            : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: profit >= 0
                              ? Colors.blue[700]
                              : Colors.red[700],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Ganancia',
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 35, color: Colors.grey[300]),
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
                        costPrice > 0 ? Helpers.formatCurrency(totalCost) : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[700],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Costo Total',
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostLine(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
          Text(
            '\$${Helpers.formatNumber(value)}',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
