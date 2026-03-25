import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/datasources/payroll_datasource.dart';
import '../../../data/providers/payroll_provider.dart';

/// Tab de incapacidades y permisos de empleados.
class EmployeesIncapacitiesTab extends ConsumerStatefulWidget {
  const EmployeesIncapacitiesTab({super.key});

  @override
  ConsumerState<EmployeesIncapacitiesTab> createState() =>
      _EmployeesIncapacitiesTabState();
}

class _EmployeesIncapacitiesTabState
    extends ConsumerState<EmployeesIncapacitiesTab> {
  @override
  Widget build(BuildContext context) {
    final payrollState = ref.watch(payrollProvider);
    final theme = Theme.of(context);
    return _buildIncapacitiesTab(theme, payrollState);
  }

  Widget _buildIncapacitiesTab(ThemeData theme, PayrollState payrollState) {
    if (payrollState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final allActive = payrollState.activeIncapacities;
    final activeIncapacidades = allActive
        .where((i) => i.type != 'permiso')
        .toList();
    final activePermisos = allActive.where((i) => i.type == 'permiso').toList();

    final pastItems = payrollState.incapacities
        .where((i) => i.status != 'activa')
        .toList();

    final now = DateTime.now();

    int diasRestantesIncap = 0;
    for (final inc in activeIncapacidades) {
      final remaining = inc.endDate.difference(now).inDays + 1;
      if (remaining > 0) diasRestantesIncap += remaining;
    }
    int diasRestantesPerm = 0;
    for (final p in activePermisos) {
      final remaining = p.endDate.difference(now).inDays + 1;
      if (remaining > 0) diasRestantesPerm += remaining;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Incapacidades',
                  '${activeIncapacidades.length}',
                  Icons.local_hospital,
                  const Color(0xFF7B1FA2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Días Restantes',
                  '$diasRestantesIncap',
                  Icons.calendar_today,
                  const Color(0xFFC62828),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Permisos',
                  '${activePermisos.length}',
                  Icons.event_busy,
                  const Color(0xFFF9A825),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Días Permiso',
                  '$diasRestantesPerm',
                  Icons.timer,
                  const Color(0xFFF9A825),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Incapacidades Activas
          Row(
            children: [
              const Icon(
                Icons.local_hospital,
                size: 20,
                color: Color(0xFF7B1FA2),
              ),
              const SizedBox(width: 8),
              const Text(
                'Incapacidades Activas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (activeIncapacidades.isEmpty)
            _buildEmptyStateCard(
              'Sin incapacidades activas',
              Icons.check_circle,
              const Color(0xFF2E7D32),
            )
          else
            ...activeIncapacidades.map(
              (inc) => _buildIncapacityCard(inc, theme),
            ),

          const SizedBox(height: 20),

          // Permisos Activos
          Row(
            children: [
              const Icon(Icons.event_busy, size: 20, color: Color(0xFFF57C00)),
              const SizedBox(width: 8),
              const Text(
                'Permisos Activos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (activePermisos.isEmpty)
            _buildEmptyStateCard(
              'Sin permisos activos',
              Icons.check_circle,
              const Color(0xFF2E7D32),
            )
          else
            ...activePermisos.map((inc) => _buildIncapacityCard(inc, theme)),

          // Historial
          if (pastItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.history, size: 20, color: Color(0xFF757575)),
                const SizedBox(width: 8),
                const Text(
                  'Historial',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...pastItems.map(
              (inc) => _buildIncapacityCard(inc, theme, isPast: true),
            ),
          ],
        ],
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

  Widget _buildEmptyStateCard(String message, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color.withValues(alpha: 0.5)),
              const SizedBox(width: 10),
              Text(
                message,
                style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncapacityCard(
    EmployeeIncapacity incapacity,
    ThemeData theme, {
    bool isPast = false,
  }) {
    final isPermiso = incapacity.type == 'permiso';
    final activeColor = isPermiso
        ? const Color(0xFFF9A825)
        : const Color(0xFF7B1FA2);
    final activeIcon = isPermiso ? Icons.event_busy : Icons.local_hospital;

    final now = DateTime.now();
    final daysRemaining = incapacity.endDate.difference(now).inDays + 1;
    final daysElapsed = now.difference(incapacity.startDate).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isPast
                      ? const Color(0xFF9E9E9E).withValues(alpha: 0.1)
                      : activeColor.withValues(alpha: 0.1),
                  child: Icon(
                    activeIcon,
                    color: isPast ? const Color(0xFF9E9E9E) : activeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incapacity.employeeName ?? 'Empleado',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        incapacity.typeLabel,
                        style: const TextStyle(color: Color(0xFF757575)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPast
                            ? const Color(0xFF9E9E9E).withValues(alpha: 0.1)
                            : activeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${incapacity.daysTotal} días',
                        style: TextStyle(
                          color: isPast ? const Color(0xFF9E9E9E) : activeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!isPast && daysRemaining > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Quedan $daysRemaining día${daysRemaining > 1 ? "s" : ""}',
                          style: TextStyle(
                            fontSize: 10,
                            color: activeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isPast) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (daysElapsed / incapacity.daysTotal).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: const Color(0xFFEEEEEE),
                  valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Desde',
                        style: TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 12,
                        ),
                      ),
                      Text(Helpers.formatDate(incapacity.startDate)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hasta',
                        style: TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 12,
                        ),
                      ),
                      Text(Helpers.formatDate(incapacity.endDate)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pago',
                        style: TextStyle(
                          color: Color(0xFF757575),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${incapacity.paymentPercentage.toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (incapacity.diagnosis != null &&
                incapacity.diagnosis!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Diagnóstico: ${incapacity.diagnosis}',
                style: const TextStyle(color: Color(0xFF616161), fontSize: 13),
              ),
            ],
            if (!isPast) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _endIncapacity(incapacity),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Terminar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _endIncapacity(EmployeeIncapacity incapacity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar Incapacidad'),
        content: Text(
          '¿Terminar la incapacidad de ${incapacity.employeeName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(payrollProvider.notifier)
                  .endIncapacity(incapacity.id);
            },
            child: const Text('Terminar'),
          ),
        ],
      ),
    );
  }
}
