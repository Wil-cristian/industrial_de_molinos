import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/audit_log.dart';
import '../datasources/audit_log_datasource.dart';

/// Estado del panel de auditoría
class AuditLogState {
  final List<AuditLog> logs;
  final bool isLoading;
  final String? error;
  final String? filterModule;
  final String? filterAction;
  final String? filterUserId;
  final DateTime? filterFromDate;
  final DateTime? filterToDate;
  final List<Map<String, String>> activeUsers;

  AuditLogState({
    this.logs = const [],
    this.isLoading = false,
    this.error,
    this.filterModule,
    this.filterAction,
    this.filterUserId,
    this.filterFromDate,
    this.filterToDate,
    this.activeUsers = const [],
  });

  AuditLogState copyWith({
    List<AuditLog>? logs,
    bool? isLoading,
    String? error,
    String? filterModule,
    String? filterAction,
    String? filterUserId,
    DateTime? filterFromDate,
    DateTime? filterToDate,
    List<Map<String, String>>? activeUsers,
    bool clearModule = false,
    bool clearAction = false,
    bool clearUserId = false,
    bool clearFromDate = false,
    bool clearToDate = false,
  }) {
    return AuditLogState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      filterModule: clearModule ? null : (filterModule ?? this.filterModule),
      filterAction: clearAction ? null : (filterAction ?? this.filterAction),
      filterUserId: clearUserId ? null : (filterUserId ?? this.filterUserId),
      filterFromDate: clearFromDate
          ? null
          : (filterFromDate ?? this.filterFromDate),
      filterToDate: clearToDate ? null : (filterToDate ?? this.filterToDate),
      activeUsers: activeUsers ?? this.activeUsers,
    );
  }
}

/// Notifier para auditoría (Riverpod 3.0)
class AuditLogNotifier extends Notifier<AuditLogState> {
  @override
  AuditLogState build() {
    return AuditLogState();
  }

  /// Cargar logs con filtros actuales
  Future<void> loadLogs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final logs = await AuditLogDatasource.getLogs(
        module: state.filterModule,
        action: state.filterAction,
        userId: state.filterUserId,
        fromDate: state.filterFromDate,
        toDate: state.filterToDate,
        limit: 200,
      );
      final users = await AuditLogDatasource.getActiveUsers();
      state = state.copyWith(logs: logs, isLoading: false, activeUsers: users);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Filtrar por módulo
  void setModuleFilter(String? module) {
    state = module == null
        ? state.copyWith(clearModule: true)
        : state.copyWith(filterModule: module);
    loadLogs();
  }

  /// Filtrar por acción
  void setActionFilter(String? action) {
    state = action == null
        ? state.copyWith(clearAction: true)
        : state.copyWith(filterAction: action);
    loadLogs();
  }

  /// Filtrar por usuario
  void setUserFilter(String? userId) {
    state = userId == null
        ? state.copyWith(clearUserId: true)
        : state.copyWith(filterUserId: userId);
    loadLogs();
  }

  /// Filtrar por rango de fechas
  void setDateRange(DateTime? from, DateTime? to) {
    state = state.copyWith(
      filterFromDate: from,
      filterToDate: to,
      clearFromDate: from == null,
      clearToDate: to == null,
    );
    loadLogs();
  }

  /// Limpiar todos los filtros
  void clearFilters() {
    state = AuditLogState();
    loadLogs();
  }
}

/// Provider principal
final auditLogProvider = NotifierProvider<AuditLogNotifier, AuditLogState>(
  AuditLogNotifier.new,
);
