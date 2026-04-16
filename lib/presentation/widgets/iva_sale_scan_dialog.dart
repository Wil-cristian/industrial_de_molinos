import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/utils/helpers.dart';
import '../../data/datasources/invoice_scanner_service.dart';
import '../../data/datasources/iva_datasource.dart';
import '../../core/utils/colombia_time.dart';

// =====================================================
// IvaSaleScanDialog
// Escanea facturas de VENTA para registrar SOLO en iva_invoices.
// NO toca: inventario, caja, proveedores, invoices, invoice_items.
// =====================================================

enum _SaleScanStep { selectImage, scanning, review, saving }

enum _SaleBatchStatus { pending, scanning, done, error }

class _SaleBatchItem {
  final int index;
  final PlatformFile file;
  _SaleBatchStatus status;
  InvoiceScanResult? result;
  String? scanError;
  bool isExpanded;
  bool selected;
  bool saved;
  String? saveError;

  final TextEditingController invoiceNumberCtrl;
  final TextEditingController invoiceDateCtrl;
  final TextEditingController cufeCtrl;
  final TextEditingController clientNameCtrl;
  final TextEditingController clientNitCtrl;
  final TextEditingController subtotalCtrl;
  final TextEditingController taxAmountCtrl;
  final TextEditingController taxRateCtrl;
  final TextEditingController reteFteCtrl;
  final TextEditingController reteIcaCtrl;
  final TextEditingController reteIvaCtrl;
  final TextEditingController totalCtrl;
  final TextEditingController notesCtrl;

  _SaleBatchItem({required this.index, required this.file})
    : status = _SaleBatchStatus.pending,
      result = null,
      scanError = null,
      isExpanded = false,
      selected = true,
      saved = false,
      saveError = null,
      invoiceNumberCtrl = TextEditingController(),
      invoiceDateCtrl = TextEditingController(),
      cufeCtrl = TextEditingController(),
      clientNameCtrl = TextEditingController(),
      clientNitCtrl = TextEditingController(),
      subtotalCtrl = TextEditingController(text: '0.00'),
      taxAmountCtrl = TextEditingController(text: '0.00'),
      taxRateCtrl = TextEditingController(text: '0.00'),
      reteFteCtrl = TextEditingController(text: '0.00'),
      reteIcaCtrl = TextEditingController(text: '0.00'),
      reteIvaCtrl = TextEditingController(text: '0.00'),
      totalCtrl = TextEditingController(text: '0.00'),
      notesCtrl = TextEditingController();

  void populateFromResult(InvoiceScanResult r, DateFormat dateFormat) {
    result = r;
    status = _SaleBatchStatus.done;
    invoiceNumberCtrl.text = r.invoiceNumber ?? '';
    invoiceDateCtrl.text = r.invoiceDate != null
        ? dateFormat.format(r.invoiceDate!)
        : '';
    cufeCtrl.text = r.cufe ?? '';
    // En facturas de venta, el "buyer" del JSON es el cliente
    clientNameCtrl.text = r.buyerName ?? r.supplier.name ?? '';
    clientNitCtrl.text = r.buyerDocument ?? r.supplier.documentNumber ?? '';
    subtotalCtrl.text = r.subtotal.toStringAsFixed(2);
    taxRateCtrl.text = r.taxRate.toStringAsFixed(2);
    taxAmountCtrl.text = r.taxAmount.toStringAsFixed(2);
    reteFteCtrl.text = r.retentionRteFte.toStringAsFixed(2);
    reteIcaCtrl.text = r.retentionIca.toStringAsFixed(2);
    reteIvaCtrl.text = r.retentionIva.toStringAsFixed(2);
    totalCtrl.text = r.total.toStringAsFixed(2);
    notesCtrl.text = r.notes ?? '';
  }

  void dispose() {
    for (final c in [
      invoiceNumberCtrl,
      invoiceDateCtrl,
      cufeCtrl,
      clientNameCtrl,
      clientNitCtrl,
      subtotalCtrl,
      taxAmountCtrl,
      taxRateCtrl,
      reteFteCtrl,
      reteIcaCtrl,
      reteIvaCtrl,
      totalCtrl,
      notesCtrl,
    ]) {
      c.dispose();
    }
  }
}

class IvaSaleScanDialog extends StatefulWidget {
  const IvaSaleScanDialog({super.key});

  @override
  State<IvaSaleScanDialog> createState() => _IvaSaleScanDialogState();

  static Future<String?> show(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      return Navigator.of(context, rootNavigator: true).push<String>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const IvaSaleScanDialog(),
        ),
      );
    }
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const IvaSaleScanDialog(),
    );
  }
}

class _IvaSaleScanDialogState extends State<IvaSaleScanDialog> {
  _SaleScanStep _step = _SaleScanStep.selectImage;
  final List<_SaleBatchItem> _items = [];
  int _savingIndex = 0;
  String? _globalError;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  int get _doneCount =>
      _items.where((i) => i.status == _SaleBatchStatus.done).length;
  int get _selectedCount => _items
      .where((i) => i.selected && i.status == _SaleBatchStatus.done)
      .length;

  // ─── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 600;

    if (isMobile) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildContent()),
              _buildActions(),
            ],
          ),
        ),
      );
    }

    final w = sw > 1200 ? 920.0 : sw * 0.9;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: w,
        constraints: const BoxConstraints(maxHeight: 840),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(child: _buildContent()),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    final theme = Theme.of(context);
    final compact = MediaQuery.of(context).size.width < 600;
    const titles = {
      _SaleScanStep.selectImage: 'Escanear Facturas de Venta (IVA)',
      _SaleScanStep.scanning: 'Analizando facturas...',
      _SaleScanStep.review: 'Revisar Datos Extraídos',
      _SaleScanStep.saving: 'Registrando en IVA...',
    };
    const icons = {
      _SaleScanStep.selectImage: Icons.receipt_long,
      _SaleScanStep.scanning: Icons.auto_awesome,
      _SaleScanStep.review: Icons.fact_check_outlined,
      _SaleScanStep.saving: Icons.save,
    };
    String? subtitle;
    if (_step == _SaleScanStep.scanning) {
      subtitle = '$_doneCount / ${_items.length} procesadas';
    } else if (_step == _SaleScanStep.review) {
      final total = _items.fold<double>(
        0,
        (s, i) => s + (double.tryParse(i.totalCtrl.text) ?? 0),
      );
      subtitle =
          '${_items.length} factura(s) · Total: ${Helpers.formatCurrency(total)}';
    } else if (_step == _SaleScanStep.saving) {
      subtitle = '$_savingIndex / $_selectedCount guardadas';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32), // verde para distinguir de compras
        borderRadius: compact
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          if (compact) ...[
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            const SizedBox(width: 4),
          ],
          Icon(icons[_step], color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_step]!,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xB3FFFFFF),
                    ),
                  ),
                const Text(
                  'Solo registra en IVA · No afecta inventario ni caja',
                  style: TextStyle(fontSize: 11, color: Color(0xB3FFFFFF)),
                ),
              ],
            ),
          ),
          _buildStepDots(),
          const SizedBox(width: 8),
          if (!compact &&
              _step != _SaleScanStep.saving &&
              _step != _SaleScanStep.scanning)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildStepDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final isActive = i == _step.index;
        final isDone = i < _step.index;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: (isDone || isActive)
                ? Colors.white
                : const Color(0x62FFFFFF),
          ),
        );
      }),
    );
  }

  // ─── Content router ────────────────────────────────────────────
  Widget _buildContent() {
    switch (_step) {
      case _SaleScanStep.selectImage:
        return _buildSelectStep();
      case _SaleScanStep.scanning:
        return _buildScanningStep();
      case _SaleScanStep.review:
        return _buildReviewStep();
      case _SaleScanStep.saving:
        return _buildSavingStep();
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  STEP 1: Seleccionar archivos
  // ──────────────────────────────────────────────────────────────
  Widget _buildSelectStep() {
    final theme = Theme.of(context);
    final showCamera = !kIsWeb;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_globalError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF9A9A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFD32F2F)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _globalError!,
                        style: const TextStyle(color: Color(0xFFD32F2F)),
                      ),
                    ),
                  ],
                ),
              ),

            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF2E7D32), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Este escáner es exclusivo para facturas de VENTA.\n'
                      'Solo guarda en el módulo IVA. No modifica inventario, caja ni proveedores.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF1B5E20)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Opciones: galería/archivos y cámara
            if (showCamera) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildSelectorCard(
                      icon: Icons.photo_library,
                      label: 'Galería / Archivos',
                      subtitle: 'PDF, JPG, PNG · Múltiples',
                      color: theme.colorScheme.primary,
                      onTap: _pickFiles,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSelectorCard(
                      icon: Icons.camera_alt,
                      label: 'Tomar Foto',
                      subtitle: 'Cámara · Varias páginas',
                      color: const Color(0xFFE65100),
                      onTap: _takePhoto,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Drop zone (escritorio / web)
              GestureDetector(
                onTap: _pickFiles,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 52,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Seleccionar facturas de venta',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Soporta PDF, JPG, PNG · Múltiples archivos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_items.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_items.length} archivo(s) seleccionado(s)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (showCamera)
                    TextButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.add_a_photo, size: 16),
                      label: const Text(
                        'Otra foto',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_items.length, (idx) {
                final item = _items[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 18,
                        color: Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.file.name,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFF9E9E9E),
                        ),
                        onPressed: () => setState(() => _items.removeAt(idx)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() {
        _globalError = null;
        for (int i = 0; i < result.files.length; i++) {
          _items.add(
            _SaleBatchItem(index: _items.length, file: result.files[i]),
          );
        }
      });
    } catch (e) {
      setState(() => _globalError = 'Error al seleccionar archivos: $e');
    }
  }

  // ─── Selector Card (para galería / cámara) ─────────────────────
  Widget _buildSelectorCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: color.withOpacity(0.7)),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tomar Foto con Cámara ─────────────────────────────────────
  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2000,
        maxHeight: 2000,
      );
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      final fileName = 'foto_${ColombiaTime.now().millisecondsSinceEpoch}.jpg';

      final platformFile = PlatformFile(
        name: fileName,
        size: bytes.length,
        bytes: Uint8List.fromList(bytes),
      );

      setState(() {
        _globalError = null;
        _items.add(_SaleBatchItem(index: _items.length, file: platformFile));
      });
    } catch (e) {
      setState(() => _globalError = 'Error al tomar foto: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  STEP 2: Scanning
  // ──────────────────────────────────────────────────────────────
  Widget _buildScanningStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final item = _items[i];
                return ListTile(
                  leading: _statusIcon(item.status),
                  title: Text(item.file.name, overflow: TextOverflow.ellipsis),
                  subtitle: item.scanError != null
                      ? Text(
                          item.scanError!,
                          style: const TextStyle(color: Color(0xFFD32F2F)),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(_SaleBatchStatus s) {
    switch (s) {
      case _SaleBatchStatus.pending:
        return const Icon(Icons.hourglass_empty, color: Color(0xFF9E9E9E));
      case _SaleBatchStatus.scanning:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _SaleBatchStatus.done:
        return const Icon(Icons.check_circle, color: Color(0xFF388E3C));
      case _SaleBatchStatus.error:
        return const Icon(Icons.error, color: Color(0xFFD32F2F));
    }
  }

  Future<void> _startScanning() async {
    setState(() => _step = _SaleScanStep.scanning);
    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      setState(() => item.status = _SaleBatchStatus.scanning);
      // Esperar un poco entre llamadas para no saturar
      if (i > 0) await Future.delayed(const Duration(milliseconds: 1200));
      await _scanSingle(item);
    }
    setState(() => _step = _SaleScanStep.review);
  }

  Future<void> _scanSingle(_SaleBatchItem item) async {
    try {
      final svcResult = await InvoiceScannerService.scanFromFile(item.file);
      if (!svcResult.success || svcResult.data == null) {
        setState(() {
          item.status = _SaleBatchStatus.error;
          item.scanError = svcResult.error ?? 'Error al escanear';
        });
        return;
      }
      setState(() => item.populateFromResult(svcResult.data!, _dateFormat));
    } catch (e) {
      setState(() {
        item.status = _SaleBatchStatus.error;
        item.scanError = e.toString();
      });
    }
  }

  // ──────────────────────────────────────────────────────────────
  //  STEP 3: Review
  // ──────────────────────────────────────────────────────────────
  Widget _buildReviewStep() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (ctx, i) => _buildReviewCard(_items[i]),
    );
  }

  Widget _buildReviewCard(_SaleBatchItem item) {
    final theme = Theme.of(context);
    final isDone = item.status == _SaleBatchStatus.done;
    final isError = item.status == _SaleBatchStatus.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: item.saved
              ? const Color(0xFF388E3C)
              : item.saveError != null
              ? const Color(0xFFD32F2F)
              : isError
              ? const Color(0xFFEF9A9A)
              : const Color(0xFFE0E0E0),
          width: item.saved || item.saveError != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: isDone
                ? () => setState(() => item.isExpanded = !item.isExpanded)
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Checkbox(
                    value: item.selected,
                    onChanged: isDone
                        ? (v) => setState(() => item.selected = v ?? true)
                        : null,
                  ),
                  _statusIcon(item.status),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.file.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isDone)
                          Text(
                            '${item.invoiceNumberCtrl.text.isNotEmpty ? item.invoiceNumberCtrl.text : "SIN-NUM"} · ${item.clientNameCtrl.text}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF757575),
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        else if (isError)
                          Text(
                            item.scanError ?? 'Error al escanear',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Releer button for errors
                  if (isError)
                    GestureDetector(
                      onTap: () => _rescanItem(item),
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF1976D2).withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 14,
                              color: Color(0xFF1976D2),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Releer',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isDone) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Helpers.formatCurrency(
                            double.tryParse(item.totalCtrl.text) ?? 0,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          'IVA: ${Helpers.formatCurrency(double.tryParse(item.taxAmountCtrl.text) ?? 0)}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      item.isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ],
                  if (item.saved)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '✓ Guardada',
                        style: TextStyle(
                          color: Color(0xFF388E3C),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (item.saveError != null)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '✗ Error',
                        style: TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Expandable form
          if (isDone && item.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormSection(
                    icon: Icons.person_outline,
                    title: 'Cliente (comprador)',
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _field(
                            'Nombre del cliente',
                            item.clientNameCtrl,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _field('NIT / Cédula', item.clientNitCtrl),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFormSection(
                    icon: Icons.receipt_long_outlined,
                    title: 'Datos de la factura',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 180,
                          child: _field('N° Factura', item.invoiceNumberCtrl),
                        ),
                        SizedBox(
                          width: 140,
                          child: _fieldDate(
                            'Fecha',
                            item.invoiceDateCtrl,
                            item,
                          ),
                        ),
                        SizedBox(
                          width: 280,
                          child: _field('CUFE', item.cufeCtrl),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFormSection(
                    icon: Icons.calculate_outlined,
                    title: 'Totales',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 140,
                          child: _fieldNum('Subtotal', item.subtotalCtrl),
                        ),
                        SizedBox(
                          width: 100,
                          child: _fieldNum('IVA %', item.taxRateCtrl),
                        ),
                        SizedBox(
                          width: 140,
                          child: _fieldNum('IVA \$', item.taxAmountCtrl),
                        ),
                        SizedBox(
                          width: 140,
                          child: _fieldNum('RteFte', item.reteFteCtrl),
                        ),
                        SizedBox(
                          width: 140,
                          child: _fieldNum('ReteICA', item.reteIcaCtrl),
                        ),
                        SizedBox(
                          width: 140,
                          child: _fieldNum('ReteIVA', item.reteIvaCtrl),
                        ),
                        SizedBox(
                          width: 140,
                          child: _fieldNum('TOTAL', item.totalCtrl, bold: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field('Notas (opcional)', item.notesCtrl),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF757575)),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF424242),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _fieldNum(
    String label,
    TextEditingController ctrl, {
    bool bold = false,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  Widget _fieldDate(
    String label,
    TextEditingController ctrl,
    _SaleBatchItem item,
  ) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        suffixIcon: const Icon(Icons.calendar_today, size: 16),
      ),
      style: const TextStyle(fontSize: 13),
      onTap: () async {
        DateTime initial = ColombiaTime.now();
        if (ctrl.text.isNotEmpty) {
          try {
            initial = _dateFormat.parse(ctrl.text);
          } catch (_) {}
        }
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null && mounted) {
          setState(() => ctrl.text = _dateFormat.format(picked));
        }
      },
    );
  }

  Future<void> _rescanItem(_SaleBatchItem item) async {
    setState(() {
      item.status = _SaleBatchStatus.scanning;
      item.scanError = null;
      item.result = null;
    });
    await _scanSingle(item);
  }

  // ──────────────────────────────────────────────────────────────
  //  STEP 4: Saving
  // ──────────────────────────────────────────────────────────────
  Widget _buildSavingStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _selectedCount > 0 ? _savingIndex / _selectedCount : null,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final item = _items[i];
                if (!item.selected || item.status != _SaleBatchStatus.done) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: item.saved
                      ? const Icon(Icons.check_circle, color: Color(0xFF388E3C))
                      : item.saveError != null
                      ? const Icon(Icons.error, color: Color(0xFFD32F2F))
                      : const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                  title: Text(item.file.name, overflow: TextOverflow.ellipsis),
                  subtitle: item.saveError != null
                      ? Text(
                          item.saveError!,
                          style: const TextStyle(color: Color(0xFFD32F2F)),
                        )
                      : item.saved
                      ? Text(
                          'Registrada en IVA · ${item.invoiceNumberCtrl.text}',
                          style: const TextStyle(color: Color(0xFF388E3C)),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  //  SAVE LOGIC — Solo guarda en iva_invoices (VENTA)
  // ──────────────────────────────────────────────────────────────
  Future<void> _saveAll() async {
    final toSave = _items
        .where((i) => i.selected && i.status == _SaleBatchStatus.done)
        .toList();
    if (toSave.isEmpty) return;

    setState(() {
      _step = _SaleScanStep.saving;
      _savingIndex = 0;
    });

    String? lastPeriod;

    for (int i = 0; i < toSave.length; i++) {
      final item = toSave[i];
      setState(() => _savingIndex = i);
      try {
        lastPeriod = await _saveOneIvaVenta(item);
        setState(() => item.saved = true);
      } catch (e) {
        setState(() => item.saveError = e.toString());
      }
    }

    setState(() => _savingIndex = toSave.length);
    if (!mounted) return;

    final savedCount = toSave.where((i) => i.saved).length;
    final errorCount = toSave.where((i) => i.saveError != null).length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedCount > 0
              ? '✅ $savedCount factura(s) de venta registrada(s) en IVA'
                    '${errorCount > 0 ? ' · ⚠ $errorCount con error' : ''}'
              : '❌ No se pudo registrar ninguna factura',
        ),
        backgroundColor: savedCount > 0
            ? const Color(0xFF388E3C)
            : const Color(0xFFD32F2F),
        duration: const Duration(seconds: 5),
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop(lastPeriod);
  }

  /// Guarda UNA factura de venta en iva_invoices. Nada más.
  Future<String> _saveOneIvaVenta(_SaleBatchItem item) async {
    final invoiceNumber = item.invoiceNumberCtrl.text.trim().isNotEmpty
        ? item.invoiceNumberCtrl.text.trim()
        : 'SIN-NUM';

    DateTime invoiceDate = ColombiaTime.now();
    if (item.invoiceDateCtrl.text.isNotEmpty) {
      try {
        invoiceDate = _dateFormat.parse(item.invoiceDateCtrl.text);
      } catch (_) {}
    }

    final subtotal = double.tryParse(item.subtotalCtrl.text) ?? 0;
    final taxAmount = double.tryParse(item.taxAmountCtrl.text) ?? 0;
    final total = double.tryParse(item.totalCtrl.text) ?? 0;
    final reteFte = double.tryParse(item.reteFteCtrl.text) ?? 0;
    final reteIca = double.tryParse(item.reteIcaCtrl.text) ?? 0;
    final reteIva = double.tryParse(item.reteIvaCtrl.text) ?? 0;

    final clientName = item.clientNameCtrl.text.trim().isNotEmpty
        ? item.clientNameCtrl.text.trim()
        : 'Cliente';
    final clientNit = item.clientNitCtrl.text.trim();

    final period = getBimonthlyPeriod(invoiceDate);

    final itemsDetail =
        item.result?.items
            .map(
              (it) =>
                  '${it.description} x${it.quantity} = \$${it.total.toStringAsFixed(0)}',
            )
            .join(' | ') ??
        '';

    await IvaDataSource.createInvoice(
      IvaInvoice(
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        company: clientName,
        invoiceType: 'VENTA',
        baseAmount: subtotal,
        ivaAmount: taxAmount,
        totalAmount: total,
        hasReteiva: reteIva > 0,
        reteivaAmount: reteIva,
        bimonthlyPeriod: period,
        notes: item.notesCtrl.text.isNotEmpty
            ? '${item.notesCtrl.text}\n$itemsDetail'
            : itemsDetail.isNotEmpty
            ? itemsDetail
            : null,
        companyDocument: clientNit.isNotEmpty ? clientNit : null,
        cufe: item.cufeCtrl.text.trim().isNotEmpty
            ? item.cufeCtrl.text.trim()
            : null,
        rteFteAmount: reteFte,
        reteIcaAmount: reteIca,
      ),
    );

    return period;
  }

  // ──────────────────────────────────────────────────────────────
  //  ACTIONS BAR
  // ──────────────────────────────────────────────────────────────
  Widget _buildActions() {
    switch (_step) {
      case _SaleScanStep.selectImage:
        return _actionsBar(
          left: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          right: FilledButton.icon(
            onPressed: _items.isEmpty ? null : _startScanning,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              _items.isEmpty
                  ? 'Selecciona archivos'
                  : 'Analizar ${_items.length} factura(s)',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
          ),
        );

      case _SaleScanStep.scanning:
        return _actionsBar(
          left: const SizedBox.shrink(),
          right: const Text(
            'Procesando...',
            style: TextStyle(color: Color(0xFF9E9E9E)),
          ),
        );

      case _SaleScanStep.review:
        return _actionsBar(
          left: TextButton(
            onPressed: () => setState(() => _step = _SaleScanStep.selectImage),
            child: const Text('← Volver'),
          ),
          right: FilledButton.icon(
            onPressed: _selectedCount == 0 ? null : _saveAll,
            icon: const Icon(Icons.save, size: 18),
            label: Text(
              _selectedCount == 0
                  ? 'Nada seleccionado'
                  : 'Guardar $_selectedCount en IVA',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
            ),
          ),
        );

      case _SaleScanStep.saving:
        return _actionsBar(
          left: const SizedBox.shrink(),
          right: const Text(
            'Guardando...',
            style: TextStyle(color: Color(0xFF9E9E9E)),
          ),
        );
    }
  }

  Widget _actionsBar({required Widget left, required Widget right}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [left, right],
      ),
    );
  }
}
