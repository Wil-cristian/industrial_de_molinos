import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers/iva_provider.dart';
import '../../data/datasources/iva_datasource.dart';
import '../widgets/invoice_scan_dialog.dart';
import '../widgets/iva_sale_scan_dialog.dart';
import '../../core/utils/colombia_time.dart';

class IvaControlPage extends ConsumerStatefulWidget {
  const IvaControlPage({super.key});

  @override
  ConsumerState<IvaControlPage> createState() => _IvaControlPageState();
}

class _IvaControlPageState extends ConsumerState<IvaControlPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() {
      ref.read(ivaProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ivaProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(state),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFacturasTab(state),
                  _buildLiquidacionTab(state),
                  _buildCalculadoraTab(state),
                  _buildConfigTab(state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════════════════════════

  Widget _buildHeader(IvaState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Título + indicadores
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Control IVA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Régimen Simple de Tributación',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Selector de período — visible en todas las pestañas
              SizedBox(width: 200, child: _buildPeriodDropdown(state)),
              // Indicador resumen
              if (state.currentSettlement != null)
                _buildMiniSummary(state.currentSettlement!),
              FilledButton.icon(
                onPressed: () => _showScanCompraDialog(),
                icon: const Icon(Icons.document_scanner, size: 18),
                label: const Text('Escanear Compra'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showScanVentaDialog(),
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Escanear Venta'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
              if (state.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: const Color(0xFF9E9E9E),
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.list_alt, size: 16), text: 'Facturas'),
              Tab(icon: Icon(Icons.calculate, size: 16), text: 'Liquidación'),
              Tab(icon: Icon(Icons.functions, size: 16), text: 'Calculadora'),
              Tab(icon: Icon(Icons.settings, size: 16), text: 'Config'),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  ESCANEAR FACTURA CON IA
  // ════════════════════════════════════════════════════════════

  /// Botón COMPRA: abre el escáner completo (guarda en compras+IVA+inventario)
  Future<void> _showScanCompraDialog() async {
    final period = await InvoiceScanDialog.show(context);
    if (period != null && mounted) {
      ref.read(ivaProvider.notifier).changePeriod(period);
    }
  }

  /// Botón VENTA: abre el escáner de ventas (solo guarda en iva_invoices)
  Future<void> _showScanVentaDialog() async {
    final period = await IvaSaleScanDialog.show(context);
    if (period != null && mounted) {
      ref.read(ivaProvider.notifier).changePeriod(period);
    }
  }

  // Dropdown de período reutilizable en el header
  Widget _buildPeriodDropdown(IvaState state) {
    final periods = _generatePeriods();
    return DropdownButtonFormField<String>(
      value: periods.contains(state.selectedPeriod)
          ? state.selectedPeriod
          : null,
      decoration: const InputDecoration(
        labelText: 'Período',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      style: const TextStyle(fontSize: 13, color: Color(0xDD000000)),
      items: periods.map((p) {
        final parts = p.split('-');
        final year = parts[0];
        final bim = int.parse(parts[1]);
        return DropdownMenuItem(
          value: p,
          child: Text(
            '${getBimesterName(bim)} $year',
            style: const TextStyle(fontSize: 13),
          ),
        );
      }).toList(),
      onChanged: (v) {
        if (v != null) ref.read(ivaProvider.notifier).changePeriod(v);
      },
    );
  }

  Widget _buildMiniSummary(BimonthlySettlement s) {
    final isPositive = s.totalAPagar > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPositive
            ? AppColors.danger.withValues(alpha: 0.1)
            : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPositive
              ? AppColors.danger.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${s.bimesterName} ${s.year}',
            style: const TextStyle(fontSize: 9, color: Color(0xFF9E9E9E)),
          ),
          Text(
            _currencyFormat.format(s.totalAPagar),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isPositive ? AppColors.danger : AppColors.success,
            ),
          ),
          Text(
            isPositive ? 'A pagar' : 'A favor',
            style: TextStyle(
              fontSize: 9,
              color: isPositive ? AppColors.danger : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 1: FACTURAS IVA
  // ════════════════════════════════════════════════════════════

  Widget _buildFacturasTab(IvaState state) {
    return Column(
      children: [
        // Toolbar: selector periodo + filtro tipo + botón agregar
        _buildFacturasToolbar(state),
        // Lista de facturas
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.filteredInvoices.isEmpty
              ? _buildEmptyState()
              : _buildFacturasList(state),
        ),
      ],
    );
  }

  Widget _buildFacturasToolbar(IvaState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final tipoDropdown = DropdownButtonFormField<String?>(
          value: state.selectedType,
          decoration: const InputDecoration(
            labelText: 'Tipo',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Color(0xDD000000)),
          items: const [
            DropdownMenuItem(
              value: null,
              child: Text('Todos', style: TextStyle(fontSize: 13)),
            ),
            DropdownMenuItem(
              value: 'COMPRA',
              child: Text('Compras', style: TextStyle(fontSize: 13)),
            ),
            DropdownMenuItem(
              value: 'VENTA',
              child: Text('Ventas', style: TextStyle(fontSize: 13)),
            ),
          ],
          onChanged: (v) => ref.read(ivaProvider.notifier).filterByType(v),
        );
        final addButton = ElevatedButton.icon(
          onPressed: () => _showInvoiceDialog(null),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Agregar', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        );

        if (isMobile) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Column(
              children: [
                tipoDropdown,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildQuickSummary(state)),
                    const SizedBox(width: 8),
                    addButton,
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              SizedBox(width: 180, child: tipoDropdown),
              const SizedBox(width: 8),
              _buildQuickSummary(state),
              const SizedBox(width: 8),
              addButton,
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickSummary(IvaState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'IVA Ventas: ${_currencyFormat.format(state.totalIvaVentas)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'IVA Compras: ${_currencyFormat.format(state.totalIvaCompras)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long, size: 64, color: const Color(0xFFE0E0E0)),
          const SizedBox(height: 12),
          Text(
            'No hay facturas en este periodo',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showInvoiceDialog(null),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Agregar Factura'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacturasList(IvaState state) {
    final invoices = state.filteredInvoices;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: invoices.length,
      itemBuilder: (ctx, idx) => _buildInvoiceCard(invoices[idx]),
    );
  }

  Widget _buildInvoiceCard(IvaInvoice inv) {
    final isVenta = inv.invoiceType == 'VENTA';
    final color = isVenta ? AppColors.success : const Color(0xFF1565C0);
    final dateStr = DateFormat('dd/MM/yyyy').format(inv.invoiceDate);
    final hasExtras =
        inv.cufe != null ||
        inv.companyDocument != null ||
        inv.rteFteAmount > 0 ||
        inv.reteIcaAmount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: () => _showInvoiceDialog(inv),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  // Tipo badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      inv.invoiceType,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Número factura
                  SizedBox(
                    width: 100,
                    child: Text(
                      inv.invoiceNumber,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Fecha
                  SizedBox(
                    width: 80,
                    child: Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
                  // Empresa
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inv.company,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (inv.companyDocument != null &&
                            inv.companyDocument!.isNotEmpty)
                          Text(
                            'NIT: ${inv.companyDocument}',
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
                  // Base
                  SizedBox(
                    width: 100,
                    child: Text(
                      _currencyFormat.format(inv.baseAmount),
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  // IVA
                  SizedBox(
                    width: 90,
                    child: Text(
                      _currencyFormat.format(inv.ivaAmount),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  // Total
                  SizedBox(
                    width: 110,
                    child: Text(
                      _currencyFormat.format(inv.totalAmount),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  // Indicadores
                  if (inv.hasReteiva)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Tooltip(
                        message:
                            'ReteIVA: ${_currencyFormat.format(inv.reteivaAmount)}',
                        child: const Icon(
                          Icons.star,
                          size: 14,
                          color: Color(0xFFF9A825),
                        ),
                      ),
                    ),
                  // Delete
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Color(0xFFC62828),
                    ),
                    onPressed: () => _confirmDelete(inv),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
              // Extra info row (CUFE, retentions) for scanned invoices
              if (hasExtras)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 50),
                      if (inv.cufe != null && inv.cufe!.isNotEmpty)
                        Expanded(
                          child: Text(
                            'CUFE: ${inv.cufe!.length > 30 ? '${inv.cufe!.substring(0, 30)}...' : inv.cufe}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      if (inv.rteFteAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'RteFte: ${_currencyFormat.format(inv.rteFteAmount)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: const Color(0xFFF57C00),
                            ),
                          ),
                        ),
                      if (inv.reteIcaAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'ReteICA: ${_currencyFormat.format(inv.reteIcaAmount)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: const Color(0xFFAB47BC),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 2: LIQUIDACIÓN BIMESTRAL
  // ════════════════════════════════════════════════════════════

  Widget _buildLiquidacionTab(IvaState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botón liquidar periodo actual
          _buildLiquidacionActions(state),
          const SizedBox(height: 16),
          // Resultado de la liquidación actual
          if (state.currentSettlement != null)
            _buildSettlementDetail(state.currentSettlement!),
          const SizedBox(height: 16),
          // Historial de liquidaciones
          _buildSettlementsHistory(state),
        ],
      ),
    );
  }

  Widget _buildLiquidacionActions(IvaState state) {
    final period = state.selectedPeriod.isEmpty
        ? getBimonthlyPeriod(ColombiaTime.now())
        : state.selectedPeriod;
    final parts = period.split('-');
    final bimName = parts.length == 2
        ? '${getBimesterName(int.parse(parts[1]))} ${parts[0]}'
        : period;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.calculate,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Liquidar Bimestre',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Periodo: $bimName',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await ref
                    .read(ivaProvider.notifier)
                    .liquidarBimestre(period);
                if (result != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Liquidación: ${_currencyFormat.format(result.totalAPagar)} a pagar',
                      ),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Calcular'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementDetail(BimonthlySettlement s) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.summarize,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Liquidación ${s.bimesterName} ${s.year}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            // Ventas
            _buildSectionHeader('VENTAS', AppColors.success),
            _buildDetailRow('Base Ventas', s.baseVentas),
            _buildDetailRow(
              'IVA Ventas (19%)',
              s.ivaVentas,
              color: AppColors.success,
            ),
            const SizedBox(height: 8),
            // Compras
            _buildSectionHeader(
              'COMPRAS (Descontable)',
              const Color(0xFF1565C0),
            ),
            _buildDetailRow('Base Compras', s.baseCompras),
            _buildDetailRow(
              'IVA Compras (19%)',
              s.ivaCompras,
              color: const Color(0xFF1565C0),
            ),
            const Divider(height: 24),
            // Cálculos
            _buildSectionHeader(
              'LIQUIDACIÓN',
              Theme.of(context).colorScheme.primary,
            ),
            _buildDetailRow('IVA Neto (Ventas - Compras)', s.ivaNeto),
            _buildDetailRow(
              'Anticipo Simple (${(s.tarifaSimple * 100).toStringAsFixed(1)}% x Base Ventas)',
              s.anticipoSimple,
            ),
            if (s.reteiva > 0)
              _buildDetailRow(
                'ReteIVA descontable',
                -s.reteiva,
                color: const Color(0xFFF9A825),
              ),
            const Divider(height: 24),
            // Total
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: s.totalAPagar > 0
                    ? AppColors.danger.withValues(alpha: 0.1)
                    : AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.totalAPagar > 0 ? 'TOTAL A PAGAR' : 'SALDO A FAVOR',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(s.totalAPagar.abs()),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: s.totalAPagar > 0
                          ? AppColors.danger
                          : AppColors.success,
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

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, double value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            _currencyFormat.format(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xDD000000),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementsHistory(IvaState state) {
    if (state.settlements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Historial de Liquidaciones',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            ...state.settlements.map((s) => _buildSettlementHistoryRow(s)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementHistoryRow(SettlementRecord s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: s.isSettled
            ? AppColors.success.withValues(alpha: 0.05)
            : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF9E9E9E).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            s.isSettled ? Icons.check_circle : Icons.pending,
            size: 18,
            color: s.isSettled ? AppColors.success : const Color(0xFFF9A825),
          ),
          const SizedBox(width: 8),
          Text(
            '${s.bimesterName} ${s.year}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            _currencyFormat.format(s.totalAPagar),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: s.totalAPagar > 0 ? AppColors.danger : AppColors.success,
            ),
          ),
          const SizedBox(width: 8),
          if (!s.isSettled)
            TextButton(
              onPressed: () => ref
                  .read(ivaProvider.notifier)
                  .markAsSettled(s.bimonthlyPeriod),
              child: const Text('Declarar', style: TextStyle(fontSize: 11)),
            )
          else
            Text(
              s.settledAt != null
                  ? DateFormat('dd/MM/yy').format(s.settledAt!)
                  : 'Declarado',
              style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 3: CALCULADORA DE FACTURACIÓN
  // ════════════════════════════════════════════════════════════

  Widget _buildCalculadoraTab(IvaState state) {
    return _CalculadoraIva(
      ivaRate: state.config?.ivaRate ?? 0.19,
      currencyFormat: _currencyFormat,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TAB 4: CONFIGURACIÓN
  // ════════════════════════════════════════════════════════════

  Widget _buildConfigTab(IvaState state) {
    return _ConfigPanel(
      config: state.config,
      onSave: (config) async {
        final ok = await ref.read(ivaProvider.notifier).saveConfig(config);
        if (ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuración guardada'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  // ════════════════════════════════════════════════════════════
  //  DIÁLOGOS
  // ════════════════════════════════════════════════════════════

  void _showInvoiceDialog(IvaInvoice? existing) {
    final isEdit = existing != null;
    final numCtrl = TextEditingController(text: existing?.invoiceNumber ?? '');
    final companyCtrl = TextEditingController(text: existing?.company ?? '');
    final nitCtrl = TextEditingController(
      text: existing?.companyDocument ?? '',
    );
    final cufeCtrl = TextEditingController(text: existing?.cufe ?? '');
    final baseCtrl = TextEditingController(
      text: existing != null ? existing.baseAmount.toStringAsFixed(0) : '',
    );
    final ivaCtrl = TextEditingController(
      text: existing != null ? existing.ivaAmount.toStringAsFixed(0) : '',
    );
    final totalCtrl = TextEditingController(
      text: existing != null ? existing.totalAmount.toStringAsFixed(0) : '',
    );
    final rteFteCtrl = TextEditingController(
      text: existing != null && existing.rteFteAmount > 0
          ? existing.rteFteAmount.toStringAsFixed(0)
          : '',
    );
    final reteIcaCtrl = TextEditingController(
      text: existing != null && existing.reteIcaAmount > 0
          ? existing.reteIcaAmount.toStringAsFixed(0)
          : '',
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    String type = existing?.invoiceType ?? 'COMPRA';
    DateTime date = existing?.invoiceDate ?? ColombiaTime.now();
    bool hasReteiva = existing?.hasReteiva ?? false;
    final ivaRate = ref.read(ivaProvider).config?.ivaRate ?? 0.19;

    // Parse items from notes (pipe-delimited from scan)
    final List<String> scannedItems = [];
    if (existing?.notes != null && existing!.notes!.contains('|')) {
      scannedItems.addAll(
        existing.notes!
            .split('|')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void calcFromTotal() {
            final total = double.tryParse(totalCtrl.text) ?? 0;
            if (total > 0) {
              final base = total / (1 + ivaRate);
              final iva = total - base;
              baseCtrl.text = base.toStringAsFixed(0);
              ivaCtrl.text = iva.toStringAsFixed(0);
            }
          }

          void calcFromBase() {
            final base = double.tryParse(baseCtrl.text) ?? 0;
            if (base > 0) {
              final iva = base * ivaRate;
              final total = base + iva;
              ivaCtrl.text = iva.toStringAsFixed(0);
              totalCtrl.text = total.toStringAsFixed(0);
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit : Icons.add_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  isEdit ? 'Editar Factura IVA' : 'Nueva Factura IVA',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tipo + Fecha
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: type,
                            decoration: const InputDecoration(
                              labelText: 'Tipo',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'COMPRA',
                                child: Text('COMPRA'),
                              ),
                              DropdownMenuItem(
                                value: 'VENTA',
                                child: Text('VENTA'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => type = v);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: date,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setDialogState(() => date = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Fecha',
                                border: OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                              ),
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(date),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Número factura
                    TextField(
                      controller: numCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Número Factura',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Empresa + NIT
                    TextField(
                      controller: companyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Empresa / Persona',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nitCtrl,
                      decoration: const InputDecoration(
                        labelText: 'NIT / Documento',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.badge_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Valores: Total → calcula base + iva
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: totalCtrl,
                            decoration: InputDecoration(
                              labelText: 'Total Factura',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.arrow_downward,
                                  size: 16,
                                ),
                                tooltip: 'Calcular Base + IVA desde Total',
                                onPressed: () {
                                  calcFromTotal();
                                  setDialogState(() {});
                                },
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: baseCtrl,
                            decoration: InputDecoration(
                              labelText: 'Valor Base',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.arrow_upward, size: 16),
                                tooltip: 'Calcular IVA + Total desde Base',
                                onPressed: () {
                                  calcFromBase();
                                  setDialogState(() {});
                                },
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: ivaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'IVA',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // ReteIVA
                    CheckboxListTile(
                      title: const Text(
                        '¿Aplica ReteIVA? (15% del IVA)',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: hasReteiva,
                      onChanged: (v) =>
                          setDialogState(() => hasReteiva = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    const SizedBox(height: 6),
                    // Retenciones RteFte + ReteICA
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: rteFteCtrl,
                            decoration: const InputDecoration(
                              labelText: 'ReteFuente',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: reteIcaCtrl,
                            decoration: const InputDecoration(
                              labelText: 'ReteICA',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // CUFE
                    TextField(
                      controller: cufeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'CUFE',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.fingerprint, size: 18),
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    // Scanned items detail
                    if (scannedItems.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF90CAF9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 14,
                                  color: const Color(0xFF1976D2),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Ítems de la Factura (${scannedItems.length})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1976D2),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 8),
                            ...scannedItems.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '• $item',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Notas
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notas (opcional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final base = double.tryParse(baseCtrl.text) ?? 0;
                  final iva = double.tryParse(ivaCtrl.text) ?? 0;
                  final total = double.tryParse(totalCtrl.text) ?? 0;

                  if (numCtrl.text.isEmpty || companyCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Número de factura y empresa son requeridos',
                        ),
                      ),
                    );
                    return;
                  }

                  final reteivaAmt = hasReteiva ? iva * 0.15 : 0.0;
                  final rteFte = double.tryParse(rteFteCtrl.text) ?? 0;
                  final reteIca = double.tryParse(reteIcaCtrl.text) ?? 0;
                  final period = getBimonthlyPeriod(date);

                  final invoice = IvaInvoice(
                    id: existing?.id,
                    invoiceNumber: numCtrl.text.trim(),
                    invoiceDate: date,
                    company: companyCtrl.text.trim(),
                    companyDocument: nitCtrl.text.trim().isEmpty
                        ? null
                        : nitCtrl.text.trim(),
                    cufe: cufeCtrl.text.trim().isEmpty
                        ? null
                        : cufeCtrl.text.trim(),
                    invoiceType: type,
                    baseAmount: base,
                    ivaAmount: iva,
                    totalAmount: total,
                    hasReteiva: hasReteiva,
                    reteivaAmount: reteivaAmt,
                    rteFteAmount: rteFte,
                    reteIcaAmount: reteIca,
                    bimonthlyPeriod: period,
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                  );

                  final notifier = ref.read(ivaProvider.notifier);
                  bool ok;
                  if (isEdit) {
                    ok = await notifier.updateInvoice(invoice);
                  } else {
                    ok = await notifier.createInvoice(invoice);
                  }

                  if (ok && ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(isEdit ? 'Guardar' : 'Crear'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(IvaInvoice inv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Factura'),
        content: Text(
          '¿Eliminar factura ${inv.invoiceNumber} de ${inv.company}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(ivaProvider.notifier).deleteInvoice(inv.id!);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───

  List<String> _generatePeriods() {
    final now = ColombiaTime.now();
    final periods = <String>[];
    for (int y = now.year; y >= now.year - 1; y--) {
      for (int b = 6; b >= 1; b--) {
        periods.add('$y-$b');
      }
    }
    return periods;
  }
}

// ═══════════════════════════════════════════════════════════════
//  CALCULADORA IVA (Widget separado para estado local)
// ═══════════════════════════════════════════════════════════════

class _CalculadoraIva extends StatefulWidget {
  final double ivaRate;
  final NumberFormat currencyFormat;

  const _CalculadoraIva({required this.ivaRate, required this.currencyFormat});

  @override
  State<_CalculadoraIva> createState() => _CalculadoraIvaState();
}

class _CalculadoraIvaState extends State<_CalculadoraIva> {
  final _totalCtrl = TextEditingController();
  final _baseCtrl = TextEditingController();
  double _base = 0;
  double _iva = 0;
  double _total = 0;
  bool _hasReteiva = false;
  double _reteiva = 0;

  @override
  void dispose() {
    _totalCtrl.dispose();
    _baseCtrl.dispose();
    super.dispose();
  }

  void _calcFromTotal() {
    final total =
        double.tryParse(_totalCtrl.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    setState(() {
      _total = total;
      _base = total / (1 + widget.ivaRate);
      _iva = total - _base;
      _reteiva = _hasReteiva ? _iva * 0.15 : 0;
      _baseCtrl.text = _base.toStringAsFixed(0);
    });
  }

  void _calcFromBase() {
    final base =
        double.tryParse(_baseCtrl.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    setState(() {
      _base = base;
      _iva = base * widget.ivaRate;
      _total = base + _iva;
      _reteiva = _hasReteiva ? _iva * 0.15 : 0;
      _totalCtrl.text = _total.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.functions,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Calculadora IVA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tarifa IVA: ${(widget.ivaRate * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Desde Total
                  const Text(
                    'Calcular desde TOTAL:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _totalCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Total Factura',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => _calcFromTotal(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _calcFromTotal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('÷ 1.19'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Desde Base
                  const Text(
                    'Calcular desde BASE:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _baseCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Valor Base',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => _calcFromBase(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _calcFromBase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('× 0.19'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ReteIVA
                  CheckboxListTile(
                    title: const Text(
                      '¿Aplica ReteIVA? (15% del IVA)',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: _hasReteiva,
                    onChanged: (v) {
                      setState(() {
                        _hasReteiva = v ?? false;
                        _reteiva = _hasReteiva ? _iva * 0.15 : 0;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const Divider(height: 24),
                  // Resultados
                  _buildResultRow(
                    'Base Gravable',
                    _base,
                    Theme.of(context).colorScheme.primary,
                  ),
                  _buildResultRow(
                    'IVA (${(widget.ivaRate * 100).toStringAsFixed(0)}%)',
                    _iva,
                    AppColors.warning,
                  ),
                  _buildResultRow(
                    'Total Factura',
                    _total,
                    AppColors.success,
                    isBold: true,
                  ),
                  if (_hasReteiva) ...[
                    const Divider(height: 16),
                    _buildResultRow(
                      'ReteIVA (15%)',
                      -_reteiva,
                      AppColors.danger,
                    ),
                    _buildResultRow(
                      'Neto a Pagar',
                      _total - _reteiva,
                      const Color(0xFF1565C0),
                      isBold: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(
    String label,
    double value,
    Color color, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            widget.currencyFormat.format(value),
            style: TextStyle(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  PANEL DE CONFIGURACIÓN
// ═══════════════════════════════════════════════════════════════

class _ConfigPanel extends StatefulWidget {
  final IvaConfig? config;
  final Future<void> Function(IvaConfig) onSave;

  const _ConfigPanel({this.config, required this.onSave});

  @override
  State<_ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends State<_ConfigPanel> {
  late TextEditingController _uvtCtrl;
  late TextEditingController _ivaRateCtrl;
  late TextEditingController _notesCtrl;
  int _grupoRst = 2;
  double _tarifaSimple = 0.02;
  int _year = ColombiaTime.now().year;

  static const _tarifasPorGrupo = {1: 0.016, 2: 0.02, 3: 0.035, 4: 0.045};

  static const _rangosGrupo = {
    1: '0 - 1,000 UVT',
    2: '1,000 - 2,500 UVT',
    3: '2,500 - 5,000 UVT',
    4: '5,000 - 100,000 UVT',
  };

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _uvtCtrl = TextEditingController(
      text: (c?.uvtValue ?? 49799).toStringAsFixed(0),
    );
    _ivaRateCtrl = TextEditingController(
      text: ((c?.ivaRate ?? 0.19) * 100).toStringAsFixed(0),
    );
    _notesCtrl = TextEditingController(text: c?.notes ?? '');
    _grupoRst = c?.grupoRst ?? 2;
    _tarifaSimple = c?.tarifaSimple ?? 0.02;
    _year = c?.year ?? ColombiaTime.now().year;
  }

  @override
  void didUpdateWidget(covariant _ConfigPanel old) {
    super.didUpdateWidget(old);
    if (widget.config != null && old.config == null) {
      final c = widget.config!;
      _uvtCtrl.text = c.uvtValue.toStringAsFixed(0);
      _ivaRateCtrl.text = (c.ivaRate * 100).toStringAsFixed(0);
      _notesCtrl.text = c.notes ?? '';
      setState(() {
        _grupoRst = c.grupoRst;
        _tarifaSimple = c.tarifaSimple;
        _year = c.year;
      });
    }
  }

  @override
  void dispose() {
    _uvtCtrl.dispose();
    _ivaRateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.settings,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Configuración IVA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Año
                  DropdownButtonFormField<int>(
                    value: _year,
                    decoration: const InputDecoration(
                      labelText: 'Año fiscal',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(5, (i) => ColombiaTime.now().year - 2 + i)
                        .map(
                          (y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _year = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Valor UVT
                  TextField(
                    controller: _uvtCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Valor UVT',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                      helperText: 'Valor de la Unidad de Valor Tributario',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 12),
                  // IVA Rate
                  TextField(
                    controller: _ivaRateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tarifa IVA (%)',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      helperText: 'Tarifa general de IVA (19%)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  // Grupo RST
                  const Text(
                    'Grupo Régimen Simple de Tributación',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(4, (i) {
                    final group = i + 1;
                    final tarifa = _tarifasPorGrupo[group]!;
                    final rango = _rangosGrupo[group]!;
                    return RadioListTile<int>(
                      value: group,
                      groupValue: _grupoRst,
                      title: Text(
                        'Grupo $group — ${(tarifa * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        'Rango: $rango',
                        style: const TextStyle(fontSize: 11),
                      ),
                      dense: true,
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _grupoRst = v;
                            _tarifaSimple = _tarifasPorGrupo[v]!;
                          });
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 12),
                  // Tarifa resultante
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tarifa Simple aplicable:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(_tarifaSimple * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Notas
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notas',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  // Guardar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final config = IvaConfig(
                          id: widget.config?.id,
                          year: _year,
                          uvtValue: double.tryParse(_uvtCtrl.text) ?? 49799,
                          grupoRst: _grupoRst,
                          tarifaSimple: _tarifaSimple,
                          ivaRate:
                              (double.tryParse(_ivaRateCtrl.text) ?? 19) / 100,
                          notes: _notesCtrl.text.isEmpty
                              ? null
                              : _notesCtrl.text,
                        );
                        widget.onSave(config);
                      },
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Guardar Configuración'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
