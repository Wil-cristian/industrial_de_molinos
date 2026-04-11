import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/helpers.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/account.dart';
import '../../data/providers/invoices_provider.dart';
import '../../data/datasources/invoices_datasource.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/providers/composite_products_provider.dart';
import '../../core/utils/print_service.dart';
import '../widgets/sale_invoice_scan_dialog.dart';
import '../../core/responsive/responsive_helper.dart';
import '../../core/utils/colombia_time.dart';

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
  String _selectedPaymentType = 'Todos';
  DateTimeRange? _dateRange;

  // Los datos vienen del provider
  List<Map<String, dynamic>> get _invoices {
    final state = ref.watch(invoicesProvider);
    return state.invoices
        .map(
          (inv) => {
            'id': inv.id,
            'series': inv.series,
            'number': '${inv.series}-${inv.number}',
            'customer': inv.customerName,
            'customerId': inv.customerId,
            'customerRuc': inv.customerDocument,
            'date': inv.issueDate,
            'dueDate': inv.dueDate,
            'deliveryDate': inv.deliveryDate,
            'items': inv.items.length,
            'subtotal': inv.subtotal,
            'tax': inv.taxAmount,
            'discount': inv.discount,
            'total': inv.total,
            'paid': inv.paidAmount,
            'status': _mapStatus(inv.status),
            'paymentMethod': inv.paymentMethod?.name,
            'salePaymentType': inv.salePaymentType,
            'laborCost': inv.laborCost,
            'notes': inv.notes,
            'products': inv.items
                .map(
                  (item) => {
                    'itemId': item.id,
                    'invoiceId': item.invoiceId,
                    'name': item.productName,
                    'quantity': item.quantity,
                    'unit': item.unit,
                    'unitPrice': item.unitPrice,
                    'discount': item.discount,
                    'taxRate': item.taxRate,
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

      bool matchesPaymentType = true;
      if (_selectedPaymentType != 'Todos') {
        matchesPaymentType = invoice['salePaymentType'] == _selectedPaymentType;
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

      return matchesSearch &&
          matchesStatus &&
          matchesPaymentType &&
          matchesDate;
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
    final isMobile = ResponsiveHelper.isMobile(context);
    final hasActiveFilters =
        _selectedStatus != 'Todos' ||
        _selectedPaymentType != 'Todos' ||
        _dateRange != null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      floatingActionButton: isMobile
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton(
                heroTag: 'invoices',
                onPressed: () => context.go('/invoices/new'),
                child: const Icon(Icons.add),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 6 : 8,
              ),
              color: Theme.of(context).colorScheme.surface,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 980;

                  if (isMobile) {
                    // ── Mobile header: título + stats arriba, búsqueda + iconos abajo ──
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título y stats
                        Row(
                          children: [
                            Text(
                              'Recibos',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            _buildQuickStat(
                              '',
                              Formatters.currency(_totalVentas),
                              const Color(0xFF1565C0),
                              Icons.trending_up,
                            ),
                            const SizedBox(width: 4),
                            _buildQuickStat(
                              '',
                              Formatters.currency(_totalPendiente),
                              const Color(0xFFF9A825),
                              Icons.schedule,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Búsqueda + filtros + acciones
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  onChanged: (value) =>
                                      setState(() => _searchQuery = value),
                                  decoration: InputDecoration(
                                    hintText: 'Buscar...',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLowest,
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
                            Badge(
                              isLabelVisible: hasActiveFilters,
                              smallSize: 8,
                              child: IconButton(
                                icon: const Icon(Icons.filter_list, size: 22),
                                onPressed: () =>
                                    _showMobileFiltersSheet(context),
                                tooltip: 'Filtros',
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.receipt_long,
                                size: 20,
                                color: Color(0xFFE65100),
                              ),
                              onPressed: () async {
                                final created =
                                    await SaleInvoiceScanDialog.show(context);
                                if (created == true) {
                                  ref.read(invoicesProvider.notifier).refresh();
                                }
                              },
                              tooltip: 'Reconciliar',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  // ── Desktop/Tablet header (original) ──
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Recibos de Caja',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          _buildQuickStat(
                            'Ventas',
                            Formatters.currency(_totalVentas),
                            const Color(0xFF1565C0),
                            Icons.trending_up,
                          ),
                          _buildQuickStat(
                            'Cobrado',
                            Formatters.currency(_totalCobrado),
                            const Color(0xFF2E7D32),
                            Icons.check_circle,
                          ),
                          _buildQuickStat(
                            'Pendiente',
                            Formatters.currency(_totalPendiente),
                            const Color(0xFFF9A825),
                            Icons.schedule,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: isNarrow ? constraints.maxWidth : 260,
                            height: 36,
                            child: TextField(
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              decoration: InputDecoration(
                                hintText: 'Buscar...',
                                prefixIcon: const Icon(Icons.search, size: 18),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                  ),
                                ),
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLowest,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          _buildFilterDropdown(
                            _selectedStatus,
                            [
                              'Todos',
                              'Pagada',
                              'Pendiente',
                              'Parcial',
                              'Vencida',
                              'Anulada',
                            ],
                            (v) => setState(() => _selectedStatus = v!),
                          ),
                          _buildPaymentTypeDropdown(),
                          SizedBox(
                            height: 36,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final range = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: ColombiaTime.now().add(
                                    const Duration(days: 365),
                                  ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                            ),
                          ),
                          if (_dateRange != null)
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                onPressed: () =>
                                    setState(() => _dateRange = null),
                                tooltip: 'Limpiar',
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          SizedBox(
                            height: 36,
                            child: FilledButton.icon(
                              onPressed: () async {
                                final created =
                                    await SaleInvoiceScanDialog.show(context);
                                if (created == true) {
                                  ref.read(invoicesProvider.notifier).refresh();
                                }
                              },
                              icon: const Icon(Icons.receipt_long, size: 16),
                              label: const Text(
                                'Reconciliar Deudas',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE65100),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 36,
                            child: FilledButton.icon(
                              onPressed: () => context.go('/invoices/new'),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'Nuevo',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            // Lista de recibos
            Expanded(child: _buildInvoicesList(_filteredInvoices)),
          ],
        ),
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
                style: TextStyle(
                  fontSize: 8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay documentos',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Los documentos emitidos aparecerán aquí',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final isMobile = ResponsiveHelper.isMobile(context);

    if (isMobile) {
      // ── Mobile: Card list ──
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: invoices.length,
        itemBuilder: (context, index) => _buildInvoiceCard(invoices[index]),
      );
    }

    // ── Desktop/Tablet: DataTable ──
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerLowest,
                ),
                dataRowMinHeight: 60,
                dataRowMaxHeight: 70,
                columnSpacing: MediaQuery.of(context).size.width < 600
                    ? 12
                    : 24,
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
      ),
    );
  }

  // ── Mobile invoice card ──────────────────────────────────────────
  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    Color statusColor;
    IconData statusIcon;
    switch (invoice['status']) {
      case 'Pagada':
        statusColor = const Color(0xFF2E7D32);
        statusIcon = Icons.check_circle;
        break;
      case 'Pendiente':
        statusColor = const Color(0xFFF9A825);
        statusIcon = Icons.schedule;
        break;
      case 'Parcial':
        statusColor = const Color(0xFF1565C0);
        statusIcon = Icons.pie_chart;
        break;
      case 'Vencida':
        statusColor = const Color(0xFFC62828);
        statusIcon = Icons.warning;
        break;
      case 'Anulada':
        statusColor = const Color(0xFF9E9E9E);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFF9E9E9E);
        statusIcon = Icons.help;
    }

    final total = invoice['total'] as double;
    final paid = invoice['paid'] as double;
    final pending = total - paid;
    final saleType = invoice['salePaymentType'] as String?;
    final typeColor = _paymentTypeColor(saleType);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showInvoiceDetails(invoice),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: number + status + menu
              Row(
                children: [
                  Text(
                    invoice['number'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _paymentTypeIcon(saleType),
                          size: 10,
                          color: typeColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _paymentTypeLabel(saleType),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 3),
                        Text(
                          invoice['status'],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    padding: EdgeInsets.zero,
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
                      if (invoice['status'] != 'Pagada' &&
                          invoice['status'] != 'Anulada')
                        PopupMenuItem(
                          value: 'payment',
                          child: Row(
                            children: [
                              Icon(
                                Icons.payment,
                                size: 18,
                                color: AppColors.success,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Registrar pago',
                                style: TextStyle(color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      if (invoice['status'] != 'Anulada')
                        PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              Icon(
                                Icons.cancel,
                                size: 18,
                                color: AppColors.danger,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Anular',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Customer
              Text(
                invoice['customer'] ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Bottom: date + total + paid
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Formatters.date(invoice['date']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.currency(total),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (pending > 0 && invoice['status'] != 'Pagada')
                        Text(
                          'Debe: ${Formatters.currency(pending)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (paid > 0 && invoice['status'] != 'Pagada')
                        Text(
                          'Pagado: ${Formatters.currency(paid)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mobile filters bottom sheet ──────────────────────────────────
  void _showMobileFiltersSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String tempStatus = _selectedStatus;
        String tempPaymentType = _selectedPaymentType;
        DateTimeRange? tempDateRange = _dateRange;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Filtros',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempStatus = 'Todos';
                            tempPaymentType = 'Todos';
                            tempDateRange = null;
                          });
                        },
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Estado',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        [
                          'Todos',
                          'Pagada',
                          'Pendiente',
                          'Parcial',
                          'Vencida',
                          'Anulada',
                        ].map((s) {
                          final selected = tempStatus == s;
                          return FilterChip(
                            label: Text(s, style: TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (_) =>
                                setSheetState(() => tempStatus = s),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tipo de Pago',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        [
                          ('Todos', 'Todos'),
                          ('cash', 'Contado'),
                          ('credit', 'Crédito'),
                          ('advance', 'Adelanto'),
                        ].map((e) {
                          final selected = tempPaymentType == e.$1;
                          return FilterChip(
                            label: Text(e.$2, style: TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (_) =>
                                setSheetState(() => tempPaymentType = e.$1),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Fecha',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (tempDateRange != null)
                        Text(
                          '${Formatters.date(tempDateRange!.start)} - ${Formatters.date(tempDateRange!.end)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: ColombiaTime.now().add(
                              const Duration(days: 365),
                            ),
                            initialDateRange: tempDateRange,
                          );
                          if (range != null) {
                            setSheetState(() => tempDateRange = range);
                          }
                        },
                        child: Text(
                          tempDateRange == null ? 'Seleccionar' : 'Cambiar',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _selectedStatus = tempStatus;
                          _selectedPaymentType = tempPaymentType;
                          _dateRange = tempDateRange;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Aplicar Filtros'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Desktop filter dropdown helper ───────────────────────────────
  Widget _buildFilterDropdown(
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      height: 36,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            items: items
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentTypeDropdown() {
    return SizedBox(
      height: 36,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedPaymentType,
            isDense: true,
            items: [
              DropdownMenuItem(
                value: 'Todos',
                child: Text(
                  'Tipo: Todos',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              DropdownMenuItem(
                value: 'cash',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.payments,
                      size: 14,
                      color: const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 4),
                    Text('Contado', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'credit',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 14,
                      color: const Color(0xFFF9A825),
                    ),
                    const SizedBox(width: 4),
                    Text('Crédito', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              DropdownMenuItem(
                value: 'advance',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.savings,
                      size: 14,
                      color: const Color(0xFF7B1FA2),
                    ),
                    const SizedBox(width: 4),
                    Text('Adelanto', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedPaymentType = value!),
          ),
        ),
      ),
    );
  }

  String _paymentTypeLabel(String? type) {
    switch (type) {
      case 'advance':
        return 'Adelanto';
      case 'credit':
        return 'Crédito';
      default:
        return 'Contado';
    }
  }

  Color _paymentTypeColor(String? type) {
    switch (type) {
      case 'advance':
        return const Color(0xFF7B1FA2);
      case 'credit':
        return const Color(0xFFF9A825);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  IconData _paymentTypeIcon(String? type) {
    switch (type) {
      case 'advance':
        return Icons.savings;
      case 'credit':
        return Icons.calendar_month;
      default:
        return Icons.payments;
    }
  }

  DataRow _buildInvoiceRow(Map<String, dynamic> invoice) {
    Color statusColor;
    IconData statusIcon;
    switch (invoice['status']) {
      case 'Pagada':
        statusColor = const Color(0xFF2E7D32);
        statusIcon = Icons.check_circle;
        break;
      case 'Pendiente':
        statusColor = const Color(0xFFF9A825);
        statusIcon = Icons.schedule;
        break;
      case 'Parcial':
        statusColor = const Color(0xFF1565C0);
        statusIcon = Icons.pie_chart;
        break;
      case 'Vencida':
        statusColor = const Color(0xFFC62828);
        statusIcon = Icons.warning;
        break;
      case 'Anulada':
        statusColor = const Color(0xFF9E9E9E);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFF9E9E9E);
        statusIcon = Icons.help;
    }

    final total = invoice['total'] as double;
    final paid = invoice['paid'] as double;
    final pending = total - paid;
    final saleType = invoice['salePaymentType'] as String?;
    final typeColor = _paymentTypeColor(saleType);

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${invoice['items']} items',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _paymentTypeIcon(saleType),
                          size: 10,
                          color: typeColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _paymentTypeLabel(saleType),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                              ColombiaTime.now(),
                            ) &&
                            invoice['status'] != 'Pagada'
                        ? const Color(0xFFC62828)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                )
              : Text(
                  '-',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
                  color: paid > 0
                      ? AppColors.success
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (pending > 0)
                Text(
                  'Debe: ${Formatters.currency(pending)}',
                  style: TextStyle(fontSize: 11, color: AppColors.warning),
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
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
                      Icon(Icons.payment, size: 18, color: AppColors.success),
                      SizedBox(width: 8),
                      Text(
                        'Registrar pago',
                        style: TextStyle(color: AppColors.success),
                      ),
                    ],
                  ),
                ),
              ],
              if (invoice['status'] != 'Anulada') ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, size: 18, color: AppColors.danger),
                      SizedBox(width: 8),
                      Text('Anular', style: TextStyle(color: AppColors.danger)),
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
            backgroundColor: AppColors.info,
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
            insetPadding: MediaQuery.of(context).size.width < 600
                ? const EdgeInsets.all(16)
                : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: Container(
              width: MediaQuery.of(context).size.width < 600
                  ? double.maxFinite
                  : 480,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height < 700
                    ? MediaQuery.of(context).size.height * 0.85
                    : 600,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.payment,
                            color: AppColors.success,
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                                bottom: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer,
                                ),
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
                                        color: AppColors.success,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      Formatters.currency(paid),
                                      style: TextStyle(
                                        color: AppColors.success,
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
                                        color: AppColors.warning,
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLowest,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                                  ),
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.success.withOpacity(
                                            0.2,
                                          ),
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
                                                  color: const Color(
                                                    0xFFE8F5E9,
                                                  ),
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
                                                      color: AppColors.success,
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
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface,
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
                                                  color: const Color(
                                                    0xFFE3F2FD,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  method.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.info,
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
                                                  color: AppColors.success,
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
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    reference,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
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
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      notes,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                                      color: const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFFFCC80),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.warning,
                                          color: AppColors.warning,
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
                                                      ? const Color(0xFF2E7D32)
                                                      : const Color(0xFF1565C0),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
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
                                  backgroundColor: AppColors.danger,
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
                                  backgroundColor: AppColors.danger,
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
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                            );
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Confirmar Abono'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
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
    final hasPagos = paidAmount > 0;

    // ═══════════════════════════════════════════════
    // Factura ya está anulada
    // ═══════════════════════════════════════════════
    if (status == 'Anulada' || status == 'cancelled') {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Esta factura ya está anulada'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // ═══════════════════════════════════════════════
    // ANULACIÓN: Mostrar diálogo con motivo obligatorio
    // ═══════════════════════════════════════════════
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.block, color: AppColors.danger, size: 28),
            const SizedBox(width: 12),
            const Text('Anular Factura'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Advertencia de pagos si aplica
              if (hasPagos) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.danger.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.payments,
                            color: AppColors.danger,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Esta factura tiene pagos registrados',
                              style: TextStyle(
                                color: const Color(0xFFC62828),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pagado: \$${paidAmount.toStringAsFixed(2)} de \$${total.toStringAsFixed(2)}',
                        style: TextStyle(color: AppColors.danger, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Al anular, los pagos serán revertidos automáticamente y se registrará en auditoría.',
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.onSurface,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Advertencia general
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta acción anulará la factura $invoiceNumber de forma permanente '
                        'y se registrará en el historial de auditoría.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Estado actual: $status  |  Total: \$${total.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
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
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext);

              try {
                final result = await InvoicesDataSource.secureCancelInvoice(
                  invoiceId,
                  reason: reasonController.text.trim(),
                );

                if (result['success'] == true) {
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
                          if (result['payments_reverted'] != null &&
                              (result['payments_reverted'] as num) > 0)
                            Text(
                              '✓ ${result['payments_reverted']} pago(s) revertido(s) por \$${result['payment_total_reverted']}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          if (result['inventory_reverted'] == true)
                            Text(
                              '✓ Inventario restaurado (${result['inventory_items']} items)',
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                } else if (result['blocked'] == true) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${result['reason']}'),
                      backgroundColor: AppColors.danger,
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Error al anular: $e'),
                    backgroundColor: AppColors.danger,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
            icon: const Icon(Icons.block, color: Colors.white),
            label: const Text('Anular', style: TextStyle(color: Colors.white)),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

// ============================================
// DIÁLOGO COMPLETO DE DETALLE DE FACTURA
// ============================================
class _InvoiceFullDetailDialog extends ConsumerStatefulWidget {
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
  ConsumerState<_InvoiceFullDetailDialog> createState() =>
      _InvoiceFullDetailDialogState();
}

class _InvoiceFullDetailDialogState
    extends ConsumerState<_InvoiceFullDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _loadingHistory = true;
  final GlobalKey _receiptKey = GlobalKey();

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
        return AppColors.success;
      case 'Pendiente':
        return AppColors.warning;
      case 'Parcial':
        return AppColors.info;
      case 'Vencida':
        return AppColors.danger;
      case 'Anulada':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF9E9E9E);
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
      insetPadding: MediaQuery.of(context).size.width < 600
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SizedBox(
        width: MediaQuery.of(context).size.width < 600
            ? double.maxFinite
            : 1100,
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
                        color: Theme.of(context).colorScheme.surface,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        inv['number'],
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(inv['status']),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          inv['status'],
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.surface,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tipo de pago badge
                      Builder(
                        builder: (context) {
                          final saleType =
                              inv['salePaymentType'] as String? ?? 'cash';
                          String label;
                          Color color;
                          IconData icon;
                          switch (saleType) {
                            case 'advance':
                              label = 'Adelanto';
                              color = const Color(0xFF7B1FA2);
                              icon = Icons.savings;
                              break;
                            case 'credit':
                              label = 'Crédito';
                              color = const Color(0xFFF9A825);
                              icon = Icons.calendar_month;
                              break;
                            default:
                              label = 'Contado';
                              color = const Color(0xFF2E7D32);
                              icon = Icons.payments;
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 12, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      // Tabs inline
                      _buildHeaderTab('Detalle', Icons.info_outline, 0),
                      _buildHeaderTab('Recibo', Icons.receipt_long, 1),
                      _buildHeaderTab('Empresa', Icons.business, 2),
                      Spacer(),
                      // Payment progress mini
                      if (inv['status'] != 'Anulada') ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Helpers.formatCurrency(total),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.surface,
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
                                        ? AppColors.success.withOpacity(0.5)
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
                                      color: AppColors.warning.withOpacity(0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                      SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.surface,
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
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          paid >= total ? AppColors.success : AppColors.warning,
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
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Emitida: ${Helpers.formatDate(inv['date'])}  •  Vence: ${Helpers.formatDate(inv['dueDate'])}${inv['deliveryDate'] != null ? '  •  Entrega: ${Helpers.formatDate(inv['deliveryDate'])}' : ''}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {
                      if (_tabController.index == 1) {
                        _printReceiptScreenshot();
                      } else {
                        PrintService.printInvoice(inv);
                      }
                    },
                    icon: Icon(Icons.print, size: 16, color: AppColors.info),
                    label: Text(
                      'Imprimir',
                      style: TextStyle(color: AppColors.info, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.info.withOpacity(0.5)),
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
                        backgroundColor: AppColors.success,
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
                      icon: Icon(
                        Icons.block,
                        size: 16,
                        color: AppColors.danger,
                      ),
                      label: Text(
                        'Anular',
                        style: TextStyle(color: AppColors.danger, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.danger.withOpacity(0.5),
                        ),
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
              ? Theme.of(context).colorScheme.surface.withOpacity(0.15)
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
    final discount = (inv['discount'] as num?)?.toDouble() ?? 0;
    final laborCostDetail = (inv['laborCost'] as num?)?.toDouble() ?? 0;
    final products = inv['products'] as List<dynamic>? ?? [];
    final paymentProgress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    final isDraft = inv['status'] == 'Borrador';

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
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withOpacity(0.04),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.person,
                            color: Theme.of(context).colorScheme.primary,
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  Helpers.formatDate(inv['date']),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Vence: ${Helpers.formatDate(inv['dueDate'])}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withOpacity(0.04),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.list_alt,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Producto',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                              if (isDraft)
                                const SizedBox(
                                  width: 110,
                                  child: Text(
                                    'Acciones',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerLow,
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
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
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
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
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
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
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
                                    if (isDraft)
                                      SizedBox(
                                        width: 110,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _ItemActionButton(
                                              icon: Icons.edit,
                                              tooltip: 'Editar',
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              onPressed: () =>
                                                  _showEditItemDialog(prod),
                                            ),
                                            _ItemActionButton(
                                              icon: Icons.call_split,
                                              tooltip: 'Dividir',
                                              color: const Color(0xFFF9A825),
                                              onPressed:
                                                  (prod['quantity'] as num?)
                                                              ?.toDouble() !=
                                                          null &&
                                                      ((prod['quantity']
                                                                      as num?)
                                                                  ?.toDouble() ??
                                                              0) >
                                                          1
                                                  ? () => _showSplitItemDialog(
                                                      prod,
                                                    )
                                                  : null,
                                            ),
                                            _ItemActionButton(
                                              icon: Icons.delete,
                                              tooltip: 'Eliminar',
                                              color: const Color(0xFFC62828),
                                              onPressed: () =>
                                                  _confirmDeleteItem(prod),
                                            ),
                                          ],
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLowest,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerLow,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.subdirectory_arrow_right,
                                        size: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${c['quantity']}× ${c['name'] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
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
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${Helpers.formatNumber((c['totalWeight'] as num?)?.toDouble() ?? 0)} kg',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildSummaryRow('Subtotal', subtotal),
                              if (laborCostDetail > 0) ...[
                                const SizedBox(height: 4),
                                _buildSummaryRow(
                                  'Mano de Obra',
                                  laborCostDetail,
                                ),
                              ],
                              if (discount > 0) ...[
                                const SizedBox(height: 4),
                                _buildSummaryRow(
                                  'Descuento',
                                  -discount,
                                  isDiscount: true,
                                ),
                              ],
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note, color: AppColors.warning, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NOTAS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFF9A825),
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  inv['notes'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
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
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withOpacity(0.04),
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
                                  ? AppColors.success
                                  : Theme.of(context).colorScheme.primary,
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
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainer,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      paid >= total
                                          ? const Color(0xFF4CAF50)
                                          : AppColors.warning,
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
                                            ? AppColors.success
                                            : AppColors.warning,
                                      ),
                                    ),
                                    Text(
                                      'pagado',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
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
                          Theme.of(context).colorScheme.primary,
                          Icons.receipt,
                        ),
                        const SizedBox(height: 8),
                        _buildPaymentInfoRow(
                          'Pagado',
                          paid,
                          AppColors.success,
                          Icons.check_circle_outline,
                        ),
                        const SizedBox(height: 8),
                        _buildPaymentInfoRow(
                          'Pendiente',
                          pending,
                          pending > 0 ? AppColors.warning : AppColors.success,
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
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.payment,
                                  size: 14,
                                  color: AppColors.info,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Método: ${inv['paymentMethod']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.info,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Tipo de venta
                        ..._buildSalePaymentTypeInfo(inv['salePaymentType']),
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
                                backgroundColor: AppColors.success,
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
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withOpacity(0.04),
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
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.hourglass_empty,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sin pagos registrados',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.15),
                                ),
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
                                          color: AppColors.success.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${idx + 1}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.success,
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
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.onSurface,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (timeStr.isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    timeStr,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
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
                                                    color: const Color(
                                                      0xFFE3F2FD,
                                                    ),
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
                                                      color: AppColors.info,
                                                    ),
                                                  ),
                                                ),
                                                if (reference.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.tag,
                                                    size: 12,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Flexible(
                                                    child: Text(
                                                      reference,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
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
                                          color: AppColors.success,
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerLowest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.notes,
                                            size: 13,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              notes,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
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
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total abonado',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                                    color: AppColors.success,
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

  List<Widget> _buildSalePaymentTypeInfo(String? saleType) {
    String label;
    Color color;
    IconData icon;
    switch (saleType) {
      case 'advance':
        label = 'Adelanto';
        color = const Color(0xFF7B1FA2);
        icon = Icons.savings;
        break;
      case 'credit':
        label = 'Crédito';
        color = const Color(0xFFF9A825);
        icon = Icons.calendar_month;
        break;
      default:
        label = 'Contado';
        color = const Color(0xFF2E7D32);
        icon = Icons.payments;
    }

    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              'Tipo: $label',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ];
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
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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

  Widget _buildSummaryRow(
    String label,
    double value, {
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDiscount
                ? Colors.red.shade700
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          Helpers.formatCurrency(value),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDiscount ? Colors.red.shade700 : null,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────
  // TAB 2: RECIBO CLIENTE
  // ──────────────────────────────────────
  Future<void> _printReceiptScreenshot() async {
    try {
      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      await Printing.layoutPdf(
        onLayout: (_) async {
          final pdf = pw.Document();
          final pdfImage = pw.MemoryImage(pngBytes);
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.letter,
              margin: const pw.EdgeInsets.all(20),
              build: (context) =>
                  pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
            ),
          );
          return pdf.save();
        },
        name: 'Recibo_${widget.invoice['number'] ?? 'SN'}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al imprimir: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Widget _buildClientReceiptTab(Map<String, dynamic> inv) {
    final products = inv['products'] as List<dynamic>? ?? [];
    const headerColor = Color(0xFF1e293b);
    final total = (inv['total'] as num?)?.toDouble() ?? 0;
    final paid = (inv['paid'] as num?)?.toDouble() ?? 0;
    final subtotal = (inv['subtotal'] as num?)?.toDouble() ?? 0;
    final tax = (inv['tax'] as num?)?.toDouble() ?? 0;
    final discount = (inv['discount'] as num?)?.toDouble() ?? 0;
    final laborCost = (inv['laborCost'] as num?)?.toDouble() ?? 0;

    return RepaintBoundary(
      key: _receiptKey,
      child: Container(
        color: const Color(0xFFF8FAFC),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
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
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
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
                                        size: 26,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'RECIBO DE CAJA',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF111418),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '#${inv['number']}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
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
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.shadow.withOpacity(0.1),
                                        blurRadius: 10,
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
                                        child: Icon(
                                          Icons.precision_manufacturing,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Industrial de Molinos',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                                const Text(
                                  'NIT: 901946675-1',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF9E9E9E),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Cliente
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                            ),
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
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      inv['customer'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111418),
                                      ),
                                    ),
                                    Text(
                                      'NIT/CC: ${inv['customerRuc'] ?? 'N/A'}',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 11,
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
                                  if (inv['deliveryDate'] != null) ...[
                                    const SizedBox(height: 6),
                                    _buildDateInfo(
                                      'Entrega:',
                                      Helpers.formatDate(inv['deliveryDate']),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Tabla
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
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
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF9E9E9E),
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
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        'P. Unit.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        'Total',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
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
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerLow,
                                      ),
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
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          '${prod['quantity']}',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: Text(
                                          Helpers.formatCurrency(
                                            (prod['unitPrice'] as num?)
                                                    ?.toDouble() ??
                                                0,
                                          ),
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                            fontSize: 11,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: Text(
                                          Helpers.formatCurrency(
                                            (prod['total'] as num?)
                                                    ?.toDouble() ??
                                                0,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
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
                        const SizedBox(height: 16),
                        // Totales
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 280,
                              child: Column(
                                children: [
                                  _buildSummaryRow('Subtotal', subtotal),
                                  if (laborCost > 0) ...[
                                    const SizedBox(height: 4),
                                    _buildSummaryRow('Mano de Obra', laborCost),
                                  ],
                                  if (discount > 0) ...[
                                    const SizedBox(height: 4),
                                    _buildSummaryRow(
                                      'Descuento',
                                      -discount,
                                      isDiscount: true,
                                    ),
                                  ],
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
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        Helpers.formatCurrency(total),
                                        style: TextStyle(
                                          fontSize: 20,
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
                                      AppColors.success,
                                    ),
                                  ],
                                  if (total - paid > 0) ...[
                                    const SizedBox(height: 4),
                                    _buildPaymentSummaryRow(
                                      'Pendiente',
                                      total - paid,
                                      AppColors.warning,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Footer
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.email,
                                size: 14,
                                color: AppColors.info,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'industriasdemolinosasfact@gmail.com',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.info,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '¡GRACIAS POR SU COMPRA!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.info,
                                  fontSize: 10,
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
      ),
    );
  }

  Widget _buildDateInfo(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
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
    final discount = (inv['discount'] as num?)?.toDouble() ?? 0;

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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.04),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withOpacity(0.08),
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
                                const Color(0xFFFFA726),
                                const Color(0xFFFF5722),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.business,
                            color: Theme.of(context).colorScheme.surface,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                      color: AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 12,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'USO INTERNO',
                          style: TextStyle(
                            color: AppColors.warning,
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
                  const Color(0xFF1565C0),
                ),
                const SizedBox(width: 10),
                _buildMiniStat(
                  'IVA',
                  Helpers.formatCurrency(tax),
                  Icons.receipt,
                  const Color(0xFF7B1FA2),
                ),
                const SizedBox(width: 10),
                _buildMiniStat(
                  'Total',
                  Helpers.formatCurrency(total),
                  Icons.payments,
                  Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                _buildMiniStat(
                  'Pagado',
                  Helpers.formatCurrency(paid),
                  Icons.check_circle,
                  const Color(0xFF2E7D32),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Cliente
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.04),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.list_alt,
                          color: Theme.of(context).colorScheme.primary,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.04),
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
                    _buildFinanceSection('COSTOS', const Color(0xFFC62828), [
                      _buildFinanceLine(
                        'Costo de productos',
                        totalCost,
                        const Color(0xFFC62828),
                      ),
                    ]),
                    const SizedBox(height: 10),
                  ],
                  _buildFinanceSection('VENTAS', const Color(0xFF2E7D32), [
                    _buildFinanceLine(
                      'Subtotal productos',
                      subtotal,
                      const Color(0xFF2E7D32),
                    ),
                    if (discount > 0)
                      _buildFinanceLine(
                        'Descuento',
                        -discount,
                        AppColors.danger,
                      ),
                    _buildFinanceLine(
                      'IVA (19%)',
                      tax,
                      const Color(0xFF7B1FA2),
                    ),
                  ]),
                  if (totalCost > 0) ...[
                    const SizedBox(height: 10),
                    _buildFinanceSection('GANANCIAS', const Color(0xFF1565C0), [
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
                                  ? AppColors.info
                                  : AppColors.danger,
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
                                  ? const Color(0xFFE1BEE7)
                                  : AppColors.danger.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${profitMargin.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: profitMargin >= 0
                                    ? const Color(0xFF7B1FA2)
                                    : AppColors.danger,
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
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.primaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primaryContainer,
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
                              color: Theme.of(context).colorScheme.primary,
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
                            color: Theme.of(context).colorScheme.primary,
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
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
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
                                  ? AppColors.success
                                  : AppColors.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pagado: ${Helpers.formatCurrency(paid)}',
                              style: TextStyle(
                                color: AppColors.success,
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
                              color: AppColors.warning,
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.04),
              blurRadius: 6,
            ),
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
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${prod['quantity']}×',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
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
                  color: Theme.of(context).colorScheme.primary,
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
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  _buildMetricChip(
                    'Costo',
                    Helpers.formatCurrency(costPrice),
                    const Color(0xFFF9A825),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Theme.of(context).colorScheme.outlineVariant,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  _buildMetricChip(
                    'Venta',
                    Helpers.formatCurrency(unitPrice),
                    const Color(0xFF2E7D32),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Theme.of(context).colorScheme.outlineVariant,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  _buildMetricChip(
                    'Ganancia',
                    '${Helpers.formatCurrency(profit)} (${profitPct.toStringAsFixed(0)}%)',
                    profit >= 0
                        ? const Color(0xFF1565C0)
                        : const Color(0xFFC62828),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
              ),
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

  // ── Item actions (edit / split / delete) ───────────────────────────

  void _showEditItemDialog(Map<String, dynamic> prod) {
    final itemId = (prod['itemId'] ?? '').toString();
    final invoiceId = (prod['invoiceId'] ?? '').toString();
    if (itemId.isEmpty || invoiceId.isEmpty) return;

    final qtyCtrl = TextEditingController(
      text: ((prod['quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
    );
    final priceCtrl = TextEditingController(
      text: ((prod['unitPrice'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Editar: ${prod['name'] ?? 'Ítem'}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cantidad (${prod['unit'] ?? 'UND'})',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio Unitario (\$)',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF43A047).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal:'),
                      Text(
                        Helpers.formatCurrency(
                          (double.tryParse(qtyCtrl.text) ?? 0) *
                              (double.tryParse(priceCtrl.text) ?? 0),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final qty = double.tryParse(qtyCtrl.text) ?? 0;
                final price = double.tryParse(priceCtrl.text) ?? 0;
                if (qty <= 0 || price <= 0) return;
                final taxRate = (prod['taxRate'] as num?)?.toDouble() ?? 0;
                final sub = qty * price;
                final tax = sub * taxRate;
                final disc = (prod['discount'] as num?)?.toDouble() ?? 0;
                final item = InvoiceItem(
                  id: itemId,
                  invoiceId: invoiceId,
                  productName: (prod['name'] ?? '').toString(),
                  quantity: qty,
                  unitPrice: price,
                  discount: disc,
                  taxRate: taxRate,
                  subtotal: sub,
                  taxAmount: tax,
                  total: sub + tax - disc,
                );
                final ok = await ref
                    .read(invoicesProvider.notifier)
                    .updateItem(item);
                if (!mounted) return;
                if (ok) {
                  widget.onRefresh();
                  Navigator.pop(context); // close detail dialog
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error al actualizar ítem'),
                      backgroundColor: Color(0xFFC62828),
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSplitItemDialog(Map<String, dynamic> prod) {
    final itemId = (prod['itemId'] ?? '').toString();
    final invoiceId = (prod['invoiceId'] ?? '').toString();
    if (itemId.isEmpty || invoiceId.isEmpty) return;

    final totalQty = (prod['quantity'] as num?)?.toDouble() ?? 0;
    final keepCtrl = TextEditingController(
      text: (totalQty / 2).toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final keepQty = double.tryParse(keepCtrl.text) ?? 0;
          final remainQty = totalQty - keepQty;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.call_split, color: Color(0xFFF9A825)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dividir: ${prod['name'] ?? 'Ítem'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Cantidad total: ${totalQty.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: keepCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad en ítem original',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9A825).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Ítem 1:'),
                            Text(
                              keepQty.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Ítem 2 (nuevo):'),
                            Text(
                              remainQty.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: remainQty > 0
                                    ? const Color(0xFF43A047)
                                    : const Color(0xFFC62828),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: keepQty > 0 && remainQty > 0
                    ? () async {
                        Navigator.pop(ctx);
                        final ok = await ref
                            .read(invoicesProvider.notifier)
                            .splitItem(itemId, invoiceId, keepQty);
                        if (!mounted) return;
                        if (ok) {
                          widget.onRefresh();
                          Navigator.pop(context);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error al dividir ítem'),
                              backgroundColor: Color(0xFFC62828),
                            ),
                          );
                        }
                      }
                    : null,
                child: const Text('Dividir'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteItem(Map<String, dynamic> prod) {
    final itemId = (prod['itemId'] ?? '').toString();
    final invoiceId = (prod['invoiceId'] ?? '').toString();
    if (itemId.isEmpty || invoiceId.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar ítem'),
        content: Text(
          '¿Eliminar "${prod['name'] ?? 'este ítem'}" de la factura?',
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
              final ok = await ref
                  .read(invoicesProvider.notifier)
                  .deleteItem(itemId, invoiceId);
              if (!mounted) return;
              if (ok) {
                widget.onRefresh();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al eliminar ítem'),
                    backgroundColor: Color(0xFFC62828),
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _ItemActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  const _ItemActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 16,
            color: onPressed != null ? color : color.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}

// ============================================
// DIÁLOGO DE PREVISUALIZACIÓN DE RECIBO DE CAJA MENOR
// ============================================
class _InvoicePreviewDialog extends StatefulWidget {
  final Map<String, dynamic> invoice;

  const _InvoicePreviewDialog({required this.invoice});

  @override
  State<_InvoicePreviewDialog> createState() => _InvoicePreviewDialogState();
}

class _InvoicePreviewDialogState extends State<_InvoicePreviewDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pagada':
        return AppColors.success;
      case 'Pendiente':
        return AppColors.warning;
      case 'Parcial':
        return AppColors.info;
      case 'Vencida':
        return AppColors.danger;
      case 'Anulada':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final screenHeight = MediaQuery.of(context).size.height;
    const headerColor = Color(0xFF1e293b);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: MediaQuery.of(context).size.width < 600
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SizedBox(
        width: MediaQuery.of(context).size.width < 600
            ? double.maxFinite
            : 1100,
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
                  Icon(
                    Icons.receipt_long,
                    color: Theme.of(context).colorScheme.surface,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vista Previa del Recibo',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.surface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(inv['status']),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      inv['status'],
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Fecha: ${Helpers.formatDate(inv['date'])}  •  Vence: ${Helpers.formatDate(inv['dueDate'])}${inv['deliveryDate'] != null ? '  •  Entrega: ${Helpers.formatDate(inv['deliveryDate'])}' : ''}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildFooterButton(
                        'Imprimir',
                        Icons.print,
                        AppColors.info,
                        () {
                          PrintService.printInvoice(widget.invoice);
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildFooterButton(
                        'Enviar',
                        Icons.email,
                        AppColors.success,
                        () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enviando por correo...'),
                              backgroundColor: AppColors.success,
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
    final discount = (inv['discount'] as num?)?.toDouble() ?? 0;
    const headerColor = Color(0xFF1e293b);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.shadow.withOpacity(0.1),
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
                                      child: Icon(
                                        Icons.precision_manufacturing,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface,
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
                                  color: Color(0xFF9E9E9E),
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
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                          ),
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
                                if (inv['deliveryDate'] != null) ...[
                                  const SizedBox(height: 8),
                                  _buildDateRow(
                                    'Entrega:',
                                    Helpers.formatDate(inv['deliveryDate']),
                                  ),
                                ],
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
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                          ),
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
                                        color: Color(0xFF9E9E9E),
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
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
                                    top: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerLow,
                                    ),
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
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
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
                                if (discount > 0)
                                  _buildTotalRow(
                                    'Descuento',
                                    -discount,
                                    color: AppColors.danger,
                                  ),
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
                                    color: AppColors.success,
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
                                    color: AppColors.warning,
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
                            Icon(Icons.email, size: 20, color: AppColors.info),
                            const SizedBox(width: 12),
                            Text(
                              'industriasdemolinosasfact@gmail.com',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.info,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '¡GRACIAS POR SU COMPRA!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.info,
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
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
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
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
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
    final discount = (inv['discount'] as num?)?.toDouble() ?? 0;

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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.05),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withOpacity(0.1),
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
                                const Color(0xFFFFA726),
                                const Color(0xFFFF5722),
                              ],
                            ),
                          ),
                          child: Icon(
                            Icons.business,
                            color: Theme.of(context).colorScheme.surface,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                      color: AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'USO INTERNO',
                          style: TextStyle(
                            color: AppColors.warning,
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
                  const Color(0xFF1565C0),
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'IVA (19%)',
                  '\$${Helpers.formatNumber(tax)}',
                  Icons.receipt,
                  const Color(0xFF7B1FA2),
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Total',
                  '\$${Helpers.formatNumber(total)}',
                  Icons.payments,
                  Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Pagado',
                  '\$${Helpers.formatNumber(paid)}',
                  Icons.check_circle,
                  const Color(0xFF2E7D32),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Información del cliente
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CLIENTE',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.05),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.list_alt,
                          color: Theme.of(context).colorScheme.primary,
                        ),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.05),
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
                        color: const Color(0xFFFFEBEE),
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
                                color: AppColors.danger,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'COSTOS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.danger,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildCostLine(
                            'Costo de productos',
                            totalCost,
                            const Color(0xFFC62828),
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
                      color: const Color(0xFFE8F5E9),
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
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'VENTAS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.success,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildCostLine(
                          'Subtotal productos',
                          subtotal,
                          const Color(0xFF2E7D32),
                        ),
                        if (discount > 0)
                          _buildCostLine(
                            'Descuento',
                            -discount,
                            AppColors.danger,
                          ),
                        _buildCostLine(
                          'IVA (19%)',
                          tax,
                          const Color(0xFF7B1FA2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Sección de Ganancias
                  if (totalCost > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
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
                                color: AppColors.info,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'GANANCIAS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.info,
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
                                      ? AppColors.info
                                      : AppColors.danger,
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
                                      ? const Color(0xFFE1BEE7)
                                      : AppColors.danger.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${profitMargin.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: profitMargin >= 0
                                        ? const Color(0xFF7B1FA2)
                                        : AppColors.danger,
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
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.primaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primaryContainer,
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
                            color: Theme.of(context).colorScheme.primary,
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
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
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
                                  ? AppColors.success
                                  : AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pagado: ${Helpers.formatCurrency(paid)}',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (total - paid > 0)
                          Text(
                            'Pendiente: ${Helpers.formatCurrency(total - paid)}',
                            style: TextStyle(
                              color: AppColors.warning,
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
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, color: AppColors.warning, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NOTAS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF9A825),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            inv['notes'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
              blurRadius: 10,
            ),
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
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.surfaceContainer,
          ),
        ),
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
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '${prod['quantity']}×',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Total Venta',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
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
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        costPerKg > 0 ? Helpers.formatCurrency(costPerKg) : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Compra/kg',
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 35,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                // Venta/kg
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        Icons.sell_outlined,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Helpers.formatCurrency(salePerKg),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Venta/kg',
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 35,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                // Ganancia
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 16,
                        color: profit >= 0 ? AppColors.info : AppColors.danger,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        costPrice > 0
                            ? '${Helpers.formatCurrency(profit)} (${profitMargin.toStringAsFixed(1)}%)'
                            : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: profit >= 0
                              ? AppColors.info
                              : AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Ganancia',
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 35,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                // Costo Total
                Expanded(
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        costPrice > 0 ? Helpers.formatCurrency(totalCost) : '-',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Costo Total',
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
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
