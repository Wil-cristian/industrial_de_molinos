import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/reports_provider.dart';
import '../../data/providers/analytics_provider.dart';
import '../../domain/entities/analytics.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/quick_actions_button.dart';

class ReportsAnalyticsPage extends ConsumerStatefulWidget {
  const ReportsAnalyticsPage({super.key});

  @override
  ConsumerState<ReportsAnalyticsPage> createState() => _ReportsAnalyticsPageState();
}

class _ReportsAnalyticsPageState extends ConsumerState<ReportsAnalyticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() {
      ref.read(analyticsProvider.notifier).loadAll();
      ref.read(salesReportProvider.notifier).loadSalesReport();
      ref.read(inventoryReportProvider.notifier).loadInventoryReport();
      ref.read(receivablesReportProvider.notifier).loadReceivablesReport();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analyticsState = ref.watch(analyticsProvider);
    final salesState = ref.watch(salesReportProvider);
    final inventoryState = ref.watch(inventoryReportProvider);
    final receivablesState = ref.watch(receivablesReportProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          Row(
            children: [
              const AppSidebar(currentRoute: '/reports'),
              Expanded(
                child: Column(
                  children: [
                    // Header con tabs
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          children: [
                            // Título y botón volver
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () => context.go('/'),
                                    color: AppTheme.primaryColor,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Reportes y Analytics',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        Text(
                                          'Análisis completo de tu negocio',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // TabBar
                            TabBar(
                              controller: _tabController,
                              labelColor: AppTheme.primaryColor,
                              unselectedLabelColor: Colors.grey[600],
                              indicatorColor: AppTheme.primaryColor,
                              indicatorWeight: 3,
                              tabs: const [
                                Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
                                Tab(icon: Icon(Icons.trending_up), text: 'Ventas'),
                                Tab(icon: Icon(Icons.inventory_2), text: 'Inventario'),
                                Tab(icon: Icon(Icons.account_balance_wallet), text: 'Cobranzas'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Contenido de tabs
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAnalyticsTab(analyticsState),
                          _buildSalesTab(salesState),
                          _buildInventoryTab(inventoryState),
                          _buildCobranzasTab(analyticsState, receivablesState),
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

  // ============================================================
  // TAB 1: ANALYTICS
  // ============================================================
  Widget _buildAnalyticsTab(AnalyticsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row superior con 3 cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Clientes
              Expanded(child: _buildTopClientsCard(state)),
              const SizedBox(width: 16),
              // Productos Estrella
              Expanded(child: _buildTopProductsCard(state)),
              const SizedBox(width: 16),
              // Ganancias/Pérdidas
              Expanded(child: _buildProfitLossCard(state)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopClientsCard(AnalyticsState state) {
    final topClients = state.customerMetrics.take(5).toList();
    
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Top Clientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'en ventas',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: topClients.isEmpty
                ? const Center(child: Text('Sin datos'))
                : ListView.builder(
                    itemCount: topClients.length,
                    itemBuilder: (context, index) {
                      final client = topClients[index];
                      final colors = [Colors.red, Colors.purple, Colors.blue, Colors.teal, Colors.amber];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                client.name.isNotEmpty ? client.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                client.name,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              Helpers.formatCurrency(client.totalSpent),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
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

  Widget _buildTopProductsCard(AnalyticsState state) {
    final products = state.topProducts.take(5).toList();
    
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.star, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Productos Estrella',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('Sin datos'))
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final maxSales = products.first.totalRevenue;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    product.productName ?? 'Sin nombre',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  Helpers.formatCurrency(product.totalRevenue),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: maxSales > 0 ? product.totalRevenue / maxSales : 0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(
                                Colors.primaries[index % Colors.primaries.length],
                              ),
                            ),
                            Text(
                              '${product.totalQuantity.toStringAsFixed(0)} unidades',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
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

  Widget _buildProfitLossCard(AnalyticsState state) {
    final data = state.profitLoss.take(6).toList().reversed.toList();
    
    // Calcular máximo para el eje Y
    double maxValue = 0;
    for (var item in data) {
      if (item.revenue > maxValue) maxValue = item.revenue;
      if (item.totalExpenses > maxValue) maxValue = item.totalExpenses;
      if (item.grossProfit.abs() > maxValue) maxValue = item.grossProfit.abs();
    }
    maxValue = maxValue * 1.2;
    if (maxValue == 0) maxValue = 1000;

    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.trending_up, color: Colors.green),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ganancias y Pérdidas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                'Últimos 6 meses',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Leyenda
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Ingresos', Colors.green),
              const SizedBox(width: 16),
              _buildLegendItem('Gastos', Colors.red),
              const SizedBox(width: 16),
              _buildLegendItem('Ganancia', Colors.blue),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.isEmpty
                ? const Center(child: Text('Sin datos'))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxValue,
                      minY: 0,
                      barGroups: data.asMap().entries.map((entry) {
                        final item = entry.value;
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: item.revenue,
                              color: Colors.green,
                              width: 8,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            BarChartRodData(
                              toY: item.totalExpenses,
                              color: Colors.red,
                              width: 8,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            BarChartRodData(
                              toY: item.grossProfit > 0 ? item.grossProfit : 0,
                              color: Colors.blue,
                              width: 8,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max || value == meta.min) return const SizedBox();
                              return Text(
                                'S/ ${(value / 1000).toStringAsFixed(0)}K',
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < data.length) {
                                final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
                                final monthIdx = data[idx].month - 1;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    months[monthIdx.clamp(0, 11)],
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  ),
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
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey[200]!,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  // ============================================================
  // TAB 2: VENTAS
  // ============================================================
  Widget _buildSalesTab(SalesReportState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = state.stats;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reporte de Ventas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                    onPressed: () {},
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Exportar', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // KPIs
          Row(
            children: [
              _buildKPICard('Ventas Totales', Helpers.formatCurrency(stats?.totalSales ?? 0), 
                Icons.attach_money, Colors.green, '${stats?.transactionCount ?? 0} transacciones'),
              const SizedBox(width: 16),
              _buildKPICard('Ticket Promedio', Helpers.formatCurrency(stats?.averageTicket ?? 0), 
                Icons.receipt, Colors.blue, 'por recibo'),
              const SizedBox(width: 16),
              _buildKPICard('Margen Bruto', '${(stats?.grossMargin ?? 0).toStringAsFixed(1)}%', 
                Icons.trending_up, Colors.orange, 'rentabilidad'),
              const SizedBox(width: 16),
              _buildKPICard('Crecimiento', '${(stats?.growthPercentage ?? 0).toStringAsFixed(1)}%', 
                Icons.show_chart, (stats?.growthPercentage ?? 0) >= 0 ? Colors.green : Colors.red, 
                'vs periodo anterior'),
            ],
          ),
          const SizedBox(height: 24),
          // Chart
          _buildSalesChart(state),
          const SizedBox(height: 24),
          // Productos y Clientes
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTopProductsSalesCard(state)),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Evolución de Ventas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              _buildLegendItem('Actual', Colors.blue),
              const SizedBox(width: 16),
              _buildLegendItem('Anterior', Colors.grey),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: state.chartData.isEmpty
                ? const Center(child: Text('No hay datos'))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: state.chartData.map((e) => 
                        e.currentValue > e.previousValue ? e.currentValue : e.previousValue
                      ).reduce((a, b) => a > b ? a : b) * 1.2,
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
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max || value == meta.min) return const SizedBox();
                              return Text('S/ ${(value / 1000).toStringAsFixed(0)}K', 
                                style: TextStyle(color: Colors.grey[600], fontSize: 11));
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 && idx < state.chartData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(state.chartData[idx].label, 
                                    style: TextStyle(color: Colors.grey[600], fontSize: 10)),
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

  Widget _buildTopProductsSalesCard(SalesReportState state) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Productos más Vendidos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: state.topProducts.isEmpty
                ? const Center(child: Text('Sin datos'))
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
                              children: [
                                Expanded(child: Text(product.productName, 
                                  style: const TextStyle(fontWeight: FontWeight.w500), 
                                  overflow: TextOverflow.ellipsis)),
                                Text(Helpers.formatCurrency(product.totalSales), 
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: maxTotal > 0 ? product.totalSales / maxTotal : 0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(Colors.primaries[index % Colors.primaries.length]),
                            ),
                            Text('${product.quantity.toStringAsFixed(0)} unidades', 
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ventas por Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: state.salesByCustomer.isEmpty
                ? const Center(child: Text('Sin datos'))
                : ListView.builder(
                    itemCount: state.salesByCustomer.length,
                    itemBuilder: (context, index) {
                      final customer = state.salesByCustomer[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.primaries[index % Colors.primaries.length].withValues(alpha: 0.2),
                          child: Text(customer.customerName.isNotEmpty 
                            ? customer.customerName[0].toUpperCase() : '?',
                            style: TextStyle(color: Colors.primaries[index % Colors.primaries.length])),
                        ),
                        title: Text(customer.customerName, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${customer.transactionCount} facturas'),
                        trailing: Text(Helpers.formatCurrency(customer.totalSales), 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 3: INVENTARIO
  // ============================================================
  Widget _buildInventoryTab(InventoryReportState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalProducts = state.products.length;
    final totalValue = state.products.fold<double>(0, (sum, p) => sum + (p.currentStock * p.unitPrice));
    final lowStockCount = state.products.where((p) => p.currentStock <= p.minStock && p.currentStock > 0).length;
    final outOfStock = state.products.where((p) => p.currentStock == 0).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reporte de Inventario', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ref.read(inventoryReportProvider.notifier).loadInventoryReport(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Exportar', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // KPIs
          Row(
            children: [
              _buildKPICard('Total Productos', '$totalProducts', Icons.inventory, Colors.blue, 'en inventario'),
              const SizedBox(width: 16),
              _buildKPICard('Valor Total', Helpers.formatCurrency(totalValue), Icons.attach_money, Colors.green, 'valorización'),
              const SizedBox(width: 16),
              _buildKPICard('Bajo Stock', '$lowStockCount', Icons.warning, Colors.orange, 'productos'),
              const SizedBox(width: 16),
              _buildKPICard('Sin Stock', '$outOfStock', Icons.error, Colors.red, 'productos'),
            ],
          ),
          const SizedBox(height: 24),
          // Lista de productos
          _buildInventoryTable(state),
        ],
      ),
    );
  }

  Widget _buildInventoryTable(InventoryReportState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text('Detalle de Inventario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${state.products.length} productos', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          const Divider(height: 1),
          DataTable(
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Categoría', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Mínimo', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Precio', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Valor', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
              DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: state.products.take(10).map((product) {
              final isLow = product.currentStock <= product.minStock && product.currentStock > 0;
              final isOut = product.currentStock == 0;
              return DataRow(cells: [
                DataCell(Text(product.productName, overflow: TextOverflow.ellipsis)),
                DataCell(Text(product.productCode)),
                DataCell(Text(product.currentStock.toStringAsFixed(1))),
                DataCell(Text(product.minStock.toStringAsFixed(1))),
                DataCell(Text(Helpers.formatCurrency(product.unitPrice))),
                DataCell(Text(Helpers.formatCurrency(product.currentStock * product.unitPrice))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOut ? Colors.red.withValues(alpha: 0.1) 
                        : isLow ? Colors.orange.withValues(alpha: 0.1) 
                        : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOut ? 'Sin Stock' : isLow ? 'Bajo' : 'OK',
                      style: TextStyle(
                        color: isOut ? Colors.red : isLow ? Colors.orange : Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 4: COBRANZAS
  // ============================================================
  Widget _buildCobranzasTab(AnalyticsState analyticsState, ReceivablesReportState receivablesState) {
    if (analyticsState.isLoading || receivablesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalDebt = receivablesState.receivables.fold<double>(0, (sum, r) => sum + r.totalDebt);
    // Vencido = todo lo que no es current (0-30 días)
    final overdueTotal = receivablesState.receivables.fold<double>(0, (sum, r) => sum + r.overdue30 + r.overdue60 + r.overdue90);
    final currentTotal = receivablesState.receivables.fold<double>(0, (sum, r) => sum + r.current);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cuentas por Cobrar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(analyticsProvider.notifier).loadAll();
                      ref.read(receivablesReportProvider.notifier).loadReceivablesReport();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Exportar', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // KPIs
          Row(
            children: [
              _buildKPICard('Total por Cobrar', Helpers.formatCurrency(totalDebt), 
                Icons.account_balance_wallet, Colors.blue, '${receivablesState.receivables.length} clientes'),
              const SizedBox(width: 16),
              _buildKPICard('Vencidas', Helpers.formatCurrency(overdueTotal), 
                Icons.warning, Colors.red, 'deuda vencida'),
              const SizedBox(width: 16),
              _buildKPICard('Al Día', Helpers.formatCurrency(currentTotal), 
                Icons.check_circle, Colors.green, '0-30 días'),
              const SizedBox(width: 16),
              _buildKPICard('Clientes Morosos', '${receivablesState.receivables.where((r) => r.overdueInvoices > 0).length}', 
                Icons.person_off, Colors.orange, 'con deuda'),
            ],
          ),
          const SizedBox(height: 24),
          // Row con gráfico de aging y tabla
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gráfico de Aging
              Expanded(child: _buildAgingChart(analyticsState)),
              const SizedBox(width: 16),
              // Tabla de clientes
              Expanded(flex: 2, child: _buildReceivablesTable(receivablesState)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgingChart(AnalyticsState state) {
    final aging = state.agingSummary;
    final total = aging.values.fold<double>(0, (sum, val) => sum + val);

    final segments = [
      {'label': 'Vigente', 'value': aging['current'] ?? 0, 'color': Colors.green},
      {'label': '1-30 días', 'value': aging['1-30 days'] ?? 0, 'color': Colors.amber},
      {'label': '31-60 días', 'value': aging['31-60 days'] ?? 0, 'color': Colors.orange},
      {'label': '61-90 días', 'value': aging['61-90 days'] ?? 0, 'color': Colors.deepOrange},
      {'label': '+90 días', 'value': aging['over 90 days'] ?? 0, 'color': Colors.red},
    ];

    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Antigüedad de Saldos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: total == 0
                ? const Center(child: Text('Sin datos'))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 50,
                      sections: segments.where((s) => (s['value'] as double) > 0).map((s) {
                        final percent = total > 0 ? ((s['value'] as double) / total * 100) : 0;
                        return PieChartSectionData(
                          color: s['color'] as Color,
                          value: s['value'] as double,
                          title: '${percent.toStringAsFixed(0)}%',
                          radius: 60,
                          titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // Leyenda
          ...segments.map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(color: s['color'] as Color, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(s['label'] as String)),
                Text('${(total > 0 ? ((s['value'] as double) / total * 100) : 0).toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Text(Helpers.formatCurrency(s['value'] as double),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildReceivablesTable(ReceivablesReportState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text('Detalle de Cartera', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${state.receivables.length} clientes con deuda', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Total Deuda', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Vigente', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('31-60 días', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('61-90 días', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('+90 días', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: state.receivables.map((r) {
                final hasOverdue = r.overdue30 + r.overdue60 + r.overdue90 > 0;
                return DataRow(cells: [
                  DataCell(Text(r.customerName, overflow: TextOverflow.ellipsis)),
                  DataCell(Text(Helpers.formatCurrency(r.totalDebt))),
                  DataCell(Text(Helpers.formatCurrency(r.current), style: const TextStyle(color: Colors.green))),
                  DataCell(Text(Helpers.formatCurrency(r.overdue30))),
                  DataCell(Text(Helpers.formatCurrency(r.overdue60))),
                  DataCell(Text(Helpers.formatCurrency(r.overdue90), 
                    style: TextStyle(color: r.overdue90 > 0 ? Colors.red : null))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasOverdue 
                          ? Colors.red.withValues(alpha: 0.1) 
                          : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasOverdue ? 'Vencido' : 'Al día',
                        style: TextStyle(
                          color: hasOverdue ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMPONENTES COMPARTIDOS
  // ============================================================
  Widget _buildKPICard(String title, String value, IconData icon, Color color, String subtitle) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 13), 
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500), 
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
