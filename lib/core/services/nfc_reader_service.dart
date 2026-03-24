import 'dart:async';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Resultado de un escaneo NFC/RFID via lector USB HID
class NfcScanResult {
  final String cardId;
  final DateTime scannedAt;
  final String? payload;

  const NfcScanResult({
    required this.cardId,
    required this.scannedAt,
    this.payload,
  });
}

/// Servicio de lectura RFID/NFC para Windows via lectores USB en modo HID.
///
/// El lector USB envía el UID de la tarjeta como entrada de teclado
/// (caracteres hex + Enter). Este servicio captura esa entrada.
class NfcReaderService {
  NfcReaderService._();
  static final instance = NfcReaderService._();

  final _scanController = StreamController<NfcScanResult>.broadcast();
  final _statusController = StreamController<bool>.broadcast();

  Stream<NfcScanResult> get onCardScanned => _scanController.stream;
  Stream<bool> get onStatusChanged => _statusController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  /// Siempre disponible en Windows (lector USB HID)
  Future<bool> isNfcAvailable() async => true;

  /// Inicia la captura HID del lector USB
  Future<void> startNfcReading() async {
    if (_isListening) return;
    _isListening = true;
    _statusController.add(true);
    HardwareKeyboard.instance.addHandler(_handleHidKeyEvent);
    AppLogger.info('📱 NFC HID listener iniciado');
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

  // ========== HID (Windows/Desktop) ==========

  final StringBuffer _hidBuffer = StringBuffer();
  Timer? _hidTimeout;
  static const _hidTimeoutMs = 100;
  static const _minCardIdLength = 4;

  bool _handleHidKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _processHidBuffer();
      return false;
    }
    final char = event.character;
    if (char != null && char.isNotEmpty && _isValidUidChar(char)) {
      _hidBuffer.write(char.toUpperCase());
      _hidTimeout?.cancel();
      _hidTimeout = Timer(
        const Duration(milliseconds: _hidTimeoutMs),
        _processHidBuffer,
      );
    }
    return false;
  }

  void _processHidBuffer() {
    _hidTimeout?.cancel();
    final cardId = _hidBuffer.toString().trim();
    _hidBuffer.clear();
    if (cardId.length >= _minCardIdLength) {
      _emitScanResult(cardId);
    }
  }

  bool _isValidUidChar(String char) {
    if (char.length != 1) return false;
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122);
  }

  void _emitScanResult(String cardId) {
    AppLogger.info('📱 NFC detectado: $cardId');
    _scanController.add(
      NfcScanResult(cardId: cardId, scannedAt: DateTime.now()),
    );
  }

  // ========== UTILIDADES ==========

  /// Simula un escaneo NFC (para testing/entrada manual)
  void simulateScan(String cardId, {String? payload}) {
    _scanController.add(
      NfcScanResult(
        cardId: cardId,
        scannedAt: DateTime.now(),
        payload: payload,
      ),
    );
  }

  void dispose() {
    stopNfcReading();
    _scanController.close();
    _statusController.close();
  }
}
