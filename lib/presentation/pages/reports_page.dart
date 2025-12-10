import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/reports_provider.dart';
import '../../data/datasources/reports_datasource.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String _selectedReport = 'Ventas';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(salesReportProvider.notifier).loadSalesReport();
      ref.read(inventoryReportProvider.notifier).loadInventoryReport();
      ref.read(receivablesReportProvider.notifier).loadReceivablesReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    final salesState = ref.watch(salesReportProvider);
    final inventoryState = ref.watch(inventoryReportProvider);
    final receivablesState = ref.watch(receivablesReportProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          Container(
            width: 280,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                            onPressed: () => context.go('/'),
                            tooltip: 'Volver al menu',
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Reportes',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Analisis y estadisticas',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildReportCategory('Ventas', Icons.trending_up, [
                        'Ventas por Periodo',
                        'Ventas por Producto',
                        'Ventas por Cliente',
                        'Productos mas Vendidos',
                      ]),
                      _buildReportCategory('Inventario', Icons.inventory_2, [
                        'Stock Actual',
                        'Valorizacion de Inventario',
                      ]),
                      _buildReportCategory('Cuentas por Cobrar', Icons.account_balance_wallet, [
                        'Cartera de Clientes',
                        'Antiguedad de Saldos',
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildMainContent(salesState, inventoryState, receivablesState),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCategory(String title, IconData icon, List<String> reports) {
    final isSelected = _selectedReport == title;
    
    return ExpansionTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryColor : Colors.black87,
        ),
      ),
      initiallyExpanded: isSelected,
      children: reports.map((report) => ListTile(
        contentPadding: const EdgeInsets.only(left: 56, right: 16),
        title: Text(report, style: const TextStyle(fontSize: 14)),
        dense: true,
        onTap: () => setState(() => _selectedReport = title),
      )).toList(),
    );
  }

  Widget _buildMainContent(SalesReportState salesState, InventoryReportState inventoryState, ReceivablesReportState receivablesState) {
    if (salesState.isLoading || inventoryState.isLoading || receivablesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (salesState.error != null) {
      return Center(child: Text('Error: ${salesState.error}', style: const TextStyle(color: Colors.red)));
    }
    
    switch (_selectedReport) {
      case 'Ventas':
        return _buildSalesReport(salesState);
      case 'Inventario':
        return _buildInventoryReport(inventoryState);
      case 'Cuentas por Cobrar':
        return _buildReceivablesReport(receivablesState);
      default:
        return _buildSalesReport(salesState);
    }
  }

  Widget _buildSalesReport(SalesReportState state) {
    final stats = state.stats;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reporte de Ventas',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ref.read(salesReportProvider.notifier).loadSalesReport(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exportacion proximamente')),
                    ),
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Exportar', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildKPICard('Ventas Totales', Helpers.formatCurrency(stats?.totalSales ?? 0), Icons.attach_money, Colors.green, '${stats?.transactionCount ?? 0} transacciones'),
              const SizedBox(width: 16),
              _buildKPICard('Ticket Promedio', Helpers.formatCurrency(stats?.averageTicket ?? 0), Icons.receipt, Colors.blue, 'por recibo'),
              const SizedBox(width: 16),
              _buildKPICard('Margen Bruto', '${(stats?.grossMargin ?? 0).toStringAsFixed(1)}%', Icons.trending_up, Colors.orange, 'rentabilidad'),
              const SizedBox(width: 16),
              _buildKPICard('Crecimiento', '${(stats?.growthPercentage ?? 0).toStringAsFixed(1)}%', Icons.show_chart, 
                (stats?.growthPercentage ?? 0) >= 0 ? Colors.green : Colors.red, 
                'vs periodo anterior'),
            ],
          ),
          const SizedBox(height: 24),
          _buildSalesChart(state),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTopProductsCard(state)),
              const SizedBox(width: 16),
              Expanded(child: _buildSalesByCustomerCard(state)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart(SalesReportState state) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Evolucion de Ventas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              _buildChartLegend('Actual', Colors.blue),
              const SizedBox(width: 16),
              _buildChartLegend('Anterior', Colors.grey),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: state.chartData.isEmpty
                ? const Center(child: Text('No hay datos de ventas por periodo'))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: state.chartData.map((e) => e.currentValue > e.previousValue ? e.currentValue : e.previousValue).reduce((a, b) => a > b ? a : b) * 1.2,
                      barGroups: state.chartData.asMap().entries.map((entry) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.currentValue,
                              color: Colors.blue,
                              width: 12,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            BarChartRodData(
                              toY: entry.value.previousValue,
                              color: Colors.grey[400],
                              width: 12,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) => Text('S/ ${(value / 1000).toStringAsFixed(0)}K', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < state.chartData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(state.chartData[index].label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsCard(SalesReportState state) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Productos mas Vendidos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: state.topProducts.isEmpty
                ? const Center(child: Text('No hay datos de productos'))
                : ListView.builder(
                    itemCount: state.topProducts.length,
                    itemBuilder: (context, index) {
                      final product = state.topProducts[index];
                      final maxTotal = state.topProducts.first.totalSales;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(product.productName, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                Text(Helpers.formatCurrency(product.totalSales), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: maxTotal > 0 ? product.totalSales / maxTotal : 0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.primaries[index % Colors.primaries.length]),
                            ),
                            Text('${product.quantity.toStringAsFixed(0)} unidades', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesByCustomerCard(SalesReportState state) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ventas por Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: state.salesByCustomer.isEmpty
                ? const Center(child: Text('No hay datos de clientes'))
                : Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sections: state.salesByCustomer.asMap().entries.map((entry) {
                              final total = state.salesByCustomer.fold<double>(0, (sum, e) => sum + e.totalSales);
                              final percentage = total > 0 ? (entry.value.totalSales / total * 100) : 0;
                              return PieChartSectionData(
                                value: entry.value.totalSales,
                                title: '${percentage.toStringAsFixed(1)}%',
                                color: Colors.primaries[entry.key % Colors.primaries.length],
                                radius: 60,
                                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              );
                            }).toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: state.salesByCustomer.asMap().entries.take(5).map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.primaries[entry.key % Colors.primaries.length],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(entry.value.customerName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryReport(InventoryReportState state) {
    final totalValue = state.products.fold<double>(0, (sum, p) => sum + p.totalValue);
    final lowStockCount = state.products.where((p) => p.isLowStock).length;
    final totalProducts = state.products.length;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Reporte de Inventario', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ref.read(inventoryReportProvider.notifier).loadInventoryReport(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportacion proximamente'))),
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Exportar', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildKPICard('Total Productos', '$totalProducts', Icons.inventory, Colors.blue, 'en inventario'),
              const SizedBox(width: 16),
              _buildKPICard('Valor Total', Helpers.formatCurrency(totalValue), Icons.attach_money, Colors.green, 'valorizacion'),
              const SizedBox(width: 16),
              _buildKPICard('Bajo Stock', '$lowStockCount', Icons.warning, Colors.orange, 'productos'),
              const SizedBox(width: 16),
              _buildKPICard('Sin Stock', '${state.products.where((p) => p.currentStock == 0).length}', Icons.error, Colors.red, 'productos'),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Detalle de Inventario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('$totalProducts productos', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Container(
                  color: Colors.grey[50],
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                      Expanded(child: Text('Codigo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                      Expanded(child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.center)),
                      Expanded(child: Text('Minimo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.center)),
                      Expanded(child: Text('Precio', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.right)),
                      Expanded(child: Text('Valor Total', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.right)),
                      const SizedBox(width: 80, child: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                ...state.products.map((item) => _buildInventoryRow(item)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryRow(InventoryReport item) {
    Color statusColor;
    String statusText;
    
    if (item.currentStock == 0) {
      statusColor = Colors.red;
      statusText = 'Sin Stock';
    } else if (item.isLowStock) {
      statusColor = Colors.orange;
      statusText = 'Bajo';
    } else {
      statusColor = Colors.green;
      statusText = 'OK';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(item.productCode, style: TextStyle(color: Colors.grey[600]))),
          Expanded(child: Text(item.currentStock.toStringAsFixed(0), textAlign: TextAlign.center)),
          Expanded(child: Text(item.minStock.toStringAsFixed(0), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600]))),
          Expanded(child: Text(Helpers.formatCurrency(item.unitPrice), textAlign: TextAlign.right)),
          Expanded(child: Text(Helpers.formatCurrency(item.totalValue), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(statusText, textAlign: TextAlign.center, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivablesReport(ReceivablesReportState state) {
    final totalDebt = state.receivables.fold<double>(0, (sum, r) => sum + r.totalDebt);
    final overdueTotal = state.receivables.fold<double>(0, (sum, r) => sum + r.overdue30 + r.overdue60 + r.overdue90);
    final currentTotal = state.receivables.fold<double>(0, (sum, r) => sum + r.current);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cuentas por Cobrar', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ref.read(receivablesReportProvider.notifier).loadReceivablesReport(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportacion proximamente'))),
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Exportar', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildKPICard('Total por Cobrar', Helpers.formatCurrency(totalDebt), Icons.account_balance_wallet, Colors.blue, '${state.receivables.length} clientes'),
              const SizedBox(width: 16),
              _buildKPICard('Vencidas', Helpers.formatCurrency(overdueTotal), Icons.warning, Colors.red, 'deuda vencida'),
              const SizedBox(width: 16),
              _buildKPICard('Al Dia', Helpers.formatCurrency(currentTotal), Icons.check_circle, Colors.green, '0-30 dias'),
              const SizedBox(width: 16),
              _buildKPICard('Clientes Morosos', '${state.receivables.where((r) => r.overdueInvoices > 0).length}', Icons.person_off, Colors.orange, 'con deuda'),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Detalle de Cartera', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${state.receivables.length} clientes con deuda', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Container(
                  color: Colors.grey[50],
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                      Expanded(child: Text('Total Deuda', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.right)),
                      Expanded(child: Text('0-30 dias', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.right)),
                      Expanded(child: Text('31-60 dias', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.right)),
                      Expanded(child: Text('61-90 dias', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.right)),
                      Expanded(child: Text('+90 dias', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.right)),
                      const SizedBox(width: 80, child: Text('Recibos', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                state.receivables.isEmpty
                    ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No hay cuentas por cobrar pendientes')))
                    : Column(children: state.receivables.map((item) => _buildReceivableRow(item)).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivableRow(ReceivableReport item) {
    Color statusColor;
    
    if (item.overdue90 > 0) {
      statusColor = Colors.red[700]!;
    } else if (item.overdue60 > 0 || item.overdue30 > 0) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item.customerName, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(Helpers.formatCurrency(item.totalDebt), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(Helpers.formatCurrency(item.current), textAlign: TextAlign.right, style: TextStyle(color: Colors.green[700]))),
          Expanded(child: Text(Helpers.formatCurrency(item.overdue30), textAlign: TextAlign.right, style: TextStyle(color: item.overdue30 > 0 ? Colors.orange : Colors.grey))),
          Expanded(child: Text(Helpers.formatCurrency(item.overdue60), textAlign: TextAlign.right, style: TextStyle(color: item.overdue60 > 0 ? Colors.orange[700] : Colors.grey))),
          Expanded(child: Text(Helpers.formatCurrency(item.overdue90), textAlign: TextAlign.right, style: TextStyle(color: item.overdue90 > 0 ? Colors.red[700] : Colors.grey))),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text('${item.overdueInvoices}', textAlign: TextAlign.center, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

