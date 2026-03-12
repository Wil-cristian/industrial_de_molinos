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
import '../../data/providers/suppliers_provider.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/cash_movement.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/material.dart' as mat;

/// Modelo interno para emparejar ítems de factura con materiales del inventario
class _ItemInventoryMatch {
  final ScannedInvoiceItem item;
  final mat.Material? aiRecommendation; // Lo que sugirió el fuzzy match
  mat.Material? matchedMaterial; // Lo que el usuario eligió
  bool createNew; // true = crear nuevo material
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

/// Diálogo de escaneo de factura con IA
/// Flujo: Seleccionar imagen → Escanear con OpenAI → Revisar datos → Registrar en contabilidad
class InvoiceScanDialog extends ConsumerStatefulWidget {
  const InvoiceScanDialog({super.key});

  @override
  ConsumerState<InvoiceScanDialog> createState() => _InvoiceScanDialogState();

  /// Mostrar el diálogo
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
  PlatformFile? _selectedFile;
  InvoiceScanResult? _scanResult;
  String? _error;
  String? _selectedSupplierId;
  bool _createNewSupplier = false;
  bool _createIvaRecord = true;
  bool _createExpenseRecord = true;
  String? _selectedAccountId;

  // Controllers para nuevo proveedor
  final _supplierNameCtrl = TextEditingController();
  final _supplierNitCtrl = TextEditingController();
  final _supplierAddressCtrl = TextEditingController();
  final _supplierPhoneCtrl = TextEditingController();
  final _supplierEmailCtrl = TextEditingController();

  // Controllers para edición
  final _invoiceNumberCtrl = TextEditingController();
  final _invoiceDateCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  final _cufeCtrl = TextEditingController();
  final _subtotalCtrl = TextEditingController();
  final _taxAmountCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  final _reteFteCtrl = TextEditingController();
  final _reteIcaCtrl = TextEditingController();
  final _reteIvaCtrl = TextEditingController();
  final _freightCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _creditDaysCtrl = TextEditingController();

  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _invoiceNumberCtrl.dispose();
    _invoiceDateCtrl.dispose();
    _dueDateCtrl.dispose();
    _cufeCtrl.dispose();
    _subtotalCtrl.dispose();
    _taxAmountCtrl.dispose();
    _taxRateCtrl.dispose();
    _reteFteCtrl.dispose();
    _reteIcaCtrl.dispose();
    _reteIvaCtrl.dispose();
    _freightCtrl.dispose();
    _totalCtrl.dispose();
    _notesCtrl.dispose();
    _creditDaysCtrl.dispose();
    _supplierNameCtrl.dispose();
    _supplierNitCtrl.dispose();
    _supplierAddressCtrl.dispose();
    _supplierPhoneCtrl.dispose();
    _supplierEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 1200 ? 900.0 : screenWidth * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 750),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(theme),
            // Content
            Flexible(child: _buildContent(theme)),
            // Actions
            _buildActions(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final titles = {
      _ScanStep.selectImage: 'Escanear Factura con IA',
      _ScanStep.scanning: 'Analizando factura...',
      _ScanStep.review: 'Revisar Datos Extraídos',
      _ScanStep.saving: 'Guardando...',
    };

    final icons = {
      _ScanStep.selectImage: Icons.document_scanner_outlined,
      _ScanStep.scanning: Icons.auto_awesome,
      _ScanStep.review: Icons.fact_check_outlined,
      _ScanStep.saving: Icons.save,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
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
                if (_step == _ScanStep.review && _scanResult != null)
                  Text(
                    'Confianza: ${(_scanResult!.confidence * 100).toStringAsFixed(0)}% · '
                    'Tokens: ${_scanResult!.totalTokens} · '
                    'Costo: ~\$${_scanResult!.estimatedCost ?? "?"}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xB3FFFFFF),
                    ),
                  ),
              ],
            ),
          ),
          // Step indicator
          _buildStepIndicator(),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Imagen', 'Escaneo', 'Revisión', 'Guardar'];
    final currentIdx = _step.index;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(steps.length, (i) {
        final isActive = i == currentIdx;
        final isDone = i < currentIdx;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isDone
                ? Colors.white
                : isActive
                ? Colors.white
                : const Color(0x62FFFFFF),
          ),
        );
      }),
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (_step) {
      case _ScanStep.selectImage:
        return _buildSelectImageStep(theme);
      case _ScanStep.scanning:
        return _buildScanningStep(theme);
      case _ScanStep.review:
        return _buildReviewStep(theme);
      case _ScanStep.saving:
        return _buildSavingStep(theme);
    }
  }

  // ─── STEP 1: Seleccionar imagen ──────────────────

  Widget _buildSelectImageStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF9A9A)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: const Color(0xFFD32F2F)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: const Color(0xFFD32F2F)),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Drop zone
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 48),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedFile != null
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFFE0E0E0),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  color: _selectedFile != null
                      ? Theme.of(context).colorScheme.primaryContainer
                      : const Color(0xFFFAFAFA),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.check_circle
                          : Icons.cloud_upload_outlined,
                      size: 64,
                      color: _selectedFile != null
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFBDBDBD),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFile != null
                          ? _selectedFile!.name
                          : 'Seleccionar foto de factura',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _selectedFile != null
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile != null
                          ? '${(_selectedFile!.size / 1024).toStringAsFixed(0)} KB · Toca para cambiar'
                          : 'JPG, PNG o PDF · Máximo 10 MB',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFFAFAFA)0,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF1976D2),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
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
                        const SizedBox(height: 4),
                        Text(
                          'La IA extraerá: proveedor, NIT, fecha, ítems con precios, '
                          'IVA, retenciones (RteFte, ICA, ReteIVA), CUFE y totales. '
                          'Costo aprox: \$0.001-0.003 por factura.',
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

  // ─── STEP 2: Escaneando ───────────────────────────

  Widget _buildScanningStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Analizando factura con IA...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'OpenAI Vision está extrayendo toda la información.\n'
            'Esto tomará unos segundos.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 3: Revisión ────────────────────────────

  Widget _buildReviewStep(ThemeData theme) {
    if (_scanResult == null) return const SizedBox.shrink();

    final suppliers = ref.watch(suppliersProvider).suppliers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Proveedor detectado + selector
          _buildSupplierSection(theme, suppliers),
          const SizedBox(height: 16),

          // Datos de factura
          _buildInvoiceDataSection(theme),
          const SizedBox(height: 16),

          // Ítems
          _buildItemsSection(theme),
          const SizedBox(height: 16),

          // Totales y retenciones
          _buildTotalsSection(theme),
          const SizedBox(height: 16),

          // Opciones
          _buildOptionsSection(theme),
        ],
      ),
    );
  }

  Widget _buildSupplierSection(ThemeData theme, List<Supplier> suppliers) {
    final detected = _scanResult!.supplier;
    final hasMatch = _selectedSupplierId != null && !_createNewSupplier;

    return _buildSection(
      theme,
      icon: Icons.business,
      title: 'Proveedor',
      subtitle: detected.name != null
          ? 'Detectado: ${detected.name} · ${detected.documentType ?? 'NIT'} ${detected.documentNumber ?? ''}'
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector: vincular existente o crear nuevo
          Row(
            children: [
              Expanded(
                child: _buildSupplierOption(
                  theme,
                  icon: Icons.link,
                  label: 'Vincular existente',
                  selected: !_createNewSupplier,
                  onTap: () => setState(() => _createNewSupplier = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSupplierOption(
                  theme,
                  icon: Icons.person_add,
                  label: 'Crear nuevo',
                  selected: _createNewSupplier,
                  onTap: () {
                    _populateNewSupplierFields();
                    setState(() {
                      _createNewSupplier = true;
                      _selectedSupplierId = null;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!_createNewSupplier) ...[
            // Dropdown de proveedores existentes
            DropdownButtonFormField<String>(
              value: _selectedSupplierId,
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
              onChanged: (v) => setState(() => _selectedSupplierId = v),
            ),
            if (hasMatch)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '✅ Vinculado automáticamente por ${detected.documentNumber != null ? 'NIT' : 'nombre'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF388E3C),
                  ),
                ),
              ),
          ] else ...[
            // Campos editables para crear nuevo proveedor
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _supplierNameCtrl,
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
                    controller: _supplierNitCtrl,
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
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _supplierAddressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _supplierPhoneCtrl,
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
                    controller: _supplierEmailCtrl,
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
                '💡 Datos pre-llenados desde la factura escaneada',
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : const Color(0xFFE0E0E0),
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
              size: 18,
              color: selected ? Theme.of(context).colorScheme.primary : const Color(0xFFFAFAFA)0,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Theme.of(context).colorScheme.primary : const Color(0xFF757575),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceDataSection(ThemeData theme) {
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
                  controller: _invoiceNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nº Factura',
                    prefixIcon: Icon(Icons.tag),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _invoiceDateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fecha factura',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  readOnly: true,
                  onTap: () => _pickDate(_invoiceDateCtrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _dueDateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vencimiento',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  readOnly: true,
                  onTap: () => _pickDate(_dueDateCtrl),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _cufeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'CUFE (Código Único)',
                    prefixIcon: Icon(Icons.qr_code),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _creditDaysCtrl,
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

  Widget _buildItemsSection(ThemeData theme) {
    final items = _scanResult!.items;

    return _buildSection(
      theme,
      icon: Icons.list_alt,
      title: 'Ítems Detectados (${items.length})',
      child: Column(
        children: [
          // Header de tabla
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 80,
                  child: Text(
                    'Código',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Text(
                    'Descripción',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(
                  width: 50,
                  child: Text(
                    'Cant',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(
                  width: 80,
                  child: Text(
                    'Precio',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(
                  width: 50,
                  child: Text(
                    'IVA%',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(
                  width: 90,
                  child: Text(
                    'Subtotal',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          // Filas de ítems
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: const Color(0xFFEEEEEE))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      item.referenceCode ?? '-',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      item.description,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${item.quantity}',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      Helpers.formatNumber(item.unitPrice),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${item.taxRate.toStringAsFixed(0)}%',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      Helpers.formatNumber(item.subtotal),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotalsSection(ThemeData theme) {
    return _buildSection(
      theme,
      icon: Icons.calculate,
      title: 'Totales y Retenciones',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna izquierda: montos principales
          Expanded(
            child: Column(
              children: [
                _buildAmountField('Subtotal', _subtotalCtrl),
                const SizedBox(height: 8),
                _buildAmountField('IVA (%)', _taxRateCtrl, suffix: '%'),
                const SizedBox(height: 8),
                _buildAmountField('Monto IVA', _taxAmountCtrl),
                const SizedBox(height: 8),
                _buildAmountField('Fletes', _freightCtrl),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Columna derecha: retenciones + total
          Expanded(
            child: Column(
              children: [
                _buildAmountField('Ret. Fuente', _reteFteCtrl),
                const SizedBox(height: 8),
                _buildAmountField('Ret. ICA', _reteIcaCtrl),
                const SizedBox(height: 8),
                _buildAmountField('Ret. IVA', _reteIvaCtrl),
                const SizedBox(height: 8),
                _buildAmountField('TOTAL', _totalCtrl, isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsSection(ThemeData theme) {
    return _buildSection(
      theme,
      icon: Icons.settings,
      title: 'Opciones',
      child: Column(
        children: [
          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notas / Observaciones',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Registrar en IVA bimestral'),
            subtitle: Text(
              'Vincula esta factura de compra con el control de IVA',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF757575),
              ),
            ),
            value: _createIvaRecord,
            onChanged: (v) => setState(() => _createIvaRecord = v),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Registrar gasto en caja'),
            subtitle: Text(
              _scanResult != null && _scanResult!.creditDays > 0
                  ? _createExpenseRecord
                        ? '💰 Pago de contado — se registrará egreso + asiento contable ahora'
                        : '⏳ Compra a crédito (${_scanResult!.creditDays} días) — podrás pagar después desde Proveedores'
                  : _createExpenseRecord
                  ? 'Crea movimiento de egreso y asiento contable automático'
                  : 'Solo registra IVA y deuda — sin salida de caja',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _scanResult != null && _scanResult!.creditDays > 0
                    ? _createExpenseRecord
                          ? const Color(0xFF388E3C)
                          : const Color(0xFFF57C00)
                    : const Color(0xFF757575),
              ),
            ),
            value: _createExpenseRecord,
            onChanged: (v) => setState(() => _createExpenseRecord = v),
          ),
          if (_createExpenseRecord) ...[
            const SizedBox(height: 8),
            FutureBuilder<List<Account>>(
              future: AccountsDataSource.getAllAccounts(),
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Cuenta de pago',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.account_balance_wallet, size: 18),
                  ),
                  items: accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            '${a.name} (\$${Formatters.currency(a.balance)})',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAccountId = v),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ─── STEP 4: Guardando ───────────────────────────

  Widget _buildSavingStep(ThemeData theme) {
    return const Padding(
      padding: EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Registrando factura en contabilidad...'),
        ],
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────

  Widget _buildActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 12),
          if (_step == _ScanStep.selectImage)
            FilledButton.icon(
              onPressed: _selectedFile != null ? _startScan : null,
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Escanear con IA'),
            ),
          if (_step == _ScanStep.review) ...[
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _step = _ScanStep.selectImage;
                  _scanResult = null;
                  _error = null;
                });
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Re-escanear'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: (_selectedSupplierId != null || _createNewSupplier)
                  ? _saveInvoice
                  : null,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Registrar Factura'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF388E3C),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Helpers de UI ────────────────────────────────

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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFEEEEEE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF388E3C),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
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

  // ─── Acciones ─────────────────────────────────────

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _error = null;
      });
    }
  }

  Future<void> _startScan() async {
    if (_selectedFile == null) return;

    setState(() {
      _step = _ScanStep.scanning;
      _error = null;
    });

    final response = await InvoiceScannerService.scanFromFile(_selectedFile!);

    if (!mounted) return;

    if (response.success && response.data != null) {
      _scanResult = response.data;
      _populateControllers();
      // Intentar auto-match con proveedor
      _autoMatchSupplier();
      // Si no se encontró match, ofrecer crear nuevo
      if (_selectedSupplierId == null) {
        _createNewSupplier = true;
        _populateNewSupplierFields();
      }
      setState(() => _step = _ScanStep.review);
    } else {
      setState(() {
        _step = _ScanStep.selectImage;
        _error = response.error ?? 'Error desconocido al escanear';
      });
    }
  }

  void _populateControllers() {
    final r = _scanResult!;
    _invoiceNumberCtrl.text = r.invoiceNumber ?? '';
    _invoiceDateCtrl.text = r.invoiceDate != null
        ? _dateFormat.format(r.invoiceDate!)
        : '';
    _dueDateCtrl.text = r.dueDate != null ? _dateFormat.format(r.dueDate!) : '';
    _cufeCtrl.text = r.cufe ?? '';
    _creditDaysCtrl.text = r.creditDays.toString();
    _subtotalCtrl.text = r.subtotal.toStringAsFixed(2);
    _taxRateCtrl.text = r.taxRate.toStringAsFixed(2);
    _taxAmountCtrl.text = r.taxAmount.toStringAsFixed(2);
    _reteFteCtrl.text = r.retentionRteFte.toStringAsFixed(2);
    _reteIcaCtrl.text = r.retentionIca.toStringAsFixed(2);
    _reteIvaCtrl.text = r.retentionIva.toStringAsFixed(2);
    _freightCtrl.text = r.freight.toStringAsFixed(2);
    _totalCtrl.text = r.total.toStringAsFixed(2);
    _notesCtrl.text = r.notes ?? '';

    // Si es compra a crédito, no registrar gasto en caja de inmediato
    if (r.creditDays > 0) {
      _createExpenseRecord = false;
    }
  }

  void _autoMatchSupplier() {
    if (_scanResult?.supplier.documentNumber == null) return;

    final suppliers = ref.read(suppliersProvider).suppliers;
    final scannedDoc = _scanResult!.supplier.documentNumber!.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    for (final s in suppliers) {
      final existingDoc = s.documentNumber.replaceAll(RegExp(r'[^0-9]'), '');
      if (existingDoc.isNotEmpty && existingDoc == scannedDoc) {
        setState(() => _selectedSupplierId = s.id);
        return;
      }
    }

    // Intentar por nombre (match parcial)
    final scannedName = _scanResult!.supplier.name?.toLowerCase() ?? '';
    if (scannedName.isEmpty) return;

    for (final s in suppliers) {
      if (s.name.toLowerCase().contains(scannedName) ||
          scannedName.contains(s.name.toLowerCase())) {
        setState(() => _selectedSupplierId = s.id);
        return;
      }
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = controller.text.isNotEmpty
        ? _dateFormat.parse(controller.text)
        : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      controller.text = _dateFormat.format(picked);
    }
  }

  void _populateNewSupplierFields() {
    final detected = _scanResult?.supplier;
    if (detected == null) return;
    _supplierNameCtrl.text = detected.name ?? '';
    _supplierNitCtrl.text = detected.documentNumber ?? '';
    _supplierAddressCtrl.text = [
      detected.address,
      detected.city,
    ].where((s) => s != null && s.isNotEmpty).join(', ');
    _supplierPhoneCtrl.text = detected.phone ?? '';
    _supplierEmailCtrl.text = detected.email ?? '';
  }

  Future<void> _saveInvoice() async {
    if (_selectedSupplierId == null && !_createNewSupplier) return;
    if (_scanResult == null) return;

    // Verificar duplicados por número de factura
    final invoiceNum = _invoiceNumberCtrl.text.trim();
    if (invoiceNum.isNotEmpty && invoiceNum != 'SIN-NUM') {
      try {
        final existing = await IvaDataSource.findByInvoiceNumber(invoiceNum);
        if (existing.isNotEmpty && mounted) {
          final dup = existing.first;
          final dateStr =
              '${dup.invoiceDate.day.toString().padLeft(2, '0')}/${dup.invoiceDate.month.toString().padLeft(2, '0')}/${dup.invoiceDate.year}';
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFF57C00),
                size: 48,
              ),
              title: const Text('⚠️ Factura posiblemente duplicada'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ya existe una factura con el número "$invoiceNum":',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFCC80)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Proveedor: ${dup.company}'),
                        Text('Fecha: $dateStr'),
                        Text('Total: \$${dup.totalAmount.toStringAsFixed(0)}'),
                        Text('Tipo: ${dup.invoiceType}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¿Deseas registrarla de todas formas?',
                    style: TextStyle(color: const Color(0xFF9E9E9E)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF57C00),
                  ),
                  child: const Text(
                    'Registrar de todas formas',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
          if (proceed != true) return;
        }
      } catch (_) {
        // Si falla la verificación, continuar (no bloquear el registro)
      }
    }

    setState(() => _step = _ScanStep.saving);

    try {
      // 0. Si es proveedor nuevo, crearlo primero
      String? supplierId = _selectedSupplierId;
      String supplierName;
      String supplierNit;

      if (_createNewSupplier) {
        final newSupplier = await SuppliersDataSource.createQuick(
          name: _supplierNameCtrl.text.trim().isNotEmpty
              ? _supplierNameCtrl.text.trim()
              : _scanResult!.supplier.name ?? 'Proveedor',
          documentType: 'NIT',
          documentNumber: _supplierNitCtrl.text.trim(),
          type: SupplierType.business,
        );
        supplierId = newSupplier.id;
        supplierName = newSupplier.displayName;
        supplierNit = newSupplier.documentNumber;

        // Si hay dirección/teléfono/email, actualizar con datos completos
        if (_supplierAddressCtrl.text.trim().isNotEmpty ||
            _supplierPhoneCtrl.text.trim().isNotEmpty ||
            _supplierEmailCtrl.text.trim().isNotEmpty) {
          await SuppliersDataSource.update(
            newSupplier.copyWith(
              address: _supplierAddressCtrl.text.trim().isNotEmpty
                  ? _supplierAddressCtrl.text.trim()
                  : null,
              phone: _supplierPhoneCtrl.text.trim().isNotEmpty
                  ? _supplierPhoneCtrl.text.trim()
                  : null,
              email: _supplierEmailCtrl.text.trim().isNotEmpty
                  ? _supplierEmailCtrl.text.trim()
                  : null,
            ),
          );
        }
      } else {
        final supplier = await SuppliersDataSource.getById(supplierId!);
        supplierName =
            supplier?.displayName ?? _scanResult!.supplier.name ?? 'Proveedor';
        supplierNit =
            supplier?.documentNumber ??
            _scanResult!.supplier.documentNumber ??
            '';
      }

      // 1. Parsear valores editados
      final subtotal =
          double.tryParse(_subtotalCtrl.text) ?? _scanResult!.subtotal;
      final taxAmount =
          double.tryParse(_taxAmountCtrl.text) ?? _scanResult!.taxAmount;
      final reteFte = double.tryParse(_reteFteCtrl.text) ?? 0;
      final reteIca = double.tryParse(_reteIcaCtrl.text) ?? 0;
      final reteIva = double.tryParse(_reteIvaCtrl.text) ?? 0;
      final total = double.tryParse(_totalCtrl.text) ?? _scanResult!.total;

      DateTime? invoiceDate;
      if (_invoiceDateCtrl.text.isNotEmpty) {
        try {
          invoiceDate = _dateFormat.parse(_invoiceDateCtrl.text);
        } catch (_) {}
      }
      invoiceDate ??= DateTime.now();

      // 2. Crear registro IVA (factura de compra)
      if (_createIvaRecord) {
        final period = getBimonthlyPeriod(invoiceDate);
        final hasReteIva = reteIva > 0;

        // Construir detalle de ítems para notas
        final itemsDetail = _scanResult!.items
            .map((i) {
              return '${i.description} x${i.quantity} = \$${i.total.toStringAsFixed(0)}';
            })
            .join(' | ');

        final ivaInvoice = IvaInvoice(
          invoiceNumber: _invoiceNumberCtrl.text.isNotEmpty
              ? _invoiceNumberCtrl.text
              : 'SIN-NUM',
          invoiceDate: invoiceDate,
          company: supplierName,
          invoiceType: 'COMPRA',
          baseAmount: subtotal,
          ivaAmount: taxAmount,
          totalAmount: total,
          hasReteiva: hasReteIva,
          reteivaAmount: reteIva,
          bimonthlyPeriod: period,
          notes: _notesCtrl.text.isNotEmpty
              ? '${_notesCtrl.text}\n$itemsDetail'
              : itemsDetail,
          companyDocument: supplierNit,
          cufe: _cufeCtrl.text.isNotEmpty ? _cufeCtrl.text : null,
          rteFteAmount: reteFte,
          reteIcaAmount: reteIca,
        );

        await IvaDataSource.createInvoice(ivaInvoice);
      }

      // 3. Crear movimiento de gasto en caja (dispara asiento contable automático)
      if (_createExpenseRecord && _selectedAccountId != null) {
        final refNumber = await AccountsDataSource.getNextReferenceNumber();

        final movement = CashMovement(
          id: '',
          accountId: _selectedAccountId!,
          type: MovementType.expense,
          category: MovementCategory.consumibles,
          amount: total,
          description: 'Factura ${_invoiceNumberCtrl.text} - $supplierName',
          reference: refNumber.toString().padLeft(6, '0'),
          personName: supplierName,
          date: invoiceDate,
        );

        await AccountsDataSource.createMovementWithBalanceUpdate(movement);
      }

      // 4. Actualizar deuda del proveedor
      await SuppliersDataSource.updateDebt(supplierId, total);

      if (!mounted) return;

      // Mostrar éxito
      final actions = <String>[];
      if (_createIvaRecord) actions.add('IVA');
      if (_createExpenseRecord && _selectedAccountId != null) {
        actions.add('Caja + Libro Diario');
      }
      if (_createNewSupplier) actions.add('Proveedor creado');
      actions.add('Deuda proveedor');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Factura ${_invoiceNumberCtrl.text} registrada → ${actions.join(', ')}',
          ),
          backgroundColor: const Color(0xFF388E3C),
          duration: const Duration(seconds: 5),
        ),
      );

      // Retornar el periodo bimestral de la factura para navegación
      final period = getBimonthlyPeriod(invoiceDate);

      // 5. Ofrecer actualizar inventario de materiales
      final invoiceRef = _invoiceNumberCtrl.text.isNotEmpty
          ? _invoiceNumberCtrl.text
          : 'SIN-NUM';
      await _offerInventoryUpdate(invoiceRef);

      if (!mounted) return;
      Navigator.of(context).pop(period);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _ScanStep.review;
        _error = 'Error guardando: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // INVENTARIO: ofrecer actualizar stock tras guardar la factura
  // ---------------------------------------------------------------------------

  /// Intenta hacer match fuzzy entre la descripción del ítem y los materiales
  mat.Material? _findBestMatch(
    String description,
    List<mat.Material> materials,
  ) {
    final descLower = description.toLowerCase();
    final descWords = descLower
        .split(RegExp(r'[\s,.\-/]+'))
        .where((w) => w.length > 2)
        .toList();

    mat.Material? best;
    int bestScore = 0;

    for (final m in materials) {
      final nameLower = m.name.toLowerCase();
      int score = 0;

      // Coincidencia exacta de nombre
      if (nameLower == descLower) score += 10;
      // El nombre contiene la descripción completa
      if (nameLower.contains(descLower)) score += 5;
      // La descripción contiene el nombre
      if (descLower.contains(nameLower)) score += 4;
      // Conteo de palabras coincidentes
      for (final word in descWords) {
        if (nameLower.contains(word)) score += 1;
      }

      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }

    // Solo retornar si hay alguna coincidencia razonable (≥2 puntos)
    return bestScore >= 2 ? best : null;
  }

  /// Muestra el diálogo de confirmación para actualizar inventario.
  /// Retorna true si el usuario confirmó y se aplicaron los cambios.
  Future<bool> _offerInventoryUpdate(String invoiceRef) async {
    if (_scanResult == null || _scanResult!.items.isEmpty) return false;
    if (!mounted) return false;

    // Cargar materiales existentes
    List<mat.Material> allMaterials;
    try {
      allMaterials = await InventoryDataSource.getAllMaterials();
    } catch (_) {
      allMaterials = [];
    }

    // Construir lista de matches
    final matches = _scanResult!.items.map((item) {
      final recommended = _findBestMatch(item.description, allMaterials);
      return _ItemInventoryMatch(
        item: item,
        aiRecommendation: recommended,
        matchedMaterial: recommended,
        createNew: recommended == null,
        selected: true,
      );
    }).toList();

    if (!mounted) return false;

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _InventoryUpdateDialog(
        matches: matches,
        invoiceRef: invoiceRef,
        allMaterials: allMaterials,
      ),
    );

    if (confirmed != true) return false;

    // Aplicar cambios de inventario
    try {
      for (final match in matches.where((m) => m.selected)) {
        final item = match.item;
        final qty = item.quantity;

        if (match.isNew) {
          // Crear nuevo material con los datos de la factura
          final now = DateTime.now();
          final newMaterial = mat.Material(
            id: '',
            code: '',
            name: item.description,
            description: 'Creado automáticamente desde factura $invoiceRef',
            category: 'consumible',
            costPrice: item.unitPrice,
            unitPrice: item.unitPrice,
            stock: qty,
            unit: item.unit.isEmpty ? 'UND' : item.unit.toUpperCase(),
            createdAt: now,
            updatedAt: now,
          );
          final created = await InventoryDataSource.createMaterial(newMaterial);

          // Registrar movimiento de entrada
          try {
            await InventoryDataSource.client.from('material_movements').insert({
              'material_id': created.id,
              'type': 'entrada',
              'quantity': qty,
              'previous_stock': 0.0,
              'new_stock': qty,
              'reason': 'Ingreso por factura de compra $invoiceRef',
              'reference': 'FAC-$invoiceRef',
            });
          } catch (_) {
            // Movimiento no es crítico
          }
        } else {
          final material = match.matchedMaterial!;
          final newStock = material.stock + qty;
          await InventoryDataSource.updateStock(material.id, newStock);

          // Registrar movimiento de entrada
          try {
            await InventoryDataSource.client.from('material_movements').insert({
              'material_id': material.id,
              'type': 'entrada',
              'quantity': qty,
              'previous_stock': material.stock,
              'new_stock': newStock,
              'reason': 'Ingreso por factura de compra $invoiceRef',
              'reference': 'FAC-$invoiceRef',
            });
          } catch (_) {
            // Movimiento no es crítico
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '📦 Inventario actualizado: '
              '${matches.where((m) => m.selected && !m.isNew).length} actualizados, '
              '${matches.where((m) => m.selected && m.isNew).length} creados',
            ),
            backgroundColor: const Color(0xFF00796B),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠ Error al actualizar inventario: $e'),
            backgroundColor: const Color(0xFFF57C00),
          ),
        );
      }
      return false;
    }
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
            // Header
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
                          '📦 Actualizar Inventario de Materiales',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Factura ${widget.invoiceRef} · ${widget.matches.length} ítem(s) detectados',
                          style: TextStyle(
                            color: const Color(0xFFB2DFDB),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF90CAF9)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: const Color(0xFF1976D2),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La IA sugiere materiales existentes. Puedes cambiar la selección '
                        'o elegir "Crear nuevo material" para cada ítem.',
                        style: TextStyle(
                          color: const Color(0xFF1565C0),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Lista de ítems
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: widget.matches.length,
                itemBuilder: (context, index) {
                  return _buildMatchItem(widget.matches[index]);
                },
              ),
            ),
            // Botones
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
    final statusColor = isNew ? const Color(0xFFF57C00) : const Color(0xFF00796B);
    final statusBg = isNew ? const Color(0xFFFFF3E0) : const Color(0xFFE0F2F1);
    final qtyLabel =
        '+${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} '
        '${item.unit.isEmpty ? 'UND' : item.unit}';

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
            // Fila 1: checkbox + descripción de factura + cantidad
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
              // AI recommendation badge
              if (match.aiRecommendation != null)
                Padding(
                  padding: const EdgeInsets.only(left: 34, bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: const Color(0xFF1E88E5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'IA sugiere: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF1E88E5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${match.aiRecommendation!.name} '
                          '(stock: ${match.aiRecommendation!.stock.toStringAsFixed(match.aiRecommendation!.stock % 1 == 0 ? 0 : 2)} ${match.aiRecommendation!.unit})',
                          style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF1976D2),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              // Dropdown de selección
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
                          Icon(
                            Icons.add_circle,
                            size: 16,
                            color: const Color(0xFFF57C00),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Crear nuevo material',
                            style: TextStyle(
                              color: const Color(0xFFF57C00),
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
                            if (isRecommended)
                              Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: const Color(0xFF1E88E5),
                              )
                            else
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 14,
                                color: const Color(0xFFFAFAFA)0,
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
                  onChanged: (val) {
                    setState(() {
                      if (val == '__new__') {
                        match.createNew = true;
                        match.matchedMaterial = null;
                      } else {
                        match.createNew = false;
                        match.matchedMaterial = widget.allMaterials.firstWhere(
                          (m) => m.id == val,
                        );
                      }
                    });
                  },
                ),
              ),
              // Info sobre resultado de la acción
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
                            ? 'Se creará "${item.description}" con stock inicial de $qtyLabel'
                            : 'Se sumará $qtyLabel a "${match.matchedMaterial!.name}" '
                                  '(${match.matchedMaterial!.stock.toStringAsFixed(match.matchedMaterial!.stock % 1 == 0 ? 0 : 2)} → '
                                  '${(match.matchedMaterial!.stock + item.quantity).toStringAsFixed((match.matchedMaterial!.stock + item.quantity) % 1 == 0 ? 0 : 2)} ${match.matchedMaterial!.unit})',
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