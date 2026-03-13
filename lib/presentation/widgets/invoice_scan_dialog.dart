import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../core/utils/helpers.dart';
import '../../data/datasources/invoice_scanner_service.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/datasources/iva_datasource.dart';
import '../../data/datasources/suppliers_datasource.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../data/datasources/invoices_datasource.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/providers/suppliers_provider.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/cash_movement.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/material.dart' as mat;

class _ItemInventoryMatch {
  final ScannedInvoiceItem item;
  final mat.Material? aiRecommendation;
  mat.Material? matchedMaterial;
  bool createNew;
  bool selected;
  _ItemInventoryMatch({
    required this.item,
    this.aiRecommendation,
    this.matchedMaterial,
    this.createNew = false,
    required this.selected,
  });
  bool get isNew => createNew || matchedMaterial == null;
}

enum _BatchScanStatus { pending, scanning, done, error }

class _BatchInvoiceItem {
  final int index;
  final PlatformFile file;
  _BatchScanStatus status;
  InvoiceScanResult? result;
  String? scanError;
  bool isExpanded;
  bool selected;
  final TextEditingController invoiceNumberCtrl;
  final TextEditingController invoiceDateCtrl;
  final TextEditingController dueDateCtrl;
  final TextEditingController creditDaysCtrl;
  final TextEditingController cufeCtrl;
  final TextEditingController subtotalCtrl;
  final TextEditingController taxAmountCtrl;
  final TextEditingController taxRateCtrl;
  final TextEditingController reteFteCtrl;
  final TextEditingController reteIcaCtrl;
  final TextEditingController reteIvaCtrl;
  final TextEditingController freightCtrl;
  final TextEditingController totalCtrl;
  final TextEditingController notesCtrl;
  String? selectedSupplierId;
  bool createNewSupplier;
  final TextEditingController supplierNameCtrl;
  final TextEditingController supplierNitCtrl;
  final TextEditingController supplierAddressCtrl;
  final TextEditingController supplierPhoneCtrl;
  final TextEditingController supplierEmailCtrl;
  bool createIvaRecord;
  bool createExpenseRecord;
  String? selectedAccountId;
  bool saved;
  String? saveError;

  _BatchInvoiceItem({required this.index, required this.file})
    : status = _BatchScanStatus.pending,
      result = null,
      scanError = null,
      isExpanded = false,
      selected = true,
      invoiceNumberCtrl = TextEditingController(),
      invoiceDateCtrl = TextEditingController(),
      dueDateCtrl = TextEditingController(),
      creditDaysCtrl = TextEditingController(text: '0'),
      cufeCtrl = TextEditingController(),
      subtotalCtrl = TextEditingController(text: '0.00'),
      taxAmountCtrl = TextEditingController(text: '0.00'),
      taxRateCtrl = TextEditingController(text: '19.00'),
      reteFteCtrl = TextEditingController(text: '0.00'),
      reteIcaCtrl = TextEditingController(text: '0.00'),
      reteIvaCtrl = TextEditingController(text: '0.00'),
      freightCtrl = TextEditingController(text: '0.00'),
      totalCtrl = TextEditingController(text: '0.00'),
      notesCtrl = TextEditingController(),
      selectedSupplierId = null,
      createNewSupplier = false,
      supplierNameCtrl = TextEditingController(),
      supplierNitCtrl = TextEditingController(),
      supplierAddressCtrl = TextEditingController(),
      supplierPhoneCtrl = TextEditingController(),
      supplierEmailCtrl = TextEditingController(),
      createIvaRecord = true,
      createExpenseRecord = true,
      selectedAccountId = null,
      saved = false,
      saveError = null;

  void populateFromResult(InvoiceScanResult r, DateFormat dateFormat) {
    result = r;
    status = _BatchScanStatus.done;
    invoiceNumberCtrl.text = r.invoiceNumber ?? '';
    invoiceDateCtrl.text = r.invoiceDate != null
        ? dateFormat.format(r.invoiceDate!)
        : '';
    dueDateCtrl.text = r.dueDate != null ? dateFormat.format(r.dueDate!) : '';
    creditDaysCtrl.text = r.creditDays.toString();
    cufeCtrl.text = r.cufe ?? '';
    subtotalCtrl.text = r.subtotal.toStringAsFixed(2);
    taxRateCtrl.text = r.taxRate.toStringAsFixed(2);
    taxAmountCtrl.text = r.taxAmount.toStringAsFixed(2);
    reteFteCtrl.text = r.retentionRteFte.toStringAsFixed(2);
    reteIcaCtrl.text = r.retentionIca.toStringAsFixed(2);
    reteIvaCtrl.text = r.retentionIva.toStringAsFixed(2);
    freightCtrl.text = r.freight.toStringAsFixed(2);
    totalCtrl.text = r.total.toStringAsFixed(2);
    notesCtrl.text = r.notes ?? '';
    supplierNameCtrl.text = r.supplier.name ?? '';
    supplierNitCtrl.text = r.supplier.documentNumber ?? '';
    supplierAddressCtrl.text = [
      r.supplier.address,
      r.supplier.city,
    ].where((s) => s != null && s.isNotEmpty).join(', ');
    supplierPhoneCtrl.text = r.supplier.phone ?? '';
    supplierEmailCtrl.text = r.supplier.email ?? '';
    if (r.creditDays > 0) createExpenseRecord = false;
  }

  void dispose() {
    for (final c in [
      invoiceNumberCtrl,
      invoiceDateCtrl,
      dueDateCtrl,
      creditDaysCtrl,
      cufeCtrl,
      subtotalCtrl,
      taxAmountCtrl,
      taxRateCtrl,
      reteFteCtrl,
      reteIcaCtrl,
      reteIvaCtrl,
      freightCtrl,
      totalCtrl,
      notesCtrl,
      supplierNameCtrl,
      supplierNitCtrl,
      supplierAddressCtrl,
      supplierPhoneCtrl,
      supplierEmailCtrl,
    ]) {
      c.dispose();
    }
  }
}

class InvoiceScanDialog extends ConsumerStatefulWidget {
  const InvoiceScanDialog({super.key});
  @override
  ConsumerState<InvoiceScanDialog> createState() => _InvoiceScanDialogState();
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const InvoiceScanDialog(),
    );
  }
}

enum _ScanStep { selectImage, scanning, review, saving }

class _InvoiceScanDialogState extends ConsumerState<InvoiceScanDialog> {
  _ScanStep _step = _ScanStep.selectImage;
  final List<_BatchInvoiceItem> _batchItems = [];
  int _savingCurrentIndex = 0;
  String? _globalError;
  List<Account> _allAccounts = [];
  bool _accountsLoaded = false;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    for (final item in _batchItems) {
      item.dispose();
    }
    super.dispose();
  }

  int get _doneCount =>
      _batchItems.where((i) => i.status == _BatchScanStatus.done).length;
  int get _selectedForSave => _batchItems
      .where((i) => i.selected && i.status == _BatchScanStatus.done)
      .length;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 1200 ? 960.0 : screenWidth * 0.9;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
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

  Widget _buildHeader() {
    final theme = Theme.of(context);
    const titles = {
      _ScanStep.selectImage: 'Escanear Facturas con IA',
      _ScanStep.scanning: 'Analizando facturas...',
      _ScanStep.review: 'Revisar Datos Extraídos',
      _ScanStep.saving: 'Registrando facturas...',
    };
    const icons = {
      _ScanStep.selectImage: Icons.document_scanner_outlined,
      _ScanStep.scanning: Icons.auto_awesome,
      _ScanStep.review: Icons.fact_check_outlined,
      _ScanStep.saving: Icons.save,
    };
    String? subtitle;
    if (_step == _ScanStep.scanning) {
      subtitle = '$_doneCount / ${_batchItems.length} procesadas';
    } else if (_step == _ScanStep.review) {
      final total = _batchItems.fold<double>(
        0,
        (s, i) => s + (double.tryParse(i.totalCtrl.text) ?? 0),
      );
      subtitle =
          '${_batchItems.length} factura(s) · Total: ${Helpers.formatCurrency(total)}';
    } else if (_step == _ScanStep.saving) {
      final toSave = _batchItems.where((i) => i.selected).length;
      subtitle = '$_savingCurrentIndex / $toSave guardadas';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
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
              ],
            ),
          ),
          _buildStepIndicator(),
          const SizedBox(width: 8),
          if (_step != _ScanStep.saving && _step != _ScanStep.scanning)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
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

  Widget _buildContent() {
    switch (_step) {
      case _ScanStep.selectImage:
        return _buildSelectImageStep();
      case _ScanStep.scanning:
        return _buildScanningStep();
      case _ScanStep.review:
        return _buildReviewStep();
      case _ScanStep.saving:
        return _buildSavingStep();
    }
  }

  // ─── Step 1: Seleccionar archivos ───────────────────────────────
  Widget _buildSelectImageStep() {
    final theme = Theme.of(context);
    final hasFiles = _batchItems.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_globalError != null) ...[
              Container(
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
              const SizedBox(height: 16),
            ],
            InkWell(
              onTap: _pickImages,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: hasFiles
                        ? theme.colorScheme.primary
                        : const Color(0xFFE0E0E0),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  color: hasFiles
                      ? theme.colorScheme.primaryContainer.withOpacity(0.25)
                      : const Color(0xFFFAFAFA),
                ),
                child: Column(
                  children: [
                    Icon(
                      hasFiles
                          ? Icons.add_photo_alternate
                          : Icons.cloud_upload_outlined,
                      size: 56,
                      color: hasFiles
                          ? theme.colorScheme.primary
                          : const Color(0xFFBDBDBD),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasFiles
                          ? 'Agregar más facturas'
                          : 'Seleccionar facturas',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hasFiles
                            ? theme.colorScheme.primary
                            : const Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'JPG, PNG o PDF · Máx. 10 MB · Puede seleccionar varias a la vez',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFBDBDBD),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasFiles) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.list, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '${_batchItems.length} factura(s) seleccionada(s)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _batchItems.clear()),
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Limpiar todo'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_batchItems.length, (i) {
                final item = _batchItems[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _fileIcon(item.file.extension),
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.file.name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${(item.file.size / 1024).toStringAsFixed(0)} KB',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF9E9E9E),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _batchItems.removeAt(i)),
                        icon: const Icon(Icons.close, size: 16),
                        color: const Color(0xFF9E9E9E),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF1976D2),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reconocimiento con OpenAI Vision (GPT-4.1 mini)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Extrae: proveedor, NIT, ítems con precios, IVA, retenciones (RteFte, ICA, ReteIVA), CUFE y totales. '
                          'Procesa múltiples facturas de forma secuencial. Costo aprox: \$0.001-0.003 por factura.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF1976D2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _fileIcon(String? ext) {
    return (ext?.toLowerCase() == 'pdf') ? Icons.picture_as_pdf : Icons.image;
  }

  // ─── Step 2: Escaneo por lotes ──────────────────────────────────
  Widget _buildScanningStep() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: _batchItems.isEmpty ? 0 : _doneCount / _batchItems.length,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_doneCount de ${_batchItems.length} facturas procesadas',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              itemCount: _batchItems.length,
              itemBuilder: (ctx, index) {
                final item = _batchItems[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _scanStatusBg(item.status),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _scanStatusBorder(item.status)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: _buildScanStatusIcon(item.status),
                      ),
                      const SizedBox(width: 12),
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
                            if (item.status == _BatchScanStatus.done &&
                                item.result != null)
                              Text(
                                '✓ ${item.result!.supplier.name ?? 'Proveedor'} · ${item.result!.items.length} ítem(s) · ${Helpers.formatCurrency(item.result!.total)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF388E3C),
                                ),
                              )
                            else if (item.status == _BatchScanStatus.error)
                              Text(
                                item.scanError ?? 'Error desconocido',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD32F2F),
                                ),
                                overflow: TextOverflow.ellipsis,
                              )
                            else if (item.status == _BatchScanStatus.scanning)
                              const Text(
                                'Analizando con OpenAI Vision...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1976D2),
                                ),
                              )
                            else
                              const Text(
                                'En cola...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (item.status == _BatchScanStatus.done &&
                          item.result != null)
                        Text(
                          '~\$${item.result!.estimatedCost ?? '?'}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      if (item.status == _BatchScanStatus.error)
                        GestureDetector(
                          onTap: () => _rescanItem(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  size: 13,
                                  color: Color(0xFF1976D2),
                                ),
                                SizedBox(width: 3),
                                Text(
                                  'Releer',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1976D2),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _scanStatusBg(_BatchScanStatus s) => switch (s) {
    _BatchScanStatus.pending => const Color(0xFFFAFAFA),
    _BatchScanStatus.scanning => const Color(0xFFE3F2FD),
    _BatchScanStatus.done => const Color(0xFFE8F5E9),
    _BatchScanStatus.error => const Color(0xFFFFEBEE),
  };
  Color _scanStatusBorder(_BatchScanStatus s) => switch (s) {
    _BatchScanStatus.pending => const Color(0xFFE0E0E0),
    _BatchScanStatus.scanning => const Color(0xFF90CAF9),
    _BatchScanStatus.done => const Color(0xFFA5D6A7),
    _BatchScanStatus.error => const Color(0xFFEF9A9A),
  };
  Widget _buildScanStatusIcon(_BatchScanStatus s) => switch (s) {
    _BatchScanStatus.pending => const Icon(
      Icons.schedule,
      size: 20,
      color: Color(0xFFBDBDBD),
    ),
    _BatchScanStatus.scanning => const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Color(0xFF1976D2),
      ),
    ),
    _BatchScanStatus.done => const Icon(
      Icons.check_circle,
      size: 20,
      color: Color(0xFF388E3C),
    ),
    _BatchScanStatus.error => const Icon(
      Icons.error,
      size: 20,
      color: Color(0xFFD32F2F),
    ),
  };

  // ─── Step 3: Revisión en lote ────────────────────────────────────
  Widget _buildReviewStep() {
    final theme = Theme.of(context);
    final suppliers = ref.watch(suppliersProvider).suppliers;
    final successItems = _batchItems
        .where((i) => i.status == _BatchScanStatus.done)
        .toList();
    final errorItems = _batchItems
        .where((i) => i.status == _BatchScanStatus.error)
        .toList();
    final selectedTotal = _batchItems
        .where((i) => i.selected && i.status == _BatchScanStatus.done)
        .fold<double>(
          0,
          (s, i) => s + (double.tryParse(i.totalCtrl.text) ?? 0),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: const Color(0xFFF5F5F5),
          child: Row(
            children: [
              _summaryChip(
                Icons.check_circle,
                '${successItems.length} OK',
                const Color(0xFF388E3C),
              ),
              if (errorItems.isNotEmpty) ...[
                const SizedBox(width: 8),
                _summaryChip(
                  Icons.error,
                  '${errorItems.length} con error',
                  const Color(0xFFD32F2F),
                ),
              ],
              const Spacer(),
              Text(
                'Total: ${Helpers.formatCurrency(selectedTotal)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _batchItems.length,
            itemBuilder: (ctx, index) =>
                _buildBatchItemCard(_batchItems[index], suppliers),
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchItemCard(_BatchInvoiceItem item, List<Supplier> suppliers) {
    final theme = Theme.of(context);
    final isError = item.status == _BatchScanStatus.error;
    final isDone = item.status == _BatchScanStatus.done;
    final supplierDisplay = item.createNewSupplier
        ? (item.supplierNameCtrl.text.isNotEmpty
              ? item.supplierNameCtrl.text
              : 'Nuevo proveedor')
        : (item.selectedSupplierId != null && suppliers.isNotEmpty
              ? suppliers
                    .firstWhere(
                      (s) => s.id == item.selectedSupplierId,
                      orElse: () => suppliers.first,
                    )
                    .name
              : (item.result?.supplier.name ?? 'Sin proveedor'));
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.saved
              ? const Color(0xFFA5D6A7)
              : isError
              ? const Color(0xFFEF9A9A)
              : item.selected
              ? theme.colorScheme.primary.withOpacity(0.4)
              : const Color(0xFFE0E0E0),
          width: item.selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: isDone
                ? () => setState(() => item.isExpanded = !item.isExpanded)
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(item.isExpanded ? 0 : 12),
              bottomRight: Radius.circular(item.isExpanded ? 0 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (isDone)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: item.selected,
                        onChanged: item.saved
                            ? null
                            : (v) => setState(() => item.selected = v ?? false),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else
                    Icon(
                      isError ? Icons.error : Icons.schedule,
                      size: 20,
                      color: isError
                          ? const Color(0xFFD32F2F)
                          : const Color(0xFFBDBDBD),
                    ),
                  const SizedBox(width: 10),
                  Icon(
                    _fileIcon(item.file.extension),
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDone && item.invoiceNumberCtrl.text.isNotEmpty
                              ? 'Factura ${item.invoiceNumberCtrl.text}'
                              : item.file.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isDone)
                          Text(
                            '$supplierDisplay · ${item.invoiceDateCtrl.text}',
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
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
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
          if (isDone && item.isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildItemSupplierSection(item, suppliers),
                  const SizedBox(height: 12),
                  _buildItemInvoiceDataSection(item),
                  const SizedBox(height: 12),
                  _buildItemsListSection(item),
                  const SizedBox(height: 12),
                  _buildItemTotalsSection(item),
                  const SizedBox(height: 12),
                  _buildItemOptionsSection(item),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemSupplierSection(
    _BatchInvoiceItem item,
    List<Supplier> suppliers,
  ) {
    final theme = Theme.of(context);
    return _buildSection(
      theme,
      icon: Icons.business,
      title: 'Proveedor',
      subtitle: item.result?.supplier.name != null
          ? 'Detectado: ${item.result!.supplier.name} · ${item.result!.supplier.documentType ?? 'NIT'} ${item.result!.supplier.documentNumber ?? ''}'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSupplierOption(
                  theme,
                  icon: Icons.link,
                  label: 'Vincular existente',
                  selected: !item.createNewSupplier,
                  onTap: () => setState(() => item.createNewSupplier = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSupplierOption(
                  theme,
                  icon: Icons.person_add,
                  label: 'Crear nuevo',
                  selected: item.createNewSupplier,
                  onTap: () => setState(() {
                    item.createNewSupplier = true;
                    item.selectedSupplierId = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!item.createNewSupplier)
            DropdownButtonFormField<String>(
              value: item.selectedSupplierId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Seleccionar proveedor',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('-- Seleccionar --'),
                ),
                ...suppliers.map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.name} · ${s.documentNumber}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => item.selectedSupplierId = v),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: item.supplierNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Razón social',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: item.supplierNitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'NIT / Documento',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: item.supplierAddressCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.supplierPhoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: item.supplierEmailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '💡 Datos pre-llenados desde la factura',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF1976D2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemInvoiceDataSection(_BatchInvoiceItem item) {
    final theme = Theme.of(context);
    return _buildSection(
      theme,
      icon: Icons.receipt_long,
      title: 'Datos de Factura',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.invoiceNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nº Factura',
                    prefixIcon: Icon(Icons.tag),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: item.invoiceDateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  readOnly: true,
                  onTap: () => _pickDateForCtrl(item.invoiceDateCtrl),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: item.dueDateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vencimiento',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  readOnly: true,
                  onTap: () => _pickDateForCtrl(item.dueDateCtrl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: item.cufeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'CUFE',
                    prefixIcon: Icon(Icons.qr_code),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: item.creditDaysCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Días crédito',
                    prefixIcon: Icon(Icons.schedule),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsListSection(_BatchInvoiceItem item) {
    final theme = Theme.of(context);
    final items = item.result?.items ?? [];
    if (items.isEmpty) return const SizedBox.shrink();
    return _buildSection(
      theme,
      icon: Icons.list_alt,
      title: 'Ítems Detectados (${items.length})',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 68,
                  child: Text(
                    'Código',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Descripción',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    'Cant',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 74,
                  child: Text(
                    'Precio',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    'IVA%',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(
                  width: 78,
                  child: Text(
                    'Subtotal',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          ...items.map(
            (inv) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 68,
                    child: Text(
                      inv.referenceCode ?? '-',
                      style: const TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      inv.description,
                      style: const TextStyle(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${inv.quantity}',
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 74,
                    child: Text(
                      Helpers.formatNumber(inv.unitPrice),
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${inv.taxRate.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 78,
                    child: Text(
                      Helpers.formatNumber(inv.subtotal),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTotalsSection(_BatchInvoiceItem item) {
    final theme = Theme.of(context);
    return _buildSection(
      theme,
      icon: Icons.calculate,
      title: 'Totales y Retenciones',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                _buildAmountField('Subtotal', item.subtotalCtrl),
                const SizedBox(height: 8),
                _buildAmountField('IVA (%)', item.taxRateCtrl, suffix: '%'),
                const SizedBox(height: 8),
                _buildAmountField('Monto IVA', item.taxAmountCtrl),
                const SizedBox(height: 8),
                _buildAmountField('Fletes', item.freightCtrl),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                _buildAmountField('Ret. Fuente', item.reteFteCtrl),
                const SizedBox(height: 8),
                _buildAmountField('Ret. ICA', item.reteIcaCtrl),
                const SizedBox(height: 8),
                _buildAmountField('Ret. IVA', item.reteIvaCtrl),
                const SizedBox(height: 8),
                _buildAmountField('TOTAL', item.totalCtrl, isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemOptionsSection(_BatchInvoiceItem item) {
    final theme = Theme.of(context);
    return _buildSection(
      theme,
      icon: Icons.settings,
      title: 'Opciones de Registro',
      child: Column(
        children: [
          TextFormField(
            controller: item.notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notas / Observaciones',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Registrar en IVA bimestral'),
            subtitle: Text(
              'Vincula esta factura al control de IVA bimestral',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF757575),
              ),
            ),
            value: item.createIvaRecord,
            onChanged: (v) => setState(() => item.createIvaRecord = v),
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Registrar gasto en caja'),
            subtitle: Text(
              item.createExpenseRecord
                  ? '💰 Crea movimiento de egreso y asiento contable'
                  : '⏳ Solo registra IVA y deuda — sin salida de caja',
              style: theme.textTheme.bodySmall?.copyWith(
                color: item.createExpenseRecord
                    ? const Color(0xFF388E3C)
                    : const Color(0xFFF57C00),
              ),
            ),
            value: item.createExpenseRecord,
            onChanged: (v) => setState(() => item.createExpenseRecord = v),
          ),
          if (item.createExpenseRecord && _allAccounts.isNotEmpty) ...[
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: item.selectedAccountId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Cuenta de pago',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.account_balance_wallet, size: 18),
              ),
              items: _allAccounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(
                        '${a.name} (\$${Formatters.currency(a.balance)})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => item.selectedAccountId = v),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Step 4: Guardando ────────────────────────────────────────────
  Widget _buildSavingStep() {
    final theme = Theme.of(context);
    final toSave = _batchItems.where((i) => i.selected).toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: toSave.isEmpty ? 0 : _savingCurrentIndex / toSave.length,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF388E3C)),
          ),
          const SizedBox(height: 6),
          Text(
            '$_savingCurrentIndex de ${toSave.length} facturas registradas',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              itemCount: toSave.length,
              itemBuilder: (ctx, index) {
                final item = toSave[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: item.saved
                        ? const Color(0xFFE8F5E9)
                        : item.saveError != null
                        ? const Color(0xFFFFEBEE)
                        : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.saved
                          ? const Color(0xFFA5D6A7)
                          : item.saveError != null
                          ? const Color(0xFFEF9A9A)
                          : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: item.saved
                            ? const Icon(
                                Icons.check_circle,
                                color: Color(0xFF388E3C),
                                size: 22,
                              )
                            : item.saveError != null
                            ? const Icon(
                                Icons.error,
                                color: Color(0xFFD32F2F),
                                size: 22,
                              )
                            : index < _savingCurrentIndex
                            ? const Icon(
                                Icons.schedule,
                                size: 20,
                                color: Color(0xFFBDBDBD),
                              )
                            : const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.invoiceNumberCtrl.text.isNotEmpty
                                  ? 'Factura ${item.invoiceNumberCtrl.text}'
                                  : item.file.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (item.saveError != null)
                              Text(
                                item.saveError!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD32F2F),
                                ),
                              )
                            else if (item.saved)
                              const Text(
                                'Registrada correctamente',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF388E3C),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions Bar ─────────────────────────────────────────────────
  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_step != _ScanStep.scanning && _step != _ScanStep.saving)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          const SizedBox(width: 12),
          if (_step == _ScanStep.selectImage)
            FilledButton.icon(
              onPressed: _batchItems.isNotEmpty ? _startBatchScan : null,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                _batchItems.length == 1
                    ? 'Escanear con IA'
                    : 'Escanear ${_batchItems.length} facturas',
              ),
            ),
          if (_step == _ScanStep.review) ...[
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _step = _ScanStep.selectImage;
                for (final item in _batchItems) {
                  item.status = _BatchScanStatus.pending;
                  item.result = null;
                  item.scanError = null;
                  item.saved = false;
                  item.saveError = null;
                }
                _globalError = null;
              }),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Re-escanear'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _selectedForSave == 0 ? null : _saveAllInvoices,
              icon: const Icon(Icons.save, size: 18),
              label: Text(
                _selectedForSave == 1
                    ? 'Registrar Factura'
                    : 'Registrar $_selectedForSave Facturas',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
              ),
            ),
          ],
          if (_step == _ScanStep.saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Helper Widgets ───────────────────────────────────────────────
  Widget _buildSection(
    ThemeData theme, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFEEEEEE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF388E3C),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(
    String label,
    TextEditingController controller, {
    String? suffix,
    bool isBold = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        prefixText: suffix == null ? '\$ ' : null,
        suffixText: suffix,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: isBold
          ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
          : null,
    );
  }

  Widget _buildSupplierOption(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFE0E0E0),
            width: selected ? 2 : 1,
          ),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFFBDBDBD),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFF757575),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Lógica de negocio ────────────────────────────────────────────
  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _globalError = null;
        final existingNames = _batchItems.map((i) => i.file.name).toSet();
        int idx = _batchItems.length;
        for (final file in result.files) {
          if (!existingNames.contains(file.name)) {
            _batchItems.add(_BatchInvoiceItem(index: idx++, file: file));
          }
        }
      });
    }
  }

  Future<void> _rescanItem(_BatchInvoiceItem item) async {
    if (item.status == _BatchScanStatus.scanning) return;
    setState(() {
      item.status = _BatchScanStatus.scanning;
      item.result = null;
      item.scanError = null;
    });
    final response = await InvoiceScannerService.scanFromFile(item.file);
    if (!mounted) return;
    if (response.success && response.data != null) {
      item.populateFromResult(response.data!, _dateFormat);
      _autoMatchSupplierForItem(item);
      if (item.selectedSupplierId == null) item.createNewSupplier = true;
    } else {
      item.status = _BatchScanStatus.error;
      item.scanError = response.error ?? 'Error desconocido';
      item.selected = false;
    }
    setState(() {});
  }

  Future<void> _startBatchScan() async {
    if (_batchItems.isEmpty) return;
    setState(() {
      _step = _ScanStep.scanning;
      _globalError = null;
      for (final item in _batchItems) {
        item.status = _BatchScanStatus.pending;
        item.result = null;
        item.scanError = null;
      }
    });
    for (int i = 0; i < _batchItems.length; i++) {
      final item = _batchItems[i];
      setState(() {
        item.status = _BatchScanStatus.scanning;
      });
      final response = await InvoiceScannerService.scanFromFile(item.file);
      if (!mounted) return;
      if (response.success && response.data != null) {
        item.populateFromResult(response.data!, _dateFormat);
        _autoMatchSupplierForItem(item);
        if (item.selectedSupplierId == null) item.createNewSupplier = true;
      } else {
        item.status = _BatchScanStatus.error;
        item.scanError = response.error ?? 'Error desconocido';
        item.selected = false;
      }
      setState(() {});

      // Pacing para evitar saturar el worker de Supabase en lotes grandes.
      if (i < _batchItems.length - 1) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }
    if (!_accountsLoaded) {
      try {
        _allAccounts = await AccountsDataSource.getAllAccounts();
        _accountsLoaded = true;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _step = _ScanStep.review;
      final first = _batchItems.firstWhere(
        (i) => i.status == _BatchScanStatus.done,
        orElse: () => _batchItems.first,
      );
      first.isExpanded = true;
    });
  }

  void _autoMatchSupplierForItem(_BatchInvoiceItem item) {
    if (item.result?.supplier.documentNumber == null) return;
    final suppliers = ref.read(suppliersProvider).suppliers;
    final scannedDoc = item.result!.supplier.documentNumber!.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    for (final s in suppliers) {
      final existingDoc = s.documentNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (existingDoc.isNotEmpty && existingDoc == scannedDoc) {
        item.selectedSupplierId = s.id;
        item.createNewSupplier = false;
        return;
      }
    }
    final scannedName = item.result!.supplier.name?.toLowerCase() ?? '';
    if (scannedName.isEmpty) return;
    for (final s in suppliers) {
      if (s.name.toLowerCase().contains(scannedName) ||
          scannedName.contains(s.name.toLowerCase())) {
        item.selectedSupplierId = s.id;
        item.createNewSupplier = false;
        return;
      }
    }
  }

  Future<void> _pickDateForCtrl(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initial = _dateFormat.parse(controller.text);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => controller.text = _dateFormat.format(picked));
    }
  }

  Future<void> _saveAllInvoices() async {
    final toSave = _batchItems
        .where((i) => i.selected && i.status == _BatchScanStatus.done)
        .toList();
    if (toSave.isEmpty) return;
    setState(() {
      _step = _ScanStep.saving;
      _savingCurrentIndex = 0;
    });
    String? lastPeriod;
    final allMatches = <_ItemInventoryMatch>[];
    List<mat.Material> allMaterials = [];
    try {
      allMaterials = await InventoryDataSource.getAllMaterials();
    } catch (_) {}
    for (int i = 0; i < toSave.length; i++) {
      final item = toSave[i];
      item.saved = false;
      item.saveError = null;
      setState(() => _savingCurrentIndex = i);
      try {
        final currentNumber = item.invoiceNumberCtrl.text.trim();
        final currentNormalized = _normalizeInvoiceNumber(currentNumber);
        if (currentNormalized.isNotEmpty) {
          final duplicatedInBatch = toSave.any(
            (other) =>
                !identical(other, item) &&
                _normalizeInvoiceNumber(other.invoiceNumberCtrl.text.trim()) ==
                    currentNormalized,
          );
          if (duplicatedInBatch) {
            throw Exception(
              'Factura duplicada en el lote: ${currentNumber.isEmpty ? 'SIN-NUM' : currentNumber}',
            );
          }
        }

        lastPeriod = await _saveOneInvoice(item);
        item.saved = true;
        if (item.result != null) {
          for (final inv in item.result!.items) {
            final recommended = _findBestMatch(inv.description, allMaterials);
            allMatches.add(
              _ItemInventoryMatch(
                item: inv,
                aiRecommendation: recommended,
                matchedMaterial: recommended,
                createNew: recommended == null,
                selected: true,
              ),
            );
          }
        }
      } catch (e) {
        item.saveError = e.toString();
      }
      setState(() {});
    }
    setState(() => _savingCurrentIndex = toSave.length);
    if (!mounted) return;
    final savedCount = toSave.where((i) => i.saved).length;
    final errorCount = toSave.where((i) => i.saveError != null).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedCount > 0
              ? '✅ $savedCount factura(s) registrada(s)${errorCount > 0 ? ' · ⚠ $errorCount con error' : ''}'
              : '❌ No se pudo registrar ninguna factura',
        ),
        backgroundColor: savedCount > 0
            ? const Color(0xFF388E3C)
            : const Color(0xFFD32F2F),
        duration: const Duration(seconds: 5),
      ),
    );
    if (allMatches.isNotEmpty && mounted) {
      final invoiceRefs = toSave
          .where((i) => i.saved)
          .map(
            (i) => i.invoiceNumberCtrl.text.isNotEmpty
                ? i.invoiceNumberCtrl.text
                : i.file.name,
          )
          .join(', ');
      await _offerBatchInventoryUpdate(allMatches, allMaterials, invoiceRefs);
    }
    if (!mounted) return;
    Navigator.of(context).pop(lastPeriod);
  }

  Future<String?> _saveOneInvoice(_BatchInvoiceItem item) async {
    if (item.result == null) throw Exception('Sin datos escaneados');
    if (item.selectedSupplierId == null && !item.createNewSupplier) {
      throw Exception('Falta proveedor');
    }
    if (item.createExpenseRecord && item.selectedAccountId == null) {
      throw Exception('Selecciona una cuenta para registrar el gasto');
    }

    final invoiceNumber = item.invoiceNumberCtrl.text.trim();
    if (invoiceNumber.isNotEmpty && invoiceNumber.toUpperCase() != 'SIN-NUM') {
      final isDuplicate = await _isDuplicateInvoiceNumber(invoiceNumber);
      if (isDuplicate) {
        throw Exception(
          'La factura $invoiceNumber ya existe y no se puede registrar de nuevo',
        );
      }
    }

    String? supplierId = item.selectedSupplierId;
    String supplierName;
    String supplierNit;
    if (item.createNewSupplier) {
      final newSupplier = await SuppliersDataSource.createQuick(
        name: item.supplierNameCtrl.text.trim().isNotEmpty
            ? item.supplierNameCtrl.text.trim()
            : item.result!.supplier.name ?? 'Proveedor',
        documentType: 'NIT',
        documentNumber: item.supplierNitCtrl.text.trim(),
        type: SupplierType.business,
      );
      supplierId = newSupplier.id;
      supplierName = newSupplier.displayName;
      supplierNit = newSupplier.documentNumber;
      if (item.supplierAddressCtrl.text.trim().isNotEmpty ||
          item.supplierPhoneCtrl.text.trim().isNotEmpty ||
          item.supplierEmailCtrl.text.trim().isNotEmpty) {
        await SuppliersDataSource.update(
          newSupplier.copyWith(
            address: item.supplierAddressCtrl.text.trim().isNotEmpty
                ? item.supplierAddressCtrl.text.trim()
                : null,
            phone: item.supplierPhoneCtrl.text.trim().isNotEmpty
                ? item.supplierPhoneCtrl.text.trim()
                : null,
            email: item.supplierEmailCtrl.text.trim().isNotEmpty
                ? item.supplierEmailCtrl.text.trim()
                : null,
          ),
        );
      }
    } else {
      final supplier = await SuppliersDataSource.getById(supplierId!);
      supplierName =
          supplier?.displayName ?? item.result!.supplier.name ?? 'Proveedor';
      supplierNit =
          supplier?.documentNumber ??
          item.result!.supplier.documentNumber ??
          '';
    }
    final subtotal =
        double.tryParse(item.subtotalCtrl.text) ?? item.result!.subtotal;
    final taxAmount =
        double.tryParse(item.taxAmountCtrl.text) ?? item.result!.taxAmount;
    final reteFte = double.tryParse(item.reteFteCtrl.text) ?? 0;
    final reteIca = double.tryParse(item.reteIcaCtrl.text) ?? 0;
    final reteIva = double.tryParse(item.reteIvaCtrl.text) ?? 0;
    final total = double.tryParse(item.totalCtrl.text) ?? item.result!.total;
    final taxRate =
        double.tryParse(item.taxRateCtrl.text) ?? item.result!.taxRate;
    final creditDays =
        int.tryParse(item.creditDaysCtrl.text) ?? item.result!.creditDays;
    DateTime invoiceDate = DateTime.now();
    if (item.invoiceDateCtrl.text.isNotEmpty) {
      try {
        invoiceDate = _dateFormat.parse(item.invoiceDateCtrl.text);
      } catch (_) {}
    }
    DateTime? dueDate;
    if (item.dueDateCtrl.text.isNotEmpty) {
      try {
        dueDate = _dateFormat.parse(item.dueDateCtrl.text);
      } catch (_) {}
    }
    if (dueDate == null && creditDays > 0) {
      dueDate = invoiceDate.add(Duration(days: creditDays));
    }

    final scannedInvoiceNumber = item.invoiceNumberCtrl.text.isNotEmpty
        ? item.invoiceNumberCtrl.text
        : 'SIN-NUM';
    final generatedNumber = await InvoicesDataSource.generateNumber('CMP');
    final invoiceNotes = [
      'Factura compra escaneada: $scannedInvoiceNumber',
      if (item.cufeCtrl.text.isNotEmpty) 'CUFE: ${item.cufeCtrl.text}',
      if (item.notesCtrl.text.isNotEmpty) item.notesCtrl.text,
    ].join('\n');

    final invoiceResponse = await SupabaseDataSource.client
        .from('invoices')
        .insert({
          'type': 'invoice',
          'series': 'CMP',
          'number': generatedNumber,
          'customer_id': null,
          'customer_name': supplierName,
          'customer_document': supplierNit,
          'customer_address': item.supplierAddressCtrl.text.trim().isNotEmpty
              ? item.supplierAddressCtrl.text.trim()
              : null,
          'issue_date': invoiceDate.toIso8601String().split('T')[0],
          'due_date': dueDate?.toIso8601String().split('T')[0],
          'subtotal': subtotal,
          'tax_rate': taxRate,
          'tax_amount': taxAmount,
          'discount': 0,
          'total': total,
          'paid_amount': item.createExpenseRecord ? total : 0,
          'status': item.createExpenseRecord ? 'paid' : 'issued',
          'payment_method': item.createExpenseRecord ? 'transfer' : null,
          'notes': invoiceNotes,
        })
        .select('id, series, number')
        .single();

    final invoiceId = (invoiceResponse['id'] as String?) ?? '';
    if (invoiceId.isEmpty) {
      throw Exception('No se pudo crear la factura en tablas core');
    }

    final invoiceItems = item.result!.items;
    if (invoiceItems.isNotEmpty) {
      await SupabaseDataSource.client
          .from('invoice_items')
          .insert(
            invoiceItems.asMap().entries.map((entry) {
              final idx = entry.key;
              final invItem = entry.value;
              return {
                'invoice_id': invoiceId,
                'product_id': null,
                'material_id': null,
                'product_code': invItem.referenceCode,
                'product_name': invItem.description,
                'description': invItem.description,
                'quantity': invItem.quantity,
                'unit': invItem.unit.isEmpty
                    ? 'UND'
                    : invItem.unit.toUpperCase(),
                'unit_price': invItem.unitPrice,
                'discount': 0,
                'tax_rate': invItem.taxRate,
                'subtotal': invItem.subtotal,
                'tax_amount': invItem.taxAmount,
                'total': invItem.total,
                'sort_order': idx,
              };
            }).toList(),
          );
    }

    if (item.createExpenseRecord) {
      await SupabaseDataSource.client.from('payments').insert({
        'invoice_id': invoiceId,
        'amount': total,
        'method': 'transfer',
        'payment_date': DateTime.now().toIso8601String().split('T')[0],
        'reference':
            'COMPRA-${invoiceResponse['series']}-${invoiceResponse['number']}',
      });
    }

    final period = getBimonthlyPeriod(invoiceDate);
    if (item.createIvaRecord) {
      final itemsDetail = item.result!.items
          .map(
            (i) =>
                '${i.description} x${i.quantity} = \$${i.total.toStringAsFixed(0)}',
          )
          .join(' | ');
      await IvaDataSource.createInvoice(
        IvaInvoice(
          invoiceNumber: item.invoiceNumberCtrl.text.isNotEmpty
              ? item.invoiceNumberCtrl.text
              : 'SIN-NUM',
          invoiceDate: invoiceDate,
          company: supplierName,
          invoiceType: 'COMPRA',
          baseAmount: subtotal,
          ivaAmount: taxAmount,
          totalAmount: total,
          hasReteiva: reteIva > 0,
          reteivaAmount: reteIva,
          bimonthlyPeriod: period,
          notes: item.notesCtrl.text.isNotEmpty
              ? '${item.notesCtrl.text}\n$itemsDetail'
              : itemsDetail,
          companyDocument: supplierNit,
          cufe: item.cufeCtrl.text.isNotEmpty ? item.cufeCtrl.text : null,
          rteFteAmount: reteFte,
          reteIcaAmount: reteIca,
        ),
      );
    }
    if (item.createExpenseRecord && item.selectedAccountId != null) {
      final refNumber = await AccountsDataSource.getNextReferenceNumber();
      await AccountsDataSource.createMovementWithBalanceUpdate(
        CashMovement(
          id: '',
          accountId: item.selectedAccountId!,
          type: MovementType.expense,
          category: MovementCategory.consumibles,
          amount: total,
          description: 'Factura ${item.invoiceNumberCtrl.text} - $supplierName',
          reference: refNumber.toString().padLeft(6, '0'),
          personName: supplierName,
          date: invoiceDate,
        ),
      );
    }
    await SuppliersDataSource.updateDebt(supplierId, total);
    return period;
  }

  String _normalizeInvoiceNumber(String value) {
    return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  Future<bool> _isDuplicateInvoiceNumber(String invoiceNumber) async {
    final trimmed = invoiceNumber.trim();
    if (trimmed.isEmpty) return false;

    final normalizedTarget = _normalizeInvoiceNumber(trimmed);
    if (normalizedTarget.isEmpty) return false;

    // Fast path: exact match with helper query.
    final exact = await IvaDataSource.findByInvoiceNumber(trimmed);
    if (exact.isNotEmpty) return true;

    // Robust path: compare normalized values to catch variants like
    // "FE 22613" vs "FE22613" or with punctuation.
    final recent = await IvaDataSource.getInvoices(limit: 5000);
    return recent.any(
      (inv) => _normalizeInvoiceNumber(inv.invoiceNumber) == normalizedTarget,
    );
  }

  Future<void> _offerBatchInventoryUpdate(
    List<_ItemInventoryMatch> matches,
    List<mat.Material> allMaterials,
    String invoiceRefs,
  ) async {
    if (matches.isEmpty || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _InventoryUpdateDialog(
        matches: matches,
        invoiceRef: invoiceRefs,
        allMaterials: allMaterials,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      for (final match in matches.where((m) => m.selected)) {
        final inv = match.item;
        final qty = inv.quantity;
        if (match.isNew) {
          final now = DateTime.now();
          // Generar código único basado en timestamp para evitar constraint violation
          final uniqueCode = 'FAC-${now.millisecondsSinceEpoch % 1000000}';
          final created = await InventoryDataSource.createMaterial(
            mat.Material(
              id: '',
              code: uniqueCode,
              name: inv.description,
              description: 'Creado automáticamente desde factura $invoiceRefs',
              category: 'consumible',
              costPrice: inv.unitPrice,
              unitPrice: inv.unitPrice,
              stock: qty,
              unit: inv.unit.isEmpty ? 'UND' : inv.unit.toUpperCase(),
              createdAt: now,
              updatedAt: now,
            ),
          );
          try {
            await InventoryDataSource.client.from('material_movements').insert({
              'material_id': created.id,
              'type': 'entrada',
              'quantity': qty,
              'previous_stock': 0.0,
              'new_stock': qty,
              'reason': 'Ingreso por factura $invoiceRefs',
              'reference': 'FAC-$invoiceRefs',
            });
          } catch (_) {}
        } else {
          final material = match.matchedMaterial!;
          final newStock = material.stock + qty;
          await InventoryDataSource.updateStock(material.id, newStock);
          try {
            await InventoryDataSource.client.from('material_movements').insert({
              'material_id': material.id,
              'type': 'entrada',
              'quantity': qty,
              'previous_stock': material.stock,
              'new_stock': newStock,
              'reason': 'Ingreso por factura $invoiceRefs',
              'reference': 'FAC-$invoiceRefs',
            });
          } catch (_) {}
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📦 Inventario: ${matches.where((m) => m.selected && !m.isNew).length} actualizados, ${matches.where((m) => m.selected && m.isNew).length} creados',
            ),
            backgroundColor: const Color(0xFF00796B),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠ Error al actualizar inventario: $e'),
            backgroundColor: const Color(0xFFF57C00),
          ),
        );
      }
    }
  }

  mat.Material? _findBestMatch(
    String description,
    List<mat.Material> materials,
  ) {
    final descLower = description.toLowerCase();
    final descWords = descLower
        .split(RegExp(r'[\s,.\-/]+'))
        .where((w) => w.length > 2)
        .toList();

    // Extrae tokens numéricos y dimensionales (ej. "1.5", "2", "3/4", "1018", "630mm").
    // Estos son discriminadores estrictos: si difieren, no es el mismo producto.
    final numericRegex = RegExp(r'\d+[.,/]?\d*\s*(?:mm|cm|m|kg|lb|")?');
    Set<String> extractNumericTokens(String s) {
      return numericRegex
          .allMatches(s.toLowerCase())
          .map((m) => m.group(0)!.replaceAll(',', '.').trim())
          .toSet();
    }

    final descNums = extractNumericTokens(descLower);

    mat.Material? best;
    int bestScore = 0;
    for (final m in materials) {
      final nameLower = m.name.toLowerCase();

      // Si ambos tienen tokens numéricos y no comparten NINGUNO → rechazo estricto.
      // Evita que "BOLA 2"" coincida con "BOLA 1.5"".
      final matNums = extractNumericTokens(nameLower);
      if (descNums.isNotEmpty && matNums.isNotEmpty) {
        final hasCommonNum = descNums.any((n) => matNums.contains(n));
        if (!hasCommonNum) continue;
      }

      int score = 0;
      if (nameLower == descLower) score += 10;
      if (nameLower.contains(descLower)) score += 5;
      if (descLower.contains(nameLower)) score += 4;
      for (final word in descWords) {
        if (nameLower.contains(word)) score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }
    return bestScore >= 2 ? best : null;
  }
}

// ---------------------------------------------------------------------------
// Widget del diálogo de actualización de inventario (StatefulWidget independiente)
// ---------------------------------------------------------------------------

class _InventoryUpdateDialog extends StatefulWidget {
  final List<_ItemInventoryMatch> matches;
  final String invoiceRef;
  final List<mat.Material> allMaterials;

  const _InventoryUpdateDialog({
    required this.matches,
    required this.invoiceRef,
    required this.allMaterials,
  });

  @override
  State<_InventoryUpdateDialog> createState() => _InventoryUpdateDialogState();
}

class _InventoryUpdateDialogState extends State<_InventoryUpdateDialog> {
  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.matches.where((m) => m.selected).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00796B),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '\u{1F4E6} Actualizar Inventario de Materiales',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Factura ${widget.invoiceRef} \u00B7 ${widget.matches.length} \u00EDtem(s) detectados',
                          style: const TextStyle(
                            color: Color(0xFFB2DFDB),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF90CAF9)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF1976D2),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La IA sugiere materiales existentes. Puedes cambiar la selecci\u00F3n o elegir "Crear nuevo material" para cada \u00EDtem.',
                        style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: widget.matches.length,
                itemBuilder: (context, index) =>
                    _buildMatchItem(widget.matches[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Omitir'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: selectedCount == 0
                        ? null
                        : () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.inventory_2, size: 18),
                    label: Text('Actualizar Inventario ($selectedCount)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchItem(_ItemInventoryMatch match) {
    final item = match.item;
    final isNew = match.isNew;
    final statusColor = isNew
        ? const Color(0xFFF57C00)
        : const Color(0xFF00796B);
    final statusBg = isNew ? const Color(0xFFFFF3E0) : const Color(0xFFE0F2F1);
    final qtyLabel =
        '+${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit.isEmpty ? 'UND' : item.unit}';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: match.selected ? statusBg : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: match.selected
              ? statusColor.withOpacity(0.4)
              : const Color(0xFFEEEEEE),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: match.selected,
                    activeColor: statusColor,
                    onChanged: (val) =>
                        setState(() => match.selected = val ?? false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.description,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    qtyLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            if (match.selected) ...[
              const SizedBox(height: 10),
              if (match.aiRecommendation != null)
                Padding(
                  padding: const EdgeInsets.only(left: 34, bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: Color(0xFF1E88E5),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'IA sugiere: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E88E5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${match.aiRecommendation!.name} (stock: ${match.aiRecommendation!.stock.toStringAsFixed(match.aiRecommendation!.stock % 1 == 0 ? 0 : 2)} ${match.aiRecommendation!.unit})',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1976D2),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 34),
                child: DropdownButtonFormField<String>(
                  value: match.createNew
                      ? '__new__'
                      : match.matchedMaterial?.id,
                  decoration: InputDecoration(
                    labelText: 'Material en inventario',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    prefixIcon: Icon(
                      match.createNew
                          ? Icons.add_circle_outline
                          : Icons.check_circle_outline,
                      color: statusColor,
                      size: 20,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<String>(
                      value: '__new__',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle,
                            size: 16,
                            color: Color(0xFFF57C00),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Crear nuevo material',
                            style: TextStyle(
                              color: Color(0xFFF57C00),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...widget.allMaterials.map((m) {
                      final isRecommended = match.aiRecommendation?.id == m.id;
                      return DropdownMenuItem<String>(
                        value: m.id,
                        child: Row(
                          children: [
                            isRecommended
                                ? const Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: Color(0xFF1E88E5),
                                  )
                                : const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 14,
                                    color: Color(0xFFBDBDBD),
                                  ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${m.name} (${m.stock.toStringAsFixed(m.stock % 1 == 0 ? 0 : 2)} ${m.unit})',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: isRecommended
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() {
                    if (val == '__new__') {
                      match.createNew = true;
                      match.matchedMaterial = null;
                    } else {
                      match.createNew = false;
                      match.matchedMaterial = widget.allMaterials.firstWhere(
                        (m) => m.id == val,
                      );
                    }
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 8),
                child: Row(
                  children: [
                    Icon(
                      isNew ? Icons.fiber_new : Icons.trending_up,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isNew
                            ? 'Se crear\u00E1 "${item.description}" con stock inicial de $qtyLabel'
                            : 'Se sumar\u00E1 $qtyLabel a "${match.matchedMaterial!.name}" (${match.matchedMaterial!.stock.toStringAsFixed(match.matchedMaterial!.stock % 1 == 0 ? 0 : 2)} \u2192 ${(match.matchedMaterial!.stock + item.quantity).toStringAsFixed((match.matchedMaterial!.stock + item.quantity) % 1 == 0 ? 0 : 2)} ${match.matchedMaterial!.unit})',
                        style: TextStyle(fontSize: 11, color: statusColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
