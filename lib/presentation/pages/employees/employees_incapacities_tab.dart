import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/datasources/payroll_datasource.dart';
import '../../../data/providers/employees_provider.dart';
import '../../../data/providers/payroll_provider.dart';

/// Tab de incapacidades y permisos de empleados.
class EmployeesIncapacitiesTab extends ConsumerStatefulWidget {
  const EmployeesIncapacitiesTab({super.key});

  @override
  ConsumerState<EmployeesIncapacitiesTab> createState() =>
      EmployeesIncapacitiesTabState();
}

class EmployeesIncapacitiesTabState
    extends ConsumerState<EmployeesIncapacitiesTab> {
  /// Public API for shell coordinator to trigger new incapacity dialog
  void showNewIncapacityDialog() => _showNewIncapacityDialog();

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
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              if (isMobile) {
                return Column(
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
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
                  ],
                );
              }
              return Row(
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
              );
            },
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

  void _showNewIncapacityDialog() {
    final employees = ref.read(employeesProvider).activeEmployees;
    if (employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay empleados activos'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    String? selectedEmployeeId;
    bool isPermiso = false;
    String selectedType = 'enfermedad';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final days = endDate.difference(startDate).inDays + 1;

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isPermiso ? Icons.event_busy : Icons.local_hospital,
                  color: isPermiso
                      ? const Color(0xFFF9A825)
                      : const Color(0xFF7B1FA2),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPermiso ? 'Registrar Permiso' : 'Registrar Incapacidad',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420, minWidth: 200),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tipo: incapacidad o permiso
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Incapacidad'),
                          icon: Icon(Icons.local_hospital),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Permiso'),
                          icon: Icon(Icons.event_busy),
                        ),
                      ],
                      selected: {isPermiso},
                      onSelectionChanged: (v) {
                        setState(() {
                          isPermiso = v.first;
                          selectedType = isPermiso ? 'permiso' : 'enfermedad';
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Empleado
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Empleado',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      value: selectedEmployeeId,
                      items: employees
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text('${e.fullName} - ${e.position}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedEmployeeId = value),
                    ),
                    const SizedBox(height: 16),

                    // Subtipo (solo incapacidad)
                    if (!isPermiso) ...[
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de Incapacidad',
                          prefixIcon: Icon(Icons.medical_services),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'enfermedad',
                            child: Text('Enfermedad General'),
                          ),
                          DropdownMenuItem(
                            value: 'accidente_laboral',
                            child: Text('Accidente Laboral'),
                          ),
                          DropdownMenuItem(
                            value: 'accidente_comun',
                            child: Text('Accidente Común'),
                          ),
                        ],
                        onChanged: (v) => setState(() => selectedType = v!),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Fechas
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: ctx,
                                initialDate: startDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 30),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) {
                                setState(() {
                                  startDate = date;
                                  if (endDate.isBefore(startDate)) {
                                    endDate = startDate;
                                  }
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Desde',
                                prefixIcon: Icon(Icons.calendar_today),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                '${startDate.day}/${startDate.month}/${startDate.year}',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: ctx,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) {
                                setState(() => endDate = date);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Hasta',
                                prefixIcon: Icon(Icons.calendar_today),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                '${endDate.day}/${endDate.month}/${endDate.year}',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Días calculados
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isPermiso
                                    ? const Color(0xFFF9A825)
                                    : const Color(0xFF7B1FA2))
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 16,
                            color: isPermiso
                                ? const Color(0xFFF9A825)
                                : const Color(0xFF7B1FA2),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$days día${days > 1 ? "s" : ""} de ${isPermiso ? "permiso" : "incapacidad"}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isPermiso
                                  ? const Color(0xFFEF6C00)
                                  : const Color(0xFF6A1B9A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Motivo
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: isPermiso
                            ? 'Motivo del permiso (opcional)'
                            : 'Diagnóstico (opcional)',
                        prefixIcon: Icon(
                          isPermiso ? Icons.note : Icons.local_hospital,
                        ),
                        border: const OutlineInputBorder(),
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
              FilledButton.icon(
                onPressed: selectedEmployeeId == null
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(ctx);
                        Navigator.pop(ctx);

                        final emp = employees.firstWhere(
                          (e) => e.id == selectedEmployeeId,
                        );
                        final incapacity = EmployeeIncapacity(
                          id: '',
                          employeeId: selectedEmployeeId!,
                          type: selectedType,
                          startDate: startDate,
                          endDate: endDate,
                          daysTotal: days,
                          diagnosis: reasonController.text.isNotEmpty
                              ? reasonController.text
                              : null,
                          employeeName: emp.fullName,
                        );

                        final success = await ref
                            .read(payrollProvider.notifier)
                            .createIncapacity(incapacity);

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? '✅ ${isPermiso ? "Permiso" : "Incapacidad"} registrada para ${emp.fullName}'
                                  : '❌ Error al registrar',
                            ),
                            backgroundColor: success
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                          ),
                        );
                      },
                icon: const Icon(Icons.check, size: 16),
                label: Text(
                  isPermiso ? 'Registrar Permiso' : 'Registrar Incapacidad',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isPermiso
                      ? const Color(0xFFF9A825)
                      : const Color(0xFF7B1FA2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
