import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/colombia_time.dart';
import '../../data/providers/hours_report_provider.dart';

/// Página de reporte de horas trabajadas — vista admin
class HoursReportPage extends ConsumerStatefulWidget {
  const HoursReportPage({super.key});

  @override
  ConsumerState<HoursReportPage> createState() => _HoursReportPageState();
}

class _HoursReportPageState extends ConsumerState<HoursReportPage> {
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy', 'es_CO');
  final _dayFormat = DateFormat('EEE dd', 'es_CO');
  final _timeFormat = DateFormat('HH:mm', 'es_CO');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hoursReportProvider.notifier).loadReport();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hoursReportProvider);
    final notifier = ref.read(hoursReportProvider.notifier);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          // === Header con controles de fecha ===
          _buildHeader(state, notifier, cs, tt),
          // === Stats bar ===
          _buildStatsBar(state, cs, tt),
          // === Filtros ===
          _buildFilters(state, notifier, cs, tt),
          // === Tabla principal ===
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.filtered.isEmpty
                    ? _buildEmpty(cs, tt)
                    : _buildTable(state, cs, tt),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(HoursReportState state, HoursReportNotifier notifier,
      ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: cs.primary, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Text('Reporte de Horas',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          // Nav semana
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Semana anterior',
            onPressed: () => notifier.previousWeek(),
          ),
          InkWell(
            onTap: () => _pickDateRange(notifier),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today, size: 16, color: cs.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${_dateFormat.format(state.startDate)} — ${_dateFormat.format(state.endDate)}',
                    style: tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Semana siguiente',
            onPressed: () => notifier.nextWeek(),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: () => notifier.currentWeek(),
            icon: const Icon(Icons.today, size: 18),
            label: const Text('Hoy'),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => notifier.loadReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(
      HoursReportState state, ColorScheme cs, TextTheme tt) {
    final totalHours = (state.totalWorkedMinutes / 60).toStringAsFixed(1);
    final overtimeHours = (state.totalOvertimeMinutes / 60).toStringAsFixed(1);
    final avgHoursPerEmployee = state.employeeSummaries.isEmpty
        ? '0'
        : (state.totalWorkedMinutes / 60 / state.employeeSummaries.length)
            .toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      color: cs.surface,
      child: Row(
        children: [
          _statChip(Icons.people, '${state.employeeSummaries.length}',
              'Empleados', cs.primary, cs, tt),
          const SizedBox(width: AppSpacing.lg),
          _statChip(Icons.access_time, '${totalHours}h', 'Total horas',
              AppColors.info, cs, tt),
          const SizedBox(width: AppSpacing.lg),
          _statChip(Icons.trending_up, '${overtimeHours}h', 'Extras',
              AppColors.warning, cs, tt),
          const SizedBox(width: AppSpacing.lg),
          _statChip(Icons.person, '${avgHoursPerEmployee}h', 'Promedio/emp',
              AppColors.success, cs, tt),
          const SizedBox(width: AppSpacing.lg),
          _statChip(Icons.calendar_today, '${state.totalDaysWorked}',
              'Días trabajados', cs.tertiary, cs, tt),
          const SizedBox(width: AppSpacing.lg),
          _statChip(Icons.nfc, '${state.employeesWithNfc}', 'Con NFC',
              AppColors.success, cs, tt),
          if (state.employeesWithoutNfc > 0) ...[
            const SizedBox(width: AppSpacing.lg),
            _statChip(Icons.nfc, '${state.employeesWithoutNfc}', 'Sin NFC',
                AppColors.danger, cs, tt),
          ],
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color,
      ColorScheme cs, TextTheme tt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(value,
            style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 4),
        Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildFilters(HoursReportState state, HoursReportNotifier notifier,
      ColorScheme cs, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          // Búsqueda
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar empleado...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm, horizontal: AppSpacing.md),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: notifier.setSearch,
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          // Filtro departamento
          DropdownButton<String>(
            value: state.filterDepartment,
            underline: const SizedBox(),
            items: state.departments
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) {
              if (v != null) notifier.setDepartmentFilter(v);
            },
          ),
          const Spacer(),
          Text('${state.filtered.length} empleados',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 64, color: cs.onSurfaceVariant),
          const SizedBox(height: AppSpacing.base),
          Text('No hay registros de horas en este período',
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildTable(
      HoursReportState state, ColorScheme cs, TextTheme tt) {
    final filtered = state.filtered;
    // Generar lista de días en el rango
    final days = <DateTime>[];
    var d = state.startDate;
    while (!d.isAfter(state.endDate)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        children: [
          for (final emp in filtered) ...[
            _buildEmployeeCard(emp, days, cs, tt),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp, List<DateTime> days,
      ColorScheme cs, TextTheme tt) {
    final name = '${emp['first_name']} ${emp['last_name']}';
    final position = emp['position'] as String? ?? '';
    final dept = emp['department'] as String? ?? '';
    final totalWorked = (emp['total_worked_minutes'] as int?) ?? 0;
    final totalOvertime = (emp['total_overtime_minutes'] as int?) ?? 0;
    final daysWorked = (emp['days_worked'] as int?) ?? 0;
    final pendingCheckout = (emp['pending_checkout'] as int?) ?? 0;
    final hasNfc = emp['has_nfc'] == true;
    final entries = (emp['entries'] as List<Map<String, dynamic>>?) ?? [];

    // Aggregate multi-entries per date: first check_in, last check_out, sum worked
    final entriesByDate = <String, Map<String, dynamic>>{};
    for (final entry in entries) {
      final dateStr = entry['entry_date'] as String;
      if (!entriesByDate.containsKey(dateStr)) {
        entriesByDate[dateStr] = Map<String, dynamic>.from(entry);
      } else {
        final existing = entriesByDate[dateStr]!;
        // Keep earliest check_in
        final existingCi = existing['check_in'] as String?;
        final newCi = entry['check_in'] as String?;
        if (existingCi != null && newCi != null && newCi.compareTo(existingCi) < 0) {
          existing['check_in'] = newCi;
        }
        // Keep latest check_out
        final existingCo = existing['check_out'] as String?;
        final newCo = entry['check_out'] as String?;
        if (newCo != null && (existingCo == null || newCo.compareTo(existingCo) > 0)) {
          existing['check_out'] = newCo;
        }
        // If any session has no check_out, mark as open
        if (newCo == null && newCi != null) {
          existing['_has_open_session'] = true;
        }
        // Sum worked minutes
        existing['worked_minutes'] = ((existing['worked_minutes'] as int?) ?? 0) + ((entry['worked_minutes'] as int?) ?? 0);
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del empleado
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: tt.titleMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: pendingCheckout > 0
                              ? AppColors.success
                              : daysWorked > 0
                                  ? AppColors.info
                                  : AppColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name,
                              style: tt.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          if (hasNfc) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.nfc, size: 16, color: AppColors.success),
                          ],
                          if (!hasNfc) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Sin NFC',
                                  style: tt.labelSmall
                                      ?.copyWith(color: AppColors.danger)),
                            ),
                          ],
                        ],
                      ),
                      Text('$position • $dept',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                // Resumen
                _summaryBadge(
                    'Horas', _formatMinutes(totalWorked), AppColors.info, tt),
                const SizedBox(width: AppSpacing.md),
                _summaryBadge('Extras', _formatMinutes(totalOvertime),
                    AppColors.warning, tt),
                const SizedBox(width: AppSpacing.md),
                _summaryBadge(
                    'Días', '$daysWorked', AppColors.success, tt),
                if (pendingCheckout > 0) ...[
                  const SizedBox(width: AppSpacing.md),
                  _summaryBadge(
                      'Sin salida', '$pendingCheckout', AppColors.danger, tt),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Tabla de días
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 48,
                columnSpacing: AppSpacing.base,
                horizontalMargin: AppSpacing.sm,
                headingTextStyle: tt.labelSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                columns: [
                  for (final day in days)
                    DataColumn(
                      label: Text(
                        _dayFormat.format(day),
                        style: TextStyle(
                          color: day.weekday >= 6
                              ? cs.onSurfaceVariant
                              : cs.onSurface,
                        ),
                      ),
                    ),
                ],
                rows: [
                  DataRow(
                    cells: [
                      for (final day in days) _buildDayCell(day, entriesByDate, cs, tt),
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

  DataCell _buildDayCell(DateTime day,
      Map<String, Map<String, dynamic>> entriesByDate, ColorScheme cs, TextTheme tt) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final entry = entriesByDate[dateStr];

    if (entry == null) {
      // Sin registro
      if (day.weekday >= 6) {
        // Fin de semana
        return DataCell(
          Text('—', style: tt.bodySmall?.copyWith(color: cs.outlineVariant)),
        );
      }
      return DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('Ausente',
              style: tt.labelSmall?.copyWith(color: AppColors.danger)),
        ),
      );
    }

    final checkIn = entry['check_in'] != null
        ? DateTime.parse(entry['check_in'] as String)
        : null;
    final checkOut = entry['check_out'] != null
        ? DateTime.parse(entry['check_out'] as String)
        : null;
    final worked = (entry['worked_minutes'] as int?) ?? 0;

    final hasOpenSession = entry['_has_open_session'] == true || (checkIn != null && checkOut == null);

    if (hasOpenSession && checkOut == null) {
      // Solo entrada, sin salida
      return DataCell(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('→ ${_timeFormat.format(ColombiaTime.toColombia(checkIn!))}',
                style: tt.labelSmall?.copyWith(color: AppColors.info)),
            Text('Sin salida',
                style: tt.labelSmall
                    ?.copyWith(color: AppColors.warning, fontSize: 10)),
          ],
        ),
      );
    }

    if (checkIn != null && checkOut != null) {
      // Completo
      final hours = _formatMinutes(worked);
      final color = worked >= 480
          ? AppColors.success
          : worked >= 360
              ? AppColors.warning
              : AppColors.danger;
      return DataCell(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${_timeFormat.format(ColombiaTime.toColombia(checkIn))} - ${_timeFormat.format(ColombiaTime.toColombia(checkOut))}',                
                style: tt.labelSmall),
            Text(hours, style: tt.labelSmall?.copyWith(
                color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return DataCell(Text('—', style: tt.bodySmall));
  }

  Widget _summaryBadge(
      String label, String value, Color color, TextTheme tt) {
    return Column(
      children: [
        Text(value,
            style: tt.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: tt.labelSmall),
      ],
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0 && m == 0) return '0h';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  Future<void> _pickDateRange(HoursReportNotifier notifier) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: DateTimeRange(
        start: ref.read(hoursReportProvider).startDate,
        end: ref.read(hoursReportProvider).endDate,
      ),
      locale: const Locale('es', 'CO'),
    );
    if (range != null) {
      await notifier.setDateRange(range.start, range.end);
    }
  }
}
