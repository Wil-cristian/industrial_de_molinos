# =============================================================
# DIAGNÓSTICO COMPLETO DE TARJETA NFC con ACR1552U
# Lee TODA la información posible de la tarjeta
# =============================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  DIAGNÓSTICO NFC - ACR1552U" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Cargar winscard.dll ---
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class WinSCard {
    [DllImport("winscard.dll", CharSet=CharSet.Unicode)]
    public static extern int SCardEstablishContext(int dwScope, IntPtr pvReserved1, IntPtr pvReserved2, out IntPtr phContext);

    [DllImport("winscard.dll", CharSet=CharSet.Unicode)]
    public static extern int SCardListReadersW(IntPtr hContext, string mszGroups, IntPtr mszReaders, ref int pcchReaders);

    [DllImport("winscard.dll", CharSet=CharSet.Unicode)]
    public static extern int SCardConnectW(IntPtr hContext, string szReader, int dwShareMode, int dwPreferredProtocols, out IntPtr phCard, out int pdwActiveProtocol);

    [DllImport("winscard.dll")]
    public static extern int SCardDisconnect(IntPtr hCard, int dwDisposition);

    [DllImport("winscard.dll")]
    public static extern int SCardReleaseContext(IntPtr hContext);

    [DllImport("winscard.dll")]
    public static extern int SCardTransmit(IntPtr hCard, IntPtr pioSendPci, byte[] pbSendBuffer, int cbSendLength, IntPtr pioRecvPci, byte[] pbRecvBuffer, ref int pcbRecvLength);

    [DllImport("winscard.dll", CharSet=CharSet.Unicode)]
    public static extern int SCardStatusW(IntPtr hCard, StringBuilder szReaderName, ref int pcchReaderLen, out int pdwState, out int pdwProtocol, byte[] pbAtr, ref int pcbAtrLen);

    public static IntPtr SCARD_PCI_T0 = GetPCI(0);
    public static IntPtr SCARD_PCI_T1 = GetPCI(1);
    
    static IntPtr GetPCI(int idx) {
        IntPtr lib = LoadLibrary("winscard.dll");
        if (idx == 0) return GetProcAddress(lib, "g_rgSCardT0Pci");
        return GetProcAddress(lib, "g_rgSCardT1Pci");
    }
    
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
    static extern IntPtr LoadLibrary(string lpFileName);
    
    [DllImport("kernel32.dll", CharSet=CharSet.Ansi, ExactSpelling=true)]
    static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);
}
"@

function Send-APDU {
    param(
        [IntPtr]$Card,
        [IntPtr]$PCI,
        [byte[]]$Command,
        [string]$Description
    )
    $recv = New-Object byte[] 258
    $recvLen = 258
    $ret = [WinSCard]::SCardTransmit($Card, $PCI, $Command, $Command.Length, [IntPtr]::Zero, $recv, [ref]$recvLen)
    
    if ($ret -ne 0) {
        Write-Host "  [$Description] ERROR: 0x$($ret.ToString('X8'))" -ForegroundColor Red
        return $null
    }
    
    $data = $recv[0..($recvLen-1)]
    $sw1 = $data[$recvLen-2]
    $sw2 = $data[$recvLen-1]
    $swHex = "$($sw1.ToString('X2'))$($sw2.ToString('X2'))"
    $dataHex = ($data[0..($recvLen-3)] | ForEach-Object { $_.ToString('X2') }) -join ' '
    
    if ($sw1 -eq 0x90 -and $sw2 -eq 0x00) {
        Write-Host "  [$Description] OK (SW=$swHex)" -ForegroundColor Green
        if ($dataHex) { Write-Host "    Data: $dataHex" -ForegroundColor Yellow }
        return @{ Data = $data[0..($recvLen-3)]; SW = $swHex; Raw = $data }
    } else {
        Write-Host "  [$Description] SW=$swHex" -ForegroundColor DarkYellow
        if ($dataHex) { Write-Host "    Data: $dataHex" -ForegroundColor Gray }
        return @{ Data = $data[0..($recvLen-3)]; SW = $swHex; Raw = $data }
    }
}

# --- Conectar ---
$ctx = [IntPtr]::Zero
$ret = [WinSCard]::SCardEstablishContext(2, [IntPtr]::Zero, [IntPtr]::Zero, [ref]$ctx)
if ($ret -ne 0) { Write-Host "Error estableciendo contexto: 0x$($ret.ToString('X8'))" -ForegroundColor Red; exit }

# Listar lectores
$bufLen = 0
[void][WinSCard]::SCardListReadersW($ctx, $null, [IntPtr]::Zero, [ref]$bufLen)
$buf = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($bufLen * 2)
[void][WinSCard]::SCardListReadersW($ctx, $null, $buf, [ref]$bufLen)
$readersStr = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($buf, $bufLen)
[System.Runtime.InteropServices.Marshal]::FreeHGlobal($buf)
$readers = $readersStr.Split([char]0) | Where-Object { $_ -ne '' }

Write-Host "Lectores detectados:" -ForegroundColor Cyan
$readers | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
Write-Host ""

# Seleccionar lector PICC (contactless)
$reader = $readers | Where-Object { $_ -match 'PICC' } | Select-Object -First 1
if (-not $reader) { $reader = $readers[0] }

Write-Host "Usando lector: $reader" -ForegroundColor Cyan
Write-Host ""
Write-Host ">>> ACERCA UNA TARJETA NFC AL LECTOR <<<" -ForegroundColor Magenta
Write-Host "Intentando conectar (esperando tarjeta)..." -ForegroundColor Gray

# Intentar conectar (loop hasta que haya tarjeta)
$card = [IntPtr]::Zero
$proto = 0
$maxAttempts = 60
for ($i = 0; $i -lt $maxAttempts; $i++) {
    $ret = [WinSCard]::SCardConnectW($ctx, $reader, 2, 3, [ref]$card, [ref]$proto)
    if ($ret -eq 0) { break }
    Start-Sleep -Milliseconds 500
    if ($i % 4 -eq 0 -and $i -gt 0) { Write-Host "  Esperando tarjeta... ($($i/2)s)" -ForegroundColor DarkGray }
}

if ($ret -ne 0) {
    Write-Host "No se detectó tarjeta en 30 segundos" -ForegroundColor Red
    [void][WinSCard]::SCardReleaseContext($ctx)
    exit
}

$protoName = if ($proto -eq 1) { "T=0" } elseif ($proto -eq 2) { "T=1" } else { "T=$proto" }
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  TARJETA DETECTADA! (Protocolo: $protoName)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$pci = if ($proto -eq 1) { [WinSCard]::SCARD_PCI_T0 } else { [WinSCard]::SCARD_PCI_T1 }

# --- 1. ATR (Answer To Reset) ---
Write-Host "1. ATR (Answer To Reset):" -ForegroundColor Cyan
$atrBuf = New-Object byte[] 36
$atrLen = 36
$readerNameBuf = New-Object System.Text.StringBuilder 256
$readerNameLen = 256
$dwState = 0
$dwProto = 0
$ret = [WinSCard]::SCardStatusW($card, $readerNameBuf, [ref]$readerNameLen, [ref]$dwState, [ref]$dwProto, $atrBuf, [ref]$atrLen)
if ($ret -eq 0) {
    $atr = ($atrBuf[0..($atrLen-1)] | ForEach-Object { $_.ToString('X2') }) -join ' '
    Write-Host "  ATR: $atr" -ForegroundColor Yellow
    Write-Host "  Estado: $dwState, Protocolo: $dwProto" -ForegroundColor Gray
    
    # Interpretar ATR básico
    if ($atrLen -ge 2) {
        $t0 = $atrBuf[1]
        $historical = $t0 -band 0x0F
        Write-Host "  Bytes históricos: $historical" -ForegroundColor Gray
    }
} else {
    Write-Host "  Error leyendo ATR: 0x$($ret.ToString('X8'))" -ForegroundColor Red
}

Write-Host ""

# --- 2. UID (Identificador Único) ---
Write-Host "2. UID (Identificador Único):" -ForegroundColor Cyan
$uid = Send-APDU -Card $card -PCI $pci -Command @(0xFF, 0xCA, 0x00, 0x00, 0x00) -Description "GET UID"
if ($uid -and $uid.SW -eq "9000") {
    $uidHex = ($uid.Data | ForEach-Object { $_.ToString('X2') }) -join ''
    $uidLen = $uid.Data.Count
    Write-Host "    UID: $uidHex ($uidLen bytes)" -ForegroundColor White
    
    if ($uidLen -eq 4) { Write-Host "    Tipo: UID simple (4 bytes) - Probablemente MIFARE Classic" -ForegroundColor Gray }
    elseif ($uidLen -eq 7) { Write-Host "    Tipo: UID doble (7 bytes) - Probablemente NTAG/MIFARE Ultralight/DESFire" -ForegroundColor Gray }
    elseif ($uidLen -eq 10) { Write-Host "    Tipo: UID triple (10 bytes)" -ForegroundColor Gray }
}

Write-Host ""

# --- 3. ATS (Answer To Select) - Info del chip ---
Write-Host "3. ATS (Answer To Select):" -ForegroundColor Cyan
Send-APDU -Card $card -PCI $pci -Command @(0xFF, 0xCA, 0x01, 0x00, 0x00) -Description "GET ATS"

Write-Host ""

# --- 4. Tipo de tarjeta vía FIRMWARE del lector ---
Write-Host "4. Info del lector ACR1552U:" -ForegroundColor Cyan
# Firmware version
Send-APDU -Card $card -PCI $pci -Command @(0xFF, 0x00, 0x48, 0x00, 0x00) -Description "Firmware Version"

Write-Host ""

# --- 5. Intentar leer páginas/bloques de la tarjeta ---
Write-Host "5. Lectura de datos de la tarjeta:" -ForegroundColor Cyan
Write-Host "   (Intentando leer primeras páginas/bloques)" -ForegroundColor Gray
Write-Host ""

# Para NTAG/Ultralight: READ pages (4 pages = 16 bytes por lectura)
Write-Host "  --- Lectura NTAG/Ultralight (páginas 0-15) ---" -ForegroundColor Cyan
for ($page = 0; $page -le 15; $page++) {
    # READ BINARY: FF B0 00 <page> <len>
    $cmd = @(0xFF, 0xB0, 0x00, [byte]$page, 0x04)
    $r = Send-APDU -Card $card -PCI $pci -Command $cmd -Description "Page $page"
    if ($r -and $r.SW -ne "9000") {
        Write-Host "    (Lectura falló en página $page - posiblemente no es NTAG o está protegida)" -ForegroundColor DarkGray
        break
    }
}

Write-Host ""

# --- 6. Intentar leer como MIFARE Classic ---
Write-Host "6. Intento MIFARE Classic (bloque 0-3, sector 0):" -ForegroundColor Cyan
# Load default key A: FF FF FF FF FF FF
$loadKey = @(0xFF, 0x82, 0x00, 0x00, 0x06, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF)
$keyResult = Send-APDU -Card $card -PCI $pci -Command $loadKey -Description "Load Key A (default)"

if ($keyResult -and $keyResult.SW -eq "9000") {
    # Authenticate block 0 with key A
    $auth = @(0xFF, 0x86, 0x00, 0x00, 0x05, 0x01, 0x00, 0x00, 0x60, 0x00)
    $authResult = Send-APDU -Card $card -PCI $pci -Command $auth -Description "Auth Block 0 Key A"
    
    if ($authResult -and $authResult.SW -eq "9000") {
        for ($blk = 0; $blk -le 3; $blk++) {
            $readCmd = @(0xFF, 0xB0, 0x00, [byte]$blk, 0x10)
            Send-APDU -Card $card -PCI $pci -Command $readCmd -Description "Block $blk"
        }
    }
}

Write-Host ""

# --- 7. Verificar si se puede escribir ---
Write-Host "7. Test de escritura (NO escribe datos reales):" -ForegroundColor Cyan
Write-Host "   La tarjeta SOPORTA escritura si las lecturas anteriores funcionaron." -ForegroundColor Gray
Write-Host "   Para NTAG215: Páginas 4-129 son escribibles (4 bytes/página = 504 bytes útiles)" -ForegroundColor Gray
Write-Host "   Para MIFARE Classic 1K: Bloques 1-2 de cada sector son escribibles (16 bytes/bloque)" -ForegroundColor Gray
Write-Host ""

# --- 8. Resumen ---
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RESUMEN" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($uid -and $uid.SW -eq "9000") {
    $uidHex = ($uid.Data | ForEach-Object { $_.ToString('X2') }) -join ''
    Write-Host "  UID: $uidHex" -ForegroundColor Yellow
    Write-Host "  Largo UID: $($uid.Data.Count) bytes" -ForegroundColor White
}
Write-Host "  Protocolo: $protoName" -ForegroundColor White
if ($atrLen -gt 0) {
    $atrStr = ($atrBuf[0..($atrLen-1)] | ForEach-Object { $_.ToString('X2') }) -join ''
    Write-Host "  ATR: $atrStr" -ForegroundColor White
    
    # Detectar tipo de chip por ATR
    $atrJoined = ($atrBuf[0..($atrLen-1)] | ForEach-Object { $_.ToString('X2') }) -join ''
    if ($atrJoined -match "0044") { Write-Host "  Chip: Probablemente NTAG (NXP)" -ForegroundColor Green }
    elseif ($atrJoined -match "0004") { Write-Host "  Chip: MIFARE compatible" -ForegroundColor Green }
    elseif ($atrJoined -match "0304") { Write-Host "  Chip: MIFARE DESFire" -ForegroundColor Green }
}
Write-Host ""
Write-Host "  CAPACIDADES DEL ACR1552U:" -ForegroundColor Cyan
Write-Host "    - Leer UID de cualquier tarjeta NFC (ISO 14443A/B, FeliCa)" -ForegroundColor White
Write-Host "    - Leer/Escribir NTAG 213/215/216 (4-888 bytes)" -ForegroundColor White
Write-Host "    - Leer/Escribir MIFARE Classic 1K/4K" -ForegroundColor White
Write-Host "    - Leer/Escribir MIFARE Ultralight" -ForegroundColor White
Write-Host "    - Leer/Escribir MIFARE DESFire" -ForegroundColor White
Write-Host "    - Soporte NFC Forum Type 1-5 tags" -ForegroundColor White
Write-Host "    - Emulación de tarjeta (Card Emulation)" -ForegroundColor White
Write-Host "    - Peer-to-peer NFC" -ForegroundColor White
Write-Host "    - Comandos APDU personalizados" -ForegroundColor White
Write-Host ""

# Limpiar
[void][WinSCard]::SCardDisconnect($card, 0)
[void][WinSCard]::SCardReleaseContext($ctx)

Write-Host "Diagnóstico completado." -ForegroundColor Green
