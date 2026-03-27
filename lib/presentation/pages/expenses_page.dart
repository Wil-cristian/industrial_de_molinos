import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/datasources/ai_assistant_datasource.dart';
import '../../data/datasources/iva_datasource.dart';
import '../../domain/entities/cash_movement.dart';
import '../../domain/entities/account.dart';
import '../widgets/expense_scan_dialog.dart';
import '../widgets/invoice_scan_dialog.dart';

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isActive = false;

  // Data
  List<CashMovement> _allExpenses = [];
  List<IvaInvoice> _ivaInvoices = [];
  List<Account> _accounts = [];

  // Filters
  DateTimeRange? _dateRange;
  MovementCategory? _selectedCategory;

  // Category config
  static const _expenseCategories = [
    MovementCategory.consumibles,
    MovementCategory.servicios_publicos,
    MovementCategory.papeleria,
    MovementCategory.nomina,
    MovementCategory.impuestos,
    MovementCategory.cuidado_personal,
    MovementCategory.transporte,
    MovementCategory.gastos_reducibles,
  ];

  static const _categoryIcons = <MovementCategory, IconData>{
    MovementCategory.consumibles: Icons.inventory_2,
    MovementCategory.servicios_publicos: Icons.electrical_services,
    MovementCategory.papeleria: Icons.description,
    MovementCategory.nomina: Icons.badge,
    MovementCategory.impuestos: Icons.account_balance,
    MovementCategory.cuidado_personal: Icons.health_and_safety,
    MovementCategory.transporte: Icons.local_shipping,
    MovementCategory.gastos_reducibles: Icons.receipt_long,
  };

  static const _categoryColors = <MovementCategory, Color>{
    MovementCategory.consumibles: Color(0xFF5C6BC0),
    MovementCategory.servicios_publicos: Color(0xFF26A69A),
    MovementCategory.papeleria: Color(0xFFEF5350),
    MovementCategory.nomina: Color(0xFF42A5F5),
    MovementCategory.impuestos: Color(0xFFAB47BC),
    MovementCategory.cuidado_personal: Color(0xFF66BB6A),
    MovementCategory.transporte: Color(0xFFFFA726),
    MovementCategory.gastos_reducibles: Color(0xFF78909C),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        _dateRange != null
            ? AccountsDataSource.getMovementsByDateRange(
                _dateRange!.start,
                _dateRange!.end,
              )
            : AccountsDataSource.getAllMovements(),
        IvaDataSource.getInvoices(type: 'COMPRA'),
        AccountsDataSource.getAllAccounts(),
      ]);

      setState(() {
        final allMovements = futures[0] as List<CashMovement>;
        _allExpenses = allMovements
            .where((m) => m.type == MovementType.expense)
            .toList();
        _ivaInvoices = futures[1] as List<IvaInvoice>;
        _accounts = futures[2] as List<Account>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<CashMovement> get _filteredExpenses {
    if (_selectedCategory == null) return _allExpenses;
    return _allExpenses.where((m) => m.category == _selectedCategory).toList();
  }

  double get _totalExpenses =>
      _allExpenses.fold(0.0, (sum, m) => sum + m.amount);

  Map<MovementCategory, double> get _expenseByCategory {
    final result = <MovementCategory, double>{};
    for (final m in _allExpenses) {
      result[m.category] = (result[m.category] ?? 0) + m.amount;
    }
    return result;
  }

  Map<MovementCategory, int> get _countByCategory {
    final result = <MovementCategory, int>{};
    for (final m in _allExpenses) {
      result[m.category] = (result[m.category] ?? 0) + 1;
    }
    return result;
  }

  String _accountName(String accountId) {
    try {
      return _accounts.firstWhere((a) => a.id == accountId).name;
    } catch (_) {
      return 'Cuenta';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-reload when navigating to this page
    final location = GoRouterState.of(context).uri.path;
    if (location == '/expenses' && !_isActive) {
      _isActive = true;
      _loadData();
    } else if (location != '/expenses') {
      _isActive = false;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        _buildCategoryCards(),
                        _buildTabBar(),
                        Expanded(child: _buildTabContent()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_bag,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compras y Gastos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _dateRange != null
                          ? '${Formatters.date(_dateRange!.start)} — ${Formatters.date(_dateRange!.end)}'
                          : 'Todos los registros',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total Gastos',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.danger.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      Formatters.currency(_totalExpenses),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showDateRangeFilter,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(_dateRange != null ? 'Filtrado' : 'Filtrar fechas'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              if (_dateRange != null)
                IconButton(
                  onPressed: () {
                    setState(() => _dateRange = null);
                    _loadData();
                  },
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Quitar filtro',
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                ),
              FilledButton.icon(
                onPressed: _scanInvoice,
                icon: const Icon(Icons.document_scanner, size: 18),
                label: const Text('Escanear Factura'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _scanExpense,
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Escanear Gasto'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _allExpenses.isEmpty ? null : _analyzeWithAI,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Analizar con IA'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CATEGORY CARDS
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategoryCards() {
    final byCategory = _expenseByCategory;
    final countByCat = _countByCategory;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          int columns;
          if (maxWidth >= 760) {
            columns = _expenseCategories.length; // all 8 in one row
          } else if (maxWidth >= 520) {
            columns = 4;
          } else {
            columns = 2;
          }
          const spacing = 6.0;
          final cardWidth = (maxWidth - (spacing * (columns - 1))) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: _expenseCategories.map((cat) {
              final amount = byCategory[cat] ?? 0;
              final count = countByCat[cat] ?? 0;
              final isSelected = _selectedCategory == cat;
              final color = _categoryColors[cat] ?? const Color(0xFF9E9E9E);
              final icon = _categoryIcons[cat] ?? Icons.category;

              return SizedBox(
                width: cardWidth,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = isSelected ? null : cat;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.25),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, size: 14, color: color),
                            if (count > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _categoryLabel(cat),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? color
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.currency(amount),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? color
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TABS
  // ═══════════════════════════════════════════════════════════
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        indicatorColor: Theme.of(context).colorScheme.primary,
        indicatorWeight: 3,
        tabs: [
          Tab(
            icon: const Icon(Icons.list_alt, size: 16),
            text: 'Movimientos (${_filteredExpenses.length})',
          ),
          Tab(
            icon: const Icon(Icons.receipt, size: 16),
            text: 'Facturas IVA (${_ivaInvoices.length})',
          ),
          const Tab(icon: Icon(Icons.pie_chart, size: 16), text: 'Resumen'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildMovementsTab(),
        _buildIvaInvoicesTab(),
        _buildSummaryTab(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TAB: MOVIMIENTOS
  // ═══════════════════════════════════════════════════════════
  Widget _buildMovementsTab() {
    final expenses = _filteredExpenses;
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedCategory != null
                  ? 'No hay gastos en "${_categoryLabel(_selectedCategory!)}"'
                  : 'No hay gastos registrados',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escanea una factura o registra un gasto en Caja Diaria',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Group by date
    final grouped = <String, List<CashMovement>>{};
    for (final m in expenses) {
      final key = Formatters.date(m.date);
      grouped.putIfAbsent(key, () => []).add(m);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final items = grouped[dateKey]!;
        final dayTotal = items.fold(0.0, (sum, m) => sum + m.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: EdgeInsets.only(bottom: 8, top: index > 0 ? 16 : 0),
              child: Row(
                children: [
                  Text(
                    dateKey,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Formatters.currency(dayTotal),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
            // Movement cards
            ...items.map((m) => _buildMovementCard(m)),
          ],
        );
      },
    );
  }

  Widget _buildMovementCard(CashMovement m) {
    final color = _categoryColors[m.category] ?? const Color(0xFF9E9E9E);
    final icon = _categoryIcons[m.category] ?? Icons.category;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        m.categoryLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (m.personName != null && m.personName!.isNotEmpty)
                      Flexible(
                        child: Text(
                          m.personName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                if (m.reference != null && m.reference!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Ref: ${m.reference}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.currency(m.amount),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
              Text(
                _accountName(m.accountId),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TAB: FACTURAS IVA
  // ═══════════════════════════════════════════════════════════
  Widget _buildIvaInvoicesTab() {
    if (_ivaInvoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt,
              size: 64,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay facturas IVA de compra',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _scanInvoice,
              icon: const Icon(Icons.document_scanner, size: 18),
              label: const Text('Escanear primera factura'),
              style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _ivaInvoices.length,
      itemBuilder: (context, index) {
        final inv = _ivaInvoices[index];
        return _buildIvaInvoiceCard(inv);
      },
    );
  }

  Widget _buildIvaInvoiceCard(IvaInvoice inv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Company + number + total
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt,
                  size: 20,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.company,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            inv.invoiceNumber,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (inv.companyDocument != null &&
                            inv.companyDocument!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'NIT: ${inv.companyDocument}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(inv.totalAmount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    Formatters.date(inv.invoiceDate),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Breakdown
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildInvDetail('Base', inv.baseAmount, AppColors.info),
                _buildInvDetail('IVA', inv.ivaAmount, AppColors.warning),
                if (inv.rteFteAmount > 0)
                  _buildInvDetail('RteFte', inv.rteFteAmount, AppColors.danger),
                if (inv.reteIcaAmount > 0)
                  _buildInvDetail(
                    'ReteICA',
                    inv.reteIcaAmount,
                    const Color(0xFF7B1FA2),
                  ),
                if (inv.hasReteiva && inv.reteivaAmount > 0)
                  _buildInvDetail(
                    'ReteIVA',
                    inv.reteivaAmount,
                    const Color(0xFF009688),
                  ),
              ],
            ),
          ),
          // Row 3: CUFE if present
          if (inv.cufe != null && inv.cufe!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'CUFE: ${inv.cufe!.length > 40 ? '${inv.cufe!.substring(0, 40)}...' : inv.cufe}',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildInvDetail(String label, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          Text(
            Formatters.currency(amount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TAB: RESUMEN
  // ═══════════════════════════════════════════════════════════
  Widget _buildSummaryTab() {
    final byCategory = _expenseByCategory;
    final countByCat = _countByCategory;
    final maxAmount = byCategory.values.fold(0.0, (a, b) => a > b ? a : b);

    final totalIvaBase = _ivaInvoices.fold(0.0, (s, i) => s + i.baseAmount);
    final totalIva = _ivaInvoices.fold(0.0, (s, i) => s + i.ivaAmount);
    final totalReteFte = _ivaInvoices.fold(0.0, (s, i) => s + i.rteFteAmount);
    final totalReteIca = _ivaInvoices.fold(0.0, (s, i) => s + i.reteIcaAmount);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IVA Summary row
          if (_ivaInvoices.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Resumen IVA Compras',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                _buildIvaPill('Base', totalIvaBase, AppColors.info),
                _buildIvaPill('IVA', totalIva, AppColors.warning),
                _buildIvaPill('RteFte', totalReteFte, AppColors.danger),
                _buildIvaPill('RteICA', totalReteIca, const Color(0xFF7B1FA2)),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // Title
          Text(
            'Desglose por Categoría',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          // Vertical bar chart
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _expenseCategories.map((cat) {
                final amount = byCategory[cat] ?? 0;
                final count = countByCat[cat] ?? 0;
                final color = _categoryColors[cat] ?? const Color(0xFF9E9E9E);
                final icon = _categoryIcons[cat] ?? Icons.category;
                final pct = _totalExpenses > 0
                    ? (amount / _totalExpenses * 100)
                    : 0.0;
                final barFraction = maxAmount > 0 ? amount / maxAmount : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Amount label on top
                        Text(
                          Formatters.currency(amount),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: amount > 0
                                ? color
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (pct > 0)
                          Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 9, color: color),
                          ),
                        const SizedBox(height: 4),
                        // The bar
                        Flexible(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final barHeight =
                                  barFraction * constraints.maxHeight;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                width: double.infinity,
                                height: barHeight.clamp(
                                  4.0,
                                  constraints.maxHeight,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      color,
                                      color.withValues(alpha: 0.6),
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Icon + label below
                        Icon(icon, size: 16, color: color),
                        const SizedBox(height: 2),
                        Text(
                          _categoryLabel(cat),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (count > 0)
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIvaPill(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
          Text(
            Formatters.currency(amount),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  AI ANALYSIS
  // ═══════════════════════════════════════════════════════════
  String _buildExpenseSummaryForAI() {
    final buf = StringBuffer();
    final byCategory = _expenseByCategory;
    final countByCat = _countByCategory;
    final total = _totalExpenses;

    buf.writeln('=== DATOS DE GASTOS ===');
    if (_dateRange != null) {
      buf.writeln(
        'Período: ${Formatters.date(_dateRange!.start)} a ${Formatters.date(_dateRange!.end)}',
      );
    } else {
      buf.writeln('Período: Todos los registros');
    }
    buf.writeln('Total gastos: ${Formatters.currency(total)}');
    buf.writeln('Cantidad de movimientos: ${_allExpenses.length}');
    buf.writeln();
    buf.writeln('--- Desglose por Categoría ---');

    // Sort categories by amount descending
    final sorted = _expenseCategories.toList()
      ..sort((a, b) {
        final amtA = byCategory[a] ?? 0;
        final amtB = byCategory[b] ?? 0;
        return amtB.compareTo(amtA);
      });

    for (final cat in sorted) {
      final amount = byCategory[cat] ?? 0;
      final count = countByCat[cat] ?? 0;
      final pct = total > 0 ? (amount / total * 100) : 0.0;
      buf.writeln(
        '• ${_categoryLabel(cat)}: ${Formatters.currency(amount)} '
        '($count movimientos, ${pct.toStringAsFixed(1)}%)',
      );
    }

    // Top 10 biggest individual expenses
    final topExpenses = List<CashMovement>.from(_allExpenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final top = topExpenses.take(10).toList();
    if (top.isNotEmpty) {
      buf.writeln();
      buf.writeln('--- Top ${top.length} Gastos Más Grandes ---');
      for (final m in top) {
        buf.writeln(
          '• ${Formatters.currency(m.amount)} - ${m.description} '
          '(${m.categoryLabel}, ${Formatters.date(m.date)})',
        );
      }
    }

    // IVA summary if available
    if (_ivaInvoices.isNotEmpty) {
      final totalIvaBase = _ivaInvoices.fold(0.0, (s, i) => s + i.baseAmount);
      final totalIva = _ivaInvoices.fold(0.0, (s, i) => s + i.ivaAmount);
      buf.writeln();
      buf.writeln('--- Facturas IVA Compras ---');
      buf.writeln('Facturas registradas: ${_ivaInvoices.length}');
      buf.writeln('Base gravable total: ${Formatters.currency(totalIvaBase)}');
      buf.writeln('IVA total: ${Formatters.currency(totalIva)}');
    }

    // Monthly trend if we have data spanning multiple months
    final byMonth = <String, double>{};
    for (final m in _allExpenses) {
      final key = '${m.date.year}-${m.date.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + m.amount;
    }
    if (byMonth.length > 1) {
      final sortedMonths = byMonth.keys.toList()..sort();
      buf.writeln();
      buf.writeln('--- Tendencia Mensual ---');
      for (final month in sortedMonths) {
        buf.writeln('• $month: ${Formatters.currency(byMonth[month]!)}');
      }
    }

    return buf.toString();
  }

  Future<void> _analyzeWithAI() async {
    final summary = _buildExpenseSummaryForAI();
    final prompt =
        'Analiza los siguientes gastos de mi negocio '
        '(Industrial de Molinos). Dame insights útiles: '
        'qué categorías consumen más, si hay gastos inusuales, '
        'recomendaciones para reducir costos, y tendencias. '
        'Sé específico con los números.\n\n$summary';

    // Show dialog with loading, then result
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AiAnalysisDialog(prompt: prompt),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════
  Future<void> _scanInvoice() async {
    final period = await InvoiceScanDialog.show(context);
    if (period != null && mounted) {
      _loadData();
    }
  }

  Future<void> _scanExpense() async {
    final registered = await ExpenseScanDialog.show(context);
    if (registered == true && mounted) {
      _loadData();
    }
  }

  Future<void> _showDateRangeFilter() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange:
          _dateRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (range != null) {
      setState(() => _dateRange = range);
      _loadData();
    }
  }

  String _categoryLabel(MovementCategory cat) {
    switch (cat) {
      case MovementCategory.consumibles:
        return 'Consumibles';
      case MovementCategory.servicios_publicos:
        return 'Servicios Públicos';
      case MovementCategory.papeleria:
        return 'Papelería';
      case MovementCategory.nomina:
        return 'Nómina';
      case MovementCategory.impuestos:
        return 'Impuestos';
      case MovementCategory.cuidado_personal:
        return 'Cuidado Personal';
      case MovementCategory.transporte:
        return 'Transporte';
      case MovementCategory.gastos_reducibles:
        return 'Gastos Reducibles';
      default:
        return cat.name;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  AI ANALYSIS DIALOG
// ═══════════════════════════════════════════════════════════════
class _AiAnalysisDialog extends StatefulWidget {
  final String prompt;
  const _AiAnalysisDialog({required this.prompt});

  @override
  State<_AiAnalysisDialog> createState() => _AiAnalysisDialogState();
}

class _AiAnalysisDialogState extends State<_AiAnalysisDialog> {
  bool _loading = true;
  String _result = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    try {
      final response = await AiAssistantDatasource.sendMessage(
        message: widget.prompt,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (response.success) {
          _result = response.response;
        } else {
          _error = response.error;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error de conexión: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = width > 700 ? 600.0 : width * 0.9;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF00897B),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Análisis IA de Gastos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _loading
                              ? 'Analizando tus gastos...'
                              : 'Análisis completado',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_loading)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFF00897B),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'La IA está analizando todas las categorías\n'
                            'de gastos y buscando patrones...',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.danger,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SelectableText(
                        _result,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
            ),
            // Footer
            if (!_loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    if (_error != null)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _runAnalysis();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reintentar'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cerrar'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
