import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/colombia_time.dart';
import '../../core/utils/helpers.dart';
import '../../core/responsive/responsive_helper.dart';
import '../../domain/entities/advance_sale.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/cash_movement.dart';
import '../../data/providers/advance_sales_provider.dart';
import '../../data/datasources/customers_datasource.dart';
import '../../data/datasources/accounts_datasource.dart';

class AdvanceSalesPage extends ConsumerStatefulWidget {
  const AdvanceSalesPage({super.key});

  @override
  ConsumerState<AdvanceSalesPage> createState() => _AdvanceSalesPageState();
}

class _AdvanceSalesPageState extends ConsumerState<AdvanceSalesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  List<Account> _accounts = [];
  bool _loadingAccounts = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    if (mounted) setState(() => _loadingAccounts = true);
    try {
      final accounts = await AccountsDataSource.getAllAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts.where((a) => a.isActive).toList();
      });
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Account? _preferredAccountForMethod(String method) {
    if (_accounts.isEmpty) return null;

    if (method == 'cash') {
      for (final account in _accounts) {
        if (account.type == AccountType.cash) return account;
      }
    } else {
      for (final account in _accounts) {
        if (account.type == AccountType.bank) return account;
      }
    }

    return _accounts.first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(advanceSalesProvider);
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      body: Column(
        children: [
          // Header
          _buildHeader(cs, state, isMobile),
          // Tabs
          Container(
            color: cs.surface,
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_top, size: 16),
                      const SizedBox(width: 6),
                      Text('Pendientes (${state.countPending})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 16),
                      const SizedBox(width: 6),
                      Text('Confirmadas (${state.confirmed.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cancel, size: 16),
                      const SizedBox(width: 6),
                      Text('Anuladas (${state.cancelled.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(state.pending),
                      _buildList(state.confirmed),
                      _buildList(state.cancelled),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
    );
  }

  Widget _buildHeader(
    ColorScheme cs,
    AdvanceSalesState state,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_send, color: cs.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                'Ventas Anticipadas',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () =>
                    ref.read(advanceSalesProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats cards
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _statChip(
                'Pendientes',
                '${state.countPending}',
                Colors.orange,
              ),
              _statChip(
                'Estimado total',
                Helpers.formatCurrency(state.totalEstimado),
                cs.primary,
              ),
              _statChip(
                'Total abonado',
                Helpers.formatCurrency(state.totalAbonado),
                AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search
          SizedBox(
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Buscar por cliente o descripción...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<AdvanceSale> sales) {
    final filtered = sales.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.customerName.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q) ||
          s.fullNumber.toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'No hay ventas anticipadas',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(advanceSalesProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) => _buildCard(filtered[index]),
      ),
    );
  }

  Widget _buildCard(AdvanceSale sale) {
    final cs = Theme.of(context).colorScheme;
    final effectiveTotal = sale.effectiveTotal;
    final progress = effectiveTotal > 0 ? sale.paidAmount / effectiveTotal : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetailSheet(sale),
        child: Column(
          children: [
            // Progress bar at top
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
              color: sale.isConfirmed
                  ? AppColors.success
                  : sale.isCancelled
                      ? AppColors.danger
                      : cs.primary,
              minHeight: 4,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: number + status badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sale.fullNumber,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(sale.status),
                      const Spacer(),
                      Text(
                        Helpers.formatDate(sale.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Customer
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sale.customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Text(
                    sale.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Amounts row
                  Row(
                    children: [
                      _amountColumn(
                        'Estimado',
                        Helpers.formatCurrency(sale.estimatedTotal),
                        cs.onSurfaceVariant,
                      ),
                      if (sale.finalTotal != null) ...[
                        const SizedBox(width: 16),
                        _amountColumn(
                          'Final',
                          Helpers.formatCurrency(sale.finalTotal!),
                          cs.primary,
                        ),
                      ],
                      const SizedBox(width: 16),
                      _amountColumn(
                        'Abonado',
                        Helpers.formatCurrency(sale.paidAmount),
                        AppColors.success,
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Pendiente',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            Helpers.formatCurrency(sale.pendingAmount),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: sale.pendingAmount > 0
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                          ),
                        ],
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

  Widget _amountColumn(String label, String value, Color color) {
    return Column(
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(AdvanceSaleStatus status) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case AdvanceSaleStatus.pending:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
        label = 'Pendiente';
        break;
      case AdvanceSaleStatus.confirmed:
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        label = 'Confirmada';
        break;
      case AdvanceSaleStatus.cancelled:
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = 'Anulada';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    );
  }

  // ============================================================
  // DETAIL BOTTOM SHEET
  // ============================================================

  void _showDetailSheet(AdvanceSale sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DetailSheet(
        sale: sale,
        onPayment: () {
          Navigator.pop(ctx);
          _showPaymentDialog(sale);
        },
        onConfirm: () {
          Navigator.pop(ctx);
          _showConfirmDialog(sale);
        },
        onCancel: () async {
          Navigator.pop(ctx);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Anular venta anticipada'),
              content: Text(
                '¿Seguro que desea anular ${sale.fullNumber}?\nLos abonos registrados permanecerán en el historial.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Anular'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await ref.read(advanceSalesProvider.notifier).cancel(sale.id);
          }
        },
        onEditPrice: () {
          Navigator.pop(ctx);
          _showEditPriceDialog(sale);
        },
      ),
    );
  }

  // ============================================================
  // CREATE DIALOG
  // ============================================================

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CreateAdvanceSaleDialog(
        onCreated: (customerName, customerId, description, estimatedTotal, notes) async {
          final result = await ref.read(advanceSalesProvider.notifier).create(
                customerName: customerName,
                customerId: customerId,
                description: description,
                estimatedTotal: estimatedTotal,
                notes: notes,
              );
          if (result != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Venta anticipada ${result.fullNumber} creada'),
                backgroundColor: AppColors.success,
              ),
            );
            return true;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ref.read(advanceSalesProvider).error ??
                  'Error al crear la venta anticipada',
                ),
                backgroundColor: const Color(0xFFC62828),
              ),
            );
          }
          return false;
        },
      ),
    );
  }

  // ============================================================
  // PAYMENT DIALOG
  // ============================================================

  Future<void> _showPaymentDialog(AdvanceSale sale) async {
    if (_accounts.isEmpty && !_loadingAccounts) {
      await _loadAccounts();
    }

    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String method = 'cash';
    DateTime paymentDate = ColombiaTime.now();
    Account? selectedAccount = _preferredAccountForMethod(method);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.payments, size: 20),
              const SizedBox(width: 8),
              Text('Registrar Abono - ${sale.fullNumber}'),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cliente: ${sale.customerName}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Pendiente: ${Helpers.formatCurrency(sale.pendingAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monto del abono',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(
                    labelText: 'Método de pago',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
                    DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
                    DropdownMenuItem(value: 'check', child: Text('Cheque')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setDialogState(() {
                      method = v;
                      selectedAccount = _preferredAccountForMethod(method) ?? selectedAccount;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_loadingAccounts)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_accounts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No hay cuentas activas para registrar el dinero recibido.',
                    ),
                  )
                else
                  DropdownButtonFormField<Account>(
                    value: _accounts.any((a) => a.id == selectedAccount?.id)
                        ? selectedAccount
                        : null,
                    decoration: InputDecoration(
                      labelText: method == 'cash'
                          ? 'Caja donde ingresó'
                          : 'Banco / cuenta donde ingresó',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.account_balance_wallet),
                    ),
                    items: _accounts
                        .map(
                          (account) => DropdownMenuItem<Account>(
                            value: account,
                            child: Text(
                              account.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedAccount = v),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    border: OutlineInputBorder(),
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
            FilledButton.icon(
              onPressed: () async {
                final amount = double.tryParse(
                  amountCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
                );
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingrese un monto válido')),
                  );
                  return;
                }
                if (selectedAccount == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Seleccione el banco o cuenta donde entró el dinero'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final ok = await ref
                    .read(advanceSalesProvider.notifier)
                    .registerPayment(
                      advanceSaleId: sale.id,
                      amount: amount,
                      method: method,
                      paymentDate: paymentDate,
                      accountId: selectedAccount!.id,
                      accountName: selectedAccount!.displayName,
                      notes: notesCtrl.text.isEmpty ? null : notesCtrl.text,
                    );
                if (ok && mounted) {
                  try {
                    await AccountsDataSource.createMovementWithBalanceUpdate(
                      CashMovement(
                        id: '',
                        accountId: selectedAccount!.id,
                        type: MovementType.income,
                        category: MovementCategory.collection,
                        amount: amount,
                        description: 'Abono venta anticipada ${sale.fullNumber} - ${sale.customerName} (${selectedAccount!.displayName})',
                        personName: sale.customerName,
                        date: paymentDate,
                      ),
                    );
                  } catch (_) {}
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Abono de ${Helpers.formatCurrency(amount)} registrado en ${selectedAccount!.displayName}'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Registrar Abono'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONFIRM DIALOG (fijar precio final)
  // ============================================================

  void _showConfirmDialog(AdvanceSale sale) {
    final finalTotalCtrl = TextEditingController(
      text: sale.estimatedTotal.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 22),
            const SizedBox(width: 8),
            const Text('Confirmar Venta'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${sale.fullNumber} - ${sale.customerName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                sale.description,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Divider(height: 24),
              Text(
                'Precio estimado: ${Helpers.formatCurrency(sale.estimatedTotal)}',
              ),
              Text(
                'Total abonado: ${Helpers.formatCurrency(sale.paidAmount)}',
                style: const TextStyle(color: AppColors.success),
              ),
              const SizedBox(height: 16),
              const Text(
                'La mercancía llegó. Ingrese el precio final real:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: finalTotalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Precio final real',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                  helperText: 'Este será el valor definitivo de la factura',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (ctx2) {
                  final finalVal = double.tryParse(
                    finalTotalCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
                  );
                  if (finalVal == null) return const SizedBox();
                  final remaining = finalVal - sale.paidAmount;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: remaining > 0
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          remaining > 0
                              ? Icons.warning_amber
                              : Icons.check_circle,
                          color: remaining > 0
                              ? Colors.orange
                              : AppColors.success,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            remaining > 0
                                ? 'El cliente quedará debiendo ${Helpers.formatCurrency(remaining)}'
                                : remaining == 0
                                    ? 'La venta queda totalmente pagada'
                                    : 'Sobra ${Helpers.formatCurrency(remaining.abs())} de abono',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: remaining > 0
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            onPressed: () async {
              final finalTotal = double.tryParse(
                finalTotalCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
              );
              if (finalTotal == null || finalTotal <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingrese un precio válido')),
                );
                return;
              }
              Navigator.pop(ctx);
              final ok = await ref
                  .read(advanceSalesProvider.notifier)
                  .confirm(id: sale.id, finalTotal: finalTotal);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${sale.fullNumber} confirmada por ${Helpers.formatCurrency(finalTotal)}',
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Confirmar Venta'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDIT PRICE DIALOG
  // ============================================================

  void _showEditPriceDialog(AdvanceSale sale) {
    final ctrl = TextEditingController(
      text: sale.estimatedTotal.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Actualizar Precio Estimado'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Precio actual: ${Helpers.formatCurrency(sale.estimatedTotal)}'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nuevo precio estimado',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
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
              final val = double.tryParse(
                ctrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
              );
              if (val == null || val <= 0) return;
              Navigator.pop(ctx);
              await ref
                  .read(advanceSalesProvider.notifier)
                  .updateEstimatedTotal(sale.id, val);
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DETAIL SHEET WIDGET
// ============================================================

class _DetailSheet extends StatelessWidget {
  final AdvanceSale sale;
  final VoidCallback onPayment;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onEditPrice;

  const _DetailSheet({
    required this.sale,
    required this.onPayment,
    required this.onConfirm,
    required this.onCancel,
    required this.onEditPrice,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveTotal = sale.effectiveTotal;
    final progress = effectiveTotal > 0 ? sale.paidAmount / effectiveTotal : 0.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.fullNumber,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      Text(
                        sale.customerName,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(sale.status),
              ],
            ),
            const SizedBox(height: 16),
            // Description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(sale.description, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Progress
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progreso de abonos',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Amounts
            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    context,
                    'Estimado',
                    Helpers.formatCurrency(sale.estimatedTotal),
                    Icons.calculate,
                  ),
                ),
                if (sale.finalTotal != null)
                  Expanded(
                    child: _infoTile(
                      context,
                      'Final',
                      Helpers.formatCurrency(sale.finalTotal!),
                      Icons.verified,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _infoTile(
                    context,
                    'Abonado',
                    Helpers.formatCurrency(sale.paidAmount),
                    Icons.check_circle,
                    color: AppColors.success,
                  ),
                ),
                Expanded(
                  child: _infoTile(
                    context,
                    'Pendiente',
                    Helpers.formatCurrency(sale.pendingAmount),
                    Icons.pending,
                    color: sale.pendingAmount > 0
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                ),
              ],
            ),
            if (sale.notes != null && sale.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sale.notes!,
                        style: TextStyle(color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Payments history
            if (sale.payments.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Historial de Abonos',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...sale.payments.map((p) => _paymentTile(context, p)),
            ],
            const SizedBox(height: 24),
            // Actions
            if (sale.isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEditPrice,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Precio'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onPayment,
                      icon: const Icon(Icons.payments, size: 18),
                      label: const Text('Abonar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      onPressed: onCancel,
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Anular'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Confirmar Factura'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AdvanceSaleStatus status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;
    switch (status) {
      case AdvanceSaleStatus.pending:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
        label = 'Pendiente';
        icon = Icons.hourglass_top;
        break;
      case AdvanceSaleStatus.confirmed:
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        label = 'Confirmada';
        icon = Icons.check_circle;
        break;
      case AdvanceSaleStatus.cancelled:
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = 'Anulada';
        icon = Icons.cancel;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color ?? cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentTile(BuildContext context, AdvanceSalePayment payment) {
    final cs = Theme.of(context).colorScheme;
    String methodLabel;
    IconData methodIcon;
    switch (payment.method) {
      case 'cash':
        methodLabel = 'Efectivo';
        methodIcon = Icons.money;
        break;
      case 'transfer':
        methodLabel = 'Transferencia';
        methodIcon = Icons.swap_horiz;
        break;
      case 'card':
        methodLabel = 'Tarjeta';
        methodIcon = Icons.credit_card;
        break;
      case 'check':
        methodLabel = 'Cheque';
        methodIcon = Icons.receipt;
        break;
      default:
        methodLabel = payment.method;
        methodIcon = Icons.payment;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(methodIcon, size: 18, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Helpers.formatCurrency(payment.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  payment.accountName != null && payment.accountName!.isNotEmpty
                      ? '$methodLabel · ${payment.accountName}'
                      : methodLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  Helpers.formatDate(payment.paymentDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (payment.notes != null && payment.notes!.isNotEmpty)
            Tooltip(
              message: payment.notes!,
              child: Icon(Icons.info_outline, size: 16, color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// CREATE DIALOG
// ============================================================

class _CreateAdvanceSaleDialog extends StatefulWidget {
  final Future<bool> Function(
    String customerName,
    String? customerId,
    String description,
    double estimatedTotal,
    String? notes,
  ) onCreated;

  const _CreateAdvanceSaleDialog({required this.onCreated});

  @override
  State<_CreateAdvanceSaleDialog> createState() =>
      _CreateAdvanceSaleDialogState();
}

class _CreateAdvanceSaleDialogState extends State<_CreateAdvanceSaleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _estimatedTotalCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedCustomerId;
  List<Customer> _customers = [];
  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;
  // Reference to the Autocomplete's internal controller
  TextEditingController? _autocompleteCtrl;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await CustomersDataSource.getAll();
      if (mounted) {
        setState(() {
          _customers = customers;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _estimatedTotalCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.schedule_send, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Nueva Venta Anticipada'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Customer autocomplete
                      Autocomplete<Customer>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return _customers;
                          }
                          return _customers.where((c) => c.name
                              .toLowerCase()
                              .contains(
                                  textEditingValue.text.toLowerCase()));
                        },
                        displayStringForOption: (c) => c.name,
                        fieldViewBuilder:
                            (ctx, controller, focusNode, onFieldSubmitted) {
                          _autocompleteCtrl = controller;
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Cliente *',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                              hintText: 'Buscar o escribir nombre',
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Requerido'
                                : null,
                            onChanged: (v) {
                              _customerNameCtrl.text = v;
                              _selectedCustomerId = null;
                            },
                          );
                        },
                        onSelected: (customer) {
                          _customerNameCtrl.text = customer.name;
                          _selectedCustomerId = customer.id;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descripción del material/producto *',
                          border: OutlineInputBorder(),
                          hintText: 'Ej: 10 toneladas de cemento gris',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _estimatedTotalCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Precio estimado *',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                          helperText:
                              'Puede cambiar cuando llegue la mercancía',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          final val = double.tryParse(
                            v.replaceAll(RegExp(r'[^\d.]'), ''),
                          );
                          if (val == null || val <= 0) return 'Monto inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notas (opcional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('Crear'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    // Read from both controllers to handle Autocomplete desync
    final customerName = _customerNameCtrl.text.isNotEmpty
        ? _customerNameCtrl.text
        : _autocompleteCtrl?.text ?? '';
    if (customerName.isEmpty) {
      setState(() {
        _submitting = false;
        _errorMessage = 'Debe seleccionar o escribir un cliente';
      });
      return;
    }

    final estimatedTotal = double.parse(
      _estimatedTotalCtrl.text.replaceAll(RegExp(r'[^\d.]'), ''),
    );

    try {
      final success = await widget.onCreated(
        customerName,
        _selectedCustomerId,
        _descriptionCtrl.text,
        estimatedTotal,
        _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      );

      if (success && mounted) {
        Navigator.pop(context);
      } else if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = 'No se pudo crear la venta anticipada. Intente de nuevo.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }
}
