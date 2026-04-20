import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import '../utils/logger.dart';
import '../../core/utils/colombia_time.dart';

/// Resultado de un escaneo NFC/RFID via PC/SC (WinSCard)
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

// ==================== WinSCard FFI Bindings ====================

typedef _SCardEstablishContextC = Int32 Function(
    Int32 scope, Pointer r1, Pointer r2, Pointer<IntPtr> ctx);
typedef _SCardEstablishContextDart = int Function(
    int scope, Pointer r1, Pointer r2, Pointer<IntPtr> ctx);

typedef _SCardReleaseContextC = Int32 Function(IntPtr ctx);
typedef _SCardReleaseContextDart = int Function(int ctx);

typedef _SCardListReadersC = Int32 Function(
    IntPtr ctx, Pointer<Utf16> groups, Pointer<Utf16> readers, Pointer<Uint32> len);
typedef _SCardListReadersDart = int Function(
    int ctx, Pointer<Utf16> groups, Pointer<Utf16> readers, Pointer<Uint32> len);

typedef _SCardConnectC = Int32 Function(IntPtr ctx, Pointer<Utf16> reader,
    Int32 share, Int32 proto, Pointer<IntPtr> card, Pointer<Int32> activeProto);
typedef _SCardConnectDart = int Function(int ctx, Pointer<Utf16> reader,
    int share, int proto, Pointer<IntPtr> card, Pointer<Int32> activeProto);

typedef _SCardDisconnectC = Int32 Function(IntPtr card, Int32 disp);
typedef _SCardDisconnectDart = int Function(int card, int disp);

typedef _SCardTransmitC = Int32 Function(
    IntPtr card,
    Pointer sendPci,
    Pointer<Uint8> send,
    Int32 sendLen,
    Pointer recvPci,
    Pointer<Uint8> recv,
    Pointer<Uint32> recvLen);
typedef _SCardTransmitDart = int Function(
    int card,
    Pointer sendPci,
    Pointer<Uint8> send,
    int sendLen,
    Pointer recvPci,
    Pointer<Uint8> recv,
    Pointer<Uint32> recvLen);

typedef _SCardGetStatusChangeC = Int32 Function(
    IntPtr ctx, Int32 timeout, Pointer readerStates, Int32 cReaders);
typedef _SCardGetStatusChangeDart = int Function(
    int ctx, int timeout, Pointer readerStates, int cReaders);

typedef _SCardCancelC = Int32 Function(IntPtr ctx);
typedef _SCardCancelDart = int Function(int ctx);

// SCARD_READERSTATE structure (Unicode version) - reserved for future event-driven mode
// ignore: unused_element
base class _SCARD_READERSTATE extends Struct {
  external Pointer<Utf16> szReader;
  external Pointer pvUserData;
  @Uint32()
  external int dwCurrentState;
  @Uint32()
  external int dwEventState;
  @Uint32()
  external int cbAtr;
  @Array(36)
  external Array<Uint8> rgbAtr;
}

/// Constantes WinSCard
class _SC {
  static const int SCOPE_SYSTEM = 2;
  static const int SHARE_SHARED = 2;
  static const int PROTOCOL_T0 = 1;
  static const int PROTOCOL_T1 = 2;
  static const int PROTOCOL_ANY = 3;
  static const int LEAVE_CARD = 0;
  static const int SCARD_STATE_UNAWARE = 0;
  static const int SCARD_STATE_CHANGED = 2;
  static const int SCARD_STATE_PRESENT = 0x20;
  static const int SCARD_STATE_EMPTY = 0x10;
  static const int SCARD_E_NO_SMARTCARD = 0x8010000C;
  static const int SCARD_E_TIMEOUT = 0x8010000A;
  static const int SCARD_E_CANCELLED = 0x80100002;
  static const int SCARD_W_REMOVED_CARD = 0x80100069;
  static const int INFINITE = -1;
  static const int OK = 0;
}

/// Servicio NFC via PC/SC (WinSCard API) para lectores ACR1552U en Windows.
///
/// Usa dart:ffi para comunicarse con winscard.dll y leer UIDs de tarjetas
/// mediante el comando APDU GET DATA (FF CA 00 00 00).
class NfcPcscService {
  NfcPcscService._();
  static final instance = NfcPcscService._();

  final _scanController = StreamController<NfcScanResult>.broadcast();
  final _statusController = StreamController<bool>.broadcast();

  Stream<NfcScanResult> get onCardScanned => _scanController.stream;
  Stream<bool> get onStatusChanged => _statusController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  int _scanCount = 0;
  int get scanCount => _scanCount;

  String? _readerName;
  String? get readerName => _readerName;

  /// Anti-duplicado
  int antiDuplicateCooldownSeconds = 3;
  String? _lastCardId;
  DateTime? _lastScanTime;

  // FFI handles
  late final DynamicLibrary _winscard;
  late final _SCardEstablishContextDart _establish;
  late final _SCardReleaseContextDart _release;
  late final _SCardListReadersDart _listReaders;
  late final _SCardConnectDart _connect;
  late final _SCardDisconnectDart _disconnect;
  late final _SCardTransmitDart _transmit;
  late final _SCardGetStatusChangeDart _getStatusChange;
  late final _SCardCancelDart _cancel;
  late final Pointer _pciT0;
  late final Pointer _pciT1;
  bool _ffiLoaded = false;

  int _hContext = 0;
  Timer? _pollTimer;
  bool _polling = false;

  void _loadFfi() {
    if (_ffiLoaded) return;
    _winscard = DynamicLibrary.open('winscard.dll');

    _establish = _winscard
        .lookupFunction<_SCardEstablishContextC, _SCardEstablishContextDart>(
            'SCardEstablishContext');
    _release = _winscard
        .lookupFunction<_SCardReleaseContextC, _SCardReleaseContextDart>(
            'SCardReleaseContext');
    _listReaders = _winscard
        .lookupFunction<_SCardListReadersC, _SCardListReadersDart>(
            'SCardListReadersW');
    _connect = _winscard
        .lookupFunction<_SCardConnectC, _SCardConnectDart>('SCardConnectW');
    _disconnect = _winscard
        .lookupFunction<_SCardDisconnectC, _SCardDisconnectDart>(
            'SCardDisconnect');
    _transmit = _winscard
        .lookupFunction<_SCardTransmitC, _SCardTransmitDart>('SCardTransmit');
    _getStatusChange = _winscard
        .lookupFunction<_SCardGetStatusChangeC, _SCardGetStatusChangeDart>(
            'SCardGetStatusChangeW');
    _cancel = _winscard
        .lookupFunction<_SCardCancelC, _SCardCancelDart>('SCardCancel');

    // Get PCI pointers for T0 and T1 protocols
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final getProcAddr = kernel32.lookupFunction<
        Pointer Function(IntPtr, Pointer<Utf8>),
        Pointer Function(int, Pointer<Utf8>)>('GetProcAddress');
    final wscHandle = kernel32.lookupFunction<IntPtr Function(Pointer<Utf16>),
        int Function(Pointer<Utf16>)>('LoadLibraryW')('winscard.dll'.toNativeUtf16());

    _pciT0 = getProcAddr(wscHandle, 'g_rgSCardT0Pci'.toNativeUtf8());
    _pciT1 = getProcAddr(wscHandle, 'g_rgSCardT1Pci'.toNativeUtf8());

    _ffiLoaded = true;
    AppLogger.info('📱 PC/SC FFI cargado correctamente');
  }

  /// Verifica si hay lectores NFC disponibles
  Future<bool> isNfcAvailable() async {
    try {
      _loadFfi();
      final readers = _getReaderList();
      return readers.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene la lista de lectores PC/SC disponibles
  List<String> _getReaderList() {
    final pCtx = calloc<IntPtr>();
    try {
      final r = _establish(_SC.SCOPE_SYSTEM, nullptr, nullptr, pCtx);
      if (r != _SC.OK) {
        AppLogger.error('❌ SCardEstablishContext failed: 0x${r.toRadixString(16)}');
        return [];
      }
      final ctx = pCtx.value;

      // First call to get buffer size
      final pLen = calloc<Uint32>();
      _listReaders(ctx, nullptr, nullptr, pLen);
      final len = pLen.value;
      if (len == 0) {
        calloc.free(pLen);
        _release(ctx);
        return [];
      }

      // Second call to get reader names
      final pBuf = calloc<Uint16>(len);
      _listReaders(ctx, nullptr, pBuf.cast<Utf16>(), pLen);

      // Parse multi-string (null-separated, double-null terminated)
      final readers = <String>[];
      int offset = 0;
      while (offset < len) {
        final str = (pBuf + offset).cast<Utf16>().toDartString();
        if (str.isEmpty) break;
        readers.add(str);
        offset += str.length + 1;
      }

      calloc.free(pLen);
      calloc.free(pBuf);
      _release(ctx);
      return readers;
    } finally {
      calloc.free(pCtx);
    }
  }

  /// Inicia el polling de tarjetas NFC via PC/SC
  Future<void> startNfcReading() async {
    if (_isListening) return;

    _loadFfi();

    // Establecer contexto
    final pCtx = calloc<IntPtr>();
    final r = _establish(_SC.SCOPE_SYSTEM, nullptr, nullptr, pCtx);
    if (r != _SC.OK) {
      calloc.free(pCtx);
      AppLogger.error('❌ No se pudo iniciar PC/SC: 0x${r.toRadixString(16)}');
      return;
    }
    _hContext = pCtx.value;
    calloc.free(pCtx);

    // Buscar lector PICC (contactless)
    final readers = _getReaderList();
    AppLogger.info('📱 PC/SC lectores encontrados: $readers');

    _readerName = readers.firstWhere(
      (r) => r.toUpperCase().contains('PICC'),
      orElse: () => readers.isNotEmpty ? readers.first : '',
    );

    if (_readerName == null || _readerName!.isEmpty) {
      AppLogger.error('❌ No se encontró lector NFC contactless');
      _release(_hContext);
      _hContext = 0;
      return;
    }

    AppLogger.info('📱 PC/SC usando lector: $_readerName');

    _isListening = true;
    _scanCount = 0;
    _lastCardId = null;
    _lastScanTime = null;
    _statusController.add(true);

    // Iniciar polling con Timer (cada 500ms)
    _polling = true;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_polling) _pollForCard();
    });

    AppLogger.info('📱 PC/SC polling iniciado (cada 500ms)');
  }

  /// Detiene el polling
  Future<void> stopNfcReading() async {
    if (!_isListening) return;
    _isListening = false;
    _polling = false;
    _pollTimer?.cancel();
    _pollTimer = null;

    if (_hContext != 0) {
      _cancel(_hContext);
      _release(_hContext);
      _hContext = 0;
    }

    _statusController.add(false);
    AppLogger.info('📱 PC/SC polling detenido');
  }

  /// Intenta conectar y leer UID de tarjeta presente
  void _pollForCard() {
    if (!_polling || _hContext == 0 || _readerName == null) return;

    final pCard = calloc<IntPtr>();
    final pProto = calloc<Int32>();
    final readerNamePtr = _readerName!.toNativeUtf16();

    try {
      final r = _connect(
        _hContext,
        readerNamePtr.cast<Utf16>(),
        _SC.SHARE_SHARED,
        _SC.PROTOCOL_ANY,
        pCard,
        pProto,
      );

      if (r != _SC.OK) {
        // No card present - this is normal
        return;
      }

      final hCard = pCard.value;
      final proto = pProto.value;

      // Card found! Send GET DATA APDU to retrieve UID
      final uid = _getCardUid(hCard, proto);

      _disconnect(hCard, _SC.LEAVE_CARD);

      if (uid != null && uid.isNotEmpty) {
        _processUid(uid);
      }
    } catch (e) {
      AppLogger.error('❌ PC/SC poll error: $e');
    } finally {
      calloc.free(pCard);
      calloc.free(pProto);
      calloc.free(readerNamePtr);
    }
  }

  /// Envía APDU GET DATA (FF CA 00 00 00) para obtener el UID
  String? _getCardUid(int hCard, int proto) {
    final pci = proto == _SC.PROTOCOL_T0 ? _pciT0 : _pciT1;

    // APDU: FF CA 00 00 00 = Get UID
    final sendBuf = calloc<Uint8>(5);
    sendBuf[0] = 0xFF; // CLA
    sendBuf[1] = 0xCA; // INS - Get Data
    sendBuf[2] = 0x00; // P1 - UID
    sendBuf[3] = 0x00; // P2
    sendBuf[4] = 0x00; // Le - max length

    final recvBuf = calloc<Uint8>(256);
    final pRecvLen = calloc<Uint32>();
    pRecvLen.value = 256;

    try {
      final r = _transmit(hCard, pci, sendBuf, 5, nullptr, recvBuf, pRecvLen);

      if (r != _SC.OK) {
        AppLogger.error('❌ SCardTransmit failed: 0x${r.toRadixString(16)}');
        return null;
      }

      final recvLen = pRecvLen.value;
      if (recvLen < 2) return null;

      final sw1 = recvBuf[recvLen - 2];
      final sw2 = recvBuf[recvLen - 1];

      if (sw1 == 0x90 && sw2 == 0x00) {
        // Success - extract UID bytes
        final uidLen = recvLen - 2;
        final uidBytes = <String>[];
        for (int i = 0; i < uidLen; i++) {
          uidBytes.add(recvBuf[i].toRadixString(16).padLeft(2, '0').toUpperCase());
        }
        return uidBytes.join('');
      } else {
        AppLogger.warning(
            '⚠️ APDU response: SW=${sw1.toRadixString(16).padLeft(2, '0')}${sw2.toRadixString(16).padLeft(2, '0')}');
        return null;
      }
    } finally {
      calloc.free(sendBuf);
      calloc.free(recvBuf);
      calloc.free(pRecvLen);
    }
  }

  void _processUid(String cardId) {
    // Anti-duplicado
    if (_isDuplicate(cardId)) return;

    _lastCardId = cardId;
    _lastScanTime = ColombiaTime.now();
    _scanCount++;

    final uidBytes = cardId.length ~/ 2;
    AppLogger.info('📱 NFC tarjeta detectada: $cardId (${uidBytes}B)');

    _scanController.add(
      NfcScanResult(
        cardId: cardId,
        scannedAt: ColombiaTime.now(),
        uidBytes: uidBytes,
      ),
    );
  }

  bool _isDuplicate(String cardId) {
    if (_lastCardId == null || _lastScanTime == null) return false;
    if (_lastCardId != cardId) return false;
    final elapsed = ColombiaTime.now().difference(_lastScanTime!).inSeconds;
    return elapsed < antiDuplicateCooldownSeconds;
  }

  /// Simula un escaneo NFC (para testing)
  void simulateScan(String cardId, {String? payload}) {
    final normalized = cardId.toUpperCase().replaceAll(RegExp(r'[\s:\-]'), '');
    if (normalized.length < 4) return;
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

  /// Resetea el anti-duplicado
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
