import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/nfc_reader_service.dart';
import '../../core/utils/logger.dart';
import '../datasources/employees_datasource.dart';

/// Resultado de un registro NFC
class NfcAttendanceResult {
  final bool success;
  final String action; // CHECK_IN, CHECK_OUT, error codes
  final String message;
  final String? employeeName;
  final String? employeeId;
  final String? photoUrl;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? workedMinutes;

  const NfcAttendanceResult({
    required this.success,
    required this.action,
    required this.message,
    this.employeeName,
    this.employeeId,
    this.photoUrl,
    this.checkIn,
    this.checkOut,
    this.workedMinutes,
  });

  factory NfcAttendanceResult.fromRpcResponse(Map<String, dynamic> json) {
    return NfcAttendanceResult(
      success: json['success'] as bool? ?? false,
      action: (json['action'] ?? json['error'] ?? 'UNKNOWN') as String,
      message: json['message'] as String? ?? 'Sin mensaje',
      employeeName: json['employee_name'] as String?,
      employeeId: json['employee_id'] as String?,
      photoUrl: json['photo_url'] as String?,
      checkIn: json['check_in'] != null
          ? DateTime.parse(json['check_in'] as String)
          : null,
      checkOut: json['check_out'] != null
          ? DateTime.parse(json['check_out'] as String)
          : null,
      workedMinutes: json['worked_minutes'] as int?,
    );
  }
}

/// Estado del kiosko NFC de asistencia (Windows - lector USB)
class NfcKioskState {
  final bool isActive;
  final bool isProcessing;
  final NfcAttendanceResult? lastResult;
  final List<NfcAttendanceResult> recentResults;
  final List<Map<String, dynamic>> todayStatus;
  final String? error;

  /// Modo vincular tarjeta: esperando escaneo para asignar a un empleado
  final bool isLinkingCard;
  final String? linkingEmployeeId;
  final String? linkingEmployeeName;
  final String? linkingResult;

  const NfcKioskState({
    this.isActive = false,
    this.isProcessing = false,
    this.lastResult,
    this.recentResults = const [],
    this.todayStatus = const [],
    this.error,
    this.isLinkingCard = false,
    this.linkingEmployeeId,
    this.linkingEmployeeName,
    this.linkingResult,
  });

  NfcKioskState copyWith({
    bool? isActive,
    bool? isProcessing,
    NfcAttendanceResult? lastResult,
    List<NfcAttendanceResult>? recentResults,
    List<Map<String, dynamic>>? todayStatus,
    String? error,
    bool? isLinkingCard,
    String? linkingEmployeeId,
    String? linkingEmployeeName,
    String? linkingResult,
    bool clearLastResult = false,
    bool clearError = false,
    bool clearLinking = false,
  }) {
    return NfcKioskState(
      isActive: isActive ?? this.isActive,
      isProcessing: isProcessing ?? this.isProcessing,
      lastResult: clearLastResult ? null : lastResult ?? this.lastResult,
      recentResults: recentResults ?? this.recentResults,
      todayStatus: todayStatus ?? this.todayStatus,
      error: clearError ? null : error ?? this.error,
      isLinkingCard: clearLinking ? false : isLinkingCard ?? this.isLinkingCard,
      linkingEmployeeId: clearLinking
          ? null
          : linkingEmployeeId ?? this.linkingEmployeeId,
      linkingEmployeeName: clearLinking
          ? null
          : linkingEmployeeName ?? this.linkingEmployeeName,
      linkingResult: clearLinking ? null : linkingResult ?? this.linkingResult,
    );
  }

  int get checkedInCount => todayStatus.where((e) {
    final entries = e['employee_time_entries'] as List?;
    return entries != null && entries.isNotEmpty;
  }).length;

  int get totalEmployees => todayStatus.length;
}

class NfcKioskNotifier extends Notifier<NfcKioskState> {
  StreamSubscription<NfcScanResult>? _scanSubscription;
  Timer? _clearResultTimer;

  @override
  NfcKioskState build() {
    ref.onDispose(() {
      _scanSubscription?.cancel();
      _clearResultTimer?.cancel();
      NfcReaderService.instance.stopNfcReading();
    });
    return const NfcKioskState();
  }

  // ========== KIOSKO (lector USB Windows) ==========

  /// Inicia el modo kiosko (para lectores USB en Windows)
  Future<void> startKiosk({String? deviceName}) async {
    state = state.copyWith(isActive: true, clearError: true);

    _scanSubscription?.cancel();
    _scanSubscription = NfcReaderService.instance.onCardScanned.listen(
      _onKioskScan,
    );

    await NfcReaderService.instance.startNfcReading();
    await loadTodayStatus();
    AppLogger.info('Modo kiosko iniciado');
  }

  void stopKiosk() {
    NfcReaderService.instance.stopNfcReading();
    _scanSubscription?.cancel();
    _clearResultTimer?.cancel();
    state = state.copyWith(isActive: false);
  }

  Future<void> _onKioskScan(NfcScanResult scan) async {
    if (state.isProcessing) return;
    state = state.copyWith(isProcessing: true, clearLastResult: true);

    try {
      final response = await EmployeesDatasource.registerNfcAttendance(
        nfcCardId: scan.cardId,
        deviceName: 'Kiosko Windows',
      );
      final result = NfcAttendanceResult.fromRpcResponse(response);
      state = state.copyWith(
        isProcessing: false,
        lastResult: result,
        recentResults: [result, ...state.recentResults.take(9)],
      );
      if (result.success) await loadTodayStatus();
      _scheduleResultClear();
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: '$e');
    }
  }

  void _scheduleResultClear() {
    _clearResultTimer?.cancel();
    _clearResultTimer = Timer(const Duration(seconds: 8), () {
      state = state.copyWith(clearLastResult: true);
    });
  }

  // ========== COMUNES ==========

  Future<void> loadTodayStatus() async {
    try {
      final status = await EmployeesDatasource.getTodayAttendanceStatus();
      state = state.copyWith(todayStatus: status);
    } catch (e) {
      AppLogger.error('Error cargando estado asistencia: $e');
    }
  }

  void simulateScan(String cardId, {String? payload}) {
    NfcReaderService.instance.simulateScan(cardId, payload: payload);
  }

  // ========== VINCULAR TARJETA A EMPLEADO ==========

  /// Inicia el modo vinculacion: espera un escaneo para asignar a un empleado
  Future<void> startCardLinking({
    required String employeeId,
    required String employeeName,
  }) async {
    if (!state.isActive) {
      await startKiosk();
    }

    _scanSubscription?.cancel();
    _scanSubscription = NfcReaderService.instance.onCardScanned.listen(
      _onLinkingScan,
    );

    state = state.copyWith(
      isLinkingCard: true,
      linkingEmployeeId: employeeId,
      linkingEmployeeName: employeeName,
      clearError: true,
    );
    AppLogger.info('Modo vincular tarjeta para: $employeeName');
  }

  /// Cancela el modo vinculacion y vuelve al modo kiosko normal
  void cancelCardLinking() {
    _scanSubscription?.cancel();
    _scanSubscription = NfcReaderService.instance.onCardScanned.listen(
      _onKioskScan,
    );
    state = state.copyWith(clearLinking: true);
    AppLogger.info('Modo vincular tarjeta cancelado');
  }

  /// Procesa un escaneo en modo vinculacion
  Future<void> _onLinkingScan(NfcScanResult scan) async {
    if (state.isProcessing) return;
    if (state.linkingEmployeeId == null) return;

    state = state.copyWith(isProcessing: true);

    try {
      final success = await EmployeesDatasource.assignNfcCard(
        employeeId: state.linkingEmployeeId!,
        nfcCardId: scan.cardId,
      );

      if (success) {
        state = state.copyWith(
          isProcessing: false,
          linkingResult:
              'Tarjeta ${scan.cardId} asignada a ${state.linkingEmployeeName}',
        );
        AppLogger.success(
          'Tarjeta ${scan.cardId} -> ${state.linkingEmployeeName}',
        );
        await loadTodayStatus();
        await Future.delayed(const Duration(seconds: 3));
        cancelCardLinking();
      } else {
        state = state.copyWith(
          isProcessing: false,
          error: 'No se pudo asignar la tarjeta. Puede que ya este en uso.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: 'Error asignando tarjeta: $e',
      );
    }
  }
}

final nfcKioskProvider = NotifierProvider<NfcKioskNotifier, NfcKioskState>(
  NfcKioskNotifier.new,
);