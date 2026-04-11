import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/providers/commissions_provider.dart';
import '../../../data/providers/employees_provider.dart';
import '../../../domain/entities/sales_commission.dart';

/// Tab de comisiones por ventas de empleados.
class EmployeesCommissionsTab extends ConsumerStatefulWidget {
  const EmployeesCommissionsTab({super.key});

  @override
  ConsumerState<EmployeesCommissionsTab> createState() =>
      EmployeesCommissionsTabState();
}

class EmployeesCommissionsTabState
    extends ConsumerState<EmployeesCommissionsTab> {
  String? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(commissionsProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final commissionsState = ref.watch(commissionsProvider);
    final employeesState = ref.watch(employeesProvider);
    final theme = Theme.of(context);

    if (commissionsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final pendingCommissions = commissionsState.pendingCommissions;
    final paidCommissions = commissionsState.paidCommissions;

    // Filtrar por empleado si se seleccionó
    final filteredPending = _selectedEmployeeId != null
        ? pendingCommissions
              .where((c) => c.employeeId == _selectedEmployeeId)
              .toList()
        : pendingCommissions;
    final filteredPaid = _selectedEmployeeId != null
        ? paidCommissions
              .where((c) => c.employeeId == _selectedEmployeeId)
              .toList()
        : paidCommissions;

    // Resumen por empleado
    final summaryByEmployee = _buildSummary(pendingCommissions, employeesState);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen general
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 500) {
                // Mobile: compact horizontal strip
                return Row(
                  children: [
                    Expanded(
                      child: _buildCompactStat(
                        'Pendientes',
                        '${pendingCommissions.length}',
                        Icons.pending_actions,
                        const Color(0xFF6A1B9A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStat(
                        'Total Pendiente',
                        Helpers.formatCurrency(commissionsState.totalPending),
                        Icons.attach_money,
                        const Color(0xFFF57C00),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStat(
                        'Pagadas',
                        '${paidCommissions.length}',
                        Icons.check_circle,
                        const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Comisiones Pendientes',
                      '${pendingCommissions.length}',
                      Icons.pending_actions,
                      const Color(0xFF6A1B9A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Pendiente',
                      Helpers.formatCurrency(commissionsState.totalPending),
                      Icons.attach_money,
                      const Color(0xFFF57C00),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Comisiones Pagadas',
                      '${paidCommissions.length}',
                      Icons.check_circle,
                      const Color(0xFF2E7D32),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Filtro por empleado
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF334155)
                    : const Color(0xFFEEEEEE),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Filtrar:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedEmployeeId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Todos los empleados',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Todos los empleados'),
                      ),
                      ...employeesState.activeEmployees.map(
                        (emp) => DropdownMenuItem<String>(
                          value: emp.id,
                          child: Text(emp.fullName),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedEmployeeId = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Resumen por empleado (solo si no hay filtro)
          if (_selectedEmployeeId == null && summaryByEmployee.isNotEmpty) ...[
            const Text(
              'Resumen por Empleado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...summaryByEmployee.map(
              (s) => _buildEmployeeSummaryCard(s, theme),
            ),
            const SizedBox(height: 24),
          ],

          // Comisiones pendientes
          const Text(
            'Comisiones Pendientes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (filteredPending.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: const Color(0xFF81C784),
                      ),
                      const SizedBox(height: 16),
                      const Text('No hay comisiones pendientes'),
                      const SizedBox(height: 4),
                      Text(
                        'Las comisiones se generan al crear ventas con vendedor asignado',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...filteredPending.map((c) => _buildCommissionCard(c, theme)),

          if (filteredPaid.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Comisiones Pagadas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...filteredPaid.map(
              (c) => _buildCommissionCard(c, theme, isPaid: true),
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _buildSummary(
    List<SalesCommission> pending,
    EmployeesState employeesState,
  ) {
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final c in pending) {
      if (!grouped.containsKey(c.employeeId)) {
        final emp = employeesState.employees
            .where((e) => e.id == c.employeeId)
            .firstOrNull;
        grouped[c.employeeId] = {
          'employee_id': c.employeeId,
          'employee_name': emp?.fullName ?? c.employeeName ?? 'Empleado',
          'total': 0.0,
          'count': 0,
        };
      }
      grouped[c.employeeId]!['total'] =
          (grouped[c.employeeId]!['total'] as double) + c.commissionAmount;
      grouped[c.employeeId]!['count'] =
          (grouped[c.employeeId]!['count'] as int) + 1;
    }
    final list = grouped.values.toList();
    list.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    return list;
  }

  Widget _buildCompactStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF757575), fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF757575),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildEmployeeSummaryCard(
    Map<String, dynamic> summary,
    ThemeData theme,
  ) {
    final name = summary['employee_name'] as String;
    final total = summary['total'] as double;
    final count = summary['count'] as int;
    final empId = summary['employee_id'] as String;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
          child: const Icon(Icons.person, color: Color(0xFF6A1B9A)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$count comisiones pendientes'),
        trailing: Text(
          Helpers.formatCurrency(total),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF6A1B9A),
          ),
        ),
        onTap: () => setState(() => _selectedEmployeeId = empId),
      ),
    );
  }

  Widget _buildCommissionCard(
    SalesCommission commission,
    ThemeData theme, {
    bool isPaid = false,
  }) {
    final dateStr = DateFormat('dd/MM/yyyy').format(commission.createdAt);
    final statusColor = isPaid
        ? const Color(0xFF2E7D32)
        : const Color(0xFFF57C00);
    final statusIcon = isPaid ? Icons.check_circle : Icons.pending;
    final statusText = isPaid ? 'Pagada' : 'Pendiente';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        commission.invoiceNumber ?? 'Sin número',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        commission.customerName ?? 'Cliente',
                        style: const TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Helpers.formatCurrency(commission.commissionAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: statusColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Detalles
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  _buildDetailChip(
                    'Venta',
                    Helpers.formatCurrency(commission.invoiceTotal),
                  ),
                  const SizedBox(width: 12),
                  _buildDetailChip(
                    'Tasa',
                    '${commission.commissionPercentage.toStringAsFixed(4)}%',
                  ),
                  const SizedBox(width: 12),
                  _buildDetailChip('Fecha', dateStr),
                  if (commission.employeeName != null) ...[
                    const SizedBox(width: 12),
                    _buildDetailChip('Vendedor', commission.employeeName!),
                  ],
                ],
              ),
            ),
            if (isPaid && commission.paidDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Pagada el ${DateFormat('dd/MM/yyyy').format(commission.paidDate!)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
