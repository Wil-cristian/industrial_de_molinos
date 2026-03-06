import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/datasources/iva_datasource.dart';
import '../../domain/entities/cash_movement.dart';
import '../../domain/entities/account.dart';
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
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
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
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shopping_bag,
            color: AppTheme.primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Compras y Gastos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  _dateRange != null
                      ? '${Formatters.date(_dateRange!.start)} — ${Formatters.date(_dateRange!.end)}'
                      : 'Todos los registros',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Total
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.errorColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Total Gastos',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.errorColor.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  Formatters.currency(_totalExpenses),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Date filter
          OutlinedButton.icon(
            onPressed: _showDateRangeFilter,
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(_dateRange != null ? 'Filtrado' : 'Filtrar fechas'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          if (_dateRange != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: () {
                setState(() => _dateRange = null);
                _loadData();
              },
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Quitar filtro',
              style: IconButton.styleFrom(foregroundColor: AppTheme.errorColor),
            ),
          ],
          const SizedBox(width: 8),
          // Scan button
          FilledButton.icon(
            onPressed: _scanInvoice,
            icon: const Icon(Icons.document_scanner, size: 18),
            label: const Text('Escanear Factura'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 8),
          // Refresh
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Row(
        children: _expenseCategories.map((cat) {
          final amount = byCategory[cat] ?? 0;
          final count = countByCat[cat] ?? 0;
          final isSelected = _selectedCategory == cat;
          final color = _categoryColors[cat] ?? Colors.grey;
          final icon = _categoryIcons[cat] ?? Icons.category;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = isSelected ? null : cat;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade200,
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
                        color: isSelected ? color : Colors.grey[700],
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
                        color: isSelected ? color : Colors.black87,
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
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: AppTheme.primaryColor,
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
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              _selectedCategory != null
                  ? 'No hay gastos en "${_categoryLabel(_selectedCategory!)}"'
                  : 'No hay gastos registrados',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Escanea una factura o registra un gasto en Caja Diaria',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Formatters.currency(dayTotal),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorColor,
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
    final color = _categoryColors[m.category] ?? Colors.grey;
    final icon = _categoryIcons[m.category] ?? Icons.category;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
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
                      Text(
                        m.personName!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                  ],
                ),
                if (m.reference != null && m.reference!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Ref: ${m.reference}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
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
                  color: AppTheme.errorColor,
                ),
              ),
              Text(
                _accountName(m.accountId),
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
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
            Icon(Icons.receipt, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No hay facturas IVA de compra',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4),
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
                        Text(
                          inv.invoiceNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (inv.companyDocument != null &&
                            inv.companyDocument!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            'NIT: ${inv.companyDocument}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    Formatters.date(inv.invoiceDate),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildInvDetail('Base', inv.baseAmount, Colors.blue),
                _buildInvDetail('IVA', inv.ivaAmount, Colors.orange),
                if (inv.rteFteAmount > 0)
                  _buildInvDetail('RteFte', inv.rteFteAmount, Colors.red),
                if (inv.reteIcaAmount > 0)
                  _buildInvDetail('ReteICA', inv.reteIcaAmount, Colors.purple),
                if (inv.hasReteiva && inv.reteivaAmount > 0)
                  _buildInvDetail('ReteIVA', inv.reteivaAmount, Colors.teal),
              ],
            ),
          ),
          // Row 3: CUFE if present
          if (inv.cufe != null && inv.cufe!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.fingerprint, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'CUFE: ${inv.cufe!.length > 40 ? '${inv.cufe!.substring(0, 40)}...' : inv.cufe}',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Colors.grey[500],
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
            Row(
              children: [
                const Text(
                  'Resumen IVA Compras',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 20),
                _buildIvaPill('Base', totalIvaBase, Colors.blue),
                const SizedBox(width: 8),
                _buildIvaPill('IVA', totalIva, Colors.orange),
                const SizedBox(width: 8),
                _buildIvaPill('RteFte', totalReteFte, Colors.red),
                const SizedBox(width: 8),
                _buildIvaPill('RteICA', totalReteIca, Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // Title
          const Text(
            'Desglose por Categoría',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
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
                final color = _categoryColors[cat] ?? Colors.grey;
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
                            color: amount > 0 ? color : Colors.grey[400],
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
                            color: Colors.grey[700],
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
                              color: Colors.grey[500],
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
  //  ACTIONS
  // ═══════════════════════════════════════════════════════════
  Future<void> _scanInvoice() async {
    final period = await InvoiceScanDialog.show(context);
    if (period != null && mounted) {
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
