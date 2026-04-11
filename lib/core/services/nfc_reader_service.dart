import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/logger.dart';
import '../../core/utils/colombia_time.dart';

/// Resultado de un escaneo NFC/RFID via lector USB HID
class NfcScanResult {
  final String cardId;
  final DateTime scannedAt;
  final String? payload;
  final int uidBytes;

  const NfcScanResult({
    required this.cardId,
    required this.scannedAt,
    this.payload,
    this.uidBytes = 0,
  });
}

/// Servicio de lectura NFC para Windows via ACS ACR1552U en modo HID.
///
/// El ACR1552U en modo keyboard emulation envía el UID de la tarjeta NTAG215
/// como caracteres hex (14 chars = 7 bytes) seguidos de Enter.
/// Este servicio captura esa entrada con protección anti-duplicado.
class NfcReaderService {
  NfcReaderService._();
  static final instance = NfcReaderService._();

  final _scanController = StreamController<NfcScanResult>.broadcast();
  final _statusController = StreamController<bool>.broadcast();

  Stream<NfcScanResult> get onCardScanned => _scanController.stream;
  Stream<bool> get onStatusChanged => _statusController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  /// Conteo total de escaneos en esta sesión
  int _scanCount = 0;
  int get scanCount => _scanCount;

  /// Siempre disponible en Windows (lector USB HID)
  Future<bool> isNfcAvailable() async => true;

  /// Inicia la captura HID del lector USB ACR1552U
  Future<void> startNfcReading() async {
    if (_isListening) return;
    _isListening = true;
    _scanCount = 0;
    _lastCardId = null;
    _lastScanTime = null;
    _statusController.add(true);
    HardwareKeyboard.instance.addHandler(_handleHidKeyEvent);
    AppLogger.info('📱 NFC HID listener iniciado (ACR1552U)');
  }

  /// Detiene la captura HID
  Future<void> stopNfcReading() async {
    if (!_isListening) return;
    _isListening = false;
    _statusController.add(false);
    HardwareKeyboard.instance.removeHandler(_handleHidKeyEvent);
    _hidBuffer.clear();
    _hidTimeout?.cancel();
    AppLogger.info('📱 NFC HID listener detenido');
  }

  // ========== HID (Windows/Desktop — ACR1552U) ==========

  final StringBuffer _hidBuffer = StringBuffer();
  Timer? _hidTimeout;

  /// Timeout para agrupar caracteres HID del mismo escaneo (ms).
  /// El ACR1552U transmite a 848 kbps, 100ms es amplio.
  static const _hidTimeoutMs = 150;

  /// Longitud mínima de UID aceptada (4 chars = 2 bytes, ej: MIFARE mini).
  static const _minCardIdLength = 4;

  /// Longitudes esperadas de UID en caracteres hex:
  /// - 8 chars = 4 bytes (MIFARE Classic)
  /// - 14 chars = 7 bytes (NTAG213/215/216, MIFARE DESFire)
  /// - 20 chars = 10 bytes (algunos NFC tags)
  static const _expectedUidLengths = {8, 14, 20};

  /// Anti-duplicado: cooldown en segundos para la misma tarjeta
  int antiDuplicateCooldownSeconds = 3;

  String? _lastCardId;
  DateTime? _lastScanTime;

  bool _handleHidKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;

    // Enter = fin de transmisión del UID
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _processHidBuffer();
      return true; // Consumir Enter para que no afecte otros campos
    }

    final char = event.character;
    if (char != null && char.isNotEmpty && _isHexChar(char)) {
      _hidBuffer.write(char.toUpperCase());
      _hidTimeout?.cancel();
      _hidTimeout = Timer(
        const Duration(milliseconds: _hidTimeoutMs),
        _processHidBuffer,
      );
      return true; // Consumir caracteres hex del lector
    }
    return false;
  }

  void _processHidBuffer() {
    _hidTimeout?.cancel();
    final raw = _hidBuffer.toString().trim();
    _hidBuffer.clear();

    // Normalizar: quitar espacios, guiones, dos puntos (formatos posibles del ACR1552U)
    final cardId = _normalizeUid(raw);

    if (cardId.length < _minCardIdLength) return;

    // Verificar anti-duplicado
    if (_isDuplicate(cardId)) {
      AppLogger.debug(
        '📱 NFC duplicado ignorado: $cardId (cooldown ${antiDuplicateCooldownSeconds}s)',
      );
      return;
    }

    _lastCardId = cardId;
    _lastScanTime = ColombiaTime.now();
    _scanCount++;
    _emitScanResult(cardId);
  }

  /// Normaliza el UID: uppercase, sin separadores
  String _normalizeUid(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[\s:\-]'), '');
  }

  /// Solo caracteres hexadecimales válidos (0-9, A-F, a-f)
  bool _isHexChar(String char) {
    if (char.length != 1) return false;
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 70) || // A-F
        (code >= 97 && code <= 102); // a-f
  }

  /// Verifica si la misma tarjeta fue escaneada dentro del cooldown
  bool _isDuplicate(String cardId) {
    if (_lastCardId == null || _lastScanTime == null) return false;
    if (_lastCardId != cardId) return false;
    final elapsed = ColombiaTime.now().difference(_lastScanTime!).inSeconds;
    return elapsed < antiDuplicateCooldownSeconds;
  }

  void _emitScanResult(String cardId) {
    final uidBytes = cardId.length ~/ 2;
    final isExpected = _expectedUidLengths.contains(cardId.length);
    AppLogger.info(
      '📱 NFC detectado: $cardId (${uidBytes}B${isExpected ? '' : ' - longitud inusual'})',
    );
    _scanController.add(
      NfcScanResult(
        cardId: cardId,
        scannedAt: ColombiaTime.now(),
        uidBytes: uidBytes,
      ),
    );
  }

  // ========== UTILIDADES ==========

  /// Simula un escaneo NFC (para testing/entrada manual)
  void simulateScan(String cardId, {String? payload}) {
    final normalized = _normalizeUid(cardId);
    if (normalized.length < _minCardIdLength) return;
    _scanCount++;
    _scanController.add(
      NfcScanResult(
        cardId: normalized,
        scannedAt: ColombiaTime.now(),
        payload: payload,
        uidBytes: normalized.length ~/ 2,
      ),
    );
  }

  /// Resetea el anti-duplicado (útil al cambiar de modo)
  void resetDuplicateGuard() {
    _lastCardId = null;
    _lastScanTime = null;
  }

  void dispose() {
    stopNfcReading();
    _scanController.close();
    _statusController.close();
  }
}
