import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/accounts_provider.dart';
import '../../data/providers/customers_provider.dart';
import '../../data/providers/suppliers_provider.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/cash_movement.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/quick_actions_button.dart';

class DailyCashPage extends ConsumerStatefulWidget {
  const DailyCashPage({super.key});

  @override
  ConsumerState<DailyCashPage> createState() => _DailyCashPageState();
}

class _DailyCashPageState extends ConsumerState<DailyCashPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(dailyCashProvider.notifier).load();
      ref.read(suppliersProvider.notifier).loadSuppliers();
      ref.read(customersProvider.notifier).loadCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyCashProvider);

    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar unificado
              const AppSidebar(currentRoute: '/daily-cash'),

              // Contenido principal
              Expanded(
                child: Container(
                  color: AppTheme.backgroundColor,
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          children: [
                            // Header con fecha
                            _buildHeader(context, state),

                        // Contenido
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cards de cuentas
                                _buildAccountCards(context, state),
                                const SizedBox(height: 24),

                                // Resumen del día
                                _buildDaySummary(context, state),
                                const SizedBox(height: 24),

                                // Lista de movimientos
                                _buildMovementsList(context, state),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ],
        ),
        // QuickActions Button
        const QuickActionsButton(),
        // FAB para nuevo movimiento
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton.extended(
            onPressed: () => _showAddMovementDialog(context),
            backgroundColor: AppTheme.primaryColor,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Nuevo Movimiento',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    return Container(
      width: 80,
      color: AppTheme.primaryColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.factory,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Molinos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavItem(
                    icon: Icons.dashboard,
                    label: 'Inicio',
                    onTap: () => context.go('/'),
                  ),
                  _NavItem(
                    icon: Icons.account_balance_wallet,
                    label: 'Caja',
                    isSelected: true,
                    onTap: () {},
                  ),
                  _NavItem(
                    icon: Icons.inventory_2,
                    label: 'Productos',
                    onTap: () => context.go('/products'),
                  ),
                  _NavItem(
                    icon: Icons.people,
                    label: 'Clientes',
                    onTap: () => context.go('/customers'),
                  ),
                  _NavItem(
                    icon: Icons.receipt_long,
                    label: 'Ventas',
                    onTap: () => context.go('/invoices'),
                  ),
                  _NavItem(
                    icon: Icons.request_quote,
                    label: 'Cotizar',
                    onTap: () => context.go('/quotations'),
                  ),
                  _NavItem(
                    icon: Icons.bar_chart,
                    label: 'Reportes',
                    onTap: () => context.go('/reports'),
                  ),
                  _NavItem(
                    icon: Icons.settings,
                    label: 'Config',
                    onTap: () => context.go('/settings'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DailyCashState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Título
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Caja Diaria',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Control de ingresos, gastos y traslados',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Selector de fecha
          InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Formatters.dateLong(state.selectedDate),
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Botón de traslado
          ElevatedButton.icon(
            onPressed: () => _showTransferDialog(context),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Traslado'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCards(BuildContext context, DailyCashState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Saldos Actuales',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance,
                    color: AppTheme.successColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Total: ${Formatters.currency(state.totalBalance)}',
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: state.accounts.asMap().entries.map((entry) {
            final index = entry.key;
            final account = entry.value;
            final isLast = index == state.accounts.length - 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 16),
                child: _buildAccountCard(context, account, state),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    Account account,
    DailyCashState state,
  ) {
    final accountColor = account.color != null
        ? Color(int.parse(account.color!.replaceFirst('#', '0xFF')))
        : AppTheme.primaryColor;

    final incomeToday = state.incomeByAccount[account.id] ?? 0.0;
    final expenseToday = state.expenseByAccount[account.id] ?? 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accountColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    account.type == AccountType.cash
                        ? Icons.account_balance_wallet
                        : Icons.account_balance,
                    color: accountColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.typeLabel,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                  onPressed: () => _showAccountOptions(context, account),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              Formatters.currency(account.balance),
              style: TextStyle(
                color: accountColor,
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Saldo actual',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    'Ingresos Hoy',
                    '+${Formatters.currency(incomeToday)}',
                    AppTheme.successColor,
                  ),
                ),
                Container(width: 1, height: 30, color: Colors.grey[200]),
                Expanded(
                  child: _buildMiniStat(
                    'Gastos Hoy',
                    '-${Formatters.currency(expenseToday)}',
                    AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color textColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  Widget _buildDaySummary(BuildContext context, DailyCashState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen del Día',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    icon: Icons.arrow_downward,
                    label: 'Total Ingresos',
                    value: state.dayIncome,
                    color: AppTheme.successColor,
                  ),
                ),
                Container(width: 1, height: 60, color: Colors.grey[300]),
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    icon: Icons.arrow_upward,
                    label: 'Total Gastos',
                    value: state.dayExpense,
                    color: AppTheme.errorColor,
                  ),
                ),
                Container(width: 1, height: 60, color: Colors.grey[300]),
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    icon: Icons.trending_up,
                    label: 'Saldo Neto',
                    value: state.dayNet,
                    color: state.dayNet >= 0
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                    showSign: true,
                  ),
                ),
                Container(width: 1, height: 60, color: Colors.grey[300]),
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    icon: Icons.receipt,
                    label: 'Movimientos',
                    valueText: '${state.movementCount}',
                    color: AppTheme.accentColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    double? value,
    String? valueText,
    required Color color,
    bool showSign = false,
  }) {
    String displayValue = valueText ?? '';
    if (value != null) {
      if (showSign && value > 0) {
        displayValue = '+${Formatters.currency(value)}';
      } else {
        displayValue = Formatters.currency(value);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            displayValue,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMovementsList(BuildContext context, DailyCashState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Movimientos del Día',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Filtro por cuenta
                DropdownButton<String?>(
                  value: state.selectedAccountId,
                  hint: const Text('Todas las cuentas'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas las cuentas'),
                    ),
                    ...state.accounts.map((account) {
                      return DropdownMenuItem<String?>(
                        value: account.id,
                        child: Text(account.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    ref.read(dailyCashProvider.notifier).selectAccount(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.filteredMovements.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No hay movimientos para esta fecha',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...state.filteredMovements.map((movement) {
                return _buildMovementRow(context, movement, state);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementRow(
    BuildContext context,
    CashMovement movement,
    DailyCashState state,
  ) {
    final account = state.getAccountById(movement.accountId);
    final isIncome = movement.isIncome;
    final isTransfer = movement.type == MovementType.transfer;

    Color iconColor;
    IconData icon;

    if (isTransfer) {
      iconColor = Colors.orange;
      icon = Icons.swap_horiz;
    } else if (isIncome) {
      iconColor = AppTheme.successColor;
      icon = Icons.arrow_downward;
    } else {
      iconColor = AppTheme.errorColor;
      icon = Icons.arrow_upward;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        movement.categoryLabel,
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (account != null)
                      Text(
                        account.name,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    if (movement.personName != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${movement.personName}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                '${isIncome ? '+' : '-'}${Formatters.currency(movement.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isIncome ? AppTheme.successColor : AppTheme.errorColor,
                ),
              ),
              Text(
                Formatters.time(movement.createdAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[400]),
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteMovement(context, movement);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Eliminar'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final state = ref.read(dailyCashProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: state.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      ref.read(dailyCashProvider.notifier).selectDate(picked);
    }
  }

  void _showAddMovementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AddMovementDialog(),
    );
  }

  void _showTransferDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const _TransferDialog());
  }

  void _showAccountOptions(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                account.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Ajustar Saldo'),
                subtitle: const Text('Corregir balance manualmente'),
                onTap: () {
                  Navigator.pop(context);
                  _showAdjustBalanceDialog(context, account);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Ver Historial'),
                subtitle: const Text('Todos los movimientos de esta cuenta'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navegar a historial de cuenta
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAdjustBalanceDialog(BuildContext context, Account account) {
    final controller = TextEditingController(
      text: account.balance.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Ajustar Saldo - ${account.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingrese el saldo real de la cuenta:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Nuevo Saldo',
                  prefixText: 'L ',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final newBalance =
                    double.tryParse(controller.text) ?? account.balance;
                ref
                    .read(dailyCashProvider.notifier)
                    .adjustBalance(account.id, newBalance);
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteMovement(BuildContext context, CashMovement movement) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Movimiento'),
          content: Text(
            '¿Está seguro de eliminar el movimiento "${movement.description}"?\n\n'
            'Esta acción revertirá el efecto en el saldo de la cuenta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(dailyCashProvider.notifier)
                    .deleteMovement(movement.id);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ===================== DIALOGO AGREGAR MOVIMIENTO =====================

class _AddMovementDialog extends ConsumerStatefulWidget {
  const _AddMovementDialog();

  @override
  ConsumerState<_AddMovementDialog> createState() => _AddMovementDialogState();
}

class _AddMovementDialogState extends ConsumerState<_AddMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isIncome = true;
  String? _selectedAccountId;
  MovementCategory? _selectedCategory;
  String? _errorMessage;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _personController = TextEditingController();
  final _referenceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Seleccionar la primera cuenta por defecto después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accounts = ref.read(dailyCashProvider).accounts;
      if (accounts.isNotEmpty && _selectedAccountId == null) {
        setState(() {
          _selectedAccountId = accounts.first.id;
        });
      }
    });
  }

  List<MovementCategory> get _incomeCategories => [
    MovementCategory.sale,
    MovementCategory.collection,
    MovementCategory.otherIncome,
  ];

  List<MovementCategory> get _expenseCategories => [
    MovementCategory.purchase,
    MovementCategory.salary,
    MovementCategory.services,
    MovementCategory.transport,
    MovementCategory.maintenance,
    MovementCategory.otherExpense,
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyCashProvider);
    final categories = _isIncome ? _incomeCategories : _expenseCategories;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: _isIncome ? AppTheme.successColor : AppTheme.errorColor,
          ),
          const SizedBox(width: 8),
          Text(_isIncome ? 'Nuevo Ingreso' : 'Nuevo Gasto'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle Ingreso/Gasto
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      label: const Text('Ingreso'),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    ButtonSegment(
                      value: false,
                      label: const Text('Gasto'),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                  ],
                  selected: {_isIncome},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _isIncome = selected.first;
                      _selectedCategory = null;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Cuenta
                DropdownButtonFormField<String>(
                  initialValue: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                  items: state.accounts.map((account) {
                    return DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(account.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedAccountId = value);
                  },
                  validator: (value) {
                    if (value == null) return 'Seleccione una cuenta';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Categoría
                DropdownButtonFormField<MovementCategory>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Categoría *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: categories.map((cat) {
                    return DropdownMenuItem<MovementCategory>(
                      value: cat,
                      child: Text(_getCategoryLabel(cat)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value);
                  },
                  validator: (value) {
                    if (value == null) return 'Seleccione una categoría';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Monto
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Monto *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: 'L ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese el monto';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) return 'Monto inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Descripción
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese una descripción';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Persona (opcional) - Autocomplete de clientes y proveedores
                Consumer(
                  builder: (context, ref, _) {
                    final customersState = ref.watch(customersProvider);
                    final suppliersState = ref.watch(suppliersProvider);

                    // Combinar nombres de clientes y proveedores
                    final allNames = <String>[];
                    for (final c in customersState.customers) {
                      allNames.add('👤 ${c.displayName}'); // Cliente
                    }
                    for (final s in suppliersState.suppliers) {
                      allNames.add('🏢 ${s.displayName}'); // Proveedor
                    }

                    return Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        // Mostrar todas las opciones si el campo está vacío (al hacer clic)
                        if (textEditingValue.text.isEmpty) {
                          // Mostrar máximo 10 opciones cuando está vacío
                          return allNames.take(10);
                        }
                        final query = textEditingValue.text.toLowerCase();
                        final matches = allNames
                            .where((name) => name.toLowerCase().contains(query))
                            .take(10)
                            .toList();

                        // Si no hay coincidencias, mostrar opción para crear
                        if (matches.isEmpty &&
                            textEditingValue.text.length > 2) {
                          return [
                            '➕ Crear "${textEditingValue.text}" como nuevo...',
                          ];
                        }
                        return matches;
                      },
                      onSelected: (String selection) {
                        if (selection.startsWith('➕ Crear')) {
                          // Mostrar diálogo para crear cliente o proveedor
                          _showCreatePersonDialog(context, ref);
                        } else {
                          // Quitar el emoji del inicio (👤 o 🏢)
                          String cleanName = selection;
                          if (selection.startsWith('👤 ')) {
                            cleanName = selection.substring(3);
                          } else if (selection.startsWith('🏢 ')) {
                            cleanName = selection.substring(3);
                          }
                          setState(() {
                            _personController.text = cleanName;
                          });
                        }
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            // Sincronizar controladores
                            if (_personController.text.isNotEmpty &&
                                controller.text.isEmpty) {
                              controller.text = _personController.text;
                            }
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: _isIncome
                                    ? 'Cliente (opcional)'
                                    : 'Proveedor/Persona (opcional)',
                                border: const OutlineInputBorder(),
                                prefixIcon: Icon(
                                  _isIncome ? Icons.person : Icons.business,
                                ),
                                hintText:
                                    'Clic para ver opciones o escriba para buscar...',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.person_add),
                                  tooltip: 'Crear nuevo',
                                  onPressed: () =>
                                      _showCreatePersonDialog(context, ref),
                                ),
                              ),
                              onChanged: (value) {
                                _personController.text = value;
                              },
                            );
                          },
                    );
                  },
                ),

                // Referencia (opcional)
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Referencia (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.tag),
                    hintText: 'Número de factura, recibo...',
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isIncome
                ? AppTheme.successColor
                : AppTheme.errorColor,
          ),
          child: Text(
            _isIncome ? 'Registrar Ingreso' : 'Registrar Gasto',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  String _getCategoryLabel(MovementCategory category) {
    switch (category) {
      case MovementCategory.sale:
        return 'Venta';
      case MovementCategory.collection:
        return 'Cobranza';
      case MovementCategory.otherIncome:
        return 'Otros Ingresos';
      case MovementCategory.purchase:
        return 'Compra';
      case MovementCategory.salary:
        return 'Salario';
      case MovementCategory.services:
        return 'Servicios';
      case MovementCategory.transport:
        return 'Transporte';
      case MovementCategory.maintenance:
        return 'Mantenimiento';
      case MovementCategory.otherExpense:
        return 'Otros Gastos';
      default:
        return category.name;
    }
  }

  void _showCreatePersonDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: _personController.text);
    String selectedType = _isIncome ? 'cliente' : 'proveedor';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Crear Nuevo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tipo
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'cliente',
                        label: Text('Cliente'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment(
                        value: 'proveedor',
                        label: Text('Proveedor'),
                        icon: Icon(Icons.business),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (selected) {
                      setDialogState(() => selectedType = selected.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Nombre
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: selectedType == 'cliente'
                          ? 'Nombre del cliente'
                          : 'Nombre del proveedor',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        selectedType == 'cliente'
                            ? Icons.person
                            : Icons.business,
                      ),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Podrás completar los datos adicionales después.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    if (selectedType == 'proveedor') {
                      await ref
                          .read(suppliersProvider.notifier)
                          .createQuickSupplier(name);
                    } else {
                      // Para clientes, por ahora solo usamos el nombre
                      // TODO: Implementar creación rápida de clientes
                    }

                    _personController.text = name;
                    if (dialogContext.mounted) Navigator.pop(dialogContext);

                    // Mostrar confirmación
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$name agregado como $selectedType'),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _save() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(dailyCashProvider.notifier);
    final amount = double.parse(_amountController.text);
    bool success;
    try {
      if (_isIncome) {
        success = await notifier.addIncome(
          accountId: _selectedAccountId!,
          amount: amount,
          description: _descriptionController.text,
          category: _selectedCategory!,
          personName: _personController.text.isEmpty
              ? null
              : _personController.text,
          reference: _referenceController.text.isEmpty
              ? null
              : _referenceController.text,
        );
      } else {
        success = await notifier.addExpense(
          accountId: _selectedAccountId!,
          amount: amount,
          description: _descriptionController.text,
          category: _selectedCategory!,
          personName: _personController.text.isEmpty
              ? null
              : _personController.text,
          reference: _referenceController.text.isEmpty
              ? null
              : _referenceController.text,
        );
      }
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isIncome ? 'Ingreso registrado' : 'Gasto registrado',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else if (!success) {
        setState(
          () => _errorMessage =
              (ref.read(dailyCashProvider).error ??
              'No se pudo registrar el movimiento.'),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    }
  }
}

// ===================== DIALOGO TRASLADO =====================

class _TransferDialog extends ConsumerStatefulWidget {
  const _TransferDialog();

  @override
  ConsumerState<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends ConsumerState<_TransferDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _fromAccountId;
  String? _toAccountId;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyCashProvider);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_horiz, color: Colors.orange),
          SizedBox(width: 8),
          Text('Traslado entre Cuentas'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cuenta origen
                DropdownButtonFormField<String>(
                  initialValue: _fromAccountId,
                  decoration: const InputDecoration(
                    labelText: 'De (Cuenta Origen)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.output, color: Colors.red),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: state.accounts.map((account) {
                    return DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(
                        '${account.name} - ${Formatters.currency(account.balance)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _fromAccountId = value);
                  },
                  validator: (value) {
                    if (value == null) return 'Seleccione cuenta origen';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Icono de flecha
                const Icon(
                  Icons.arrow_downward,
                  color: Colors.orange,
                  size: 28,
                ),
                const SizedBox(height: 16),

                // Cuenta destino
                DropdownButtonFormField<String>(
                  initialValue: _toAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Hacia (Cuenta Destino)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.input, color: Colors.green),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: state.accounts.where((a) => a.id != _fromAccountId).map((
                    account,
                  ) {
                    return DropdownMenuItem<String>(
                      value: account.id,
                      child: Text(
                        '${account.name} - ${Formatters.currency(account.balance)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _toAccountId = value);
                  },
                  validator: (value) {
                    if (value == null) return 'Seleccione cuenta destino';
                    if (value == _fromAccountId) return 'Debe ser diferente';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Monto
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Monto',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: 'L ',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese el monto';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) return 'Monto inválido';

                    if (_fromAccountId != null) {
                      final fromAccount = state.getAccountById(_fromAccountId!);
                      if (fromAccount != null && amount > fromAccount.balance) {
                        return 'Saldo insuficiente';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Descripción
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    isDense: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese descripción';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _transfer,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Trasladar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _transfer() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(dailyCashProvider.notifier);
    final amount = double.parse(_amountController.text);

    final success = await notifier.transfer(
      fromAccountId: _fromAccountId!,
      toAccountId: _toAccountId!,
      amount: amount,
      description: _descriptionController.text,
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Traslado realizado exitosamente'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

// ===================== NAV ITEM =====================

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          border: isSelected
              ? const Border(left: BorderSide(color: Colors.white, width: 3))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
