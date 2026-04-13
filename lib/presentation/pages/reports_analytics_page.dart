import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/print_service.dart';
import '../../data/providers/reports_provider.dart';
import '../../data/providers/analytics_provider.dart';
import '../../data/providers/debt_management_provider.dart';
import '../../data/providers/payroll_provider.dart';
import '../../data/providers/employees_provider.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../domain/entities/cash_movement.dart';
import '../../core/utils/colombia_time.dart';

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
    _tabController = TabController(length: 6, vsync: this);
    Future.microtask(() {
      ref.read(analyticsProvider.notifier).loadAll();
      ref.read(inventoryReportProvider.notifier).loadInventoryReport();
      ref.read(receivablesReportProvider.notifier).loadReceivablesReport();
      ref.read(debtManagementProvider.notifier).loadOverdueDebts();
      ref.read(payrollProvider.notifier).loadLoans();
      ref.read(employeesProvider.notifier).loadEmployees();
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
    final inventoryState = ref.watch(inventoryReportProvider);
    final receivablesState = ref.watch(receivablesReportProvider);
    final debtState = ref.watch(debtManagementProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Header compacto con tabs en línea
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, size: 20),
                        onPressed: () => context.go('/'),
                        color: Theme.of(context).colorScheme.primary,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Reportes y Analytics',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showMonthlyReportDialog(context),
                        icon: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          'Informe Mensual',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TabBar(
                    controller: _tabController,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    indicatorWeight: 2,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    tabs: const [
                      Tab(text: 'Analytics'),
                      Tab(text: 'Inventario'),
                      Tab(text: 'Cobranzas'),
                      Tab(text: 'Mora'),
                      Tab(text: 'Flujo Caja'),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_remove_outlined, size: 14),
                            SizedBox(width: 4),
                            Text('Gastos Empleados'),
                          ],
                        ),
                      ),
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
                  _buildAnalyticsTab(analyticsState),
                  _buildInventoryTab(inventoryState),
                  _buildCobranzasTab(analyticsState, receivablesState),
                  _buildMoraInteresesTab(debtState),
                  _buildCashFlowTab(),
                  const _EmployeeExpensesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIÁLOGO: INFORME MENSUAL PDF
  // ============================================================
  void _showMonthlyReportDialog(BuildContext context) {
    final now = ColombiaTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;

    final monthNames = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: const Color(0xFFD32F2F)),
              const SizedBox(width: 8),
              const Text('Informe Mensual de Rentabilidad'),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona el período del informe:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Mes',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        value: selectedMonth,
                        items: List.generate(12, (i) => i + 1)
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(monthNames[m]),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedMonth = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Año',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        value: selectedYear,
                        items: [now.year - 1, now.year, now.year + 1]
                            .map(
                              (y) => DropdownMenuItem(
                                value: y,
                                child: Text(y.toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedYear = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF90CAF9)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'El informe incluye:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Resumen ejecutivo (ventas, costos, utilidad)',
                        style: TextStyle(fontSize: 11),
                      ),
                      Text(
                        '• Desglose de costos por categoría',
                        style: TextStyle(fontSize: 11),
                      ),
                      Text(
                        '• Comparativo de últimos meses',
                        style: TextStyle(fontSize: 11),
                      ),
                      Text(
                        '• Productos estrella',
                        style: TextStyle(fontSize: 11),
                      ),
                      Text(
                        '• Préstamos activos de empleados',
                        style: TextStyle(fontSize: 11),
                      ),
                      Text(
                        '• Proyecciones próximo mes',
                        style: TextStyle(fontSize: 11),
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
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await _generateMonthlyReport(selectedMonth, selectedYear);
              },
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text(
                'Generar PDF',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateMonthlyReport(int month, int year) async {
    // Mostrar loading
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Generando informe PDF...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    try {
      final analyticsState = ref.read(analyticsProvider);
      final payrollState = ref.read(payrollProvider);

      // Obtener gastos del mes seleccionado por categoría
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 0, 23, 59, 59);
      final movements = await AccountsDataSource.getMovementsByDateRange(
        start,
        end,
      );
      final expenseByCategory = <String, double>{};
      for (final m in movements.where((m) => m.type == MovementType.expense)) {
        final key = m.categoryLabel;
        expenseByCategory[key] = (expenseByCategory[key] ?? 0) + m.amount;
      }

      // Convertir entidades a Map para PrintService
      final profitLossMap = analyticsState.profitLoss
          .map(
            (p) => {
              'year': p.year,
              'month': p.month,
              'revenue': p.revenue,
              'fixed_expenses': p.fixedExpenses,
              'variable_expenses': p.variableExpenses,
              'gross_profit': p.grossProfit,
            },
          )
          .toList();

      final topProductsMap = analyticsState.topProducts
          .map(
            (p) => {
              'product_key': p.productKey,
              'product_name': p.productName,
              'product_code': p.productCode,
              'times_sold': p.timesSold,
              'total_revenue': p.totalRevenue,
              'avg_price': p.avgPrice,
            },
          )
          .toList();

      final loansMap = payrollState.activeLoans
          .map(
            (l) => {
              'employee_name': l.employeeName ?? 'Empleado',
              'total_amount': l.totalAmount,
              'paid_amount': l.paidAmount,
              'remaining_amount': l.remainingAmount,
              'status': l.status,
            },
          )
          .toList();

      await PrintService.shareMonthlyReport(
        profitLoss: profitLossMap,
        topProducts: topProductsMap,
        activeLoans: loansMap,
        expenseByCategory: expenseByCategory,
        month: month,
        year: year,
      );

      messenger.hideCurrentSnackBar();
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error generando informe: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // ============================================================
  // TAB 1: ANALYTICS - DASHBOARD MEJORADO
  // ============================================================
  Widget _buildAnalyticsTab(AnalyticsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error cargando analytics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(analyticsProvider.notifier).loadAll();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
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

    return LayoutBuilder(
      builder: (context, pageConstraints) {
        final isMobile = pageConstraints.maxWidth < 600;
        final isTablet =
            pageConstraints.maxWidth >= 600 && pageConstraints.maxWidth < 1100;
        final gap = isMobile ? 10.0 : 12.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 10 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── SECCIÓN 1: KPIs PRINCIPALES ──
              _buildSectionTitle('Resumen General', Icons.dashboard),
              SizedBox(height: gap / 2),
              _buildKPIGrid(
                constraints: pageConstraints,
                gap: gap,
                cards: [
                  _buildKPICard(
                    'Ingresos Totales',
                    Helpers.formatCurrency(totalRevenue),
                    Icons.trending_up,
                    const Color(0xFF1565C0),
                    subtitle: 'Últimos 12 meses',
                    change: revenueChange,
                  ),
                  _buildKPICard(
                    'Utilidad Neta',
                    Helpers.formatCurrency(totalProfit),
                    Icons.account_balance_wallet,
                    totalProfit >= 0
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                    subtitle: 'Últimos 12 meses',
                    change: profitChange,
                  ),
                  _buildKPICard(
                    'Clientes Activos',
                    '$activeClients / $totalClients',
                    Icons.people,
                    const Color(0xFF7B1FA2),
                    subtitle: totalClients > 0
                        ? '${(activeClients / totalClients * 100).toStringAsFixed(0)}% del total'
                        : 'Sin clientes',
                  ),
                  _buildKPICard(
                    'Por Cobrar',
                    Helpers.formatCurrency(totalReceivables),
                    Icons.receipt_long,
                    const Color(0xFFF9A825),
                    subtitle: overdueAmount > 0
                        ? '${Helpers.formatCurrency(overdueAmount)} vencido'
                        : 'Todo al día',
                    isWarning: overdueAmount > 0,
                  ),
                  _buildKPICard(
                    'Ticket Promedio',
                    Helpers.formatCurrency(
                      state.healthSnapshot?.avgInvoiceValue ?? 0,
                    ),
                    Icons.receipt,
                    const Color(0xFF009688),
                    subtitle:
                        '${state.healthSnapshot?.totalInvoices ?? 0} facturas',
                  ),
                ],
              ),
              SizedBox(height: gap * 1.5),

              // ── SECCIÓN 2: SALUD DEL NEGOCIO ──
              _buildSectionTitle('Salud del Negocio', Icons.health_and_safety),
              SizedBox(height: gap / 2),
              _buildKPIGrid(
                constraints: pageConstraints,
                gap: gap,
                maxColumns: 4,
                cards: [
                  _buildHealthScoreCard(state),
                  _buildDSOCard(state),
                  _buildCEIGauge(state),
                ],
              ),
              SizedBox(height: gap),
              _buildDSOTrendChart(state),
              SizedBox(height: gap * 1.5),

              // ── SECCIÓN 3: TENDENCIAS ──
              _buildSectionTitle('Tendencias', Icons.show_chart),
              SizedBox(height: gap / 2),
              if (!isMobile) ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildRevenueExpensesTrendCard(state),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        flex: 2,
                        child: _buildClientDistributionCard(state),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _buildRevenueExpensesTrendCard(state),
                SizedBox(height: gap),
                _buildClientDistributionCard(state),
              ],
              SizedBox(height: gap * 1.5),

              // ── SECCIÓN 4: ESTADO DE RESULTADOS ──
              _buildSectionTitle('Estado de Resultados', Icons.bar_chart),
              SizedBox(height: gap / 2),
              _buildProfitLossDetailedCard(state),
              SizedBox(height: gap * 1.5),

              // ── SECCIÓN 5: ANÁLISIS ABC ──
              _buildSectionTitle(
                'Análisis ABC (Pareto)',
                Icons.stacked_bar_chart,
              ),
              SizedBox(height: gap / 2),
              _buildParetoABCChart(state),
              SizedBox(height: gap * 1.5),

              // ── SECCIÓN 6: RANKINGS ──
              _buildSectionTitle('Rankings', Icons.emoji_events),
              SizedBox(height: gap / 2),
              if (!isMobile) ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildTopClientsCardEnhanced(state)),
                      SizedBox(width: gap),
                      Expanded(child: _buildTopProductsCardEnhanced(state)),
                      if (!isTablet) ...[
                        SizedBox(width: gap),
                        Expanded(child: _buildAgingCard(state)),
                      ],
                    ],
                  ),
                ),
                if (isTablet) ...[
                  SizedBox(height: gap),
                  _buildAgingCard(state),
                ],
              ] else ...[
                _buildTopClientsCardEnhanced(state),
                SizedBox(height: gap),
                _buildTopProductsCardEnhanced(state),
                SizedBox(height: gap),
                _buildAgingCard(state),
              ],
              SizedBox(height: gap * 1.5),

              // ── SECCIÓN 7: INVENTARIO Y MATERIALES ──
              _buildSectionTitle('Inventario y Materiales', Icons.inventory_2),
              SizedBox(height: gap / 2),
              _buildCreditProfitInventoryChart(state),
              SizedBox(height: gap),
              if (!isMobile) ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildInventoryTurnoverCard(state)),
                      SizedBox(width: gap),
                      Expanded(child: _buildMaterialEfficiencyCard(state)),
                    ],
                  ),
                ),
              ] else ...[
                _buildInventoryTurnoverCard(state),
                SizedBox(height: gap),
                _buildMaterialEfficiencyCard(state),
              ],
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ── Helper: Título de sección ──
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper: KPI Grid adaptativo ──
  Widget _buildKPIGrid({
    required BoxConstraints constraints,
    required double gap,
    required List<Widget> cards,
    int maxColumns = 5,
  }) {
    final w = constraints.maxWidth;
    int cols;
    if (w >= 1100) {
      cols = maxColumns.clamp(1, 5);
    } else if (w >= 800) {
      cols = maxColumns.clamp(1, 4).clamp(1, 3);
    } else if (w >= 600) {
      cols = 2;
    } else {
      cols = 2;
    }
    final cardWidth = (w - gap * (cols - 1)) / cols;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
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
            color: const Color(0xFF000000).withValues(alpha: 0.05),
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
                color: isGood
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFF9A825),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              color: isGood ? const Color(0xFF388E3C) : const Color(0xFFF57C00),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isGood ? Icons.check_circle : Icons.warning,
                size: 14,
                color: isGood
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFF9A825),
              ),
              const SizedBox(width: 4),
              Text(
                isGood
                    ? 'Dentro de meta (≤$dsoTarget días)'
                    : 'Sobre meta (>$dsoTarget días)',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation(
                dso <= 30
                    ? const Color(0xFF2E7D32)
                    : (dso <= 45
                          ? const Color(0xFFF9A825)
                          : const Color(0xFFC62828)),
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
      if (cei >= 90) return const Color(0xFF2E7D32);
      if (cei >= 80) return const Color(0xFF1565C0);
      if (cei >= 70) return const Color(0xFFF9A825);
      return const Color(0xFFC62828);
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
            color: const Color(0xFF000000).withValues(alpha: 0.05),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      const Color(0xFFC62828),
                      const Color(0xFFF9A825),
                      const Color(0xFF1565C0),
                      const Color(0xFF2E7D32),
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
                    color: const Color(0xFF000000),
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
                style: TextStyle(
                  fontSize: 8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '50%',
                style: TextStyle(
                  fontSize: 8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '100%',
                style: TextStyle(
                  fontSize: 8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
                color: const Color(0xFFC62828).withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'Meta 30d',
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: !hasData
                ? Center(
                    child: Text(
                      'Sin datos de DSO',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          strokeWidth: 1,
                        ),
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                            color: const Color(
                              0xFFC62828,
                            ).withValues(alpha: 0.5),
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
                          color: const Color(0xFF1565C0),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, idx) {
                              final dso = dsoData[idx].dso;
                              return FlDotCirclePainter(
                                radius: 3,
                                color: dso <= 30
                                    ? const Color(0xFF2E7D32)
                                    : (dso <= 45
                                          ? const Color(0xFFF9A825)
                                          : const Color(0xFFC62828)),
                                strokeWidth: 1,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(
                              0xFF1565C0,
                            ).withValues(alpha: 0.1),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Análisis ABC (Pareto 80/20)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              _buildABCLegend('A', const Color(0xFF2E7D32), '80% valor'),
              _buildABCLegend('B', const Color(0xFFF9A825), '15% valor'),
              _buildABCLegend('C', const Color(0xFFC62828), '5% valor'),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 2,
                    color: const Color(0xFF7B1FA2),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '% Acum.',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: !hasData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bar_chart,
                          size: 48,
                          color: const Color(0xFFE0E0E0),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin datos de productos',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
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
                                    barColor = const Color(0xFF2E7D32);
                                    break;
                                  case 'B':
                                    barColor = const Color(0xFFF9A825);
                                    break;
                                  default:
                                    barColor = const Color(0xFFC62828);
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
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
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
                                          color: const Color(0xFFAB47BC),
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
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
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
                  const Color(0xFF2E7D32),
                ),
                _buildABCSummary(
                  'B',
                  abcData.where((p) => p.abcCategory == 'B').length,
                  abcData.length,
                  const Color(0xFFF9A825),
                ),
                _buildABCSummary(
                  'C',
                  abcData.where((p) => p.abcCategory == 'C').length,
                  abcData.length,
                  const Color(0xFFC62828),
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
        Text(
          desc,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
            color: const Color(0xFF000000).withValues(alpha: 0.05),
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
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                        : const Color(0xFFC62828).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 10,
                        color: change >= 0
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${change.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: change >= 0
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isWarning
                  ? const Color(0xFFF57C00)
                  : const Color(0xFF424242),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isWarning
                    ? const Color(0xFFF9A825)
                    : const Color(0xFF9E9E9E),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Tendencia de Ingresos vs Gastos',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              _buildLegendDot('Ingresos', const Color(0xFF1565C0)),
              _buildLegendDot('Gastos', const Color(0xFFC62828)),
              _buildLegendDot('Utilidad', const Color(0xFF2E7D32)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: !hasValidData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 48,
                          color: const Color(0xFFE0E0E0),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin datos de tendencia',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          strokeWidth: 1,
                        ),
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
                          color: const Color(0xFF1565C0),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(
                              0xFF1565C0,
                            ).withValues(alpha: 0.1),
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
                          color: const Color(0xFFC62828),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(
                              0xFFC62828,
                            ).withValues(alpha: 0.1),
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
                          color: const Color(0xFF2E7D32),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Estado de Clientes',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (!hasData)
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      size: 48,
                      color: const Color(0xFFE0E0E0),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sin datos de clientes',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
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
                        color: const Color(0xFF2E7D32),
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
                        color: const Color(0xFFF9A825),
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
                        color: const Color(0xFFC62828),
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
                        color: const Color(0xFF1565C0),
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
          const SizedBox(height: 8),
          // Leyenda
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildPieLegend(
                'Activos',
                const Color(0xFF2E7D32),
                active,
                total,
              ),
              _buildPieLegend(
                'Regulares',
                const Color(0xFFF9A825),
                regular,
                total,
              ),
              _buildPieLegend(
                'Inactivos',
                const Color(0xFFC62828),
                inactive,
                total,
              ),
              if (newClients > 0)
                _buildPieLegend(
                  'Nuevos',
                  const Color(0xFF1565C0),
                  newClients,
                  total,
                ),
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
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // Top Clientes mejorado
  Widget _buildTopClientsCardEnhanced(AnalyticsState state) {
    final topClients = state.customerMetrics.take(8).toList();
    final maxSpent = topClients.isNotEmpty ? topClients.first.totalSpent : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: const Color(0xFFFFA000),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Top Clientes',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'por ventas',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          topClients.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Sin datos')),
                )
              : Column(
                  children: List.generate(topClients.length, (index) {
                    final client = topClients[index];
                    final progress = maxSpent > 0
                        ? client.totalSpent / maxSpent
                        : 0.0;
                    final rankColors = [
                      const Color(0xFFFFA000),
                      const Color(0xFFBDBDBD),
                      const Color(0xFFA1887F),
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
                                  : const Color(0xFFF5F5F5),
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
                                    : const Color(0xFF757575),
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
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                                    valueColor: AlwaysStoppedAnimation(
                                      index == 0
                                          ? const Color(0xFFFFA000)
                                          : const Color(0xFF42A5F5),
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
                                  ? const Color(0xFFFFA000)
                                  : const Color(0xFF43A047),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
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
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: const Color(0xFF1E88E5), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Productos Estrella',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'por ingresos',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          products.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Sin datos')),
                )
              : Column(
                  children: List.generate(products.length, (index) {
                    final product = products[index];
                    final progress = maxRevenue > 0
                        ? product.totalRevenue / maxRevenue
                        : 0.0;
                    final barColor =
                        Colors.primaries[(index * 2) % Colors.primaries.length];

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
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLow,
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
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
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: const Color(0xFFFB8C00), size: 20),
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
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total por cobrar',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
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
          Column(
            children: [
              _buildAgingBar(
                'Vigente',
                current,
                total,
                const Color(0xFF2E7D32),
              ),
              _buildAgingBar(
                '1-30 días',
                d1_30,
                total,
                const Color(0xFFFBC02D),
              ),
              _buildAgingBar(
                '31-60 días',
                d31_60,
                total,
                const Color(0xFFF9A825),
              ),
              _buildAgingBar(
                '61-90 días',
                d61_90,
                total,
                const Color(0xFFFF5722),
              ),
              _buildAgingBar(
                '+90 días',
                over90,
                total,
                const Color(0xFFC62828),
              ),
            ],
          ),
          // Alerta si hay mucho vencido
          if (d61_90 + over90 > 0)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFC62828).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Color(0xFFC62828),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${Helpers.formatCurrency(d61_90 + over90)} crítico (+60 días)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFC62828),
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
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerLow,
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
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Estado de Resultados',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              // Resumen rápido
              _buildMiniStat(
                'Ingresos',
                Helpers.formatCurrency(totalRevenue),
                const Color(0xFF1565C0),
              ),
              _buildMiniStat(
                'Gastos',
                Helpers.formatCurrency(totalExpenses),
                const Color(0xFFC62828),
              ),
              _buildMiniStat(
                'Utilidad',
                Helpers.formatCurrency(totalProfit),
                totalProfit >= 0
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
              ),
              _buildMiniStat(
                'Margen',
                '${margin.toStringAsFixed(1)}%',
                const Color(0xFF7B1FA2),
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
                          color: const Color(0xFFE0E0E0),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin datos de ingresos/gastos',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                              color: const Color(0xFF42A5F5),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                              rodStackItems: [
                                BarChartRodStackItem(
                                  0,
                                  item.totalExpenses,
                                  const Color(0xFFE57373),
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
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
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendDot('Ingresos', const Color(0xFF42A5F5)),
              const SizedBox(width: 16),
              _buildLegendDot(
                'Gastos (dentro de barra)',
                const Color(0xFFE57373),
              ),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
  // NUEVAS GRÁFICAS - FASE 2 (KPIs Industriales)
  // ============================================================

  // Score de Salud del Negocio
  Widget _buildHealthScoreCard(AnalyticsState state) {
    final snapshot = state.healthSnapshot;
    final score = snapshot?.healthScore ?? 0;
    final label = snapshot?.healthLabel ?? 'Sin datos';

    Color getScoreColor() {
      if (score >= 80) return const Color(0xFF2E7D32);
      if (score >= 60) return const Color(0xFF1565C0);
      if (score >= 40) return const Color(0xFFF9A825);
      if (score >= 20) return const Color(0xFFFF5722);
      return const Color(0xFFC62828);
    }

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety, color: getScoreColor(), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Salud',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Tooltip(
                message: 'Score basado en cobros, inventario y mora',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Text(
              '$score',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: getScoreColor(),
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: getScoreColor().withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: getScoreColor(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation(getScoreColor()),
            ),
          ),
        ],
      ),
    );
  }

  // Gráfico: Crédito vs Ganancia vs Inventario (mensual)
  Widget _buildCreditProfitInventoryChart(AnalyticsState state) {
    final data = state.businessHealthTrend;
    final hasData =
        data.isNotEmpty &&
        data.any((d) => d.revenue > 0 || d.creditExtended > 0);

    // Calcular escalas para eje dual
    // Eje izquierdo: crédito, ingresos, ganancia
    double primaryMax = 0;
    for (final d in data) {
      final vals = [d.creditExtended, d.revenue, d.estimatedProfit];
      for (final v in vals) {
        if (v > primaryMax) primaryMax = v;
      }
    }

    // Eje derecho: Score de salud inventario (buenos - críticos)
    // Calcular max/min del score para normalizar
    int scoreMax = 0;
    int scoreMin = 0;
    for (final d in data) {
      if (d.stockHealthScore > scoreMax) scoreMax = d.stockHealthScore;
      if (d.stockHealthScore < scoreMin) scoreMin = d.stockHealthScore;
    }
    final scoreAbsMax = [
      scoreMax.abs(),
      scoreMin.abs(),
    ].reduce((a, b) => a > b ? a : b);

    // Normalizar score al rango del eje primario
    List<FlSpot> normalizeStockHealth() {
      if (scoreAbsMax == 0) {
        return data.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), primaryMax * 0.5);
        }).toList();
      }
      return data.asMap().entries.map((e) {
        // Mapear score de [-scoreAbsMax, +scoreAbsMax] a [0, primaryMax]
        final normalized =
            ((e.value.stockHealthScore + scoreAbsMax) / (scoreAbsMax * 2)) *
            primaryMax;
        return FlSpot(e.key.toDouble(), normalized);
      }).toList();
    }

    // Convertir valor normalizado de vuelta a score real para tooltip
    int denormalizeScore(double normalizedVal) {
      if (primaryMax == 0 || scoreAbsMax == 0) return 0;
      return ((normalizedVal / primaryMax) * (scoreAbsMax * 2) - scoreAbsMax)
          .round();
    }

    return Container(
      height: 420,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.compare_arrows,
                    color: Color(0xFF3F51B5),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Crédito vs Ganancia vs Salud Inventario',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              _buildLegendDot('Crédito Otorgado', const Color(0xFFC62828)),
              _buildLegendDot('Ingresos', const Color(0xFF2E7D32)),
              _buildLegendDot('Ganancia Est.', const Color(0xFF1565C0)),
              _buildLegendDot(
                'Salud Inventario (eje der.)',
                const Color(0xFFF9A825),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Summary numbers
          if (state.healthSnapshot != null)
            Row(
              children: [
                _buildMiniMetric(
                  'Crédito Activo',
                  state.healthSnapshot!.totalReceivables,
                  const Color(0xFFC62828),
                ),
                const SizedBox(width: 16),
                _buildMiniMetric(
                  'Ventas Totales',
                  state.healthSnapshot!.totalRevenue,
                  const Color(0xFF2E7D32),
                ),
                const SizedBox(width: 16),
                _buildMiniMetric(
                  'Productos Críticos',
                  (state.healthSnapshot!.lowStockProducts +
                          state.healthSnapshot!.outOfStockProducts)
                      .toDouble(),
                  const Color(0xFFF9A825),
                  isCurrency: false,
                ),
                const SizedBox(width: 16),
                _buildMiniMetric(
                  'Cobrado',
                  state.healthSnapshot!.totalCollected,
                  const Color(0xFF009688),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Expanded(
            child: !hasData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 48,
                          color: const Color(0xFFE0E0E0),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sin datos de ventas para comparar.\nCrea facturas para ver esta gráfica.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          strokeWidth: 1,
                        ),
                      ),
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
                                _formatCompact(value),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    data[idx].monthName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max || value == meta.min) {
                                return const SizedBox();
                              }
                              final score = denormalizeScore(value);
                              return Text(
                                '${score > 0 ? "+" : ""}$score',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFF9A825),
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        // Línea: Crédito otorgado (rojo)
                        LineChartBarData(
                          spots: data
                              .asMap()
                              .entries
                              .map(
                                (e) => FlSpot(
                                  e.key.toDouble(),
                                  e.value.creditExtended,
                                ),
                              )
                              .toList(),
                          isCurved: true,
                          color: const Color(0xFFC62828),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(
                              0xFFC62828,
                            ).withValues(alpha: 0.08),
                          ),
                        ),
                        // Línea: Ingresos (verde)
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
                          color: const Color(0xFF2E7D32),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                        // Línea: Ganancia estimada (azul, dashed)
                        LineChartBarData(
                          spots: data
                              .asMap()
                              .entries
                              .map(
                                (e) => FlSpot(
                                  e.key.toDouble(),
                                  e.value.estimatedProfit,
                                ),
                              )
                              .toList(),
                          isCurved: true,
                          color: const Color(0xFF1565C0),
                          barWidth: 2,
                          dashArray: [5, 5],
                          dotData: const FlDotData(show: false),
                        ),
                        // Línea: Salud Inventario (naranja) - normalizado al eje derecho
                        LineChartBarData(
                          spots: normalizeStockHealth(),
                          isCurved: true,
                          color: const Color(0xFFF9A825),
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 3,
                                  color: const Color(0xFFF9A825),
                                  strokeWidth: 1,
                                  strokeColor: Colors.white,
                                ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(
                              0xFFF9A825,
                            ).withValues(alpha: 0.10),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) {
                            return spots.map((spot) {
                              final labels = [
                                'Crédito',
                                'Ingresos',
                                'Ganancia',
                                'Salud Inv.',
                              ];
                              final colors = [
                                const Color(0xFFC62828),
                                const Color(0xFF2E7D32),
                                const Color(0xFF1565C0),
                                const Color(0xFFF9A825),
                              ];
                              // Para salud inventario mostrar score, no valor normalizado
                              if (spot.barIndex == 3) {
                                final score = denormalizeScore(spot.y);
                                final displayText =
                                    '${labels[spot.barIndex]}: ${score > 0 ? "+" : ""}$score';
                                return LineTooltipItem(
                                  displayText,
                                  TextStyle(
                                    color: colors[spot.barIndex],
                                    fontSize: 11,
                                  ),
                                );
                              }
                              final displayValue = spot.y;
                              final displayText =
                                  '${labels[spot.barIndex]}: ${Helpers.formatCurrency(displayValue)}';
                              return LineTooltipItem(
                                displayText,
                                TextStyle(
                                  color: colors[spot.barIndex],
                                  fontSize: 11,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(
    String label,
    double value,
    Color color, {
    bool isCurrency = true,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            isCurrency
                ? Helpers.formatCurrency(value)
                : value.toInt().toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCompact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }

  // Card: Rotación de Inventario de Productos
  Widget _buildInventoryTurnoverCard(AnalyticsState state) {
    final items = state.inventoryTurnover
        .where((i) => i.inventoryStatus != 'NORMAL')
        .toList();
    final hasData = items.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.autorenew, color: Color(0xFF009688), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Rotación de Inventario',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Tooltip(
                message:
                    'Veces que el inventario se renueva al año.\nMayor rotación = mejor eficiencia.',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          !hasData
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Sin productos en estado crítico ✓',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    Color statusColor;
                    IconData statusIcon;
                    switch (item.inventoryStatus) {
                      case 'SIN_STOCK':
                        statusColor = const Color(0xFFC62828);
                        statusIcon = Icons.error;
                        break;
                      case 'STOCK_BAJO':
                        statusColor = const Color(0xFFF9A825);
                        statusIcon = Icons.warning;
                        break;
                      case 'SIN_MOVIMIENTO':
                        statusColor = const Color(0xFF9E9E9E);
                        statusIcon = Icons.pause_circle;
                        break;
                      case 'SOBREINVENTARIO':
                        statusColor = const Color(0xFF7B1FA2);
                        statusIcon = Icons.inventory_2;
                        break;
                      default:
                        statusColor = const Color(0xFF2E7D32);
                        statusIcon = Icons.check_circle;
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item.productCode,
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${item.annualTurnoverRate.toStringAsFixed(1)}x',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: item.annualTurnoverRate > 4
                                        ? const Color(0xFF2E7D32)
                                        : (item.annualTurnoverRate > 1
                                              ? const Color(0xFFF9A825)
                                              : const Color(0xFFC62828)),
                                  ),
                                ),
                                Text(
                                  'Rotación/año',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.daysOfInventory >= 999
                                      ? '∞'
                                      : '${item.daysOfInventory}d',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: item.daysOfInventory > 180
                                        ? const Color(0xFFC62828)
                                        : (item.daysOfInventory > 90
                                              ? const Color(0xFFF9A825)
                                              : const Color(0xFF2E7D32)),
                                  ),
                                ),
                                Text(
                                  'Días inv.',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Helpers.formatCurrency(item.stockValue),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Valor stock',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ],
      ),
    );
  }

  // Card: Eficiencia de Materia Prima
  Widget _buildMaterialEfficiencyCard(AnalyticsState state) {
    final items = state.materialEfficiency
        .where((i) => i.reorderStatus != 'NORMAL')
        .toList();
    final hasData = items.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.precision_manufacturing,
                color: Color(0xFF795548),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Eficiencia Materia Prima',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Tooltip(
                message:
                    'Consumo y duración estimada de materiales.\nSemáforo de reabastecimiento automático.',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          !hasData
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Sin materiales en estado crítico ✓',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    Color statusColor;
                    String statusLabel;
                    switch (item.reorderStatus) {
                      case 'URGENTE':
                        statusColor = const Color(0xFFC62828);
                        statusLabel = 'URGENTE';
                        break;
                      case 'CRITICO':
                        statusColor = const Color(0xFFFF5722);
                        statusLabel = 'CRÍTICO';
                        break;
                      case 'ALERTA':
                        statusColor = const Color(0xFFF9A825);
                        statusLabel = 'ALERTA';
                        break;
                      case 'BAJO':
                        statusColor = const Color(0xFFF9A825);
                        statusLabel = 'BAJO';
                        break;
                      default:
                        statusColor = const Color(0xFF2E7D32);
                        statusLabel = 'OK';
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 32,
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.materialName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${item.category ?? ''} · ${item.currentStock.toStringAsFixed(1)} ${item.unit ?? 'UND'}',
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  item.daysOfStockRemaining >= 999
                                      ? '∞'
                                      : '${item.daysOfStockRemaining}d',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: item.daysOfStockRemaining <= 7
                                        ? const Color(0xFFC62828)
                                        : (item.daysOfStockRemaining <= 15
                                              ? const Color(0xFFF9A825)
                                              : const Color(0xFF2E7D32)),
                                  ),
                                ),
                                Text(
                                  'Duración',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${item.dailyConsumptionRate.toStringAsFixed(1)}/${item.unit ?? 'd'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Consumo/día',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
        ],
      ),
    );
  } // ============================================================

  // TAB 2: INVENTARIO
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
    final totalStockValue =
        (state.summary['totalStockSaleValue'] ?? 0.0) as double;
    final totalPotentialProfit =
        (state.summary['totalPotentialProfit'] ?? 0.0) as double;
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                  const Color(0xFFC62828),
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
                  const Color(0xFFF9A825),
                  subtitle: 'por debajo del mínimo',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Sin Stock',
                  '$outOfStock',
                  Icons.remove_shopping_cart,
                  const Color(0xFFC62828),
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
                  const Color(0xFF1565C0),
                  subtitle: 'inversión en inventario',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Valor Stock (Venta)',
                  Helpers.formatCurrency(totalStockValue),
                  Icons.sell,
                  const Color(0xFF2E7D32),
                  subtitle: 'valor de venta potencial',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKPICard(
                  'Ganancia Potencial',
                  Helpers.formatCurrency(totalPotentialProfit),
                  Icons.trending_up,
                  totalPotentialProfit >= 0
                      ? const Color(0xFF009688)
                      : const Color(0xFFC62828),
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
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: const Color(0xFF66BB6A),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '¡Todo en orden!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay items con stock crítico en este momento',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
            color: const Color(0xFF000000).withValues(alpha: 0.05),
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
                      color: const Color(0xFFF57C00),
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
                    color: const Color(0xFFC62828).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.products.length} items críticos',
                    style: TextStyle(
                      color: const Color(0xFFD32F2F),
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
                    ? const Color(0xFF2E7D32)
                    : product.marginPercent > 15
                    ? const Color(0xFFF9A825)
                    : const Color(0xFFC62828);
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
                              ? const Color(0xFFF9A825).withValues(alpha: 0.1)
                              : const Color(0xFF1565C0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: product.itemType == 'material'
                                ? const Color(0xFFF57C00)
                                : const Color(0xFF1976D2),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${product.currentStock.toStringAsFixed(1)} ${product.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: product.isOutOfStock
                              ? const Color(0xFFC62828)
                              : product.isLowStock
                              ? const Color(0xFFF9A825)
                              : null,
                        ),
                      ),
                    ),
                    // Precio de compra/costo
                    DataCell(
                      Text(
                        Helpers.formatCurrency(product.costPrice),
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF616161),
                        ),
                      ),
                    ),
                    // Precio de venta
                    DataCell(
                      Text(
                        Helpers.formatCurrency(product.unitPrice),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Margen %
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                          color: product.profitPerUnit > 0
                              ? const Color(0xFF388E3C)
                              : const Color(0xFFC62828),
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
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Costo: ${Helpers.formatCurrency(product.stockCostValue)}',
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
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: product.isOutOfStock
                              ? const Color(0xFFC62828).withValues(alpha: 0.1)
                              : product.isLowStock
                              ? const Color(0xFFF9A825).withValues(alpha: 0.1)
                              : const Color(0xFF2E7D32).withValues(alpha: 0.1),
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
                                ? const Color(0xFFC62828)
                                : product.isLowStock
                                ? const Color(0xFFF9A825)
                                : const Color(0xFF2E7D32),
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
  // TAB 3: COBRANZAS
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Cuentas por Cobrar',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
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
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // KPIs
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                _buildKPICard(
                  'Total por Cobrar',
                  Helpers.formatCurrency(totalDebt),
                  Icons.account_balance_wallet,
                  const Color(0xFF1565C0),
                  subtitle: '${receivablesState.receivables.length} clientes',
                ),
                _buildKPICard(
                  'Vencidas',
                  Helpers.formatCurrency(overdueTotal),
                  Icons.warning,
                  const Color(0xFFC62828),
                  subtitle: 'deuda vencida',
                ),
                _buildKPICard(
                  'Al Día',
                  Helpers.formatCurrency(currentTotal),
                  Icons.check_circle,
                  const Color(0xFF2E7D32),
                  subtitle: '0-30 días',
                ),
                _buildKPICard(
                  'Clientes Morosos',
                  '${receivablesState.receivables.where((r) => r.overdueInvoices > 0).length}',
                  Icons.person_off,
                  const Color(0xFFF9A825),
                  subtitle: 'con deuda',
                ),
              ];
              if (constraints.maxWidth < 600) {
                final w = (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: cards
                      .map((c) => SizedBox(width: w, child: c))
                      .toList(),
                );
              }
              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[2]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[3]),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // Row con gráfico de aging y tabla
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return Column(
                  children: [
                    _buildAgingChart(analyticsState),
                    const SizedBox(height: 16),
                    _buildReceivablesTable(receivablesState),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildAgingChart(analyticsState)),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _buildReceivablesTable(receivablesState),
                  ),
                ],
              );
            },
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
        'color': const Color(0xFF2E7D32),
      },
      {
        'label': '1-30 días',
        'value': aging['1-30 days'] ?? 0,
        'color': const Color(0xFFF9A825),
      },
      {
        'label': '31-60 días',
        'value': aging['31-60 days'] ?? 0,
        'color': const Color(0xFFF9A825),
      },
      {
        'label': '61-90 días',
        'value': aging['61-90 days'] ?? 0,
        'color': const Color(0xFFFF5722),
      },
      {
        'label': '+90 días',
        'value': aging['over 90 days'] ?? 0,
        'color': const Color(0xFFC62828),
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
            color: const Color(0xFF000000).withValues(alpha: 0.05),
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
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Detalle de Cartera',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${state.receivables.length} clientes con deuda',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
                      color: Color(0xFFF9A825),
                    ),
                    label: const Text(
                      'Ver Mora',
                      style: TextStyle(color: Color(0xFFF9A825)),
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
                            style: const TextStyle(color: Color(0xFF2E7D32)),
                          ),
                        ),
                        DataCell(Text(Helpers.formatCurrency(r.overdue30))),
                        DataCell(Text(Helpers.formatCurrency(r.overdue60))),
                        DataCell(
                          Text(
                            Helpers.formatCurrency(r.overdue90),
                            style: TextStyle(
                              color: r.overdue90 > 0
                                  ? const Color(0xFFC62828)
                                  : null,
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
                                  ? const Color(
                                      0xFFC62828,
                                    ).withValues(alpha: 0.1)
                                  : const Color(
                                      0xFF2E7D32,
                                    ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              hasOverdue ? 'Vencido' : 'Al día',
                              style: TextStyle(
                                color: hasOverdue
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFF2E7D32),
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
                                      color: const Color(
                                        0xFFF9A825,
                                      ).withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.notification_important,
                                      color: Color(0xFFF9A825),
                                      size: 18,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF2E7D32),
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
  // TAB 4: MORA E INTERESES
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selector de tasa de interés
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final moraCards = [
                _buildKPICard(
                  'Deuda Vencida',
                  Helpers.formatCurrency(debtState.totalOverdue),
                  Icons.money_off,
                  const Color(0xFFC62828),
                  subtitle: '${debtState.overdueDebts.length} facturas',
                ),
                _buildKPICard(
                  'Intereses Acumulados',
                  Helpers.formatCurrency(debtState.totalInterest),
                  Icons.trending_up,
                  const Color(0xFFF9A825),
                  subtitle: 'por mora',
                ),
                _buildKPICard(
                  'Total con Intereses',
                  Helpers.formatCurrency(debtState.totalWithInterest),
                  Icons.account_balance,
                  Theme.of(context).colorScheme.primary,
                  subtitle: 'deuda total',
                ),
                _buildKPICard(
                  'Clientes en Mora',
                  '${debtsOver30.length}',
                  Icons.person_off,
                  const Color(0xFFFF5722),
                  subtitle: '>30 días',
                ),
              ];
              if (constraints.maxWidth < 600) {
                final w = (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: moraCards
                      .map((c) => SizedBox(width: w, child: c))
                      .toList(),
                );
              }
              return Row(
                children: [
                  Expanded(child: moraCards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: moraCards[1]),
                  const SizedBox(width: 16),
                  Expanded(child: moraCards[2]),
                  const SizedBox(width: 16),
                  Expanded(child: moraCards[3]),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Alerta de notificaciones
          if (debtState.debtsNeedingNotification.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9A825).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF9A825).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notification_important,
                    color: Color(0xFFF9A825),
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
                            color: Color(0xFFF9A825),
                          ),
                        ),
                        Text(
                          '${debtState.debtsNeedingNotification.length} clientes necesitan notificación de mora (>30 días)',
                          style: TextStyle(color: const Color(0xFF616161)),
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
                      backgroundColor: const Color(0xFFF9A825),
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
                  color: const Color(0xFF000000).withValues(alpha: 0.05),
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
                          color: const Color(0xFFC62828).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${debtsCritical.length} críticos (+60 días)',
                          style: const TextStyle(
                            color: Color(0xFFC62828),
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
                            color: Color(0xFF2E7D32),
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
                              return const Color(
                                0xFFC62828,
                              ).withValues(alpha: 0.05);
                            }
                            if (debt.daysOverdue > 30) {
                              return const Color(
                                0xFFF9A825,
                              ).withValues(alpha: 0.05);
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
                                  color: Color(0xFFF9A825),
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
                                        color: const Color(0xFFF9A825),
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
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
              color: const Color(0xFF1565C0).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1565C0).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF1565C0)),
                    SizedBox(width: 8),
                    Text(
                      'Configuración de Mora',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
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
                  style: TextStyle(color: const Color(0xFF616161), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getDaysColor(int days) {
    if (days <= 30) return const Color(0xFFF9A825);
    if (days <= 60) return const Color(0xFFF9A825);
    return const Color(0xFFC62828);
  }

  Widget _buildStatusBadge(String status, String label) {
    Color color;
    switch (status) {
      case 'vigente':
        color = const Color(0xFF2E7D32);
        break;
      case 'vencido':
        color = const Color(0xFFF9A825);
        break;
      case 'moroso':
        color = const Color(0xFFF9A825);
        break;
      case 'critico':
        color = const Color(0xFFC62828);
        break;
      default:
        color = const Color(0xFF9E9E9E);
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9A825),
            ),
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
            backgroundColor: AppColors.success,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF9A825),
            ),
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
            backgroundColor: success
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828),
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
              style: const TextStyle(color: Color(0xFFF9A825)),
            ),
            Text(
              'Nuevo total: ${Helpers.formatCurrency(debt.totalWithInterest)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9A825).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Color(0xFFF9A825), size: 20),
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
              backgroundColor: Theme.of(context).colorScheme.primary,
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
            backgroundColor: success
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  // ============================================================
  // TAB 5: FLUJO DE CAJA - DESGLOSE POR CATEGORÍA
  // ============================================================
  Widget _buildCashFlowTab() {
    return _CashFlowTabContent();
  }
}

class _CashFlowTabContent extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CashFlowTabContent> createState() =>
      _CashFlowTabContentState();
}

class _CashFlowTabContentState extends ConsumerState<_CashFlowTabContent> {
  DateTime _startDate = ColombiaTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = ColombiaTime.now();
  List<CashMovement> _movements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    setState(() => _isLoading = true);
    try {
      final movements = await AccountsDataSource.getMovementsByDateRange(
        _startDate,
        _endDate,
      );
      setState(() {
        _movements = movements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, double> _groupByCategory(MovementType type) {
    final result = <String, double>{};
    for (final m in _movements.where((m) => m.type == type)) {
      final key = m.categoryLabel;
      result[key] = (result[key] ?? 0) + m.amount;
    }
    return result;
  }

  // _catLabel ya no es necesario: las claves del Map son los labels directos

  static const _catColorMap = <String, Color>{
    'Venta': Color(0xFF2E7D32),
    'Cobranza': Color(0xFF009688),
    'Pago Préstamo': Color(0xFF81C784),
    'Otros Ingresos': Color(0xFF81C784),
    'Cuidado Personal': Color(0xFFE91E63),
    'Servicios Públicos': Color(0xFF7B1FA2),
    'Papelería': Color(0xFF3F51B5),
    'Nómina': Color(0xFFFF5722),
    'Impuestos': Color(0xFFC62828),
    'Consumibles': Color(0xFF5C6BC0),
    'Transporte': Color(0xFFFFA726),
    'Gastos Reducibles': Color(0xFF78909C),
    'Traslado Salida': Color(0xFFF9A825),
    'Traslado Entrada': Color(0xFF29B6F6),
  };

  static const _extraColors = [
    Color(0xFF8D6E63),
    Color(0xFF26A69A),
    Color(0xFFAB47BC),
    Color(0xFFEC407A),
    Color(0xFF66BB6A),
    Color(0xFF42A5F5),
    Color(0xFFEF5350),
    Color(0xFF7E57C2),
  ];

  Color _catColor(String label) {
    if (_catColorMap.containsKey(label)) return _catColorMap[label]!;
    // Categorías custom: asignar color por hash
    final idx = label.hashCode.abs() % _extraColors.length;
    return _extraColors[idx];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final expenses = _groupByCategory(MovementType.expense);
    final incomes = _groupByCategory(MovementType.income);
    final totalExpense = expenses.values.fold(0.0, (s, v) => s + v);
    final totalIncome = incomes.values.fold(0.0, (s, v) => s + v);
    final expenseEntries = expenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final incomeEntries = incomes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtro de fechas
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.date_range, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Período:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2025, 1, 1),
                        lastDate: ColombiaTime.now(),
                        initialDateRange: DateTimeRange(
                          start: _startDate,
                          end: _endDate,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked.start;
                          _endDate = picked.end;
                        });
                        _loadMovements();
                      }
                    },
                    child: Text(
                      '${Helpers.formatDate(_startDate)}  →  ${Helpers.formatDate(_endDate)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  // Resumen rápido
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ingresos: ${Formatters.currency(totalIncome)}',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Gastos: ${Formatters.currency(totalExpense)}',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (totalIncome - totalExpense) >= 0
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Neto: ${Formatters.currency(totalIncome - totalExpense)}',
                      style: TextStyle(
                        color: (totalIncome - totalExpense) >= 0
                            ? AppColors.success
                            : AppColors.danger,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gráfico de torta + tablas
          LayoutBuilder(
            builder: (context, constraints) {
              final gastoCard = Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            color: AppColors.danger,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Gastos por Categoría',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                          Text(
                            Formatters.currency(totalExpense),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      if (expenseEntries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Sin gastos en este período'),
                          ),
                        )
                      else ...[
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: expenseEntries.map((e) {
                                final pct = totalExpense > 0
                                    ? (e.value / totalExpense * 100)
                                    : 0.0;
                                return PieChartSectionData(
                                  value: e.value,
                                  color: _catColor(e.key),
                                  title: '${pct.toStringAsFixed(0)}%',
                                  titleStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  radius: 80,
                                );
                              }).toList(),
                              sectionsSpace: 2,
                              centerSpaceRadius: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...expenseEntries.map((e) {
                          final pct = totalExpense > 0
                              ? (e.value / totalExpense * 100)
                              : 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _catColor(e.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e.key,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  Formatters.currency(e.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 45,
                                  child: Text(
                                    '${pct.toStringAsFixed(1)}%',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
              final ingresoCard = Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            color: AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ingresos por Categoría',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                          Text(
                            Formatters.currency(totalIncome),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      if (incomeEntries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('Sin ingresos en este período'),
                          ),
                        )
                      else ...[
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: incomeEntries.map((e) {
                                final pct = totalIncome > 0
                                    ? (e.value / totalIncome * 100)
                                    : 0.0;
                                return PieChartSectionData(
                                  value: e.value,
                                  color: _catColor(e.key),
                                  title: '${pct.toStringAsFixed(0)}%',
                                  titleStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  radius: 80,
                                );
                              }).toList(),
                              sectionsSpace: 2,
                              centerSpaceRadius: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...incomeEntries.map((e) {
                          final pct = totalIncome > 0
                              ? (e.value / totalIncome * 100)
                              : 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _catColor(e.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e.key,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  Formatters.currency(e.value),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 45,
                                  child: Text(
                                    '${pct.toStringAsFixed(1)}%',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
              if (constraints.maxWidth < 600) {
                return Column(
                  children: [
                    gastoCard,
                    const SizedBox(height: 16),
                    ingresoCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: gastoCard),
                  const SizedBox(width: 16),
                  Expanded(child: ingresoCard),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Total movimientos
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceAround,
                children: [
                  _buildFlowStat(
                    'Total Movimientos',
                    '${_movements.length}',
                    AppColors.info,
                  ),
                  _buildFlowStat(
                    'Ingresos',
                    '${_movements.where((m) => m.type == MovementType.income).length}',
                    AppColors.success,
                  ),
                  _buildFlowStat(
                    'Gastos',
                    '${_movements.where((m) => m.type == MovementType.expense).length}',
                    AppColors.danger,
                  ),
                  _buildFlowStat(
                    'Traslados',
                    '${_movements.where((m) => m.type == MovementType.transfer).length}',
                    const Color(0xFFF9A825),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
      ..color = const Color(0xFF7B1FA2)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xFF7B1FA2)
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
      ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.3)
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

// ============================================================
// TAB: GASTOS POR EMPLEADOS (material_movements salidas)
// ============================================================
class _EmployeeExpensesTab extends ConsumerStatefulWidget {
  const _EmployeeExpensesTab();

  @override
  ConsumerState<_EmployeeExpensesTab> createState() =>
      _EmployeeExpensesTabState();
}

class _EmployeeExpensesTabState extends ConsumerState<_EmployeeExpensesTab> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  String? _filterEmployeeId;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      var q = InventoryDataSource.client
          .from('material_movements')
          .select(
            'id, quantity, reason, reference, created_at, material_id, previous_stock, new_stock, materials(name, unit, cost_price)',
          )
          .eq('type', 'salida')
          .like('reason', 'Retiro por empleado:%');

      if (_dateRange != null) {
        q = q
            .gte('created_at', ColombiaTime.toIso8601(_dateRange!.start))
            .lte(
              'created_at',
              ColombiaTime.toIso8601(
                _dateRange!.end.add(const Duration(days: 1)),
              ),
            );
      }

      final response = await q.order('created_at', ascending: false);
      setState(() {
        _records = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _extractEmployeeName(String? reason) {
    if (reason == null) return '—';
    final prefix = 'Retiro por empleado: ';
    if (!reason.startsWith(prefix)) return reason;
    final rest = reason.substring(prefix.length);
    final dashIdx = rest.indexOf(' — ');
    return dashIdx >= 0 ? rest.substring(0, dashIdx) : rest;
  }

  String _extractNotes(String? reason) {
    if (reason == null) return '';
    final dashIdx = reason.indexOf(' — ');
    return dashIdx >= 0 ? reason.substring(dashIdx + 3) : '';
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filterEmployeeId == null) return _records;
    return _records
        .where(
          (r) =>
              _extractEmployeeName(r['reason'] as String?) ==
              _filterEmployee?.fullName,
        )
        .toList();
  }

  // Para filtrar por empleado seleccionado del provider
  dynamic get _filterEmployee {
    if (_filterEmployeeId == null) return null;
    final employees = ref.read(employeesProvider).employees;
    try {
      return employees.firstWhere((e) => e.id == _filterEmployeeId);
    } catch (_) {
      return null;
    }
  }

  double get _totalCost {
    return _filtered.fold(0.0, (sum, r) {
      final mat = r['materials'] as Map<String, dynamic>?;
      final cost = (mat?['cost_price'] as num?)?.toDouble() ?? 0;
      final qty = (r['quantity'] as num?)?.toDouble() ?? 0;
      return sum + cost * qty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider).employees;

    return Column(
      children: [
        // Filtros
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.person_remove_outlined,
                        color: Color(0xFFFF5722),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Retiros de Inventario por Empleados',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFFE64A19),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: narrow ? constraints.maxWidth : 220,
                        child: DropdownButtonFormField<String>(
                          value: _filterEmployeeId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Empleado',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Todos'),
                            ),
                            ...employees.map(
                              (e) => DropdownMenuItem(
                                value: e.id,
                                child: Text(
                                  e.fullName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _filterEmployeeId = v),
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          _dateRange == null
                              ? 'Todas las fechas'
                              : '${_dateRange!.start.day}/${_dateRange!.start.month} – ${_dateRange!.end.day}/${_dateRange!.end.month}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2024),
                            lastDate: ColombiaTime.now().add(
                              const Duration(days: 1),
                            ),
                            initialDateRange: _dateRange,
                          );
                          if (picked != null) {
                            setState(() => _dateRange = picked);
                            _loadRecords();
                          }
                        },
                      ),
                      if (_dateRange != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            setState(() => _dateRange = null);
                            _loadRecords();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Actualizar'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5722),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _loadRecords,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        // Resumen cards
        if (!_isLoading && _records.isNotEmpty)
          Container(
            color: const Color(0xFFFAFAFA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 760;
                if (narrow) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: _summaryCard(
                          'Total Retiros',
                          '${_filtered.length}',
                          const Color(0xFFFF5722),
                          Icons.move_to_inbox,
                        ),
                      ),
                      SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: _summaryCard(
                          'Costo Total',
                          '\$${_totalCost.toStringAsFixed(0)}',
                          const Color(0xFFD32F2F),
                          Icons.attach_money,
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _summaryCard(
                          'Empleados',
                          '${_filtered.map((r) => _extractEmployeeName(r['reason'] as String?)).toSet().length}',
                          const Color(0xFF607D8B),
                          Icons.people,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    _summaryCard(
                      'Total Retiros',
                      '${_filtered.length}',
                      const Color(0xFFFF5722),
                      Icons.move_to_inbox,
                    ),
                    const SizedBox(width: 12),
                    _summaryCard(
                      'Costo Total',
                      '\$${_totalCost.toStringAsFixed(0)}',
                      const Color(0xFFD32F2F),
                      Icons.attach_money,
                    ),
                    const SizedBox(width: 12),
                    _summaryCard(
                      'Empleados',
                      '${_filtered.map((r) => _extractEmployeeName(r['reason'] as String?)).toSet().length}',
                      const Color(0xFF607D8B),
                      Icons.people,
                    ),
                  ],
                );
              },
            ),
          ),
        // Tabla
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_remove_outlined,
                        size: 64,
                        color: const Color(0xFFE0E0E0),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay retiros registrados',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Usa "Salida por Empleado" en el inventario para registrar retiros',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _buildTable(),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722).withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                _th('Fecha', 110),
                _th('Empleado', null, flex: 2),
                _th('Material', null, flex: 2),
                _th('Cantidad', 90, align: TextAlign.right),
                _th('Costo Unit.', 90, align: TextAlign.right),
                _th('Total', 90, align: TextAlign.right),
                _th('Notas', null, flex: 2),
              ],
            ),
          ),
          // Rows
          Expanded(
            child: ListView.separated(
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              itemBuilder: (context, i) {
                final r = _filtered[i];
                final mat = r['materials'] as Map<String, dynamic>?;
                final matName = mat?['name'] as String? ?? '—';
                final matUnit = mat?['unit'] as String? ?? '';
                final costUnit = (mat?['cost_price'] as num?)?.toDouble() ?? 0;
                final qty = (r['quantity'] as num?)?.toDouble() ?? 0;
                final total = costUnit * qty;
                final empName = _extractEmployeeName(r['reason'] as String?);
                final notes = _extractNotes(r['reason'] as String?);
                final date = DateTime.tryParse(
                  r['created_at'] as String? ?? '',
                );
                final dateStr = date != null
                    ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                    : '—';

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(
                                0xFFFF5722,
                              ).withOpacity(0.15),
                              child: Text(
                                empName.isNotEmpty
                                    ? empName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: const Color(0xFFE64A19),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                empName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          matName,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          '${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)} $matUnit',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          '\$${costUnit.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          '\$${total.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD32F2F),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          notes,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
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

  Widget _th(
    String text,
    double? width, {
    int flex = 0,
    TextAlign align = TextAlign.left,
  }) {
    final child = Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
        color: const Color(0xFFD84315),
      ),
      textAlign: align,
    );
    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex, child: child);
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
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
}
