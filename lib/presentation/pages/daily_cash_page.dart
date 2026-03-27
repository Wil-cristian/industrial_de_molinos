import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/accounts_provider.dart';
import '../../data/providers/customers_provider.dart';
import '../../data/providers/suppliers_provider.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/datasources/storage_datasource.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/cash_movement.dart';

String _categoryLabel(MovementCategory category, [String? customName]) {
  switch (category) {
    case MovementCategory.sale:
      return 'Venta';
    case MovementCategory.collection:
      return 'Cobranza';
    case MovementCategory.pago_prestamo:
      return 'Pago Préstamo';
    case MovementCategory.otherIncome:
      return 'Otros Ingresos';
    case MovementCategory.cuidado_personal:
      return 'Cuidado Personal';
    case MovementCategory.servicios_publicos:
      return 'Servicios Públicos';
    case MovementCategory.papeleria:
      return 'Papelería';
    case MovementCategory.nomina:
      return 'Nómina';
    case MovementCategory.impuestos:
      return 'Impuestos';
    case MovementCategory.consumibles:
      return 'Consumibles';
    case MovementCategory.transporte:
      return 'Transporte';
    case MovementCategory.gastos_reducibles:
      return 'Gastos Reducibles';
    case MovementCategory.transferOut:
      return 'Traslado Salida';
    case MovementCategory.transferIn:
      return 'Traslado Entrada';
    case MovementCategory.custom:
      return customName ?? 'Otra';
  }
}

class DailyCashPage extends ConsumerStatefulWidget {
  const DailyCashPage({super.key});

  @override
  ConsumerState<DailyCashPage> createState() => _DailyCashPageState();
}

class _DailyCashPageState extends ConsumerState<DailyCashPage> {
  bool _isActive = false;

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

    // Auto-reload when this page becomes active (IndexedStack keeps pages alive)
    final location = GoRouterState.of(context).uri.path;
    if (location == '/daily-cash' && !_isActive) {
      _isActive = true;
      Future.microtask(() {
        if (mounted) ref.read(dailyCashProvider.notifier).load();
      });
    } else if (location != '/daily-cash') {
      _isActive = false;
    }

    return Scaffold(
      body: Stack(
        children: [
          // Contenido principal (sin sidebar - el router lo maneja)
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Header section compacto
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 900;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.factory,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Caja Diaria',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            'Control de ingresos, gastos y traslados',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: const Color(
                                                    0xFF757575,
                                                  ),
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: isNarrow
                                            ? constraints.maxWidth
                                            : 360,
                                      ),
                                      child: InkWell(
                                        onTap: () => _selectDate(context),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  isNarrow
                                                      ? Formatters.date(
                                                          state.selectedDate,
                                                        )
                                                      : Formatters.dateLong(
                                                          state.selectedDate,
                                                        ),
                                                  style: TextStyle(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(
                                                Icons.arrow_drop_down,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _showHistoryRangeDialog(context),
                                      icon: const Icon(Icons.history, size: 18),
                                      label: const Text('Ver Historial'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFF616161,
                                        ),
                                        side: BorderSide(
                                          color: const Color(0xFFE0E0E0),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _showAddMovementDialog(context),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: Text(
                                        isNarrow ? 'Nuevo' : 'Nuevo Movimiento',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _showTransferDialog(context),
                                      icon: const Icon(
                                        Icons.swap_horiz,
                                        size: 18,
                                      ),
                                      label: const Text('Traslado'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFF9A825,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => ref
                                          .read(dailyCashProvider.notifier)
                                          .load(),
                                      icon: const Icon(Icons.refresh),
                                      tooltip: 'Recargar datos',
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      // Contenido
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cards de cuentas
                              _buildAccountCards(context, state),
                              const SizedBox(height: 4),

                              // Resumen del día
                              _buildDaySummary(context, state),
                              const SizedBox(height: 4),

                              // Desglose por categoría
                              if (state.movements.isNotEmpty)
                                _buildCategoryBreakdown(context, state),
                              if (state.movements.isNotEmpty)
                                const SizedBox(height: 4),

                              // Lista de movimientos
                              _buildMovementsList(context, state),
                            ],
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

  Widget _buildAccountCards(BuildContext context, DailyCashState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Saldos Actuales',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance,
                    color: AppColors.success,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Total: ${Formatters.currency(state.totalBalance)}',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 900;
            if (isNarrow) {
              final columns = constraints.maxWidth < 620 ? 1 : 2;
              final spacing = 6.0;
              final cardWidth = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - spacing) / 2;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: state.accounts.map((account) {
                  return SizedBox(
                    width: cardWidth,
                    child: _buildAccountCard(context, account, state),
                  );
                }).toList(),
              );
            }

            return Row(
              children: state.accounts.asMap().entries.map((entry) {
                final index = entry.key;
                final account = entry.value;
                final isLast = index == state.accounts.length - 1;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : 3),
                    child: _buildAccountCard(context, account, state),
                  ),
                );
              }).toList(),
            );
          },
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
        : Theme.of(context).colorScheme.primary;

    final incomeToday = state.incomeByAccount[account.id] ?? 0.0;
    final expenseToday = state.expenseByAccount[account.id] ?? 0.0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: accountColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Icon(
                    account.type == AccountType.cash
                        ? Icons.account_balance_wallet
                        : Icons.account_balance,
                    color: accountColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: TextStyle(
                          color: const Color(0xFF424242),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.typeLabel,
                        style: TextStyle(
                          color: const Color(0xFF9E9E9E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.more_vert, color: const Color(0xFFBDBDBD)),
                  onPressed: () => _showAccountOptions(context, account),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              Formatters.currency(account.balance),
              style: TextStyle(
                color: accountColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Saldo actual',
              style: TextStyle(color: const Color(0xFF9E9E9E), fontSize: 10),
            ),
            const Divider(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat(
                  'Ingresos hoy',
                  Formatters.currency(incomeToday),
                  const Color(0xFF2E7D32),
                ),
                _buildMiniStat(
                  'Gastos hoy',
                  Formatters.currency(expenseToday),
                  const Color(0xFFC62828),
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
        Text(
          label,
          style: TextStyle(color: const Color(0xFF9E9E9E), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDaySummary(BuildContext context, DailyCashState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen del Día',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            LayoutBuilder(
              builder: (context, constraints) {
                final items = [
                  _buildSummaryItem(
                    context,
                    icon: Icons.arrow_downward,
                    label: 'Total Ingresos',
                    value: state.dayIncome,
                    color: AppColors.success,
                  ),
                  _buildSummaryItem(
                    context,
                    icon: Icons.arrow_upward,
                    label: 'Total Gastos',
                    value: state.dayExpense,
                    color: AppColors.danger,
                  ),
                  _buildSummaryItem(
                    context,
                    icon: Icons.trending_up,
                    label: 'Saldo Neto',
                    value: state.dayNet,
                    color: state.dayNet >= 0
                        ? AppColors.success
                        : AppColors.danger,
                    showSign: true,
                  ),
                  _buildSummaryItem(
                    context,
                    icon: Icons.receipt,
                    label: 'Movimientos',
                    valueText: '${state.movementCount}',
                    color: AppColors.info,
                  ),
                ];

                if (constraints.maxWidth < 860) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items
                        .map(
                          (item) => SizedBox(
                            width: (constraints.maxWidth - 8) / 2,
                            child: item,
                          ),
                        )
                        .toList(),
                  );
                }

                return Row(
                  children: [
                    Expanded(child: items[0]),
                    Container(
                      width: 1,
                      height: 60,
                      color: const Color(0xFFE0E0E0),
                    ),
                    Expanded(child: items[1]),
                    Container(
                      width: 1,
                      height: 60,
                      color: const Color(0xFFE0E0E0),
                    ),
                    Expanded(child: items[2]),
                    Container(
                      width: 1,
                      height: 60,
                      color: const Color(0xFFE0E0E0),
                    ),
                    Expanded(child: items[3]),
                  ],
                );
              },
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
          Text(
            label,
            style: TextStyle(color: const Color(0xFF757575), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(BuildContext context, DailyCashState state) {
    final expenseByCat = state.expenseByCategory;
    final incomeByCat = state.incomeByCategory;

    if (expenseByCat.isEmpty && incomeByCat.isEmpty) return const SizedBox();

    // Sorted entries by amount descending
    final expenseEntries = expenseByCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final incomeEntries = incomeByCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Desglose por Categoría',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (incomeEntries.isNotEmpty) ...[
              Text(
                'Ingresos',
                style: TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              ...incomeEntries.map(
                (e) => _buildCategoryRow(
                  e.key,
                  e.key,
                  e.value,
                  state.dayIncome,
                  AppColors.success,
                ),
              ),
              if (expenseEntries.isNotEmpty) const Divider(height: 16),
            ],
            if (expenseEntries.isNotEmpty) ...[
              Text(
                'Gastos',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              ...expenseEntries.map(
                (e) => _buildCategoryRow(
                  e.key,
                  e.key,
                  e.value,
                  state.dayExpense,
                  AppColors.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(
    String key,
    String label,
    double amount,
    double total,
    Color color,
  ) {
    final percentage = total > 0 ? (amount / total) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: const TextStyle(fontSize: 13)),
                    ),
                    Text(
                      '${(percentage * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Stack(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    Formatters.currency(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: 140,
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: Text(
                  Formatters.currency(amount),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF757575),
                  ),
                ),
              ),
            ],
          );
        },
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
            LayoutBuilder(
              builder: (context, constraints) {
                final filter = DropdownButton<String?>(
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
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    ref.read(dailyCashProvider.notifier).selectAccount(value);
                  },
                );

                if (constraints.maxWidth < 760) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Movimientos del Día',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      filter,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Movimientos del Día',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    filter,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            if (state.filteredMovements.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.inbox, size: 64, color: Color(0xFF9E9E9E)),
                      SizedBox(height: 16),
                      Text(
                        'No hay movimientos para esta fecha',
                        style: TextStyle(color: Color(0xFF9E9E9E)),
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
    final isTransferIn = movement.category == MovementCategory.transferIn;

    Color iconColor;
    IconData icon;

    if (isTransfer) {
      iconColor = const Color(0xFFF9A825);
      icon = isTransferIn ? Icons.arrow_downward : Icons.arrow_upward;
    } else if (isIncome) {
      iconColor = AppColors.success;
      icon = Icons.arrow_downward;
    } else {
      iconColor = AppColors.danger;
      icon = Icons.arrow_upward;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;

          final metaRow = Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              if (account != null)
                Text(
                  account.name,
                  style: TextStyle(
                    color: const Color(0xFF757575),
                    fontSize: 12,
                  ),
                ),
              if (movement.personName != null)
                Text(
                  '• ${movement.personName}',
                  style: TextStyle(
                    color: const Color(0xFF757575),
                    fontSize: 12,
                  ),
                ),
            ],
          );

          final amountBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome || isTransferIn ? '+' : '-'}${Formatters.currency(movement.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isTransfer
                      ? const Color(0xFFF9A825)
                      : (isIncome ? AppColors.success : AppColors.danger),
                ),
              ),
              Text(
                Formatters.time(movement.createdAt),
                style: TextStyle(color: const Color(0xFF9E9E9E), fontSize: 11),
              ),
              if (movement.attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_file,
                        size: 12,
                        color: const Color(0xFF42A5F5),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${movement.attachments.length}',
                        style: TextStyle(
                          color: const Color(0xFF42A5F5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );

          final menu = PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: const Color(0xFFBDBDBD)),
            onSelected: (value) {
              if (value == 'detail') {
                _showMovementDetail(context, movement, state);
              } else if (value == 'delete') {
                _confirmDeleteMovement(context, movement);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'detail',
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF1565C0),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('Ver Detalle'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Color(0xFFC62828), size: 20),
                    SizedBox(width: 8),
                    Text('Eliminar'),
                  ],
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    const SizedBox(width: 12),
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
                          metaRow,
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [amountBlock, const Spacer(), menu]),
              ],
            );
          }

          return Row(
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
                    metaRow,
                  ],
                ),
              ),
              amountBlock,
              const SizedBox(width: 8),
              menu,
            ],
          );
        },
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

  void _showHistoryRangeDialog(BuildContext context) {
    DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    DateTime endDate = DateTime.now();
    String? selectedAccountId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ver Historial de Movimientos'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width < 600
                ? double.maxFinite
                : 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selector de cuenta
                DropdownButtonFormField<String?>(
                  value: selectedAccountId,
                  hint: const Text('Todas las cuentas'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas las cuentas'),
                    ),
                    ...ref.read(dailyCashProvider).accounts.map((account) {
                      return DropdownMenuItem<String?>(
                        value: account.id,
                        child: Text(account.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => selectedAccountId = value);
                  },
                  decoration: InputDecoration(
                    labelText: 'Filtrar por Cuenta',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Fecha inicio
                ListTile(
                  title: const Text('Desde'),
                  subtitle: Text(Formatters.dateLong(startDate)),
                  leading: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2020),
                      lastDate: endDate,
                    );
                    if (picked != null) {
                      setState(() => startDate = picked);
                    }
                  },
                ),
                const Divider(),

                // Fecha fin
                ListTile(
                  title: const Text('Hasta'),
                  subtitle: Text(Formatters.dateLong(endDate)),
                  leading: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => endDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Ver Movimientos'),
              onPressed: () async {
                Navigator.pop(context);
                _showHistoryResults(
                  context,
                  startDate,
                  endDate,
                  selectedAccountId,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryResults(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
    String? accountId,
  ) async {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return FutureBuilder<List<CashMovement>>(
            future: AccountsDataSource.getMovementsByDateRange(
              startDate,
              endDate,
            ),
            builder: (context, snapshot) {
              List<CashMovement> movements = [];
              if (snapshot.hasData) {
                movements = snapshot.data ?? [];
                // Filtrar por cuenta si está seleccionada
                if (accountId != null) {
                  movements = movements
                      .where(
                        (m) =>
                            m.accountId == accountId ||
                            m.toAccountId == accountId,
                      )
                      .toList();
                }
              }

              return AlertDialog(
                title: Text(
                  'Movimientos: ${Formatters.dateLong(startDate)} - ${Formatters.dateLong(endDate)}',
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width < 600
                      ? double.maxFinite
                      : 700,
                  height: MediaQuery.of(context).size.height < 700
                      ? MediaQuery.of(context).size.height * 0.6
                      : 500,
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : movements.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox,
                                size: 64,
                                color: const Color(0xFFBDBDBD),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay movimientos en este rango',
                                style: TextStyle(
                                  color: const Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Resumen
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      const Text(
                                        'Total Movimientos',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9E9E9E),
                                        ),
                                      ),
                                      Text(
                                        movements.length.toString(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const Text(
                                        'Total Ingresos',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9E9E9E),
                                        ),
                                      ),
                                      Text(
                                        '\$${Helpers.formatNumber(movements.where((m) => m.type == MovementType.income).fold(0.0, (sum, m) => sum + m.amount))}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const Text(
                                        'Total Gastos',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF9E9E9E),
                                        ),
                                      ),
                                      Text(
                                        '\$${Helpers.formatNumber(movements.where((m) => m.type == MovementType.expense).fold(0.0, (sum, m) => sum + m.amount))}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFC62828),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Lista
                            Expanded(
                              child: ListView.separated(
                                itemCount: movements.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 0),
                                itemBuilder: (context, index) {
                                  final movement = movements[index];
                                  final accountName =
                                      ref
                                          .read(dailyCashProvider)
                                          .getAccountById(movement.accountId)
                                          ?.name ??
                                      'Desconocida';

                                  final isIncome =
                                      movement.type == MovementType.income;
                                  final color = isIncome
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828);

                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      isIncome
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color: color,
                                      size: 20,
                                    ),
                                    title: Text(
                                      movement.description,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          accountName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: const Color(0xFF757575),
                                          ),
                                        ),
                                        Text(
                                          Formatters.dateTime(movement.date),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: const Color(0xFF9E9E9E),
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Text(
                                      '\$${Helpers.formatNumber(movement.amount)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
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

  void _confirmDeleteMovement(BuildContext context, CashMovement movement) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar Movimiento'),
          content: Text(
            '¿Está seguro de eliminar el movimiento "${movement.description}"?\n\n'
            'Esta acción revertirá el efecto en el saldo de la cuenta.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await ref
                    .read(dailyCashProvider.notifier)
                    .deleteMovement(movement.id);
                if (!success) {
                  final error = ref.read(dailyCashProvider).error;
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $error'),
                      backgroundColor: const Color(0xFFC62828),
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Movimiento eliminado correctamente'),
                      backgroundColor: Color(0xFF2E7D32),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
              ),
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

  void _showMovementDetail(
    BuildContext context,
    CashMovement movement,
    DailyCashState state,
  ) {
    final account = state.getAccountById(movement.accountId);
    final isIncome = movement.isIncome;
    final isTransfer = movement.type == MovementType.transfer;
    final color = isTransfer
        ? const Color(0xFFF9A825)
        : (isIncome ? AppColors.success : AppColors.danger);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  movement.description,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width < 600
                ? double.maxFinite
                : 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Monto destacado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${isIncome ? '+' : '-'}${Formatters.currency(movement.amount)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            movement.categoryLabel,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Información del movimiento
                  _detailRow(
                    Icons.account_balance_wallet,
                    'Cuenta',
                    account?.name ?? 'N/A',
                  ),
                  if (movement.reference != null &&
                      movement.reference!.isNotEmpty)
                    _detailRow(Icons.tag, 'Referencia', movement.reference!),
                  if (movement.personName != null &&
                      movement.personName!.isNotEmpty)
                    _detailRow(Icons.person, 'Persona', movement.personName!),
                  _detailRow(
                    Icons.calendar_today,
                    'Fecha',
                    Formatters.date(movement.date),
                  ),
                  _detailRow(
                    Icons.access_time,
                    'Hora',
                    Formatters.time(movement.createdAt),
                  ),
                  _detailRow(Icons.category, 'Tipo', movement.typeLabel),

                  // Adjuntos
                  if (movement.attachments.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 18,
                          color: const Color(0xFF1E88E5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Adjuntos (${movement.attachments.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: const Color(0xFF1976D2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...movement.attachments.map((attachment) {
                      final publicUrl = StorageDatasource.getPublicUrl(
                        attachment.path,
                      );
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (attachment.isImage)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                                child: Image.network(
                                  publicUrl,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 80,
                                    color: const Color(0xFFEEEEEE),
                                    child: const Center(
                                      child: Icon(Icons.broken_image, size: 32),
                                    ),
                                  ),
                                ),
                              ),
                            ListTile(
                              dense: true,
                              leading: Icon(
                                attachment.isImage
                                    ? Icons.image
                                    : (attachment.isPdf
                                          ? Icons.picture_as_pdf
                                          : Icons.insert_drive_file),
                                color: attachment.isImage
                                    ? const Color(0xFF1565C0)
                                    : (attachment.isPdf
                                          ? const Color(0xFFC62828)
                                          : const Color(0xFF757575)),
                                size: 20,
                              ),
                              title: Text(
                                attachment.name,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                _formatFileSize(attachment.size),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: const Color(0xFF9E9E9E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: const Color(0xFFBDBDBD),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sin archivos adjuntos',
                            style: TextStyle(
                              color: const Color(0xFF9E9E9E),
                              fontSize: 12,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF9E9E9E)),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: const Color(0xFF757575), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
  String? _selectedCustomName; // Nombre de la categoría custom seleccionada
  String? _errorMessage;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _personController = TextEditingController();
  final _referenceController = TextEditingController();
  final List<PlatformFile> _attachedFiles = [];
  List<Map<String, dynamic>> _customCategories = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accounts = ref.read(dailyCashProvider).accounts;
      if (accounts.isNotEmpty && _selectedAccountId == null) {
        setState(() {
          _selectedAccountId = accounts.first.id;
        });
      }
      _loadNextReference();
      _loadCustomCategories();
    });
  }

  Future<void> _loadCustomCategories() async {
    try {
      final data = await SupabaseDataSource.client
          .from('custom_categories')
          .select()
          .order('name');
      if (mounted) {
        setState(() {
          _customCategories = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (_) {}
  }

  Future<void> _addCustomCategory() async {
    final nameController = TextEditingController();
    final type = _isIncome ? 'income' : 'expense';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Categoría'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            border: OutlineInputBorder(),
            hintText: 'Ej: Mantenimiento',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) Navigator.pop(ctx, name);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        await SupabaseDataSource.client.from('custom_categories').insert({
          'name': result,
          'type': type,
        });
        await _loadCustomCategories();
        if (mounted) {
          setState(() {
            _selectedCategory = MovementCategory.custom;
            _selectedCustomName = result;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().contains('idx_custom_categories_name_type')
                    ? 'Ya existe una categoría con ese nombre'
                    : 'Error al crear categoría',
              ),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
      }
    }
  }

  Future<void> _loadNextReference() async {
    final nextNum = await AccountsDataSource.getNextReferenceNumber();
    if (mounted) {
      setState(() {
        _referenceController.text = 'MOV-${nextNum.toString().padLeft(4, '0')}';
      });
    }
  }

  List<MovementCategory> get _incomeCategories => [
    MovementCategory.sale,
    MovementCategory.collection,
    MovementCategory.otherIncome,
  ];

  List<MovementCategory> get _expenseCategories => [
    MovementCategory.cuidado_personal,
    MovementCategory.servicios_publicos,
    MovementCategory.papeleria,
    MovementCategory.nomina,
    MovementCategory.impuestos,
    MovementCategory.consumibles,
    MovementCategory.transporte,
    MovementCategory.gastos_reducibles,
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.read(dailyCashProvider);
    final builtInCategories = _isIncome
        ? _incomeCategories
        : _expenseCategories;
    final typeFilter = _isIncome ? 'income' : 'expense';
    final filteredCustom = _customCategories
        .where((c) => c['type'] == typeFilter)
        .toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: _isIncome ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 8),
          Text(_isIncome ? 'Nuevo Ingreso' : 'Nuevo Gasto'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width < 600 ? double.maxFinite : 500,
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
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory != null
                            ? (_selectedCategory == MovementCategory.custom
                                  ? 'custom_${_selectedCustomName ?? ''}'
                                  : _selectedCategory!.name)
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Categoría *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: [
                          ...builtInCategories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat.name,
                              child: Text(_categoryLabel(cat)),
                            );
                          }),
                          if (filteredCustom.isNotEmpty)
                            const DropdownMenuItem<String>(
                              enabled: false,
                              value: '__divider__',
                              child: Divider(),
                            ),
                          ...filteredCustom.map((c) {
                            final name = c['name'] as String;
                            return DropdownMenuItem<String>(
                              value: 'custom_$name',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.label_outline,
                                    size: 16,
                                    color: const Color(0xFF757575),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(name),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          if (value == null || value == '__divider__') return;
                          setState(() {
                            if (value.startsWith('custom_')) {
                              _selectedCategory = MovementCategory.custom;
                              _selectedCustomName = value.substring(7);
                            } else {
                              _selectedCategory = MovementCategory.values
                                  .firstWhere(
                                    (c) => c.name == value,
                                    orElse: () => MovementCategory.otherIncome,
                                  );
                              _selectedCustomName = null;
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Seleccione una categoría';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addCustomCategory,
                      icon: const Icon(Icons.add),
                      tooltip: 'Crear categoría',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
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

                // Persona (opcional) - Clientes para ingresos, Proveedores para gastos
                Builder(
                  builder: (context) {
                    final customersState = ref.read(customersProvider);
                    final suppliersState = ref.read(suppliersProvider);

                    // Mostrar clientes para ingresos, proveedores para gastos
                    final allNames = <String>[];
                    if (_isIncome) {
                      for (final c in customersState.customers) {
                        allNames.add('👤 ${c.displayName}'); // Cliente
                      }
                    } else {
                      for (final s in suppliersState.suppliers) {
                        allNames.add('🏢 ${s.displayName}'); // Proveedor
                      }
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
                const SizedBox(height: 16),

                // Archivos adjuntos
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            color: const Color(0xFF757575),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Archivos adjuntos',
                            style: TextStyle(
                              color: const Color(0xFF616161),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _pickFiles,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Agregar'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_attachedFiles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _attachedFiles.map((file) {
                            final isImage =
                                file.extension?.toLowerCase() == 'jpg' ||
                                file.extension?.toLowerCase() == 'jpeg' ||
                                file.extension?.toLowerCase() == 'png';
                            final isPdf =
                                file.extension?.toLowerCase() == 'pdf';

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isImage
                                    ? const Color(0xFFE3F2FD)
                                    : (isPdf
                                          ? const Color(0xFFFFEBEE)
                                          : const Color(0xFFF5F5F5)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isImage
                                      ? const Color(0xFF90CAF9)
                                      : (isPdf
                                            ? const Color(0xFFEF9A9A)
                                            : const Color(0xFFE0E0E0)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isImage
                                        ? Icons.image
                                        : (isPdf
                                              ? Icons.picture_as_pdf
                                              : Icons.insert_drive_file),
                                    size: 16,
                                    color: isImage
                                        ? const Color(0xFF1565C0)
                                        : (isPdf
                                              ? const Color(0xFFC62828)
                                              : const Color(0xFF757575)),
                                  ),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 120,
                                    ),
                                    child: Text(
                                      file.name,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _attachedFiles.remove(file);
                                      });
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: const Color(0xFF757575),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Sin archivos adjuntos',
                            style: TextStyle(
                              color: const Color(0xFF9E9E9E),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Color(0xFFC62828)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isIncome ? AppColors.success : AppColors.danger,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isIncome ? 'Registrar Ingreso' : 'Registrar Gasto',
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar archivos: $e')),
        );
      }
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
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF757575),
                    ),
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
                          backgroundColor: AppColors.success,
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

  bool _isSaving = false;

  void _save() async {
    setState(() {
      _errorMessage = null;
      _isSaving = false;
    });
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(dailyCashProvider.notifier);
    final amount = double.parse(_amountController.text);

    // Mostrar advertencia si el saldo quedará negativo, pero permitir continuar
    if (!_isIncome && _selectedAccountId != null) {
      final state = ref.read(dailyCashProvider);
      final account = state.getAccountById(_selectedAccountId!);
      if (account != null && account.balance < amount) {
        final newBalance = account.balance - amount;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Saldo insuficiente'),
            content: Text(
              'La cuenta "${account.name}" tiene \$${account.balance.toStringAsFixed(0)} disponible.\n\n'
              'Al registrar este gasto el saldo quedará en \$${newBalance.toStringAsFixed(0)}.\n\n'
              '¿Desea continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    setState(() => _isSaving = true);

    String? movementId;
    try {
      if (_isIncome) {
        movementId = await notifier.addIncome(
          accountId: _selectedAccountId!,
          amount: amount,
          description: _descriptionController.text,
          category: _selectedCategory!,
          customCategoryName: _selectedCustomName,
          personName: _personController.text.isEmpty
              ? null
              : _personController.text,
          reference: _referenceController.text.isEmpty
              ? null
              : _referenceController.text,
        );
      } else {
        movementId = await notifier.addExpense(
          accountId: _selectedAccountId!,
          amount: amount,
          description: _descriptionController.text,
          category: _selectedCategory!,
          customCategoryName: _selectedCustomName,
          personName: _personController.text.isEmpty
              ? null
              : _personController.text,
          reference: _referenceController.text.isEmpty
              ? null
              : _referenceController.text,
        );
      }

      if (movementId != null) {
        // Subir archivos adjuntos a Supabase Storage
        if (_attachedFiles.isNotEmpty) {
          try {
            // Asegurar que el bucket existe
            await StorageDatasource.ensureBucketExists();

            if (mounted) {
              setState(
                () => _errorMessage =
                    'Subiendo ${_attachedFiles.length} archivo(s)...',
              );
            }

            final attachments = await StorageDatasource.uploadFiles(
              files: _attachedFiles,
              movementId: movementId,
            );
            // Guardar las referencias en la DB
            await StorageDatasource.saveAttachmentsToMovement(
              movementId,
              attachments,
            );

            // Refrescar movimientos para mostrar el ícono de adjuntos
            notifier.refreshMovements();
          } catch (uploadError) {
            // El movimiento ya se guardó, avisamos del error
            if (mounted) {
              setState(() => _isSaving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Movimiento guardado, pero error al subir archivos: $uploadError',
                  ),
                  backgroundColor: const Color(0xFFF9A825),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }

        if (mounted) {
          Navigator.pop(context);
          final hasFiles = _attachedFiles.isNotEmpty;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isIncome
                    ? 'Ingreso registrado${hasFiles ? ' con adjuntos' : ''}'
                    : 'Gasto registrado${hasFiles ? ' con adjuntos' : ''}',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage =
              ref.read(dailyCashProvider).error ??
              'No se pudo registrar el movimiento.';
        });
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
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
    final state = ref.read(dailyCashProvider);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.swap_horiz, color: Color(0xFFF9A825)),
          SizedBox(width: 8),
          Text('Traslado entre Cuentas'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width < 600
              ? double.maxFinite
              : 400,
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
                    prefixIcon: Icon(Icons.output, color: Color(0xFFC62828)),
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
                  color: Color(0xFFF9A825),
                  size: 28,
                ),
                const SizedBox(height: 16),

                // Cuenta destino
                DropdownButtonFormField<String>(
                  initialValue: _toAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Hacia (Cuenta Destino)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.input, color: Color(0xFF2E7D32)),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF9A825),
          ),
          child: const Text('Trasladar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  void _transfer() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(dailyCashProvider.notifier);
    final amount = double.parse(_amountController.text);

    // Validar saldo suficiente en cuenta origen
    if (_fromAccountId != null) {
      final state = ref.read(dailyCashProvider);
      final fromAccount = state.getAccountById(_fromAccountId!);
      if (fromAccount != null && fromAccount.balance < amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saldo insuficiente. Disponible: \$${fromAccount.balance.toStringAsFixed(0)} en ${fromAccount.name}',
            ),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
        return;
      }
    }

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
          backgroundColor: Color(0xFFF9A825),
        ),
      );
    }
  }
}

// ===================== NAV ITEM =====================
// ignore: unused_element - Reserved for sidebar navigation
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isSelected,
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
              ? const Color(0xFFFFFFFF).withOpacity(0.1)
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
