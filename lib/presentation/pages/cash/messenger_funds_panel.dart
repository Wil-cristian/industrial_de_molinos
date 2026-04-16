import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/providers/messenger_funds_provider.dart';
import '../../../data/providers/employees_provider.dart';
import '../../../data/providers/accounts_provider.dart';
import '../../../domain/entities/messenger_fund.dart';
import '../../../domain/entities/employee.dart';
import '../../../domain/entities/account.dart';

/// Panel/Dialog de Fondos de Mensajería integrado en Caja Diaria.
class MessengerFundsPanel extends ConsumerStatefulWidget {
  const MessengerFundsPanel({super.key});

  @override
  ConsumerState<MessengerFundsPanel> createState() =>
      _MessengerFundsPanelState();
}

class _MessengerFundsPanelState extends ConsumerState<MessengerFundsPanel> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(messengerFundsProvider.notifier).load();
      // Asegurar que empleados estén cargados
      final empState = ref.read(employeesProvider);
      if (empState.employees.isEmpty) {
        ref.read(employeesProvider.notifier).loadEmployees();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messengerFundsProvider);
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fondos de Mensajería'),
        actions: [
          IconButton(
            onPressed: () => ref.read(messengerFundsProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _showCreateFundDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(isMobile ? 'Nuevo' : 'Nuevo Fondo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text(state.error!, style: TextStyle(color: theme.colorScheme.error)))
              : _buildBody(context, state, theme, isMobile),
    );
  }

  Widget _buildBody(BuildContext context, MessengerFundsState state, ThemeData theme, bool isMobile) {
    return CustomScrollView(
      slivers: [
        // ── Resumen ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summaryCard(
                  'Fondos Activos',
                  '${state.openFunds.length}',
                  Icons.people_outline,
                  Colors.blue,
                  isMobile,
                ),
                _summaryCard(
                  'Total Entregado',
                  Helpers.formatCurrency(state.totalActiveGiven),
                  Icons.arrow_circle_up,
                  Colors.orange,
                  isMobile,
                ),
                _summaryCard(
                  'Total Gastado',
                  Helpers.formatCurrency(state.totalActiveSpent),
                  Icons.receipt_long,
                  Colors.green,
                  isMobile,
                ),
                _summaryCard(
                  'Pendiente Legalizar',
                  Helpers.formatCurrency(state.totalActivePending),
                  Icons.pending_actions,
                  Colors.red,
                  isMobile,
                ),
              ],
            ),
          ),
        ),

        // ── Fondos abiertos ──
        if (state.openFunds.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Fondos Abiertos',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _fundCard(context, state.openFunds[index], theme),
              ),
              childCount: state.openFunds.length,
            ),
          ),
        ],

        // ── Fondos cerrados ──
        if (state.closedFunds.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Historial',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _fundCard(context, state.closedFunds[index], theme),
              ),
              childCount: state.closedFunds.length,
            ),
          ),
        ],

        // ── Vacío ──
        if (state.funds.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delivery_dining, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No hay fondos de mensajería',
                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateFundDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear Primer Fondo'),
                  ),
                ],
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color, bool compact) {
    return SizedBox(
      width: compact ? double.infinity : 200,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _fundCard(BuildContext context, MessengerFund fund, ThemeData theme) {
    final statusColor = _statusColor(fund.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showFundDetail(context, fund),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    child: Icon(Icons.delivery_dining, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fund.employeeName,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Entregado: ${Helpers.formatCurrency(fund.amountGiven)} • ${Helpers.formatDate(fund.dateGiven)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      fund.statusLabel,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Barra de progreso
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fund.progress.clamp(0.0, 1.0),
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(statusColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniStat('Gastado', Helpers.formatCurrency(fund.amountSpent), Colors.orange),
                  const SizedBox(width: 16),
                  _miniStat('Devuelto', Helpers.formatCurrency(fund.amountReturned), Colors.green),
                  const SizedBox(width: 16),
                  _miniStat('Pendiente', Helpers.formatCurrency(fund.remainingBalance), Colors.red),
                ],
              ),
              if (fund.isOpen) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showLegalizeDialog(context, fund),
                        icon: const Icon(Icons.receipt_long, size: 16),
                        label: const Text('Legalizar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green[700],
                          side: BorderSide(color: Colors.green[300]!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showReturnDialog(context, fund),
                        icon: const Icon(Icons.keyboard_return, size: 16),
                        label: const Text('Devolver'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          side: BorderSide(color: Colors.blue[300]!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _confirmCancelFund(context, fund),
                      icon: const Icon(Icons.cancel_outlined, size: 20),
                      tooltip: 'Cancelar fondo',
                      style: IconButton.styleFrom(foregroundColor: Colors.red),
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

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Color _statusColor(MessengerFundStatus status) {
    switch (status) {
      case MessengerFundStatus.abierto:
        return Colors.blue;
      case MessengerFundStatus.parcial:
        return Colors.orange;
      case MessengerFundStatus.legalizado:
        return Colors.green;
      case MessengerFundStatus.cancelado:
        return Colors.grey;
    }
  }

  // ===================== DIÁLOGOS =====================

  /// Diálogo para crear nuevo fondo
  void _showCreateFundDialog(BuildContext context) {
    final empState = ref.read(employeesProvider);
    final cashState = ref.read(dailyCashProvider);
    final activeEmployees = empState.employees.where((e) => e.status == EmployeeStatus.activo).toList();
    final accounts = cashState.accounts;

    Employee? selectedEmployee;
    Account? selectedAccount;
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.delivery_dining, color: Colors.blue),
                SizedBox(width: 8),
                Text('Crear Fondo de Mensajería'),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Este dinero NO se registra como gasto. Se legaliza cuando el mensajero devuelve los recibos.',
                              style: TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Selector de empleado
                    DropdownButtonFormField<Employee>(
                      decoration: const InputDecoration(
                        labelText: 'Mensajero',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      items: activeEmployees.map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.fullName),
                      )).toList(),
                      onChanged: (e) => setDialogState(() => selectedEmployee = e),
                      value: selectedEmployee,
                    ),
                    const SizedBox(height: 12),

                    // Selector de cuenta
                    DropdownButtonFormField<Account>(
                      decoration: const InputDecoration(
                        labelText: 'Cuenta de Salida',
                        prefixIcon: Icon(Icons.account_balance_wallet),
                        border: OutlineInputBorder(),
                      ),
                      items: accounts.map((a) => DropdownMenuItem(
                        value: a,
                        child: Text('${a.name} (${Helpers.formatCurrency(a.balance)})'),
                      )).toList(),
                      onChanged: (a) => setDialogState(() => selectedAccount = a),
                      value: selectedAccount,
                    ),
                    const SizedBox(height: 12),

                    // Monto
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Monto a Entregar',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    ),
                    const SizedBox(height: 12),

                    // Notas
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas (opcional)',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
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
              ElevatedButton.icon(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (selectedEmployee == null || selectedAccount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Complete todos los campos')),
                    );
                    return;
                  }
                  if (amount > selectedAccount!.balance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Saldo insuficiente. Disponible: ${Helpers.formatCurrency(selectedAccount!.balance)}')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final result = await ref.read(messengerFundsProvider.notifier).createFund(
                    employeeId: selectedEmployee!.id,
                    employeeName: selectedEmployee!.fullName,
                    amount: amount,
                    accountId: selectedAccount!.id,
                    notes: notesController.text.isNotEmpty ? notesController.text : null,
                  );
                  if (result != null && context.mounted) {
                    // Recargar caja diaria también
                    ref.read(dailyCashProvider.notifier).load();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Fondo de ${Helpers.formatCurrency(amount)} entregado a ${selectedEmployee!.fullName}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Entregar Fondo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Diálogo para legalizar un gasto/compra
  void _showLegalizeDialog(BuildContext context, MessengerFund fund) {
    FundItemType selectedType = FundItemType.compra;
    final amountController = TextEditingController();
    final descController = TextEditingController();
    final refController = TextEditingController();
    String selectedCategory = 'consumibles';

    final categories = [
      ('consumibles', 'Consumibles / Materiales'),
      ('servicios_publicos', 'Servicios Públicos'),
      ('transporte', 'Transporte'),
      ('papeleria', 'Papelería'),
      ('cuidado_personal', 'Cuidado Personal'),
      ('gastos_reducibles', 'Gastos Reducibles'),
      ('impuestos', 'Impuestos'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Legalizar Gasto', style: TextStyle(fontSize: 16)),
                      Text(
                        '${fund.employeeName} • Disponible: ${Helpers.formatCurrency(fund.remainingBalance)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tipo de item
                    SegmentedButton<FundItemType>(
                      segments: const [
                        ButtonSegment(value: FundItemType.compra, label: Text('Compra'), icon: Icon(Icons.shopping_cart, size: 16)),
                        ButtonSegment(value: FundItemType.pago_factura, label: Text('Pago'), icon: Icon(Icons.receipt, size: 16)),
                        ButtonSegment(value: FundItemType.gasto, label: Text('Gasto'), icon: Icon(Icons.money_off, size: 16)),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (s) => setDialogState(() => selectedType = s.first),
                    ),
                    const SizedBox(height: 16),

                    // Monto
                    TextFormField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: 'Monto',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: const OutlineInputBorder(),
                        helperText: 'Máximo: ${Helpers.formatCurrency(fund.remainingBalance)}',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    ),
                    const SizedBox(height: 12),

                    // Descripción
                    TextFormField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Referencia
                    TextFormField(
                      controller: refController,
                      decoration: const InputDecoration(
                        labelText: 'Referencia / Nº Factura (opcional)',
                        prefixIcon: Icon(Icons.tag),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Categoría
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      value: selectedCategory,
                      items: categories.map((c) => DropdownMenuItem(
                        value: c.$1,
                        child: Text(c.$2),
                      )).toList(),
                      onChanged: (v) => setDialogState(() => selectedCategory = v ?? 'consumibles'),
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
              ElevatedButton.icon(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text) ?? 0;
                  if (amount <= 0 || descController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ingrese monto y descripción')),
                    );
                    return;
                  }
                  if (amount > fund.remainingBalance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Monto excede el saldo disponible (${Helpers.formatCurrency(fund.remainingBalance)})')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final result = await ref.read(messengerFundsProvider.notifier).legalizeItem(
                    fundId: fund.id,
                    itemType: selectedType,
                    amount: amount,
                    description: descController.text,
                    reference: refController.text.isNotEmpty ? refController.text : null,
                    category: selectedCategory,
                  );
                  if (result != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Gasto de ${Helpers.formatCurrency(amount)} legalizado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Registrar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Diálogo para devolver dinero sobrante
  void _showReturnDialog(BuildContext context, MessengerFund fund) {
    final amountController = TextEditingController(
      text: fund.remainingBalance.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard_return, color: Colors.blue),
            SizedBox(width: 8),
            Text('Devolver Dinero'),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Saldo pendiente:', style: TextStyle(color: Colors.grey[700])),
                    Text(
                      Helpers.formatCurrency(fund.remainingBalance),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Monto a Devolver',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
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
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0 || amount > fund.remainingBalance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Monto inválido. Máximo: ${Helpers.formatCurrency(fund.remainingBalance)}')),
                );
                return;
              }
              Navigator.pop(ctx);
              final result = await ref.read(messengerFundsProvider.notifier).legalizeItem(
                fundId: fund.id,
                itemType: FundItemType.devolucion,
                amount: amount,
                description: 'Devolución de dinero sobrante',
              );
              if (result != null && context.mounted) {
                ref.read(dailyCashProvider.notifier).load();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${Helpers.formatCurrency(amount)} devuelto a caja'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Devolver'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Confirmar cancelación de fondo
  void _confirmCancelFund(BuildContext context, MessengerFund fund) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar Fondo?'),
        content: Text(
          'Se devolverán ${Helpers.formatCurrency(fund.remainingBalance)} a la cuenta. '
          'Los gastos ya legalizados (${Helpers.formatCurrency(fund.amountSpent)}) se mantienen.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(messengerFundsProvider.notifier).cancelFund(fund.id);
              if (ok && context.mounted) {
                ref.read(dailyCashProvider.notifier).load();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fondo cancelado'), backgroundColor: Colors.orange),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );
  }

  /// Detalle de un fondo
  void _showFundDetail(BuildContext context, MessengerFund fund) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: scrollController,
                children: [
                  // Header
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _statusColor(fund.status).withValues(alpha: 0.1),
                        radius: 24,
                        child: Icon(Icons.delivery_dining, color: _statusColor(fund.status)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fund.employeeName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text(
                              '${fund.statusLabel} • ${Helpers.formatDate(fund.dateGiven)}',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        Helpers.formatCurrency(fund.amountGiven),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Resumen
                  Card(
                    color: Colors.grey[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _detailRow('Entregado', Helpers.formatCurrency(fund.amountGiven), Colors.blue),
                          _detailRow('Gastado', Helpers.formatCurrency(fund.amountSpent), Colors.orange),
                          _detailRow('Devuelto', Helpers.formatCurrency(fund.amountReturned), Colors.green),
                          const Divider(),
                          _detailRow('Pendiente', Helpers.formatCurrency(fund.remainingBalance), Colors.red),
                        ],
                      ),
                    ),
                  ),
                  if (fund.notes != null && fund.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Notas: ${fund.notes}', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 16),

                  // Items legalizados
                  Text('Detalle de Gastos', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (fund.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Sin gastos registrados aún', style: TextStyle(color: Colors.grey[400])),
                    )
                  else
                    ...fund.items.map((item) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.itemType == FundItemType.devolucion ? Colors.blue[50] : Colors.orange[50],
                          child: Icon(
                            item.itemType == FundItemType.devolucion ? Icons.keyboard_return : Icons.receipt,
                            color: item.itemType == FundItemType.devolucion ? Colors.blue : Colors.orange,
                            size: 18,
                          ),
                        ),
                        title: Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${item.itemTypeLabel}${item.reference != null ? ' • ${item.reference}' : ''} • ${Helpers.formatDate(item.createdAt)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          '${item.itemType == FundItemType.devolucion ? '+' : '-'}${Helpers.formatCurrency(item.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: item.itemType == FundItemType.devolucion ? Colors.blue : Colors.orange,
                          ),
                        ),
                      ),
                    )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
