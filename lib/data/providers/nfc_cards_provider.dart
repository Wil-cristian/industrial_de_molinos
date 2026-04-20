import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/nfc_pcsc_service.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/employee.dart';
import '../datasources/employees_datasource.dart';

/// Estado del módulo de configuración de tarjetas NFC
class NfcCardsState {
  final List<Employee> employees;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  /// Lector NFC activo escuchando
  final bool isReaderActive;

  /// Modo asignación: esperando escaneo para un empleado
  final bool isAssigning;
  final String? assigningEmployeeId;
  final String? assigningEmployeeName;

  /// Resultado de última operación
  final String? operationResult;
  final bool operationSuccess;

  /// Último card ID escaneado (para preview)
  final String? lastScannedCardId;

  /// Filtro: mostrar solo empleados con/sin tarjeta
  final NfcCardFilter filter;

  const NfcCardsState({
    this.employees = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.isReaderActive = false,
    this.isAssigning = false,
    this.assigningEmployeeId,
    this.assigningEmployeeName,
    this.operationResult,
    this.operationSuccess = false,
    this.lastScannedCardId,
    this.filter = NfcCardFilter.all,
  });

  NfcCardsState copyWith({
    List<Employee>? employees,
    bool? isLoading,
    String? error,
    String? searchQuery,
    bool? isReaderActive,
    bool? isAssigning,
    String? assigningEmployeeId,
    String? assigningEmployeeName,
    String? operationResult,
    bool? operationSuccess,
    String? lastScannedCardId,
    NfcCardFilter? filter,
    bool clearError = false,
    bool clearAssigning = false,
    bool clearResult = false,
    bool clearLastScanned = false,
  }) {
    return NfcCardsState(
      employees: employees ?? this.employees,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      searchQuery: searchQuery ?? this.searchQuery,
      isReaderActive: isReaderActive ?? this.isReaderActive,
      isAssigning:
          clearAssigning ? false : isAssigning ?? this.isAssigning,
      assigningEmployeeId: clearAssigning
          ? null
          : assigningEmployeeId ?? this.assigningEmployeeId,
      assigningEmployeeName: clearAssigning
          ? null
          : assigningEmployeeName ?? this.assigningEmployeeName,
      operationResult:
          clearResult ? null : operationResult ?? this.operationResult,
      operationSuccess: clearResult
          ? false
          : operationSuccess ?? this.operationSuccess,
      lastScannedCardId: clearLastScanned
          ? null
          : lastScannedCardId ?? this.lastScannedCardId,
      filter: filter ?? this.filter,
    );
  }

  /// Empleados filtrados por búsqueda y filtro
  List<Employee> get filteredEmployees {
    var list = employees;

    // Filtro por tarjeta
    switch (filter) {
      case NfcCardFilter.withCard:
        list = list
            .where(
                (e) => e.nfcCardId != null && e.nfcCardId!.isNotEmpty)
            .toList();
        break;
      case NfcCardFilter.withoutCard:
        list = list
            .where(
                (e) => e.nfcCardId == null || e.nfcCardId!.isEmpty)
            .toList();
        break;
      case NfcCardFilter.all:
        break;
    }

    // Filtro por búsqueda
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      list = list.where((e) {
        return e.fullName.toLowerCase().contains(query) ||
            (e.nfcCardId?.toLowerCase().contains(query) ?? false) ||
            (e.department?.toLowerCase().contains(query) ?? false) ||
            (e.position.toLowerCase().contains(query));
      }).toList();
    }

    return list;
  }

  int get totalEmployees => employees.length;
  int get withCardCount =>
      employees.where((e) => e.nfcCardId != null && e.nfcCardId!.isNotEmpty).length;
  int get withoutCardCount => totalEmployees - withCardCount;
}

enum NfcCardFilter { all, withCard, withoutCard }

class NfcCardsNotifier extends Notifier<NfcCardsState> {
  StreamSubscription<NfcScanResult>? _scanSubscription;
  Timer? _resultClearTimer;

  @override
  NfcCardsState build() {
    ref.onDispose(() {
      _scanSubscription?.cancel();
      _resultClearTimer?.cancel();
      if (state.isReaderActive) {
        NfcPcscService.instance.stopNfcReading();
      }
    });
    return const NfcCardsState();
  }

  /// Cargar todos los empleados activos
  Future<void> loadEmployees() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await EmployeesDatasource.getEmployees(activeOnly: true);
      state = state.copyWith(employees: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error cargando empleados: $e',
      );
    }
  }

  /// Actualizar búsqueda
  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Cambiar filtro
  void setFilter(NfcCardFilter filter) {
    state = state.copyWith(filter: filter);
  }

  /// Iniciar lector NFC via PC/SC
  Future<void> startReader() async {
    if (state.isReaderActive) return;
    try {
      await NfcPcscService.instance.startNfcReading();
      _scanSubscription?.cancel();
      _scanSubscription =
          NfcPcscService.instance.onCardScanned.listen(_onCardScanned);
      state = state.copyWith(isReaderActive: true);
      AppLogger.info('📱 NFC Config: lector PC/SC iniciado (✔️ ${NfcPcscService.instance.readerName})');
    } catch (e) {
      AppLogger.error('❌ NFC Config: error iniciando lector: $e');
      state = state.copyWith(
        error: 'Error iniciando lector NFC: $e',
      );
    }
  }

  /// Detener lector NFC
  Future<void> stopReader() async {
    await NfcPcscService.instance.stopNfcReading();
    _scanSubscription?.cancel();
    state = state.copyWith(isReaderActive: false, clearAssigning: true);
    AppLogger.info('📱 NFC Config: lector detenido');
  }

  /// Iniciar modo asignación para un empleado
  Future<void> startAssigning({
    required String employeeId,
    required String employeeName,
  }) async {
    // Asegurar que el lector esté activo
    if (!state.isReaderActive) {
      AppLogger.warning('⚠️ NFC Config: lector no activo, iniciando...');
      await startReader();
    }
    NfcPcscService.instance.resetDuplicateGuard();
    state = state.copyWith(
      isAssigning: true,
      assigningEmployeeId: employeeId,
      assigningEmployeeName: employeeName,
      clearResult: true,
      clearLastScanned: true,
    );
    AppLogger.info('📱 NFC Config: esperando escaneo para asignar a $employeeName ($employeeId)');
  }

  /// Cancelar modo asignación
  void cancelAssigning() {
    NfcPcscService.instance.resetDuplicateGuard();
    state = state.copyWith(clearAssigning: true, clearResult: true);
  }

  /// Callback cuando se escanea una tarjeta
  Future<void> _onCardScanned(NfcScanResult scan) async {
    AppLogger.info('📱 NFC Config: tarjeta escaneada: ${scan.cardId} (${scan.uidBytes}B)');
    state = state.copyWith(lastScannedCardId: scan.cardId);

    if (!state.isAssigning || state.assigningEmployeeId == null) {
      AppLogger.info('📱 NFC Config: no en modo asignación, ignorando escaneo');
      return;
    }

    // Guardar datos antes de await (el state puede cambiar)
    final employeeId = state.assigningEmployeeId!;
    final employeeName = state.assigningEmployeeName ?? 'Empleado';

    try {
      // Verificar si la tarjeta ya está asignada a otro empleado
      AppLogger.info('📱 NFC Config: verificando si tarjeta ya está asignada...');
      final existing = await EmployeesDatasource.getEmployeeByNfc(scan.cardId);
      if (existing != null && existing.id != employeeId) {
        AppLogger.warning('⚠️ Tarjeta ${scan.cardId} ya asignada a ${existing.fullName}');
        state = state.copyWith(
          operationResult:
              'Esta tarjeta ya está asignada a ${existing.fullName}',
          operationSuccess: false,
        );
        _scheduleResultClear();
        return;
      }

      // Asignar tarjeta
      AppLogger.info('📱 NFC Config: asignando tarjeta ${scan.cardId} a $employeeName ($employeeId)...');
      final success = await EmployeesDatasource.assignNfcCard(
        employeeId: employeeId,
        nfcCardId: scan.cardId,
      );

      if (success) {
        state = state.copyWith(
          operationResult:
              'Tarjeta ${scan.cardId} asignada a $employeeName',
          operationSuccess: true,
          clearAssigning: true,
        );
        AppLogger.success(
          '✅ Tarjeta ${scan.cardId} → $employeeName',
        );
        await loadEmployees();
      } else {
        state = state.copyWith(
          operationResult: 'Error al asignar la tarjeta. Revisa la consola para detalles.',
          operationSuccess: false,
        );
        AppLogger.error('❌ NFC Config: assignNfcCard retornó false');
      }
    } catch (e, stack) {
      AppLogger.error('❌ NFC Config: excepción en _onCardScanned: $e\n$stack');
      state = state.copyWith(
        operationResult: 'Error inesperado: $e',
        operationSuccess: false,
      );
    }
    _scheduleResultClear();
  }

  /// Desasignar tarjeta de un empleado
  Future<void> removeCard(String employeeId, String employeeName) async {
    final success = await EmployeesDatasource.removeNfcCard(employeeId);
    if (success) {
      state = state.copyWith(
        operationResult: 'Tarjeta removida de $employeeName',
        operationSuccess: true,
      );
      AppLogger.success('✅ Tarjeta removida de $employeeName');
      await loadEmployees();
    } else {
      state = state.copyWith(
        operationResult: 'Error al remover la tarjeta',
        operationSuccess: false,
      );
    }
    _scheduleResultClear();
  }

  /// Reasignar: quitar tarjeta actual y poner en modo asignación
  Future<void> reassignCard({
    required String employeeId,
    required String employeeName,
  }) async {
    await EmployeesDatasource.removeNfcCard(employeeId);
    await loadEmployees();
    startAssigning(employeeId: employeeId, employeeName: employeeName);
  }

  void _scheduleResultClear() {
    _resultClearTimer?.cancel();
    _resultClearTimer = Timer(const Duration(seconds: 5), () {
      state = state.copyWith(clearResult: true);
    });
  }
}

final nfcCardsProvider =
    NotifierProvider<NfcCardsNotifier, NfcCardsState>(NfcCardsNotifier.new);
