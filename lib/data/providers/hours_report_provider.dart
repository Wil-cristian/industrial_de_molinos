import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/colombia_time.dart';
import '../../core/utils/logger.dart';
import '../datasources/employees_datasource.dart';

/// Estado del reporte de horas trabajadas
class HoursReportState {
  final List<Map<String, dynamic>> employeeSummaries;
  final DateTime startDate;
  final DateTime endDate;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String filterDepartment;

  const HoursReportState({
    this.employeeSummaries = const [],
    required this.startDate,
    required this.endDate,
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.filterDepartment = 'Todos',
  });

  HoursReportState copyWith({
    List<Map<String, dynamic>>? employeeSummaries,
    DateTime? startDate,
    DateTime? endDate,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? filterDepartment,
    bool clearError = false,
  }) {
    return HoursReportState(
      employeeSummaries: employeeSummaries ?? this.employeeSummaries,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
      filterDepartment: filterDepartment ?? this.filterDepartment,
    );
  }

  /// Empleados filtrados por búsqueda y departamento
  List<Map<String, dynamic>> get filtered {
    var list = employeeSummaries;
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((e) {
        final name = '${e['first_name']} ${e['last_name']}'.toLowerCase();
        return name.contains(q);
      }).toList();
    }
    if (filterDepartment != 'Todos') {
      list = list.where((e) => e['department'] == filterDepartment).toList();
    }
    return list;
  }

  /// Departamentos únicos
  List<String> get departments {
    final deps = employeeSummaries
        .map((e) => e['department'] as String? ?? 'Sin depto')
        .toSet()
        .toList()
      ..sort();
    return ['Todos', ...deps];
  }

  /// Totales globales
  int get totalWorkedMinutes => employeeSummaries.fold<int>(
      0, (sum, e) => sum + ((e['total_worked_minutes'] as int?) ?? 0));
  int get totalOvertimeMinutes => employeeSummaries.fold<int>(
      0, (sum, e) => sum + ((e['total_overtime_minutes'] as int?) ?? 0));
  int get totalDaysWorked => employeeSummaries.fold<int>(
      0, (sum, e) => sum + ((e['days_worked'] as int?) ?? 0));
  int get employeesWithNfc =>
      employeeSummaries.where((e) => e['has_nfc'] == true).length;
  int get employeesWithoutNfc =>
      employeeSummaries.where((e) => e['has_nfc'] != true).length;
}

/// Provider del reporte de horas
final hoursReportProvider =
    NotifierProvider<HoursReportNotifier, HoursReportState>(
  HoursReportNotifier.new,
);

class HoursReportNotifier extends Notifier<HoursReportState> {
  @override
  HoursReportState build() {
    // Por defecto: semana actual (lunes a domingo)
    final now = ColombiaTime.now();
    final weekday = now.weekday; // 1=lun, 7=dom
    final monday = now.subtract(Duration(days: weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    return HoursReportState(
      startDate: DateTime(monday.year, monday.month, monday.day),
      endDate: DateTime(sunday.year, sunday.month, sunday.day),
    );
  }

  /// Cargar reporte de horas para el rango actual
  Future<void> loadReport() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final summaries = await EmployeesDatasource.getHoursSummaryAllEmployees(
        startDate: state.startDate,
        endDate: state.endDate,
      );
      state = state.copyWith(
        employeeSummaries: summaries,
        isLoading: false,
      );
      AppLogger.info(
          '📊 Reporte cargado: ${summaries.length} empleados, ${state.startDate} - ${state.endDate}');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  /// Cambiar rango de fechas y recargar
  Future<void> setDateRange(DateTime start, DateTime end) async {
    state = state.copyWith(startDate: start, endDate: end);
    await loadReport();
  }

  /// Ir a la semana anterior
  Future<void> previousWeek() async {
    final newStart = state.startDate.subtract(const Duration(days: 7));
    final newEnd = state.endDate.subtract(const Duration(days: 7));
    await setDateRange(newStart, newEnd);
  }

  /// Ir a la semana siguiente
  Future<void> nextWeek() async {
    final newStart = state.startDate.add(const Duration(days: 7));
    final newEnd = state.endDate.add(const Duration(days: 7));
    await setDateRange(newStart, newEnd);
  }

  /// Semana actual
  Future<void> currentWeek() async {
    final now = ColombiaTime.now();
    final weekday = now.weekday;
    final monday = now.subtract(Duration(days: weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    await setDateRange(
      DateTime(monday.year, monday.month, monday.day),
      DateTime(sunday.year, sunday.month, sunday.day),
    );
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setDepartmentFilter(String dept) {
    state = state.copyWith(filterDepartment: dept);
  }
}
