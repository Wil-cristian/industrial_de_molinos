import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/providers/analytics_provider.dart';

class CustomerHistoryPage extends ConsumerStatefulWidget {
  final String customerId;

  const CustomerHistoryPage({super.key, required this.customerId});

  @override
  ConsumerState<CustomerHistoryPage> createState() =>
      _CustomerHistoryPageState();
}

class _CustomerHistoryPageState extends ConsumerState<CustomerHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(symbol: '\$ ', decimalDigits: 2);
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Cargar datos del cliente
    Future.microtask(() {
      ref
          .read(customerHistoryProvider.notifier)
          .loadCustomerHistory(widget.customerId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/customers'),
        ),
        title: Text(state.metrics?.name ?? 'Historial de Cliente'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Resumen'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Compras'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Productos'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref
                .read(customerHistoryProvider.notifier)
                .loadCustomerHistory(widget.customerId),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Error: ${state.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(customerHistoryProvider.notifier)
                            .loadCustomerHistory(widget.customerId),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSummaryTab(state),
                    _buildPurchasesTab(state),
                    _buildProductsTab(state),
                  ],
                ),
    );
  }

  // ============================================================
  // TAB 1: RESUMEN
  // ============================================================
  Widget _buildSummaryTab(CustomerHistoryState state) {
    final metrics = state.metrics;
    final clv = state.clv;

    if (metrics == null) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de información básica
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Text(
                          metrics.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                              fontSize: 24, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metrics.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (metrics.documentNumber != null)
                              Text(
                                'Doc: ${metrics.documentNumber}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            _buildStatusChip(metrics.activityStatus),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Cliente desde',
                      metrics.customerSince != null
                          ? _dateFormat.format(metrics.customerSince!)
                          : '-'),
                  _buildInfoRow('Última compra',
                      metrics.lastPurchaseDate != null
                          ? _dateFormat.format(metrics.lastPurchaseDate!)
                          : 'Sin compras'),
                  _buildInfoRow('Días sin comprar',
                      metrics.daysSinceLastPurchase?.toString() ?? '-'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // KPIs principales
          Text('Métricas de Compra',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  'Total Compras',
                  metrics.totalPurchases.toString(),
                  Icons.shopping_cart,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiCard(
                  'Total Gastado',
                  _currencyFormat.format(metrics.totalSpent),
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  'Ticket Promedio',
                  _currencyFormat.format(metrics.averageTicket),
                  Icons.receipt,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildKpiCard(
                  'Deuda Actual',
                  _currencyFormat.format(metrics.debt),
                  Icons.account_balance_wallet,
                  metrics.debt > 0 ? Colors.red : Colors.grey,
                ),
              ),
            ],
          ),

          // CLV si está disponible
          if (clv != null) ...[
            const SizedBox(height: 24),
            Text('Valor del Cliente (CLV)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              color: Colors.indigo[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildClvMetric('Meses como cliente',
                            clv.monthsAsCustomer.toString()),
                        _buildClvMetric('Ingreso mensual',
                            _currencyFormat.format(clv.monthlyRevenue)),
                        _buildClvMetric('Valor anual estimado',
                            _currencyFormat.format(clv.estimatedAnnualValue)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Límite de crédito
          const SizedBox(height: 24),
          Text('Crédito', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow('Límite de crédito',
                      _currencyFormat.format(metrics.creditLimit)),
                  _buildInfoRow(
                      'Utilizado', _currencyFormat.format(metrics.debt)),
                  _buildInfoRow('Disponible',
                      _currencyFormat.format(metrics.creditLimit - metrics.debt)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: metrics.creditLimit > 0
                        ? (metrics.debt / metrics.creditLimit).clamp(0, 1)
                        : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      metrics.debt / metrics.creditLimit > 0.8
                          ? Colors.red
                          : Colors.green,
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

  // ============================================================
  // TAB 2: HISTORIAL DE COMPRAS
  // ============================================================
  Widget _buildPurchasesTab(CustomerHistoryState state) {
    final purchasesByInvoice = state.purchasesByInvoice;

    if (purchasesByInvoice.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay compras registradas'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: purchasesByInvoice.length,
      itemBuilder: (context, index) {
        final invoiceId = purchasesByInvoice.keys.elementAt(index);
        final items = purchasesByInvoice[invoiceId]!;
        final firstItem = items.first;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(firstItem.invoiceStatus),
              child: const Icon(Icons.receipt, color: Colors.white, size: 20),
            ),
            title: Text(
              firstItem.invoiceNumber ?? 'Sin número',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (firstItem.issueDate != null)
                  Text(_dateFormat.format(firstItem.issueDate!)),
                Text(
                  _currencyFormat.format(firstItem.invoiceTotal ?? 0),
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: _buildStatusChip(firstItem.invoiceStatus ?? 'pending'),
            children: [
              const Divider(height: 1),
              ...items.map((item) => ListTile(
                    dense: true,
                    title: Text(item.productName ?? 'Producto'),
                    subtitle: Text(item.productCode ?? ''),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${item.quantity ?? 0} x ${_currencyFormat.format(item.unitPrice ?? 0)}'),
                        Text(
                          _currencyFormat.format(item.itemTotal ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // TAB 3: PRODUCTOS COMPRADOS
  // ============================================================
  Widget _buildProductsTab(CustomerHistoryState state) {
    final products = state.productAnalysis;

    if (products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay productos comprados'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              product.productName ?? 'Producto',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.productCode != null)
                  Text('Código: ${product.productCode}'),
                Text(
                  'Comprado ${product.purchaseCount} veces',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Row(
                  children: [
                    Icon(Icons.date_range, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Primera: ${product.firstPurchase != null ? _dateFormat.format(product.firstPurchase!) : '-'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Última: ${product.lastPurchase != null ? _dateFormat.format(product.lastPurchase!) : '-'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFormat.format(product.totalSpent),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  'Qty: ${product.totalQuantity.toStringAsFixed(1)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _buildKpiCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildClvMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.indigo,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'activo':
      case 'issued':
      case 'paid':
        color = Colors.green;
        label = status;
        break;
      case 'regular':
      case 'pending':
        color = Colors.orange;
        label = status;
        break;
      case 'inactivo':
      case 'cancelled':
        color = Colors.red;
        label = status;
        break;
      case 'nuevo':
      case 'draft':
        color = Colors.blue;
        label = status;
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Chip(
      label: Text(
        label,
        style: TextStyle(color: color, fontSize: 11),
      ),
      backgroundColor: color.withOpacity(0.1),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'issued':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
