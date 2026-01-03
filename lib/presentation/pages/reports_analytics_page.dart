import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/reports_provider.dart';
import '../../data/providers/analytics_provider.dart';
import '../../data/providers/debt_management_provider.dart';

class ReportsAnalyticsPage extends ConsumerStatefulWidget {
  const ReportsAnalyticsPage({super.key});

  @override
  ConsumerState<ReportsAnalyticsPage> createState() =>
      _ReportsAnalyticsPageState();
}

class _ReportsAnalyticsPageState extends ConsumerState<ReportsAnalyticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    Future.microtask(() {
      ref.read(analyticsProvider.notifier).loadAll();
      ref.read(salesReportProvider.notifier).loadSalesReport();
      ref.read(inventoryReportProvider.notifier).loadInventoryReport();
      ref.read(receivablesReportProvider.notifier).loadReceivablesReport();
      ref.read(debtManagementProvider.notifier).loadOverdueDebts();
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
    final debtState = ref.watch(debtManagementProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header compacto con tabs en línea
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
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
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: () => context.go('/'),
                  color: AppTheme.primaryColor,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Reportes y Analytics',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                          // TabBar inline
                          Expanded(
                            child: TabBar(
                              controller: _tabController,
                              labelColor: AppTheme.primaryColor,
                              unselectedLabelColor: Colors.grey[600],
                              indicatorColor: AppTheme.primaryColor,
                              indicatorWeight: 2,
                              isScrollable: true,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              tabs: const [
                                Tab(text: 'Analytics'),
                                Tab(text: 'Ventas'),
                                Tab(text: 'Inventario'),
                                Tab(text: 'Cobranzas'),
                                Tab(text: 'Mora'),
                              ],
                            ),
                          ),
                        ],
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
                          _buildMoraInteresesTab(debtState),
                        ],
                      ),
                    ),
                  ],
      ),
    );
  }

  // ============================================================
  // TAB 1: ANALYTICS - DASHBOARD MEJORADO
  // ============================================================
  Widget _buildAnalyticsTab(AnalyticsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Calcular KPIs
    final totalRevenue = state.profitLoss.fold(
      0.0,
      (sum, p) => sum + p.revenue,
    );
    final totalProfit = state.profitLoss.fold(
      0.0,
      (sum, p) => sum + p.grossProfit,
    );
    final totalClients = state.customerMetrics.length;
    final activeClients = state.customerMetrics
        .where((c) => c.activityStatus == 'Activo')
        .length;
    final totalReceivables = state.totalReceivables;
    final overdueAmount = state.overdueReceivables;

    // Último mes vs anterior
    final lastMonth = state.profitLoss.isNotEmpty
        ? state.profitLoss.first
        : null;
    final prevMonth = state.profitLoss.length > 1 ? state.profitLoss[1] : null;
    final revenueChange =
        lastMonth != null && prevMonth != null && prevMonth.revenue > 0
        ? ((lastMonth.revenue - prevMonth.revenue) / prevMonth.revenue * 100)
        : 0.0;
    final profitChange =
        lastMonth != null && prevMonth != null && prevMonth.grossProfit != 0
        ? ((lastMonth.grossProfit - prevMonth.grossProfit) /
              prevMonth.grossProfit.abs() *
              100)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ROW 1: KPIs principales
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'Ingresos Totales',
                  Helpers.formatCurrency(totalRevenue),
                  Icons.trending_up,
                  Colors.blue,
                  subtitle: 'Últimos 12 meses',
                  change: revenueChange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Utilidad Neta',
                  Helpers.formatCurrency(totalProfit),
                  Icons.account_balance_wallet,
                  totalProfit >= 0 ? Colors.green : Colors.red,
                  subtitle: 'Últimos 12 meses',
                  change: profitChange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Clientes Activos',
                  '$activeClients / $totalClients',
                  Icons.people,
                  Colors.purple,
                  subtitle: totalClients > 0
                      ? '${(activeClients / totalClients * 100).toStringAsFixed(0)}% del total'
                      : 'Sin clientes',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Por Cobrar',
                  Helpers.formatCurrency(totalReceivables),
                  Icons.receipt_long,
                  Colors.orange,
                  subtitle: overdueAmount > 0
                      ? '${Helpers.formatCurrency(overdueAmount)} vencido'
                      : 'Todo al día',
                  isWarning: overdueAmount > 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ROW 2: KPIs de Cobranzas (DSO, CEI, AR Turnover)
          Row(
            children: [
              Expanded(child: _buildDSOCard(state)),
              const SizedBox(width: 12),
              Expanded(child: _buildCEIGauge(state)),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildDSOTrendChart(state)),
            ],
          ),
          const SizedBox(height: 16),

          // ROW 3: Gráficos principales
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tendencia de Ingresos y Gastos (gráfico de área)
              Expanded(flex: 2, child: _buildRevenueExpensesTrendCard(state)),
              const SizedBox(width: 12),
              // Distribución de Clientes
              Expanded(child: _buildClientDistributionCard(state)),
            ],
          ),
          const SizedBox(height: 16),

          // ROW 4: Análisis ABC Pareto
          _buildParetoABCChart(state),
          const SizedBox(height: 16),

          // ROW 5: Rankings y detalles
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Clientes mejorado
              Expanded(child: _buildTopClientsCardEnhanced(state)),
              const SizedBox(width: 12),
              // Productos Estrella mejorado
              Expanded(child: _buildTopProductsCardEnhanced(state)),
              const SizedBox(width: 12),
              // Aging de cuentas por cobrar
              Expanded(child: _buildAgingCard(state)),
            ],
          ),
          const SizedBox(height: 16),

          // ROW 6: Profit/Loss detallado
          _buildProfitLossDetailedCard(state),
        ],
      ),
    );
  }

  // ============================================================
  // NUEVAS GRÁFICAS - FASE 1
  // ============================================================

  // Card de DSO (Days Sales Outstanding)
  Widget _buildDSOCard(AnalyticsState state) {
    final kpis = state.collectionKPIs;
    final dso = kpis?.dso ?? 0;
    final dsoTarget = 30.0; // Meta: 30 días
    final isGood = dso <= dsoTarget;

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: isGood ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'DSO',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Tooltip(
                message: 'Days Sales Outstanding\nDías promedio para cobrar',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${dso.toStringAsFixed(1)} días',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isGood ? Colors.green[700] : Colors.orange[700],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isGood ? Icons.check_circle : Icons.warning,
                size: 14,
                color: isGood ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                isGood
                    ? 'Dentro de meta (≤$dsoTarget días)'
                    : 'Sobre meta (>$dsoTarget días)',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (dso / 60).clamp(0, 1),
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                dso <= 30
                    ? Colors.green
                    : (dso <= 45 ? Colors.orange : Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Gauge de CEI (Collection Effectiveness Index)
  Widget _buildCEIGauge(AnalyticsState state) {
    final kpis = state.collectionKPIs;
    final cei = kpis?.cei ?? 0;

    Color getColor() {
      if (cei >= 90) return Colors.green;
      if (cei >= 80) return Colors.blue;
      if (cei >= 70) return Colors.orange;
      return Colors.red;
    }

    String getStatus() {
      if (cei >= 90) return 'Excelente';
      if (cei >= 80) return 'Bueno';
      if (cei >= 70) return 'Regular';
      return 'Crítico';
    }

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: getColor(), size: 20),
              const SizedBox(width: 8),
              const Text(
                'CEI',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Tooltip(
                message:
                    'Collection Effectiveness Index\nÍndice de Efectividad de Cobro',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const Spacer(),
          // Gauge visual simplificado
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${cei.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: getColor(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: getColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  getStatus(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: getColor(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Barra de gauge
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    colors: [
                      Colors.red,
                      Colors.orange,
                      Colors.blue,
                      Colors.green,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: (cei / 100 * (MediaQuery.of(context).size.width * 0.1))
                    .clamp(0, double.infinity),
                child: Container(
                  width: 4,
                  height: 12,
                  transform: Matrix4.translationValues(0, -2, 0),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0%',
                style: TextStyle(fontSize: 8, color: Colors.grey[400]),
              ),
              Text(
                '50%',
                style: TextStyle(fontSize: 8, color: Colors.grey[400]),
              ),
              Text(
                '100%',
                style: TextStyle(fontSize: 8, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Gráfico de Tendencia DSO
  Widget _buildDSOTrendChart(AnalyticsState state) {
    final dsoData = state.dsoTrend;
    final hasData = dsoData.isNotEmpty && dsoData.any((d) => d.dso > 0);

    double maxDSO = 60;
    if (hasData) {
      maxDSO = dsoData.map((d) => d.dso).reduce((a, b) => a > b ? a : b) * 1.2;
      if (maxDSO < 30) maxDSO = 60;
    }

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tendencia DSO',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                width: 20,
                height: 3,
                color: Colors.red.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Meta 30d',
                style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: !hasData
                ? Center(
                    child: Text(
                      'Sin datos de DSO',
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max || value == meta.min) {
                                return const SizedBox();
                              }
                              return Text(
                                '${value.toInt()}d',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[500],
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx >= 0 &&
                                  idx < dsoData.length &&
                                  idx % 2 == 0) {
                                return Text(
                                  dsoData[idx].monthName,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey[500],
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: 0,
                      maxY: maxDSO,
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: 30,
                            color: Colors.red.withValues(alpha: 0.5),
                            strokeWidth: 2,
                            dashArray: [5, 5],
                          ),
                        ],
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: dsoData
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value.dso))
                              .toList(),
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, idx) {
                              final dso = dsoData[idx].dso;
                              return FlDotCirclePainter(
                                radius: 3,
                                color: dso <= 30
                                    ? Colors.green
                                    : (dso <= 45 ? Colors.orange : Colors.red),
                                strokeWidth: 1,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blue.withValues(alpha: 0.1),
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

  // Gráfico Pareto ABC
  Widget _buildParetoABCChart(AnalyticsState state) {
    final abcData = state.productABC.take(15).toList();
    final hasData = abcData.isNotEmpty;

    return Container(
      height: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Análisis ABC (Pareto 80/20)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _buildABCLegend('A', Colors.green, '80% valor'),
              const SizedBox(width: 12),
              _buildABCLegend('B', Colors.orange, '15% valor'),
              const SizedBox(width: 12),
              _buildABCLegend('C', Colors.red, '5% valor'),
              const SizedBox(width: 12),
              Container(width: 20, height: 2, color: Colors.purple),
              const SizedBox(width: 4),
              Text(
                '% Acum.',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: !hasData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bar_chart,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin datos de productos',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final barWidth =
                          (constraints.maxWidth - 60) / abcData.length - 4;
                      final maxRevenue = abcData.isNotEmpty
                          ? abcData
                                    .map((p) => p.totalRevenue)
                                    .reduce((a, b) => a > b ? a : b) *
                                1.2
                          : 10000.0;

                      return Stack(
                        children: [
                          // Barras
                          BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: maxRevenue,
                              barGroups: abcData.asMap().entries.map((entry) {
                                final product = entry.value;
                                Color barColor;
                                switch (product.abcCategory) {
                                  case 'A':
                                    barColor = Colors.green;
                                    break;
                                  case 'B':
                                    barColor = Colors.orange;
                                    break;
                                  default:
                                    barColor = Colors.red;
                                }
                                return BarChartGroupData(
                                  x: entry.key,
                                  barRods: [
                                    BarChartRodData(
                                      toY: product.totalRevenue,
                                      width: barWidth.clamp(8, 30),
                                      color: barColor,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
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
                                      if (value == meta.max ||
                                          value == meta.min) {
                                        return const SizedBox();
                                      }
                                      return Text(
                                        '\$${(value / 1000).toStringAsFixed(0)}K',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 35,
                                    getTitlesWidget: (value, meta) {
                                      // Mostrar escala de % acumulado
                                      final pct = value / maxRevenue * 100;
                                      if (pct == 0 || pct > 100) {
                                        return const SizedBox();
                                      }
                                      return Text(
                                        '${pct.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.purple[400],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      if (idx >= 0 && idx < abcData.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: RotatedBox(
                                            quarterTurns: -1,
                                            child: Text(
                                              abcData[idx].productName.length >
                                                      8
                                                  ? '${abcData[idx].productName.substring(0, 8)}...'
                                                  : abcData[idx].productName,
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox();
                                    },
                                    reservedSize: 60,
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
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
                          // Línea acumulada (overlay)
                          Positioned.fill(
                            left: 50,
                            right: 35,
                            top: 0,
                            bottom: 68,
                            child: CustomPaint(
                              painter: _CumulativeLinePainter(
                                data: abcData
                                    .map((p) => p.cumulativePercentage)
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          // Resumen ABC
          if (hasData) ...[
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildABCSummary(
                  'A',
                  abcData.where((p) => p.abcCategory == 'A').length,
                  abcData.length,
                  Colors.green,
                ),
                _buildABCSummary(
                  'B',
                  abcData.where((p) => p.abcCategory == 'B').length,
                  abcData.length,
                  Colors.orange,
                ),
                _buildABCSummary(
                  'C',
                  abcData.where((p) => p.abcCategory == 'C').length,
                  abcData.length,
                  Colors.red,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildABCLegend(String category, Color color, String desc) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            category,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(desc, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildABCSummary(String category, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100) : 0;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                '$count productos',
                style: TextStyle(fontSize: 11, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${pct.toStringAsFixed(0)}% del total',
          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
        ),
      ],
    );
  }

  // KPI Card con cambio porcentual
  Widget _buildKPICard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    double? change,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (change != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: change >= 0
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: change >= 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${change.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: change >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isWarning ? Colors.orange[700] : Colors.grey[800],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isWarning ? Colors.orange : Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Gráfico de tendencia de ingresos vs gastos
  Widget _buildRevenueExpensesTrendCard(AnalyticsState state) {
    final data = state.profitLoss.take(12).toList().reversed.toList();

    double maxY = 0;
    for (var item in data) {
      if (item.revenue > maxY) maxY = item.revenue;
      if (item.totalExpenses > maxY) maxY = item.totalExpenses;
    }
    maxY = maxY * 1.15;
    if (maxY == 0) maxY = 10000;

    final hasValidData =
        data.isNotEmpty &&
        data.any((d) => d.revenue > 0 || d.totalExpenses > 0);

    return Container(
      height: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tendencia de Ingresos vs Gastos',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _buildLegendDot('Ingresos', Colors.blue),
              const SizedBox(width: 12),
              _buildLegendDot('Gastos', Colors.red),
              const SizedBox(width: 12),
              _buildLegendDot('Utilidad', Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: !hasValidData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin datos de tendencia',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max || value == meta.min) {
                                return const SizedBox();
                              }
                              return Text(
                                '\$${(value / 1000).toStringAsFixed(0)}K',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
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
                                final months = [
                                  'Ene',
                                  'Feb',
                                  'Mar',
                                  'Abr',
                                  'May',
                                  'Jun',
                                  'Jul',
                                  'Ago',
                                  'Sep',
                                  'Oct',
                                  'Nov',
                                  'Dic',
                                ];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    months[(data[idx].month - 1).clamp(0, 11)],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: [
                        // Ingresos
                        LineChartBarData(
                          spots: data
                              .asMap()
                              .entries
                              .map(
                                (e) =>
                                    FlSpot(e.key.toDouble(), e.value.revenue),
                              )
                              .toList(),
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blue.withValues(alpha: 0.1),
                          ),
                        ),
                        // Gastos
                        LineChartBarData(
                          spots: data
                              .asMap()
                              .entries
                              .map(
                                (e) => FlSpot(
                                  e.key.toDouble(),
                                  e.value.totalExpenses,
                                ),
                              )
                              .toList(),
                          isCurved: true,
                          color: Colors.red,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.red.withValues(alpha: 0.1),
                          ),
                        ),
                        // Utilidad
                        LineChartBarData(
                          spots: data
                              .asMap()
                              .entries
                              .map(
                                (e) => FlSpot(
                                  e.key.toDouble(),
                                  e.value.grossProfit > 0
                                      ? e.value.grossProfit
                                      : 0,
                                ),
                              )
                              .toList(),
                          isCurved: true,
                          color: Colors.green,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          dashArray: [5, 5],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  // Distribución de clientes por actividad
  Widget _buildClientDistributionCard(AnalyticsState state) {
    final clients = state.customerMetrics;
    final active = clients.where((c) => c.activityStatus == 'Activo').length;
    final regular = clients.where((c) => c.activityStatus == 'Regular').length;
    final inactive = clients
        .where((c) => c.activityStatus == 'Inactivo')
        .length;
    final newClients = clients.where((c) => c.activityStatus == 'Nuevo').length;
    final total = clients.length;

    // Verificar si hay datos válidos para mostrar
    final hasData =
        total > 0 &&
        (active > 0 || regular > 0 || inactive > 0 || newClients > 0);

    return Container(
      height: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado de Clientes',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: !hasData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pie_chart_outline,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin datos de clientes',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: [
                          if (active > 0)
                            PieChartSectionData(
                              value: active.toDouble(),
                              title: '$active',
                              color: Colors.green,
                              radius: 45,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (regular > 0)
                            PieChartSectionData(
                              value: regular.toDouble(),
                              title: '$regular',
                              color: Colors.orange,
                              radius: 45,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (inactive > 0)
                            PieChartSectionData(
                              value: inactive.toDouble(),
                              title: '$inactive',
                              color: Colors.red,
                              radius: 45,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          if (newClients > 0)
                            PieChartSectionData(
                              value: newClients.toDouble(),
                              title: '$newClients',
                              color: Colors.blue,
                              radius: 45,
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          // Leyenda
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildPieLegend('Activos', Colors.green, active, total),
              _buildPieLegend('Regulares', Colors.orange, regular, total),
              _buildPieLegend('Inactivos', Colors.red, inactive, total),
              if (newClients > 0)
                _buildPieLegend('Nuevos', Colors.blue, newClients, total),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieLegend(String label, Color color, int value, int total) {
    final pct = total > 0 ? (value / total * 100).toStringAsFixed(0) : '0';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($pct%)',
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // Top Clientes mejorado
  Widget _buildTopClientsCardEnhanced(AnalyticsState state) {
    final topClients = state.customerMetrics.take(8).toList();
    final maxSpent = topClients.isNotEmpty ? topClients.first.totalSpent : 1;

    return Container(
      height: 380,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Top Clientes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'por ventas',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: topClients.isEmpty
                ? const Center(child: Text('Sin datos'))
                : ListView.builder(
                    itemCount: topClients.length,
                    itemBuilder: (context, index) {
                      final client = topClients[index];
                      final progress = maxSpent > 0
                          ? client.totalSpent / maxSpent
                          : 0.0;
                      final rankColors = [
                        Colors.amber[700]!,
                        Colors.grey[400]!,
                        Colors.brown[300]!,
                      ];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            // Ranking badge
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: index < 3
                                    ? rankColors[index].withValues(alpha: 0.2)
                                    : Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: index < 3
                                      ? rankColors[index]
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Avatar
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.primaries[(index * 3) %
                                        Colors.primaries.length],
                                    Colors.primaries[(index * 3 + 5) %
                                        Colors.primaries.length],
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                client.name.isNotEmpty
                                    ? client.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Nombre y barra
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    client.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 4,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation(
                                        index == 0
                                            ? Colors.amber[700]
                                            : Colors.blue[400],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Monto
                            Text(
                              Helpers.formatCurrency(client.totalSpent),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: index == 0
                                    ? Colors.amber[700]
                                    : Colors.green[600],
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

  // Productos Estrella mejorado
  Widget _buildTopProductsCardEnhanced(AnalyticsState state) {
    final products = state.topProducts.take(8).toList();
    final maxRevenue = products.isNotEmpty ? products.first.totalRevenue : 1;

    return Container(
      height: 380,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Productos Estrella',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'por ingresos',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: products.isEmpty
                ? const Center(child: Text('Sin datos'))
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final progress = maxRevenue > 0
                          ? product.totalRevenue / maxRevenue
                          : 0.0;
                      final barColor = Colors
                          .primaries[(index * 2) % Colors.primaries.length];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: barColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: barColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    product.productName ?? 'Sin nombre',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  Helpers.formatCurrency(product.totalRevenue),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: barColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const SizedBox(width: 28),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: Colors.grey[100],
                                      valueColor: AlwaysStoppedAnimation(
                                        barColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${product.totalQuantity.toStringAsFixed(0)} uds',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
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
      ),
    );
  }

  // Aging de cuentas por cobrar
  Widget _buildAgingCard(AnalyticsState state) {
    final aging = state.agingSummary;
    final current = aging['current'] ?? 0;
    final d1_30 = aging['1-30 days'] ?? 0;
    final d31_60 = aging['31-60 days'] ?? 0;
    final d61_90 = aging['61-90 days'] ?? 0;
    final over90 = aging['over 90 days'] ?? 0;
    final total = current + d1_30 + d31_60 + d61_90 + over90;

    return Container(
      height: 380,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.orange[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Antigüedad de Cartera',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Total
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total por cobrar',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  Helpers.formatCurrency(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Barras de aging
          Expanded(
            child: Column(
              children: [
                _buildAgingBar('Vigente', current, total, Colors.green),
                _buildAgingBar('1-30 días', d1_30, total, Colors.yellow[700]!),
                _buildAgingBar('31-60 días', d31_60, total, Colors.orange),
                _buildAgingBar('61-90 días', d61_90, total, Colors.deepOrange),
                _buildAgingBar('+90 días', over90, total, Colors.red),
              ],
            ),
          ),
          // Alerta si hay mucho vencido
          if (d61_90 + over90 > 0)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${Helpers.formatCurrency(d61_90 + over90)} crítico (+60 días)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAgingBar(
    String label,
    double amount,
    double total,
    Color color,
  ) {
    final pct = total > 0 ? amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                Helpers.formatCurrency(amount),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  // Profit/Loss detallado con comparativa
  Widget _buildProfitLossDetailedCard(AnalyticsState state) {
    final data = state.profitLoss.take(12).toList().reversed.toList();

    double maxY = 0;
    for (var item in data) {
      if (item.revenue > maxY) maxY = item.revenue;
    }
    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 10000;

    // Calcular totales
    final totalRevenue = data.fold(0.0, (sum, p) => sum + p.revenue);
    final totalExpenses = data.fold(0.0, (sum, p) => sum + p.totalExpenses);
    final totalProfit = data.fold(0.0, (sum, p) => sum + p.grossProfit);
    final margin = totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0;

    // Verificar si hay datos válidos para mostrar
    final hasValidData =
        data.isNotEmpty &&
        data.any((d) => d.revenue > 0 || d.totalExpenses > 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Estado de Resultados',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Resumen rápido
              _buildMiniStat(
                'Ingresos',
                Helpers.formatCurrency(totalRevenue),
                Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildMiniStat(
                'Gastos',
                Helpers.formatCurrency(totalExpenses),
                Colors.red,
              ),
              const SizedBox(width: 16),
              _buildMiniStat(
                'Utilidad',
                Helpers.formatCurrency(totalProfit),
                totalProfit >= 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 16),
              _buildMiniStat(
                'Margen',
                '${margin.toStringAsFixed(1)}%',
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 250,
            child: !hasValidData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bar_chart,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin datos de ingresos/gastos',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      minY: 0,
                      groupsSpace: 12,
                      barGroups: data.asMap().entries.map((entry) {
                        final item = entry.value;
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: item.revenue,
                              width: 16,
                              color: Colors.blue[400],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                              rodStackItems: [
                                BarChartRodStackItem(
                                  0,
                                  item.totalExpenses,
                                  Colors.red[300]!,
                                ),
                              ],
                            ),
                          ],
                          showingTooltipIndicators: [],
                        );
                      }).toList(),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 50,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max || value == meta.min) {
                                return const SizedBox();
                              }
                              return Text(
                                '\$${(value / 1000).toStringAsFixed(0)}K',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
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
                                final months = [
                                  'Ene',
                                  'Feb',
                                  'Mar',
                                  'Abr',
                                  'May',
                                  'Jun',
                                  'Jul',
                                  'Ago',
                                  'Sep',
                                  'Oct',
                                  'Nov',
                                  'Dic',
                                ];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    months[(data[idx].month - 1).clamp(0, 11)],
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot('Ingresos', Colors.blue[400]!),
              const SizedBox(width: 16),
              _buildLegendDot('Gastos (dentro de barra)', Colors.red[300]!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
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
                    onPressed: () => ref
                        .read(salesReportProvider.notifier)
                        .loadSalesReport(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text(
                      'Exportar',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // KPIs
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'Ventas Totales',
                  Helpers.formatCurrency(stats?.totalSales ?? 0),
                  Icons.attach_money,
                  Colors.green,
                  subtitle: '${stats?.transactionCount ?? 0} transacciones',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard(
                  'Ticket Promedio',
                  Helpers.formatCurrency(stats?.averageTicket ?? 0),
                  Icons.receipt,
                  Colors.blue,
                  subtitle: 'por recibo',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard(
                  'Margen Bruto',
                  '${(stats?.grossMargin ?? 0).toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.orange,
                  subtitle: 'rentabilidad',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard(
                  'Crecimiento',
                  '${(stats?.growthPercentage ?? 0).toStringAsFixed(1)}%',
                  Icons.show_chart,
                  (stats?.growthPercentage ?? 0) >= 0
                      ? Colors.green
                      : Colors.red,
                  subtitle: 'vs periodo anterior',
                ),
              ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Evolución de Ventas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _buildLegendItem('Actual', Colors.blue),
              const SizedBox(width: 16),
              _buildLegendItem('Anterior', Colors.grey),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: state.chartData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bar_chart,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No hay datos de ventas',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : (() {
                    final maxVal = state.chartData.isEmpty
                        ? 0.0
                        : state.chartData
                              .map(
                                (e) => e.currentValue > e.previousValue
                                    ? e.currentValue
                                    : e.previousValue,
                              )
                              .fold(0.0, (a, b) => a > b ? a : b);
                    final maxY = maxVal > 0 ? maxVal * 1.2 : 10000.0;
                    return BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        barGroups: state.chartData.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.currentValue,
                                color: Colors.blue,
                                width: 12,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                              BarChartRodData(
                                toY: entry.value.previousValue,
                                color: Colors.grey[400],
                                width: 12,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
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
                                if (value == meta.max || value == meta.min) {
                                  return const SizedBox();
                                }
                                return Text(
                                  '\$ ${(value / 1000).toStringAsFixed(0)}K',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                );
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
                                    child: Text(
                                      state.chartData[idx].label,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) =>
                              FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    );
                  })(),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Productos más Vendidos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
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
                                Expanded(
                                  child: Text(
                                    product.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  Helpers.formatCurrency(product.totalSales),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: maxTotal > 0
                                  ? product.totalSales / maxTotal
                                  : 0,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(
                                Colors.primaries[index %
                                    Colors.primaries.length],
                              ),
                            ),
                            Text(
                              '${product.quantity.toStringAsFixed(0)} unidades',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
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

  Widget _buildSalesByCustomerCard(SalesReportState state) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ventas por Cliente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
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
                          backgroundColor: Colors
                              .primaries[index % Colors.primaries.length]
                              .withValues(alpha: 0.2),
                          child: Text(
                            customer.customerName.isNotEmpty
                                ? customer.customerName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Colors
                                  .primaries[index % Colors.primaries.length],
                            ),
                          ),
                        ),
                        title: Text(
                          customer.customerName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${customer.transactionCount} facturas'),
                        trailing: Text(
                          Helpers.formatCurrency(customer.totalSales),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
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

    final totalCritical = state.products.length;
    final lowStockCount = state.products.where((p) => p.isLowStock).length;
    final outOfStock = state.products.where((p) => p.isOutOfStock).length;
    final materialsCount = state.products
        .where((p) => p.itemType == 'material')
        .length;
    final productsCount = state.products
        .where((p) => p.itemType == 'product' || p.itemType == 'recipe')
        .length;
    
    // Usar valores del summary (que incluye TODOS los productos)
    final totalStockCost = (state.summary['totalStockCost'] ?? 0.0) as double;
    final totalStockValue = (state.summary['totalStockSaleValue'] ?? 0.0) as double;
    final totalPotentialProfit = (state.summary['totalPotentialProfit'] ?? 0.0) as double;
    final avgMargin = (state.summary['avgMargin'] ?? 0.0) as double;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Análisis de Inventario y Márgenes',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Items que requieren atención inmediata',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => ref
                        .read(inventoryReportProvider.notifier)
                        .loadInventoryReport(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // KPIs - Primera fila (Stock)
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'Items Críticos',
                  '$totalCritical',
                  Icons.warning_amber,
                  Colors.red,
                  subtitle:
                      '$productsCount productos, $materialsCount materiales',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Stock Bajo',
                  '$lowStockCount',
                  Icons.trending_down,
                  Colors.orange,
                  subtitle: 'por debajo del mínimo',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Sin Stock',
                  '$outOfStock',
                  Icons.remove_shopping_cart,
                  Colors.red,
                  subtitle: 'agotados o negativos',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // KPIs - Segunda fila (Márgenes)
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'Valor Stock (Costo)',
                  Helpers.formatCurrency(totalStockCost),
                  Icons.inventory_2,
                  Colors.blue,
                  subtitle: 'inversión en inventario',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Valor Stock (Venta)',
                  Helpers.formatCurrency(totalStockValue),
                  Icons.sell,
                  Colors.green,
                  subtitle: 'valor de venta potencial',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Ganancia Potencial',
                  Helpers.formatCurrency(totalPotentialProfit),
                  Icons.trending_up,
                  totalPotentialProfit >= 0 ? Colors.teal : Colors.red,
                  subtitle: 'margen promedio: ${avgMargin.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Mensaje si no hay críticos
          if (state.products.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.green[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '¡Todo en orden!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay items con stock crítico en este momento',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            // Lista de productos críticos
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Items que Requieren Atención',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.products.length} items críticos',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              columns: const [
                DataColumn(
                  label: Text(
                    'Nombre',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Categoría',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Tipo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Stock',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'P. Compra',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'P. Venta',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Margen',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Ganancia/U',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Valor Stock',
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
              ],
              rows: state.products.map((product) {
                final marginColor = product.marginPercent > 30 
                    ? Colors.green 
                    : product.marginPercent > 15 
                        ? Colors.orange 
                        : Colors.red;
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              product.productName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              product.productCode,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: product.itemType == 'material'
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: product.itemType == 'material'
                                ? Colors.orange[700]
                                : Colors.blue[700],
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        product.itemType == 'material'
                            ? 'Material'
                            : product.itemType == 'recipe'
                                ? 'Receta'
                                : 'Producto',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${product.currentStock.toStringAsFixed(1)} ${product.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: product.isOutOfStock
                              ? Colors.red
                              : product.isLowStock
                              ? Colors.orange
                              : null,
                        ),
                      ),
                    ),
                    // Precio de compra/costo
                    DataCell(
                      Text(
                        Helpers.formatCurrency(product.costPrice),
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                    // Precio de venta
                    DataCell(
                      Text(
                        Helpers.formatCurrency(product.unitPrice),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                    // Margen %
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: marginColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              product.marginPercent > 30 
                                  ? Icons.trending_up 
                                  : product.marginPercent > 15 
                                      ? Icons.trending_flat 
                                      : Icons.trending_down,
                              size: 14,
                              color: marginColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${product.marginPercent.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: marginColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Ganancia por unidad
                    DataCell(
                      Text(
                        Helpers.formatCurrency(product.profitPerUnit),
                        style: TextStyle(
                          fontSize: 12,
                          color: product.profitPerUnit > 0 ? Colors.green[700] : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Valor del stock
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            Helpers.formatCurrency(product.stockSaleValue),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Costo: ${Helpers.formatCurrency(product.stockCostValue)}',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: product.isOutOfStock
                              ? Colors.red.withValues(alpha: 0.1)
                              : product.isLowStock
                              ? Colors.orange.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          product.isOutOfStock
                              ? 'Sin Stock'
                              : product.isLowStock
                              ? 'Bajo'
                              : 'OK',
                          style: TextStyle(
                            color: product.isOutOfStock
                                ? Colors.red
                                : product.isLowStock
                                ? Colors.orange
                                : Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 4: COBRANZAS
  // ============================================================
  Widget _buildCobranzasTab(
    AnalyticsState analyticsState,
    ReceivablesReportState receivablesState,
  ) {
    if (analyticsState.isLoading || receivablesState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalDebt = receivablesState.receivables.fold<double>(
      0,
      (sum, r) => sum + r.totalDebt,
    );
    // Vencido = todo lo que no es current (0-30 días)
    final overdueTotal = receivablesState.receivables.fold<double>(
      0,
      (sum, r) => sum + r.overdue30 + r.overdue60 + r.overdue90,
    );
    final currentTotal = receivablesState.receivables.fold<double>(
      0,
      (sum, r) => sum + r.current,
    );

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
                'Cuentas por Cobrar',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(analyticsProvider.notifier).loadAll();
                      ref
                          .read(receivablesReportProvider.notifier)
                          .loadReceivablesReport();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text(
                      'Exportar',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // KPIs
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'Total por Cobrar',
                  Helpers.formatCurrency(totalDebt),
                  Icons.account_balance_wallet,
                  Colors.blue,
                  subtitle: '${receivablesState.receivables.length} clientes',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard(
                  'Vencidas',
                  Helpers.formatCurrency(overdueTotal),
                  Icons.warning,
                  Colors.red,
                  subtitle: 'deuda vencida',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard(
                  'Al Día',
                  Helpers.formatCurrency(currentTotal),
                  Icons.check_circle,
                  Colors.green,
                  subtitle: '0-30 días',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard(
                  'Clientes Morosos',
                  '${receivablesState.receivables.where((r) => r.overdueInvoices > 0).length}',
                  Icons.person_off,
                  Colors.orange,
                  subtitle: 'con deuda',
                ),
              ),
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
              Expanded(
                flex: 2,
                child: _buildReceivablesTable(receivablesState),
              ),
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
      {
        'label': 'Vigente',
        'value': aging['current'] ?? 0,
        'color': Colors.green,
      },
      {
        'label': '1-30 días',
        'value': aging['1-30 days'] ?? 0,
        'color': Colors.amber,
      },
      {
        'label': '31-60 días',
        'value': aging['31-60 days'] ?? 0,
        'color': Colors.orange,
      },
      {
        'label': '61-90 días',
        'value': aging['61-90 days'] ?? 0,
        'color': Colors.deepOrange,
      },
      {
        'label': '+90 días',
        'value': aging['over 90 days'] ?? 0,
        'color': Colors.red,
      },
    ];

    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Antigüedad de Saldos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: total == 0
                ? const Center(child: Text('Sin datos'))
                : Row(
                    children: [
                      // Gráfico de torta (lado izquierdo)
                      Expanded(
                        flex: 1,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 35,
                            sections: segments
                                .where((s) => (s['value'] as double) > 0)
                                .map((s) {
                                  final percent = total > 0
                                      ? ((s['value'] as double) / total * 100)
                                      : 0;
                                  return PieChartSectionData(
                                    color: s['color'] as Color,
                                    value: s['value'] as double,
                                    title: '${percent.toStringAsFixed(0)}%',
                                    radius: 45,
                                    titleStyle: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  );
                                })
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Leyenda (lado derecho)
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: segments
                              .map(
                                (s) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: s['color'] as Color,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s['label'] as String,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              Helpers.formatCurrency(
                                                s['value'] as double,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivablesTable(ReceivablesReportState state) {
    return Container(
      height: 380, // Altura fija para evitar errores de layout
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Text(
                  'Detalle de Cartera',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${state.receivables.length} clientes con deuda',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                // Botón para ir a Mora e Intereses
                if (state.receivables.any(
                  (r) => r.overdue30 + r.overdue60 + r.overdue90 > 0,
                ))
                  TextButton.icon(
                    onPressed: () {
                      _tabController.animateTo(4); // Ir a tab de Mora
                    },
                    icon: const Icon(
                      Icons.warning_amber,
                      size: 18,
                      color: Colors.orange,
                    ),
                    label: const Text(
                      'Ver Mora',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  horizontalMargin: 16,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Cliente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Total Deuda',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'Vigente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        '31-60 días',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        '61-90 días',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        '+90 días',
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
                        'Mora',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: state.receivables.map((r) {
                    final hasOverdue =
                        r.overdue30 + r.overdue60 + r.overdue90 > 0;
                    final needsNotification =
                        r.overdue30 > 0 || r.overdue60 > 0 || r.overdue90 > 0;
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(r.customerName, overflow: TextOverflow.ellipsis),
                        ),
                        DataCell(Text(Helpers.formatCurrency(r.totalDebt))),
                        DataCell(
                          Text(
                            Helpers.formatCurrency(r.current),
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                        DataCell(Text(Helpers.formatCurrency(r.overdue30))),
                        DataCell(Text(Helpers.formatCurrency(r.overdue60))),
                        DataCell(
                          Text(
                            Helpers.formatCurrency(r.overdue90),
                            style: TextStyle(
                              color: r.overdue90 > 0 ? Colors.red : null,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
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
                        // Columna de notificación de mora
                        DataCell(
                          needsNotification
                              ? Tooltip(
                                  message:
                                      'Cliente en mora - notificación pendiente',
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                        alpha: 0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.notification_important,
                                      color: Colors.orange,
                                      size: 18,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 5: MORA E INTERESES
  // ============================================================
  Widget _buildMoraInteresesTab(DebtManagementState debtState) {
    if (debtState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final debtsOver30 = debtState.overdueDebts
        .where((d) => d.daysOverdue > 30)
        .toList();
    final debtsCritical = debtState.overdueDebts
        .where((d) => d.daysOverdue > 60)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gestión de Mora e Intereses',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tasa de interés: ${debtState.defaultInterestRate}% mensual',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              Row(
                children: [
                  // Selector de tasa de interés
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text('Tasa: '),
                        DropdownButton<double>(
                          value: debtState.defaultInterestRate,
                          underline: const SizedBox(),
                          items: [1.0, 1.5, 2.0, 2.5, 3.0, 5.0].map((rate) {
                            return DropdownMenuItem(
                              value: rate,
                              child: Text('$rate%'),
                            );
                          }).toList(),
                          onChanged: (rate) {
                            if (rate != null) {
                              ref
                                  .read(debtManagementProvider.notifier)
                                  .setDefaultInterestRate(rate);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(debtManagementProvider.notifier)
                          .loadOverdueDebts();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // KPIs de Mora
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'Deuda Vencida',
                  Helpers.formatCurrency(debtState.totalOverdue),
                  Icons.money_off,
                  Colors.red,
                  subtitle: '${debtState.overdueDebts.length} facturas',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard(
                  'Intereses Acumulados',
                  Helpers.formatCurrency(debtState.totalInterest),
                  Icons.trending_up,
                  Colors.orange,
                  subtitle: 'por mora',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard(
                  'Total con Intereses',
                  Helpers.formatCurrency(debtState.totalWithInterest),
                  Icons.account_balance,
                  AppTheme.primaryColor,
                  subtitle: 'deuda total',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildKPICard(
                  'Clientes en Mora',
                  '${debtsOver30.length}',
                  Icons.person_off,
                  Colors.deepOrange,
                  subtitle: '>30 días',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Alerta de notificaciones
          if (debtState.debtsNeedingNotification.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notification_important,
                    color: Colors.orange,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notificaciones de Mora Pendientes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        Text(
                          '${debtState.debtsNeedingNotification.length} clientes necesitan notificación de mora (>30 días)',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _sendAllNotifications(
                      debtState.debtsNeedingNotification,
                    ),
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    label: const Text(
                      'Enviar Todas',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

          // Tabla de deudas con intereses
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Text(
                        'Deudas Vencidas con Intereses',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${debtsCritical.length} críticos (+60 días)',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (debtState.overdueDebts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 64,
                            color: Colors.green,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '¡Sin deudas vencidas!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text('No hay facturas pendientes de cobro vencidas'),
                        ],
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Cliente',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Factura',
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
                            'Días Venc.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(
                            'Deuda',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text(
                            'Interés',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          numeric: true,
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
                            'Estado',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Acciones',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows: debtState.overdueDebts.map((debt) {
                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((
                            states,
                          ) {
                            if (debt.daysOverdue > 60) {
                              return Colors.red.withValues(alpha: 0.05);
                            }
                            if (debt.daysOverdue > 30) {
                              return Colors.orange.withValues(alpha: 0.05);
                            }
                            return null;
                          }),
                          cells: [
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 150,
                                ),
                                child: Text(
                                  debt.customerName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(debt.invoiceNumber)),
                            DataCell(Text(Helpers.formatDate(debt.dueDate))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getDaysColor(
                                    debt.daysOverdue,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${debt.daysOverdue}',
                                  style: TextStyle(
                                    color: _getDaysColor(debt.daysOverdue),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(Helpers.formatCurrency(debt.pendingAmount)),
                            ),
                            DataCell(
                              Text(
                                Helpers.formatCurrency(debt.interestAmount),
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                Helpers.formatCurrency(debt.totalWithInterest),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              _buildStatusBadge(debt.status, debt.statusLabel),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Botón de notificación
                                  if (debt.daysOverdue > 30)
                                    Tooltip(
                                      message: 'Enviar recordatorio',
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.notification_add,
                                          size: 20,
                                        ),
                                        color: Colors.orange,
                                        onPressed: () =>
                                            _sendReminderDialog(debt),
                                      ),
                                    ),
                                  // Botón de aplicar interés
                                  Tooltip(
                                    message: 'Aplicar interés a factura',
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.add_circle,
                                        size: 20,
                                      ),
                                      color: AppTheme.primaryColor,
                                      onPressed: debt.interestApplied
                                          ? null
                                          : () => _applyInterestDialog(debt),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Información de configuración
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Configuración de Mora',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Tasa de interés actual: ${debtState.defaultInterestRate}% mensual\n'
                  '• Notificaciones automáticas: Clientes con más de 30 días de vencimiento\n'
                  '• Estado "Moroso": 31-60 días vencidos\n'
                  '• Estado "Crítico": Más de 60 días vencidos\n'
                  '• Los intereses se calculan sobre el saldo pendiente',
                  style: TextStyle(color: Colors.grey[700], height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getDaysColor(int days) {
    if (days <= 30) return Colors.amber;
    if (days <= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStatusBadge(String status, String label) {
    Color color;
    switch (status) {
      case 'vigente':
        color = Colors.green;
        break;
      case 'vencido':
        color = Colors.amber;
        break;
      case 'moroso':
        color = Colors.orange;
        break;
      case 'critico':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _sendAllNotifications(List<DebtWithInterest> debts) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar Notificaciones'),
        content: Text(
          '¿Enviar notificación de mora a ${debts.length} clientes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (var debt in debts) {
        await ref
            .read(debtManagementProvider.notifier)
            .sendManualReminder(debt);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${debts.length} notificaciones enviadas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _sendReminderDialog(DebtWithInterest debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar Recordatorio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${debt.customerName}'),
            Text('Factura: ${debt.invoiceNumber}'),
            Text(
              'Deuda con intereses: ${Helpers.formatCurrency(debt.totalWithInterest)}',
            ),
            const SizedBox(height: 12),
            const Text('¿Enviar recordatorio de pago?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(debtManagementProvider.notifier)
          .sendManualReminder(debt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Recordatorio enviado' : 'Error al enviar'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyInterestDialog(DebtWithInterest debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aplicar Interés'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: ${debt.customerName}'),
            Text('Factura: ${debt.invoiceNumber}'),
            const Divider(),
            Text(
              'Deuda original: ${Helpers.formatCurrency(debt.pendingAmount)}',
            ),
            Text(
              'Interés (${debt.interestRate}%): ${Helpers.formatCurrency(debt.interestAmount)}',
              style: const TextStyle(color: Colors.orange),
            ),
            Text(
              'Nuevo total: ${Helpers.formatCurrency(debt.totalWithInterest)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción modificará el total de la factura',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text(
              'Aplicar Interés',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(debtManagementProvider.notifier)
          .applyInterestToInvoice(debt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Interés aplicado correctamente'
                  : 'Error al aplicar interés',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  // Función auxiliar para leyendas
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
}

// CustomPainter para línea acumulativa del gráfico Pareto
class _CumulativeLinePainter extends CustomPainter {
  final List<double> data;

  _CumulativeLinePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.purple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.purple
      ..style = PaintingStyle.fill;

    final path = Path();
    final barWidth = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final x = barWidth * i + barWidth / 2;
      final y = size.height - (data[i] / 100 * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Dibujar punto
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }

    canvas.drawPath(path, paint);

    // Líneas de referencia 80% y 95%
    final refPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Línea 80%
    final y80 = size.height - (80 / 100 * size.height);
    canvas.drawLine(Offset(0, y80), Offset(size.width, y80), refPaint);

    // Línea 95%
    final y95 = size.height - (95 / 100 * size.height);
    canvas.drawLine(Offset(0, y95), Offset(size.width, y95), refPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
