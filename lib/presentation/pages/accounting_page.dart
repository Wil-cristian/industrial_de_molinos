import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/accounting_provider.dart';
import '../../data/datasources/accounting_datasource.dart';

class AccountingPage extends ConsumerStatefulWidget {
  const AccountingPage({super.key});

  @override
  ConsumerState<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends ConsumerState<AccountingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedAccountCode;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });
    Future.microtask(() {
      ref.read(accountingProvider.notifier).loadAll();
    });
  }

  void _onTabChanged(int index) {
    final notifier = ref.read(accountingProvider.notifier);
    switch (index) {
      case 0: // Libro Diario
        notifier.loadJournalEntries(startDate: _startDate, endDate: _endDate);
        break;
      case 1: // Balance General
        notifier.loadBalanceGeneral();
        break;
      case 2: // Estado de Resultados
        notifier.loadEstadoResultados(desde: _startDate, hasta: _endDate);
        break;
      case 3: // Libro Mayor
        notifier.loadLibroMayor(_selectedAccountCode);
        break;
      case 4: // Balance de Comprobación
        notifier.loadBalanceComprobacion();
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(accountingProvider);

    // Auto-reload when this page becomes active (IndexedStack keeps pages alive)
    final location = GoRouterState.of(context).uri.path;
    if (location == '/accounting' && !_isActive) {
      _isActive = true;
      Future.microtask(() {
        if (mounted) ref.read(accountingProvider.notifier).loadAll();
      });
    } else if (location != '/accounting') {
      _isActive = false;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          // ── Header ──
          _buildHeader(state),
          // ── Contenido ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLibroDiario(state),
                _buildBalanceGeneral(state),
                _buildEstadoResultados(state),
                _buildLibroMayor(state),
                _buildBalanceComprobacion(state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════════════════════════

  Widget _buildHeader(AccountingState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          // Título + Acciones
          Row(
            children: [
              Icon(
                Icons.account_balance,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Contabilidad',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              // Total asientos badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.totalEntries} asientos',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // Filtro de fechas
              _buildDateFilter(),
              const SizedBox(width: 8),
              // Refresh
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () {
                  ref.read(accountingProvider.notifier).loadAll();
                },
                tooltip: 'Actualizar',
                visualDensity: VisualDensity.compact,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(
                icon: Icon(Icons.menu_book, size: 18),
                text: 'Libro Diario',
                height: 52,
              ),
              Tab(
                icon: Icon(Icons.account_balance_wallet, size: 18),
                text: 'Balance General',
                height: 52,
              ),
              Tab(
                icon: Icon(Icons.trending_up, size: 18),
                text: 'Estado de Resultados',
                height: 52,
              ),
              Tab(
                icon: Icon(Icons.library_books, size: 18),
                text: 'Libro Mayor',
                height: 52,
              ),
              Tab(
                icon: Icon(Icons.fact_check, size: 18),
                text: 'Balance Comprobación',
                height: 52,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    final hasFilter = _startDate != null || _endDate != null;
    return OutlinedButton.icon(
      onPressed: _showDateRangeDialog,
      icon: Icon(
        Icons.date_range,
        size: 16,
        color: hasFilter ? AppColors.success : Theme.of(context).colorScheme.primary,
      ),
      label: Text(
        hasFilter
            ? '${_startDate != null ? Formatters.date(_startDate!) : '...'} - ${_endDate != null ? Formatters.date(_endDate!) : '...'}'
            : 'Filtrar fechas',
        style: TextStyle(
          fontSize: 12,
          color: hasFilter ? AppColors.success : Theme.of(context).colorScheme.primary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        side: BorderSide(
          color: hasFilter ? AppColors.success : const Color(0xFFE0E0E0),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _showDateRangeDialog() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Theme.of(context).colorScheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _onTabChanged(_tabController.index);
    }
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: LIBRO DIARIO
  // ════════════════════════════════════════════════════════════

  Widget _buildLibroDiario(AccountingState state) {
    if (state.isLoading) return _loadingWidget();
    if (state.error != null) return _errorWidget(state.error!);
    if (state.journalEntries.isEmpty) {
      return _emptyWidget('No hay asientos contables');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: state.journalEntries.length,
      itemBuilder: (context, index) {
        final entry = state.journalEntries[index];
        return _JournalEntryCard(entry: entry);
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: BALANCE GENERAL
  // ════════════════════════════════════════════════════════════

  Widget _buildBalanceGeneral(AccountingState state) {
    if (state.isLoading) return _loadingWidget();
    if (state.error != null) return _errorWidget(state.error!);
    if (state.balanceGeneral.isEmpty) {
      return _emptyWidget('Sin datos de balance');
    }

    final activos = state.balanceGeneral
        .where((b) => b.tipo == 'asset')
        .toList();
    final pasivos = state.balanceGeneral
        .where((b) => b.tipo == 'liability')
        .toList();
    final patrimonio = state.balanceGeneral
        .where((b) => b.tipo == 'equity')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // ── Resumen ──
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Total Activos',
                  value: state.totalActivos,
                  color: AppColors.success,
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  title: 'Total Pasivos',
                  value: state.totalPasivos,
                  color: AppColors.danger,
                  icon: Icons.trending_down,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  title: 'Patrimonio',
                  value: state.totalPatrimonio,
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.account_balance,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Activos ──
          _BalanceSection(
            title: 'ACTIVOS',
            icon: Icons.arrow_upward,
            color: AppColors.success,
            items: activos,
          ),
          const SizedBox(height: 12),

          // ── Pasivos ──
          _BalanceSection(
            title: 'PASIVOS',
            icon: Icons.arrow_downward,
            color: AppColors.danger,
            items: pasivos,
          ),
          const SizedBox(height: 12),

          // ── Patrimonio ──
          _BalanceSection(
            title: 'PATRIMONIO',
            icon: Icons.star,
            color: Theme.of(context).colorScheme.primary,
            items: patrimonio,
          ),

          const SizedBox(height: 16),

          // ── Ecuación contable ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _EquationBlock(
                  'Activos',
                  state.totalActivos,
                  AppColors.success,
                ),
                const Text(
                  '=',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                _EquationBlock(
                  'Pasivos',
                  state.totalPasivos,
                  AppColors.danger,
                ),
                const Text(
                  '+',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                _EquationBlock(
                  'Patrimonio',
                  state.totalPatrimonio,
                  Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: ESTADO DE RESULTADOS
  // ════════════════════════════════════════════════════════════

  Widget _buildEstadoResultados(AccountingState state) {
    if (state.isLoading) return _loadingWidget();
    if (state.error != null) return _errorWidget(state.error!);
    if (state.estadoResultados.isEmpty) {
      return _emptyWidget('Sin datos de resultados');
    }

    final ingresos = state.estadoResultados
        .where((r) => r.tipo == 'income')
        .toList();
    final gastos = state.estadoResultados
        .where((r) => r.tipo == 'expense')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // ── Resumen ──
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Ingresos',
                  value: state.totalIngresos,
                  color: AppColors.success,
                  icon: Icons.arrow_circle_up,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  title: 'Gastos',
                  value: state.totalGastos,
                  color: AppColors.danger,
                  icon: Icons.arrow_circle_down,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  title: 'Utilidad Neta',
                  value: state.utilidadNeta,
                  color: state.utilidadNeta >= 0
                      ? AppColors.success
                      : AppColors.danger,
                  icon: Icons.trending_flat,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryCard(
                  title: 'Margen',
                  value: state.margenUtilidad,
                  color: AppColors.warning,
                  icon: Icons.percent,
                  isPercentage: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Ingresos ──
          _ResultSection(
            title: 'INGRESOS',
            items: ingresos,
            color: AppColors.success,
          ),
          const SizedBox(height: 12),

          // ── Gastos ──
          _ResultSection(
            title: 'GASTOS',
            items: gastos,
            color: AppColors.danger,
          ),
          const SizedBox(height: 16),

          // ── Utilidad Neta ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: state.utilidadNeta >= 0
                    ? [
                        AppColors.success,
                        AppColors.success.withValues(alpha: 0.7),
                      ]
                    : [
                        AppColors.danger,
                        AppColors.danger.withValues(alpha: 0.7),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  state.utilidadNeta >= 0 ? Icons.emoji_events : Icons.warning,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    const Text(
                      'UTILIDAD NETA DEL PERIODO',
                      style: TextStyle(
                        color: const Color(0xB3FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      Formatters.currency(state.utilidadNeta),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── P&L Mensual ──
          if (state.pylMensual.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMonthlyPLTable(state.pylMensual),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyPLTable(List<MonthlyPL> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Resultados Mensuales',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 36,
              columnSpacing: 20,
              horizontalMargin: 12,
              headingTextStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: const Color(0xFF616161),
              ),
              columns: const [
                DataColumn(label: Text('Mes')),
                DataColumn(label: Text('Ingresos'), numeric: true),
                DataColumn(label: Text('Gastos'), numeric: true),
                DataColumn(label: Text('Utilidad'), numeric: true),
                DataColumn(label: Text('Margen'), numeric: true),
              ],
              rows: items.map((m) {
                final utility = m.ingresos - m.gastos;
                final margin = m.ingresos > 0
                    ? (utility / m.ingresos) * 100
                    : 0.0;
                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        Formatters.date(m.mes),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    DataCell(
                      Text(
                        Formatters.currency(m.ingresos),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        Formatters.currency(m.gastos),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        Formatters.currency(utility),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: utility >= 0
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${margin.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12),
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

  // ════════════════════════════════════════════════════════════
  //  TAB 4: LIBRO MAYOR
  // ════════════════════════════════════════════════════════════

  Widget _buildLibroMayor(AccountingState state) {
    return Column(
      children: [
        // Selector de cuenta
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Icon(Icons.filter_list, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Cuenta:',
                style: TextStyle(fontSize: 13, color: const Color(0xFF616161)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedAccountCode,
                    isExpanded: true,
                    isDense: true,
                    hint: const Text(
                      'Todas las cuentas',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: const TextStyle(fontSize: 13, color: const Color(0xDD000000)),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas las cuentas'),
                      ),
                      ...state.chartOfAccounts.map(
                        (acc) => DropdownMenuItem(
                          value: acc.code,
                          child: Text('${acc.code} - ${acc.name}'),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedAccountCode = val);
                      ref.read(accountingProvider.notifier).loadLibroMayor(val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Contenido
        Expanded(
          child: state.isLoading
              ? _loadingWidget()
              : state.libroMayor.isEmpty
              ? _emptyWidget('Seleccione una cuenta o no hay movimientos')
              : _buildLedgerTable(state.libroMayor),
        ),
      ],
    );
  }

  Widget _buildLedgerTable(List<LedgerItem> items) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 38,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 38,
            columnSpacing: 16,
            horizontalMargin: 12,
            headingTextStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: const Color(0xFF616161),
            ),
            columns: const [
              DataColumn(label: Text('Fecha')),
              DataColumn(label: Text('N° Asiento')),
              DataColumn(label: Text('Cuenta')),
              DataColumn(label: Text('Descripción')),
              DataColumn(label: Text('Debe'), numeric: true),
              DataColumn(label: Text('Haber'), numeric: true),
              DataColumn(label: Text('Saldo'), numeric: true),
            ],
            rows: items.map((item) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      Formatters.date(item.fecha),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.asiento,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${item.codigo} ${item.cuenta}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(
                        item.descripcion,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.debe > 0 ? Formatters.currency(item.debe) : '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    Text(
                      item.haber > 0 ? Formatters.currency(item.haber) : '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    Text(
                      Formatters.currency(item.saldoAcumulado),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.saldoAcumulado >= 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 5: BALANCE DE COMPROBACIÓN
  // ════════════════════════════════════════════════════════════

  Widget _buildBalanceComprobacion(AccountingState state) {
    if (state.isLoading) return _loadingWidget();
    if (state.error != null) return _errorWidget(state.error!);
    if (state.balanceComprobacion.isEmpty) return _emptyWidget('Sin datos');

    double totalDebit = 0;
    double totalCredit = 0;
    double totalDebitBalance = 0;
    double totalCreditBalance = 0;
    for (final item in state.balanceComprobacion) {
      totalDebit += item.totalDebe;
      totalCredit += item.totalHaber;
      if (item.saldo >= 0) {
        totalDebitBalance += item.saldo;
      } else {
        totalCreditBalance += item.saldo.abs();
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            // Encabezado
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.fact_check,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Balance de Comprobación',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (totalDebit - totalCredit).abs() < 0.01
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      (totalDebit - totalCredit).abs() < 0.01
                          ? '✓ Cuadrado'
                          : '⚠ Descuadrado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (totalDebit - totalCredit).abs() < 0.01
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Tabla
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 38,
                dataRowMinHeight: 30,
                dataRowMaxHeight: 34,
                columnSpacing: 20,
                horizontalMargin: 12,
                headingTextStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: const Color(0xFF616161),
                ),
                columns: const [
                  DataColumn(label: Text('Código')),
                  DataColumn(label: Text('Cuenta')),
                  DataColumn(label: Text('Total Debe'), numeric: true),
                  DataColumn(label: Text('Total Haber'), numeric: true),
                  DataColumn(label: Text('Saldo Deudor'), numeric: true),
                  DataColumn(label: Text('Saldo Acreedor'), numeric: true),
                ],
                rows: [
                  ...state.balanceComprobacion.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            item.codigo,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.cuenta,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Text(
                            Formatters.currency(item.totalDebe),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Text(
                            Formatters.currency(item.totalHaber),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.saldo >= 0
                                ? Formatters.currency(item.saldo)
                                : '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.saldo < 0
                                ? Formatters.currency(item.saldo.abs())
                                : '',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                  // Fila de totales
                  DataRow(
                    color: WidgetStateProperty.all(
                      Theme.of(context).colorScheme.primaryContainer,
                    ),
                    cells: [
                      const DataCell(Text('')),
                      const DataCell(
                        Text(
                          'TOTALES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          Formatters.currency(totalDebit),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          Formatters.currency(totalCredit),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          Formatters.currency(totalDebitBalance),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          Formatters.currency(totalCreditBalance),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }

  // ════════════════════════════════════════════════════════════
  //  WIDGETS COMUNES
  // ════════════════════════════════════════════════════════════

  Widget _loadingWidget() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            'Cargando datos contables...',
            style: TextStyle(color: const Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }

  Widget _errorWidget(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          Text('Error: $error', style: TextStyle(color: AppColors.danger)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => ref.read(accountingProvider.notifier).loadAll(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _emptyWidget(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 64, color: const Color(0xFFE0E0E0)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'Los asientos se crean automáticamente\nal registrar movimientos de caja, facturas y pagos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  WIDGETS AUXILIARES
// ════════════════════════════════════════════════════════════

/// Card de asiento contable expandible
class _JournalEntryCard extends StatefulWidget {
  final JournalEntry entry;
  const _JournalEntryCard({required this.entry});

  @override
  State<_JournalEntryCard> createState() => _JournalEntryCardState();
}

class _JournalEntryCardState extends State<_JournalEntryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera
              Row(
                children: [
                  // Número de asiento
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e.entryNumber,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tipo referencia
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _referenceColor(
                        e.referenceType ?? '',
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.referenceTypeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _referenceColor(e.referenceType ?? ''),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Fecha
                  Text(
                    Formatters.dateTime(e.entryDate),
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  // Monto
                  Text(
                    Formatters.currency(e.totalDebit),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              // Descripción
              if (e.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  e.description,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  maxLines: _expanded ? null : 1,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
              ],
              // Líneas expandidas
              if (_expanded && e.lines.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Cabecera de líneas
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Cuenta',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'Debe',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        'Haber',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...e.lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            '${line.accountCode} - ${line.accountName}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            line.debit > 0
                                ? Formatters.currency(line.debit)
                                : '',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            line.credit > 0
                                ? Formatters.currency(line.credit)
                                : '',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Totales de líneas
                const Divider(height: 8),
                Row(
                  children: [
                    const Expanded(
                      flex: 3,
                      child: Text(
                        'TOTALES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        Formatters.currency(e.totalDebit),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        Formatters.currency(e.totalCredit),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _referenceColor(String type) {
    switch (type) {
      case 'cash_movement':
        return AppColors.warning;
      case 'payment':
        return AppColors.success;
      case 'invoice':
        return Theme.of(context).colorScheme.primary;
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

/// Summary card para totales
class _SummaryCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  final IconData icon;
  final bool isPercentage;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isPercentage
                ? '${value.toStringAsFixed(1)}%'
                : Formatters.currency(value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección de balance (activos, pasivos, patrimonio)
class _BalanceSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<BalanceItem> items;

  const _BalanceSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (s, i) => s + i.saldo);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  Formatters.currency(total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Items
          ...items.map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: const Color(0xFFF5F5F5))),
              ),
              child: Row(
                children: [
                  Text(
                    item.codigo,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.cuenta,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    Formatters.currency(item.saldo),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: item.saldo >= 0
                          ? const Color(0xDD000000)
                          : AppColors.danger,
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
}

/// Sección de resultados (ingresos o gastos)
class _ResultSection extends StatelessWidget {
  final String title;
  final List<ResultItem> items;
  final Color color;

  const _ResultSection({
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.fold<double>(0, (s, i) => s + i.monto);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const Spacer(),
                Text(
                  Formatters.currency(total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ...items.map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: const Color(0xFFF5F5F5))),
              ),
              child: Row(
                children: [
                  Text(
                    item.codigo,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.cuenta,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    Formatters.currency(item.monto),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
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
}

/// Bloque de ecuación contable
class _EquationBlock extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _EquationBlock(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(
          Formatters.currency(value),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
