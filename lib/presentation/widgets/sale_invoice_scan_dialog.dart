import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/utils/helpers.dart';
import '../../data/datasources/invoice_scanner_service.dart';
import '../../data/datasources/invoices_datasource.dart';
import '../../data/datasources/customers_datasource.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../data/datasources/products_datasource.dart';
import '../../data/datasources/iva_datasource.dart';
import '../../data/datasources/scan_corrections_datasource.dart';
import '../../data/providers/invoices_provider.dart';
import '../../data/providers/customers_provider.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/material.dart' as mat;
import '../../domain/entities/product.dart';
import 'material_form_dialog.dart';
import 'customer_form_dialog.dart';
import 'quick_product_dialog.dart';

// =====================================================
// SaleInvoiceScanDialog — Reconciliación de Deudas
// Escanea facturas de VENTA antiguas/físicas y las
// registra en invoices + invoice_items + iva_invoices.
// Asocia con cliente existente para respaldar deudas
// pendientes (CxC) con la factura real correspondiente.
// =====================================================

enum _ScanStep { selectImage, scanning, review, saving }

enum _BatchStatus { pending, scanning, done, error }

/// Asocia cada item escaneado con su producto/material en inventario
class _ItemMatch {
  final ScannedInvoiceItem scannedItem;
  Product? matchedProduct;
  mat.Material? matchedMaterial;
  bool selected = true;

  _ItemMatch({required this.scannedItem});

  bool get hasMatch => matchedProduct != null || matchedMaterial != null;

  String get matchLabel {
    if (matchedProduct != null) return matchedProduct!.name;
    if (matchedMaterial != null) return matchedMaterial!.name;
    return 'Sin asociar';
  }
}

class _BatchItem {
  final int index;
  final PlatformFile file;
  _BatchStatus status;
  InvoiceScanResult? result;
  String? scanError;
  bool isExpanded;
  bool selected;
  bool saved;
  String? saveError;

  // Datos editables extraídos
  final TextEditingController invoiceNumberCtrl;
  final TextEditingController invoiceDateCtrl;
  final TextEditingController dueDateCtrl;
  final TextEditingController clientNameCtrl;
  final TextEditingController clientNitCtrl;
  final TextEditingController subtotalCtrl;
  final TextEditingController taxAmountCtrl;
  final TextEditingController taxRateCtrl;
  final TextEditingController totalCtrl;
  final TextEditingController notesCtrl;

  // Cliente asociado
  Customer? matchedCustomer;
  bool createNewCustomer;

  // Control de inventario
  bool deductInventory;

  // Tipo de pago: cash, credit, advance
  String paymentType;

  // Items de la factura con match a productos/materiales
  List<_ItemMatch> itemMatches;

  _BatchItem({required this.index, required this.file})
    : status = _BatchStatus.pending,
      result = null,
      scanError = null,
      isExpanded = false,
      selected = true,
      saved = false,
      saveError = null,
      matchedCustomer = null,
      createNewCustomer = false,
      deductInventory = false,
      paymentType = 'cash',
      itemMatches = [],
      invoiceNumberCtrl = TextEditingController(),
      invoiceDateCtrl = TextEditingController(),
      dueDateCtrl = TextEditingController(),
      clientNameCtrl = TextEditingController(),
      clientNitCtrl = TextEditingController(),
      subtotalCtrl = TextEditingController(text: '0.00'),
      taxAmountCtrl = TextEditingController(text: '0.00'),
      taxRateCtrl = TextEditingController(text: '0.00'),
      totalCtrl = TextEditingController(text: '0.00'),
      notesCtrl = TextEditingController();

  void populateFromResult(
    InvoiceScanResult r,
    DateFormat dateFormat,
    List<Customer> customers,
    List<Product> products,
    List<mat.Material> materials,
  ) {
    result = r;
    status = _BatchStatus.done;
    invoiceNumberCtrl.text = r.invoiceNumber ?? '';
    invoiceDateCtrl.text = r.invoiceDate != null
        ? dateFormat.format(r.invoiceDate!)
        : '';
    dueDateCtrl.text = '';
    // En facturas de venta, el "buyer" es el cliente
    clientNameCtrl.text = r.buyerName ?? '';
    clientNitCtrl.text = r.buyerDocument ?? '';
    subtotalCtrl.text = r.subtotal.toStringAsFixed(2);
    taxRateCtrl.text = r.taxRate.toStringAsFixed(2);
    taxAmountCtrl.text = r.taxAmount.toStringAsFixed(2);
    totalCtrl.text = r.total.toStringAsFixed(2);

    // Auto-detectar si es factura histórica (>30 días) → no descontar inventario
    final invoiceDate = r.invoiceDate ?? DateTime.now();
    final daysSinceInvoice = DateTime.now().difference(invoiceDate).inDays;
    deductInventory = daysSinceInvoice <= 30;

    // Matchear items con productos/materiales del inventario
    itemMatches = r.items.map((si) {
      final match = _ItemMatch(scannedItem: si);
      // 1. Intentar match con producto
      match.matchedProduct = _findBestProductMatch(si.description, products);
      // 2. Si no hay producto, intentar con material
      if (match.matchedProduct == null) {
        match.matchedMaterial = _findBestMaterialMatch(
          si.description,
          materials,
        );
      }
      return match;
    }).toList();

    // Intentar matchear con cliente existente por NIT/documento
    final clientDoc = (r.buyerDocument ?? '').trim();
    final clientName = (r.buyerName ?? '').trim().toLowerCase();
    // También intentar con el supplier (si la factura fue emitida POR el cliente al molino)
    final supplierName = (r.supplier.name ?? '').trim().toLowerCase();
    final supplierDoc = (r.supplier.documentNumber ?? '').trim();

    // 1. Match por documento del buyer
    if (clientDoc.isNotEmpty) {
      matchedCustomer = customers
          .where((c) => c.documentNumber.trim() == clientDoc)
          .firstOrNull;
    }
    // 2. Match por documento del supplier
    if (matchedCustomer == null && supplierDoc.isNotEmpty) {
      matchedCustomer = customers
          .where((c) => c.documentNumber.trim() == supplierDoc)
          .firstOrNull;
    }
    // 3. Match por nombre (buyer o supplier, busca en ambas direcciones)
    if (matchedCustomer == null) {
      final namesToTry = [clientName, supplierName].where((n) => n.isNotEmpty);
      for (final searchName in namesToTry) {
        matchedCustomer = customers.where((c) {
          final cn = c.name.toLowerCase();
          final tn = c.tradeName?.toLowerCase() ?? '';
          return cn.contains(searchName) ||
              searchName.contains(cn) ||
              (tn.isNotEmpty &&
                  (tn.contains(searchName) || searchName.contains(tn)));
        }).firstOrNull;
        if (matchedCustomer != null) break;
      }
    }
  }

  /// Match item escaneado con producto por nombre (scoring)
  static Product? _findBestProductMatch(
    String description,
    List<Product> products,
  ) {
    final descLower = description.toLowerCase();
    final descWords = descLower
        .split(RegExp(r'[\s,.\-/]+'))
        .where((w) => w.length > 2)
        .toList();
    final numericRegex = RegExp(r'\d+[.,/]?\d*\s*(?:mm|cm|m|kg|lb|")?');
    final descNums = numericRegex
        .allMatches(descLower)
        .map((m) => m.group(0)!.replaceAll(',', '.').trim())
        .toSet();

    Product? best;
    int bestScore = 0;
    for (final p in products) {
      final nameLower = p.name.toLowerCase();
      final matNums = numericRegex
          .allMatches(nameLower)
          .map((m) => m.group(0)!.replaceAll(',', '.').trim())
          .toSet();
      if (descNums.isNotEmpty && matNums.isNotEmpty) {
        if (!descNums.any((n) => matNums.contains(n))) continue;
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
        best = p;
      }
    }
    return bestScore >= 2 ? best : null;
  }

  /// Match item escaneado con material por nombre (scoring)
  static mat.Material? _findBestMaterialMatch(
    String description,
    List<mat.Material> materials,
  ) {
    final descLower = description.toLowerCase();
    final descWords = descLower
        .split(RegExp(r'[\s,.\-/]+'))
        .where((w) => w.length > 2)
        .toList();
    final numericRegex = RegExp(r'\d+[.,/]?\d*\s*(?:mm|cm|m|kg|lb|")?');
    final descNums = numericRegex
        .allMatches(descLower)
        .map((m) => m.group(0)!.replaceAll(',', '.').trim())
        .toSet();

    mat.Material? best;
    int bestScore = 0;
    for (final m in materials) {
      final nameLower = m.name.toLowerCase();
      final matNums = numericRegex
          .allMatches(nameLower)
          .map((m) => m.group(0)!.replaceAll(',', '.').trim())
          .toSet();
      if (descNums.isNotEmpty && matNums.isNotEmpty) {
        if (!descNums.any((n) => matNums.contains(n))) continue;
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

  void dispose() {
    for (final c in [
      invoiceNumberCtrl,
      invoiceDateCtrl,
      dueDateCtrl,
      clientNameCtrl,
      clientNitCtrl,
      subtotalCtrl,
      taxAmountCtrl,
      taxRateCtrl,
      totalCtrl,
      notesCtrl,
    ]) {
      c.dispose();
    }
  }
}

class SaleInvoiceScanDialog extends ConsumerStatefulWidget {
  const SaleInvoiceScanDialog({super.key});

  @override
  ConsumerState<SaleInvoiceScanDialog> createState() =>
      _SaleInvoiceScanDialogState();

  /// Abre la página fullscreen de escaneo de facturas de venta.
  /// Retorna true si se guardaron facturas, false/null si se canceló.
  static Future<bool?> show(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => const SaleInvoiceScanDialog(),
      ),
    );
  }
}

class _SaleInvoiceScanDialogState extends ConsumerState<SaleInvoiceScanDialog> {
  _ScanStep _step = _ScanStep.selectImage;
  final List<_BatchItem> _items = [];
  int _savingIndex = 0;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  List<Customer> _allCustomers = [];
  List<Product> _allProducts = [];
  List<mat.Material> _allMaterials = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        CustomersDataSource.getAll(activeOnly: false),
        ProductsDataSource.getAll(),
        InventoryDataSource.getAllMaterials(),
      ]);
      _allCustomers = results[0] as List<Customer>;
      _allProducts = results[1] as List<Product>;
      _allMaterials = results[2] as List<mat.Material>;
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  int get _doneCount =>
      _items.where((i) => i.status == _BatchStatus.done).length;
  int get _selectedCount =>
      _items.where((i) => i.selected && i.status == _BatchStatus.done).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildContent()),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    const titles = {
      _ScanStep.selectImage: 'Escanear Facturas de Venta',
      _ScanStep.scanning: 'Analizando con IA...',
      _ScanStep.review: 'Revisar y Asociar',
      _ScanStep.saving: 'Registrando...',
    };
    String? subtitle;
    if (_step == _ScanStep.scanning) {
      subtitle = '$_doneCount / ${_items.length} procesadas';
    } else if (_step == _ScanStep.review) {
      final total = _items.fold<double>(
        0,
        (s, i) => s + (double.tryParse(i.totalCtrl.text) ?? 0),
      );
      subtitle =
          '${_items.length} factura(s) · ${Helpers.formatCurrency(total)}';
    } else if (_step == _ScanStep.saving) {
      subtitle = '$_savingIndex / $_selectedCount reconciliadas';
    }
    return AppBar(
      backgroundColor: const Color(0xFFE65100),
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(false),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titles[_step] ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
      actions: [
        if (_step == _ScanStep.review)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              side: BorderSide.none,
              label: Text(
                '${_items.where((i) => i.matchedCustomer != null).length}/${_items.length} asociados',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              avatar: const Icon(Icons.people, color: Colors.white, size: 16),
            ),
          ),
      ],
    );
  }

  // ─── Content ───────────────────────────────────────────────────
  Widget _buildContent() {
    switch (_step) {
      case _ScanStep.selectImage:
        return _buildFileSelector();
      case _ScanStep.scanning:
        return _buildScanningProgress();
      case _ScanStep.review:
        return _buildReviewList();
      case _ScanStep.saving:
        return _buildSavingProgress();
    }
  }

  // ─── File Selector ─────────────────────────────────────────────
  Widget _buildFileSelector() {
    final cs = Theme.of(context).colorScheme;
    final showCamera = !kIsWeb;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Opciones: galería/archivos y cámara
          if (showCamera) ...[
            Row(
              children: [
                Expanded(
                  child: _buildSelectorCard(
                    icon: Icons.photo_library,
                    label: 'Galería / Archivos',
                    subtitle: 'JPG, PNG, PDF',
                    color: cs.primary,
                    onTap: _pickFiles,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSelectorCard(
                    icon: Icons.camera_alt,
                    label: 'Tomar Foto',
                    subtitle: 'Cámara del celular',
                    color: const Color(0xFFE65100),
                    onTap: _takePhoto,
                  ),
                ),
              ],
            ),
          ] else ...[
            InkWell(
              onTap: _pickFiles,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: cs.primary.withValues(alpha: 0.05),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.document_scanner,
                      size: 48,
                      color: cs.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Seleccionar fotos de facturas antiguas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'JPG, PNG, PDF · Se reconciliarán deudas existentes con facturas reales',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...List.generate(
              _items.length,
              (i) => ListTile(
                leading: Icon(Icons.image, color: cs.primary),
                title: Text(
                  _items[i].file.name,
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _items[i].dispose();
                    _items.removeAt(i);
                  }),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Información de lo que hará
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE0B2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Color(0xFFF57C00),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lo que hará este proceso:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: const Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoPoint(
                  Icons.auto_awesome,
                  'Analiza cada foto con IA (OpenAI Vision)',
                ),
                _buildInfoPoint(
                  Icons.person_search,
                  'Compara con clientes existentes y sus deudas',
                ),
                _buildInfoPoint(
                  Icons.receipt_long,
                  'Crea la factura real (VTA) que respalda la deuda',
                ),
                _buildInfoPoint(
                  Icons.inventory_2,
                  'Asocia items con productos/materiales y descuenta stock',
                ),
                _buildInfoPoint(
                  Icons.account_balance_wallet,
                  'Asocia la deuda (CxC) del cliente con su factura',
                ),
                _buildInfoPoint(
                  Icons.calculate,
                  'Registra en IVA para declaración',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 26),
          Icon(icon, size: 14, color: const Color(0xFFF57C00)),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  // ─── Scanning Progress ─────────────────────────────────────────
  Widget _buildScanningProgress() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Procesando $_doneCount de ${_items.length} facturas...',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ...List.generate(
            _items.length,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (_items[i].status == _BatchStatus.done)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF2E7D32),
                      size: 20,
                    )
                  else if (_items[i].status == _BatchStatus.error)
                    const Icon(Icons.error, color: Color(0xFFC62828), size: 20)
                  else if (_items[i].status == _BatchStatus.scanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.schedule,
                      color: Color(0xFF9E9E9E),
                      size: 20,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _items[i].file.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (_items[i].scanError != null)
                    Text(
                      'Error',
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFFC62828),
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

  // ─── Review List ───────────────────────────────────────────────
  Widget _buildReviewList() {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final listPadding = screenWidth < 500 ? 8.0 : 16.0;
    return ListView.builder(
      padding: EdgeInsets.all(listPadding),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        if (item.status != _BatchStatus.done) {
          return Card(
            color: const Color(0xFFFFEBEE),
            child: ListTile(
              leading: const Icon(Icons.error, color: Color(0xFFC62828)),
              title: Text(item.file.name),
              subtitle: Text(item.scanError ?? 'Error al escanear'),
            ),
          );
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              // Header con checkbox y nombre de archivo
              ListTile(
                leading: Checkbox(
                  value: item.selected,
                  onChanged: (v) => setState(() => item.selected = v ?? true),
                ),
                title: Text(
                  item.invoiceNumberCtrl.text.isNotEmpty
                      ? 'Factura ${item.invoiceNumberCtrl.text}'
                      : item.file.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${item.clientNameCtrl.text} · ${Helpers.formatCurrency(double.tryParse(item.totalCtrl.text) ?? 0)}',
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: LayoutBuilder(
                  builder: (context, constraints) {
                    // On narrow screens, only show icon + expand
                    final isNarrow = MediaQuery.of(context).size.width < 500;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: isNarrow ? 40 : 180,
                          ),
                          decoration: BoxDecoration(
                            color: item.matchedCustomer != null
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: isNarrow
                              ? Icon(
                                  item.matchedCustomer != null
                                      ? Icons.person
                                      : Icons.person_search,
                                  size: 16,
                                  color: item.matchedCustomer != null
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFF57C00),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      item.matchedCustomer != null
                                          ? Icons.person
                                          : Icons.person_search,
                                      size: 14,
                                      color: item.matchedCustomer != null
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFF57C00),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        item.matchedCustomer != null
                                            ? item.matchedCustomer!.displayName
                                            : 'Sin asociar',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: item.matchedCustomer != null
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFFF57C00),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        IconButton(
                          icon: Icon(
                            item.isExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          onPressed: () => setState(
                            () => item.isExpanded = !item.isExpanded,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Detalles expandibles
              if (item.isExpanded)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    screenWidth < 500 ? 10 : 16,
                    0,
                    screenWidth < 500 ? 10 : 16,
                    screenWidth < 500 ? 10 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),

                      // ── Asociar Cliente ──
                      _buildCustomerAssociation(item),

                      const SizedBox(height: 16),

                      // ── Datos de la factura ──
                      Text(
                        'Datos de la Factura',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 500;
                          if (isNarrow) {
                            return Column(
                              children: [
                                TextField(
                                  controller: item.invoiceNumberCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'N° Factura',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: item.invoiceDateCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Fecha emisión',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          hintText: 'dd/mm/aaaa',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: item.dueDateCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Fecha vencimiento',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          hintText: 'dd/mm/aaaa',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: item.subtotalCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Subtotal',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          prefixText: '\$ ',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: item.taxAmountCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'IVA',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          prefixText: '\$ ',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: item.totalCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Total',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                          prefixText: '\$ ',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: item.invoiceNumberCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'N° Factura',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: item.invoiceDateCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Fecha emisión',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        hintText: 'dd/mm/aaaa',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: item.dueDateCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Fecha vencimiento',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        hintText: 'dd/mm/aaaa',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: item.subtotalCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Subtotal',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        prefixText: '\$ ',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: item.taxAmountCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'IVA',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        prefixText: '\$ ',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: item.totalCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Total',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        prefixText: '\$ ',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),

                      // ── Items escaneados con match de inventario ──
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, itemHeaderConstraints) {
                          final narrow = itemHeaderConstraints.maxWidth < 360;
                          return Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Items (${item.itemMatches.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: cs.primary,
                                ),
                              ),
                              if (item.itemMatches.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        item.itemMatches.every(
                                          (m) => m.hasMatch,
                                        )
                                        ? const Color(0xFFE8F5E9)
                                        : const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${item.itemMatches.where((m) => m.hasMatch).length}/${item.itemMatches.length} inv.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          item.itemMatches.every(
                                            (m) => m.hasMatch,
                                          )
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFF57C00),
                                    ),
                                  ),
                                ),
                              if (item.itemMatches.any((m) => !m.hasMatch))
                                SizedBox(
                                  height: 28,
                                  child: narrow
                                      ? FilledButton(
                                          onPressed: () =>
                                              _showAutoCreateDialog(item),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF1565C0,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                          ),
                                          child: Text(
                                            'Auto-crear ${item.itemMatches.where((m) => !m.hasMatch).length}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        )
                                      : FilledButton.icon(
                                          onPressed: () =>
                                              _showAutoCreateDialog(item),
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 14,
                                          ),
                                          label: Text(
                                            'Auto-crear ${item.itemMatches.where((m) => !m.hasMatch).length}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF1565C0,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                          ),
                                        ),
                                ),
                              SizedBox(
                                height: 28,
                                child: narrow
                                    ? OutlinedButton(
                                        onPressed: () =>
                                            _showAddItemManualDialog(item),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          side: BorderSide(
                                            color: cs.primary.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          '+ Item',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      )
                                    : OutlinedButton.icon(
                                        onPressed: () =>
                                            _showAddItemManualDialog(item),
                                        icon: const Icon(Icons.add, size: 14),
                                        label: const Text(
                                          'Agregar item',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          side: BorderSide(
                                            color: cs.primary.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                      if (item.itemMatches.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 500;
                            if (isNarrow) {
                              // Mobile: card-based item list
                              return Column(
                                children: item.itemMatches.map((im) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: cs.outlineVariant,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      color: im.hasMatch
                                          ? const Color(0xFFF1F8E9)
                                          : const Color(0xFFFFF8E1),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              im.hasMatch
                                                  ? Icons.check_circle
                                                  : Icons.warning_amber_rounded,
                                              size: 18,
                                              color: im.hasMatch
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFF57C00),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                im.scannedItem.description,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${im.scannedItem.quantity.toStringAsFixed(0)} × \$${im.scannedItem.unitPrice.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () =>
                                                    _showItemMatchPicker(
                                                      item,
                                                      im,
                                                    ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: im.hasMatch
                                                        ? const Color(
                                                            0xFFE8F5E9,
                                                          )
                                                        : const Color(
                                                            0xFFFFF8E1,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: im.hasMatch
                                                          ? const Color(
                                                              0xFFA5D6A7,
                                                            )
                                                          : const Color(
                                                              0xFFFFE082,
                                                            ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        im.hasMatch
                                                            ? Icons.inventory_2
                                                            : Icons
                                                                  .help_outline,
                                                        size: 16,
                                                        color: im.hasMatch
                                                            ? const Color(
                                                                0xFF2E7D32,
                                                              )
                                                            : const Color(
                                                                0xFFF57C00,
                                                              ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          im.matchLabel,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: im.hasMatch
                                                                ? const Color(
                                                                    0xFF2E7D32,
                                                                  )
                                                                : const Color(
                                                                    0xFFF57C00,
                                                                  ),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      Icon(
                                                        Icons.swap_horiz,
                                                        size: 14,
                                                        color:
                                                            cs.onSurfaceVariant,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              Helpers.formatCurrency(
                                                im.scannedItem.total,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            }
                            // Desktop: table-based layout
                            return Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: cs.outlineVariant),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerLow,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        SizedBox(width: 28),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Descripción',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            'Producto / Material',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Cant.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Total',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...item.itemMatches.map(
                                    (im) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 28,
                                            child: Icon(
                                              im.hasMatch
                                                  ? Icons.check_circle
                                                  : Icons.warning_amber_rounded,
                                              size: 16,
                                              color: im.hasMatch
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFF57C00),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              im.scannedItem.description,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 3,
                                            child: InkWell(
                                              onTap: () => _showItemMatchPicker(
                                                item,
                                                im,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: im.hasMatch
                                                      ? const Color(0xFFE8F5E9)
                                                      : const Color(0xFFFFF8E1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: im.hasMatch
                                                        ? const Color(
                                                            0xFFA5D6A7,
                                                          )
                                                        : const Color(
                                                            0xFFFFE082,
                                                          ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      im.hasMatch
                                                          ? Icons.inventory_2
                                                          : Icons.help_outline,
                                                      size: 14,
                                                      color: im.hasMatch
                                                          ? const Color(
                                                              0xFF2E7D32,
                                                            )
                                                          : const Color(
                                                              0xFFF57C00,
                                                            ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        im.matchLabel,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: im.hasMatch
                                                              ? const Color(
                                                                  0xFF2E7D32,
                                                                )
                                                              : const Color(
                                                                  0xFFF57C00,
                                                                ),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons.swap_horiz,
                                                      size: 12,
                                                      color:
                                                          cs.onSurfaceVariant,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              im.scannedItem.quantity
                                                  .toStringAsFixed(0),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              Helpers.formatCurrency(
                                                im.scannedItem.total,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
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
                          },
                        ),
                      ],

                      // ── Control de inventario ──
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => setState(
                          () => item.deductInventory = !item.deductInventory,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: item.deductInventory
                                ? const Color(0xFFE3F2FD)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: item.deductInventory
                                  ? const Color(0xFF90CAF9)
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: item.deductInventory,
                                  onChanged: (v) => setState(
                                    () => item.deductInventory = v ?? false,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Descontar inventario',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      item.deductInventory
                                          ? 'Se restará stock al registrar'
                                          : 'Solo registra factura y deuda CxC, sin mover stock',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Tipo de pago ──
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Tipo de pago:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          _buildPaymentTypeChip(
                            item,
                            'cash',
                            'Contado',
                            Icons.payments,
                            const Color(0xFF2E7D32),
                          ),
                          _buildPaymentTypeChip(
                            item,
                            'credit',
                            'Crédito',
                            Icons.calendar_month,
                            const Color(0xFFF9A825),
                          ),
                          _buildPaymentTypeChip(
                            item,
                            'advance',
                            'Adelanto',
                            Icons.savings,
                            const Color(0xFF7B1FA2),
                          ),
                        ],
                      ),

                      // ── Notas ──
                      const SizedBox(height: 12),
                      TextField(
                        controller: item.notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notas',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── Payment Type Chip ─────────────────────────────────────────
  Widget _buildPaymentTypeChip(
    _BatchItem item,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final selected = item.paymentType == value;
    return InkWell(
      onTap: () => setState(() => item.paymentType = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.grey[400]!,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? color : Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Customer Association ──────────────────────────────────────
  Widget _buildCustomerAssociation(_BatchItem item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: item.matchedCustomer != null
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: item.matchedCustomer != null
                  ? const Color(0xFFA5D6A7)
                  : const Color(0xFFFFE082),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    item.matchedCustomer != null
                        ? Icons.person
                        : Icons.person_search,
                    size: 18,
                    color: item.matchedCustomer != null
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFF57C00),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.matchedCustomer != null
                          ? 'Cliente: ${item.matchedCustomer!.displayName}'
                          : 'Sin cliente — seleccionar o crear',
                      style: TextStyle(
                        fontSize: isNarrow ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: item.matchedCustomer != null
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFF57C00),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isNarrow) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        onPressed: () => _showCustomerPickerDialog(item),
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: Text(
                          item.matchedCustomer != null
                              ? 'Cambiar'
                              : 'Seleccionar',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (isNarrow) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: OutlinedButton.icon(
                    onPressed: () => _showCustomerPickerDialog(item),
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: Text(
                      item.matchedCustomer != null
                          ? 'Cambiar cliente'
                          : 'Seleccionar cliente',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ],
              if (item.matchedCustomer != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text(
                        '${item.matchedCustomer!.documentType.displayName}: ${item.matchedCustomer!.documentNumber}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF616161),
                        ),
                      ),
                    ),
                    if (item.matchedCustomer!.currentBalance > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Deuda: ${Helpers.formatCurrency(item.matchedCustomer!.currentBalance)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFC62828),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (item.matchedCustomer == null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Text(
                        'De factura: ${item.clientNameCtrl.text} · ${item.clientNitCtrl.text}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF616161),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 28,
                      child: FilledButton.icon(
                        onPressed: () => _createCustomerFromScan(item),
                        icon: const Icon(Icons.person_add, size: 14),
                        label: const Text(
                          'Crear Cliente',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF57C00),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── Customer Picker Dialog ────────────────────────────────────
  void _showCustomerPickerDialog(_BatchItem item) {
    String search = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) {
          final filtered = search.isEmpty
              ? _allCustomers
              : _allCustomers.where((c) {
                  final q = search.toLowerCase();
                  return c.name.toLowerCase().contains(q) ||
                      c.documentNumber.contains(q) ||
                      (c.tradeName?.toLowerCase().contains(q) ?? false);
                }).toList();

          return AlertDialog(
            title: const Text('Seleccionar Cliente'),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width < 500
                  ? double.maxFinite
                  : 450,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre o NIT...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setInnerState(() => search = v),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('Sin resultados'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Theme.of(
                                    ctx,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  child: Text(
                                    c.name.isNotEmpty
                                        ? c.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: Theme.of(ctx).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  c.displayName,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  '${c.documentType.displayName}: ${c.documentNumber}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: c.currentBalance > 0
                                    ? Text(
                                        Helpers.formatCurrency(
                                          c.currentBalance,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFC62828),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  setState(() => item.matchedCustomer = c);
                                },
                                dense: true,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Create Customer from Scan ─────────────────────────────────
  Future<void> _createCustomerFromScan(_BatchItem item) async {
    final scanName = item.clientNameCtrl.text.trim();
    final scanNit = item.clientNitCtrl.text.trim();

    final isNit = scanNit.length >= 9;

    final customer = await CustomerFormDialog.show(
      context,
      suggestedName: scanName,
      suggestedDocNumber: scanNit.isNotEmpty ? scanNit : null,
      suggestedDocType: isNit ? DocumentType.nit : DocumentType.cc,
      suggestedType: isNit ? CustomerType.business : CustomerType.individual,
      showScanBanner: true,
    );

    if (customer != null) {
      _allCustomers.add(customer);
      setState(() => item.matchedCustomer = customer);
    }
  }

  // ─── Saving Progress ───────────────────────────────────────────
  Widget _buildSavingProgress() {
    final toSave = _items
        .where((i) => i.selected && i.status == _BatchStatus.done)
        .toList();
    final allDone = toSave.every((i) => i.saved || i.saveError != null);
    final savedCount = toSave.where((i) => i.saved).length;
    final errorCount = toSave.where((i) => i.saveError != null).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (!allDone) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Reconciliando $_savingIndex de $_selectedCount facturas...',
              style: const TextStyle(fontSize: 16),
            ),
          ] else ...[
            Icon(
              errorCount == 0
                  ? Icons.check_circle
                  : Icons.warning_amber_rounded,
              color: errorCount == 0
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFF57C00),
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              errorCount == 0
                  ? '\u00a1Reconciliación completa!'
                  : '$savedCount reconciliada(s), $errorCount con error',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],

          // ── Resumen de facturas ──
          const SizedBox(height: 16),
          ...toSave.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  if (item.saved)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF2E7D32),
                      size: 20,
                    )
                  else if (item.saveError != null)
                    const Icon(Icons.error, color: Color(0xFFC62828), size: 20)
                  else
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.invoiceNumberCtrl.text.isNotEmpty
                          ? 'Factura ${item.invoiceNumberCtrl.text}'
                          : item.file.name,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (item.saved)
                    const Text(
                      'Registrada',
                      style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
                    )
                  else if (item.saveError != null)
                    Flexible(
                      child: Text(
                        item.saveError!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFC62828),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Panel de reconciliación ── (solo cuando terminó)
          if (allDone && savedCount > 0) ...[
            const SizedBox(height: 24),
            _buildReconciliationSummary(toSave),
          ],
        ],
      ),
    );
  }

  Widget _buildReconciliationSummary(List<_BatchItem> savedItems) {
    final saved = savedItems.where((i) => i.saved).toList();

    // Total CxC generada
    final totalCxC = saved.fold<double>(
      0,
      (s, i) => s + (double.tryParse(i.totalCtrl.text) ?? 0),
    );

    // Clientes únicos
    final customerMap = <String, double>{};
    for (final item in saved) {
      final cName = item.matchedCustomer?.displayName ?? 'Sin cliente';
      final total = double.tryParse(item.totalCtrl.text) ?? 0;
      customerMap[cName] = (customerMap[cName] ?? 0) + total;
    }

    // Items de inventario
    int itemsAssociated = 0;
    int itemsUnmatched = 0;
    for (final item in saved) {
      for (final im in item.itemMatches) {
        if (im.hasMatch) {
          itemsAssociated++;
        } else {
          itemsUnmatched++;
        }
      }
    }

    // Inventario descontado o no
    final withDeduction = saved.where((i) => i.deductInventory).length;
    final withoutDeduction = saved.where((i) => !i.deductInventory).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de Reconciliación',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 20),

          // Estadísticas generales
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _summaryChip(
                Icons.receipt_long,
                '${saved.length} factura(s)',
                const Color(0xFF1565C0),
              ),
              _summaryChip(
                Icons.people,
                '${customerMap.length} cliente(s)',
                const Color(0xFF2E7D32),
              ),
              _summaryChip(
                Icons.account_balance_wallet,
                Helpers.formatCurrency(totalCxC),
                const Color(0xFFC62828),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Deuda por cliente
          const Text(
            'Deudas CxC por Cliente:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ...customerMap.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.person, size: 14, color: Color(0xFF616161)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(e.key, style: const TextStyle(fontSize: 12)),
                  ),
                  Text(
                    Helpers.formatCurrency(e.value),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC62828),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Items
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (itemsAssociated > 0)
                _summaryChip(
                  Icons.inventory_2,
                  '$itemsAssociated asociado(s)',
                  const Color(0xFF2E7D32),
                ),
              if (itemsUnmatched > 0)
                _summaryChip(
                  Icons.error_outline,
                  '$itemsUnmatched sin asociar (requerido)',
                  const Color(0xFFC62828),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Inventario
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: withDeduction > 0
                  ? const Color(0xFFE3F2FD)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  withDeduction > 0 ? Icons.warning_amber : Icons.info_outline,
                  size: 14,
                  color: withDeduction > 0
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF616161),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    withDeduction > 0
                        ? '$withDeduction con descuento de inventario, $withoutDeduction sin descuento'
                        : 'Inventario NO descontado (solo deudas CxC registradas)',
                    style: TextStyle(
                      fontSize: 11,
                      color: withDeduction > 0
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF616161),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions Bar ───────────────────────────────────────────────
  Widget _buildActions() {
    switch (_step) {
      case _ScanStep.selectImage:
        return _actionsBar(
          left: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          right: LayoutBuilder(
            builder: (ctx, constraints) {
              final narrow = constraints.maxWidth < 180;
              return FilledButton.icon(
                onPressed: _items.isEmpty ? null : _startScanning,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _items.isEmpty
                      ? (narrow ? 'Selecciona' : 'Selecciona archivos')
                      : (narrow
                            ? 'Analizar ${_items.length}'
                            : 'Analizar ${_items.length} factura(s)'),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        );
      case _ScanStep.scanning:
        return _actionsBar(
          left: const SizedBox.shrink(),
          right: const SizedBox.shrink(),
        );
      case _ScanStep.review:
        final unassociated = _items
            .where(
              (i) =>
                  i.selected &&
                  i.status == _BatchStatus.done &&
                  i.matchedCustomer == null,
            )
            .length;
        final isNarrowActions = MediaQuery.of(context).size.width < 500;
        return _actionsBar(
          left: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: isNarrowActions
                      ? const EdgeInsets.symmetric(horizontal: 6)
                      : null,
                ),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 2),
              OutlinedButton.icon(
                onPressed: _addMorePhotos,
                icon: const Icon(Icons.add_a_photo, size: 16),
                label: isNarrowActions
                    ? const SizedBox.shrink()
                    : const Text('Otra foto', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrowActions ? 8 : 10,
                  ),
                ),
              ),
            ],
          ),
          center: unassociated > 0
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '$unassociated sin cli.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFF57C00),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : null,
          right: LayoutBuilder(
            builder: (ctx, constraints) {
              final narrow = constraints.maxWidth < 140;
              return FilledButton.icon(
                onPressed: _selectedCount == 0 ? null : _saveAll,
                icon: const Icon(Icons.save, size: 18),
                label: Text(
                  narrow ? '$_selectedCount' : 'Reconciliar $_selectedCount',
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 16),
                ),
              );
            },
          ),
        );
      case _ScanStep.saving:
        final allDone = _items
            .where((i) => i.selected && i.status == _BatchStatus.done)
            .every((i) => i.saved || i.saveError != null);
        return _actionsBar(
          left: allDone
              ? LayoutBuilder(
                  builder: (ctx, constraints) {
                    final narrow = constraints.maxWidth < 180;
                    return OutlinedButton.icon(
                      onPressed: _resetForNewScan,
                      icon: const Icon(Icons.document_scanner, size: 18),
                      label: Text(
                        narrow ? 'Otra' : 'Escanear otra factura',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                )
              : const SizedBox.shrink(),
          right: allDone
              ? FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Cerrar'),
                )
              : const SizedBox.shrink(),
        );
    }
  }

  Widget _actionsBar({
    required Widget left,
    required Widget right,
    Widget? center,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width < 500 ? 12 : 20,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Flexible(child: left),
          if (center != null) ...[
            const SizedBox(width: 4),
            Flexible(child: center),
          ],
          const SizedBox(width: 8),
          Flexible(child: right),
        ],
      ),
    );
  }

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
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color.withOpacity(0.7)),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Logic: Pick Files ─────────────────────────────────────────
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      for (int i = 0; i < result.files.length; i++) {
        _items.add(_BatchItem(index: _items.length, file: result.files[i]));
      }
    });
  }

  // ─── Logic: Take Photo with Camera ─────────────────────────────
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    final fileName = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Convertir a PlatformFile para reusar el flujo existente
    final platformFile = PlatformFile(
      name: fileName,
      size: bytes.length,
      bytes: Uint8List.fromList(bytes),
    );

    final batchItem = _BatchItem(index: _items.length, file: platformFile);
    setState(() => _items.add(batchItem));

    // Escanear inmediatamente solo esta foto
    await _scanSingleItem(batchItem);
  }

  /// Escanea un solo item y va a review si es exitoso
  Future<void> _scanSingleItem(_BatchItem item) async {
    setState(() {
      _step = _ScanStep.scanning;
      item.status = _BatchStatus.scanning;
    });

    try {
      final svcResult = await InvoiceScannerService.scanFromFile(item.file);
      if (svcResult.success && svcResult.data != null) {
        setState(() {
          item.populateFromResult(
            svcResult.data!,
            _dateFormat,
            _allCustomers,
            _allProducts,
            _allMaterials,
          );
          item.isExpanded = true;
        });
      } else {
        setState(() {
          item.status = _BatchStatus.error;
          item.scanError = svcResult.error ?? 'Error desconocido';
        });
      }
    } catch (e) {
      setState(() {
        item.status = _BatchStatus.error;
        item.scanError = e.toString();
      });
    }

    // Ir a review si hay al menos 1 exitosa
    if (_items.any((i) => i.status == _BatchStatus.done)) {
      setState(() => _step = _ScanStep.review);
    } else {
      // Si falló, volver a selección para reintentar
      setState(() => _step = _ScanStep.selectImage);
    }
  }

  // ─── Logic: Start Scanning ─────────────────────────────────────
  Future<void> _startScanning() async {
    setState(() => _step = _ScanStep.scanning);

    for (final item in _items) {
      // Skip items already processed
      if (item.status != _BatchStatus.pending) continue;
      setState(() => item.status = _BatchStatus.scanning);
      try {
        final svcResult = await InvoiceScannerService.scanFromFile(item.file);
        if (svcResult.success && svcResult.data != null) {
          setState(() {
            item.populateFromResult(
              svcResult.data!,
              _dateFormat,
              _allCustomers,
              _allProducts,
              _allMaterials,
            );
          });
        } else {
          setState(() {
            item.status = _BatchStatus.error;
            item.scanError = svcResult.error ?? 'Error desconocido';
          });
        }
      } catch (e) {
        setState(() {
          item.status = _BatchStatus.error;
          item.scanError = e.toString();
        });
      }
    }

    // Si al menos 1 exitosa, ir a review
    if (_items.any((i) => i.status == _BatchStatus.done)) {
      // Expandir la primera exitosa
      final first = _items.firstWhere((i) => i.status == _BatchStatus.done);
      first.isExpanded = true;
      setState(() => _step = _ScanStep.review);
    }
  }

  // ─── Item Match Picker ─────────────────────────────────────────
  void _showItemMatchPicker(_BatchItem batchItem, _ItemMatch itemMatch) {
    String search = '';
    // Combinar productos y materiales en una lista unificada
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) {
          final q = search.toLowerCase();
          final filteredProducts = q.isEmpty
              ? _allProducts
              : _allProducts
                    .where(
                      (p) =>
                          p.name.toLowerCase().contains(q) ||
                          p.code.toLowerCase().contains(q),
                    )
                    .toList();
          final filteredMaterials = q.isEmpty
              ? _allMaterials
              : _allMaterials
                    .where(
                      (m) =>
                          m.name.toLowerCase().contains(q) ||
                          m.code.toLowerCase().contains(q) ||
                          m.category.toLowerCase().contains(q),
                    )
                    .toList();

          return AlertDialog(
            title: Text(
              'Asociar: ${itemMatch.scannedItem.description}',
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width < 500
                  ? double.maxFinite
                  : 500,
              height: 450,
              child: Column(
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Buscar producto o material...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setInnerState(() => search = v),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        if (filteredProducts.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'PRODUCTOS (${filteredProducts.length})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ),
                          ...filteredProducts.map(
                            (p) => ListTile(
                              dense: true,
                              leading: Icon(
                                p.isRecipe
                                    ? Icons.receipt_long
                                    : Icons.category,
                                size: 20,
                                color: const Color(0xFF1565C0),
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                '${p.code} · Stock: ${p.stock.toStringAsFixed(0)} ${p.unit}${p.isRecipe ? ' · Receta' : ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  itemMatch.matchedProduct = p;
                                  itemMatch.matchedMaterial = null;
                                });
                              },
                            ),
                          ),
                        ],
                        if (filteredMaterials.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'MATERIALES (${filteredMaterials.length})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                          ...filteredMaterials.map(
                            (m) => ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.inventory_2,
                                size: 20,
                                color: Color(0xFF2E7D32),
                              ),
                              title: Text(
                                m.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                '${m.code} · ${m.category} · Stock: ${m.stock.toStringAsFixed(1)} ${m.unit}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() {
                                  itemMatch.matchedMaterial = m;
                                  itemMatch.matchedProduct = null;
                                });
                              },
                            ),
                          ),
                        ],
                        if (filteredProducts.isEmpty &&
                            filteredMaterials.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('Sin resultados'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actionsOverflowButtonSpacing: 0,
            actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            actions: [
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _createProductFromItem(itemMatch);
                          },
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text(
                            'Producto',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 34),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _createMaterialFromItem(itemMatch);
                          },
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text(
                            'Material',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 34),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Add Item Manually (Material/Product picker) ───────────────
  void _showAddItemManualDialog(_BatchItem batchItem) {
    String search = '';
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: '0');
    Product? selectedProduct;
    mat.Material? selectedMaterial;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) {
          final q = search.toLowerCase();
          final filteredProducts = q.isEmpty
              ? _allProducts
              : _allProducts
                    .where(
                      (p) =>
                          p.name.toLowerCase().contains(q) ||
                          p.code.toLowerCase().contains(q),
                    )
                    .toList();
          final filteredMaterials = q.isEmpty
              ? _allMaterials
              : _allMaterials
                    .where(
                      (m) =>
                          m.name.toLowerCase().contains(q) ||
                          m.code.toLowerCase().contains(q) ||
                          m.category.toLowerCase().contains(q),
                    )
                    .toList();

          final hasSelection =
              selectedProduct != null || selectedMaterial != null;
          final selectedName =
              selectedProduct?.name ?? selectedMaterial?.name ?? '';

          return AlertDialog(
            title: const Text(
              'Agregar Item Manual',
              style: TextStyle(fontSize: 16),
            ),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width < 500
                  ? double.maxFinite
                  : 520,
              height: 500,
              child: Column(
                children: [
                  // Selección actual
                  if (hasSelection) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                selectedProduct != null
                                    ? Icons.category
                                    : Icons.inventory_2,
                                size: 16,
                                color: selectedProduct != null
                                    ? const Color(0xFF1565C0)
                                    : const Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  selectedName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setInnerState(() {
                                  selectedProduct = null;
                                  selectedMaterial = null;
                                }),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Cantidad',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: priceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Precio unit.',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    prefixText: '\$ ',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Buscador
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Buscar producto o material...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setInnerState(() => search = v),
                  ),
                  const SizedBox(height: 8),
                  // Lista
                  Expanded(
                    child: ListView(
                      children: [
                        if (filteredProducts.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'PRODUCTOS (${filteredProducts.length})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ),
                          ...filteredProducts.map(
                            (p) => ListTile(
                              dense: true,
                              selected: selectedProduct?.id == p.id,
                              selectedTileColor: const Color(0xFFE3F2FD),
                              leading: Icon(
                                p.isRecipe
                                    ? Icons.receipt_long
                                    : Icons.category,
                                size: 20,
                                color: const Color(0xFF1565C0),
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                '${p.code} · Precio: ${Helpers.formatCurrency(p.unitPrice)} · Stock: ${p.stock.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () => setInnerState(() {
                                selectedProduct = p;
                                selectedMaterial = null;
                                priceCtrl.text = p.unitPrice.toStringAsFixed(2);
                              }),
                            ),
                          ),
                        ],
                        if (filteredMaterials.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'MATERIALES (${filteredMaterials.length})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                          ...filteredMaterials.map(
                            (m) => ListTile(
                              dense: true,
                              selected: selectedMaterial?.id == m.id,
                              selectedTileColor: const Color(0xFFE8F5E9),
                              leading: const Icon(
                                Icons.inventory_2,
                                size: 20,
                                color: Color(0xFF2E7D32),
                              ),
                              title: Text(
                                m.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                '${m.code} · ${m.category} · Precio: ${Helpers.formatCurrency(m.effectivePrice)} · Stock: ${m.stock.toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () => setInnerState(() {
                                selectedMaterial = m;
                                selectedProduct = null;
                                priceCtrl.text = m.effectivePrice
                                    .toStringAsFixed(2);
                              }),
                            ),
                          ),
                        ],
                        if (filteredProducts.isEmpty &&
                            filteredMaterials.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text('Sin resultados'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // Crear material nuevo
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final created = await showDialog<mat.Material>(
                    context: context,
                    builder: (_) => const MaterialFormDialog(),
                  );
                  if (created != null) {
                    // Recargar materiales
                    final freshMaterials =
                        await InventoryDataSource.getAllMaterials();
                    setState(() {
                      _allMaterials = freshMaterials;
                      // Agregar como item
                      final newItem = _ItemMatch(
                        scannedItem: ScannedInvoiceItem(
                          description: created.name,
                          quantity: 1,
                          unitPrice: created.effectivePrice,
                          total: created.effectivePrice,
                          taxRate: 0,
                          unit: created.unit,
                        ),
                      );
                      newItem.matchedMaterial = created;
                      batchItem.itemMatches.add(newItem);
                      _recalcTotals(batchItem);
                    });
                  }
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Crear Material',
                  style: TextStyle(fontSize: 12),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              if (hasSelection)
                FilledButton.icon(
                  onPressed: () {
                    final qty =
                        double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1;
                    final price =
                        double.tryParse(priceCtrl.text.replaceAll(',', '.')) ??
                        0;
                    Navigator.pop(ctx);
                    setState(() {
                      final newItem = _ItemMatch(
                        scannedItem: ScannedInvoiceItem(
                          description: selectedName,
                          quantity: qty,
                          unitPrice: price,
                          total: qty * price,
                          taxRate: 0,
                          unit:
                              selectedProduct?.unit ??
                              selectedMaterial?.unit ??
                              'UND',
                        ),
                      );
                      newItem.matchedProduct = selectedProduct;
                      newItem.matchedMaterial = selectedMaterial;
                      batchItem.itemMatches.add(newItem);
                      _recalcTotals(batchItem);
                    });
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                ),
            ],
          );
        },
      ),
    );
  }

  // Recalcula totales del batch item cuando se agregan/quitan items
  void _recalcTotals(_BatchItem item) {
    double total = 0;
    for (final im in item.itemMatches) {
      total += im.scannedItem.total;
    }
    item.totalCtrl.text = total.toStringAsFixed(2);
    item.subtotalCtrl.text = total.toStringAsFixed(2);
  }

  // ─── Create Product from Scanned Item ──────────────────────────
  Future<void> _createProductFromItem(_ItemMatch itemMatch) async {
    final si = itemMatch.scannedItem;
    final name = si.description.trim();
    if (name.isEmpty) return;

    final product = await QuickProductDialog.show(
      context,
      suggestedName: name,
      suggestedDescription: name,
      suggestedUnitPrice: si.unitPrice,
      suggestedCostPrice: si.unitPrice,
      suggestedUnit: si.unit.isNotEmpty ? si.unit : 'UND',
      showScanBanner: true,
    );

    if (product != null) {
      _allProducts.add(product);
      setState(() {
        itemMatch.matchedProduct = product;
        itemMatch.matchedMaterial = null;
      });
    }
  }

  // ─── Create Material from Scanned Item ─────────────────────────
  Future<void> _createMaterialFromItem(_ItemMatch itemMatch) async {
    final si = itemMatch.scannedItem;
    final name = si.description.trim();
    if (name.isEmpty) return;

    // Intentar inferir categoría del nombre
    final nameLower = name.toLowerCase();
    String? guessedCategory;
    if (nameLower.contains('tubo') || nameLower.contains('tubería')) {
      guessedCategory = 'tubo';
    } else if (nameLower.contains('lámina') || nameLower.contains('lamina')) {
      guessedCategory = 'lamina';
    } else if (nameLower.contains('eje') || nameLower.contains('barra')) {
      guessedCategory = 'eje';
    } else if (nameLower.contains('perfil') ||
        nameLower.contains('ángulo') ||
        nameLower.contains('angulo')) {
      guessedCategory = 'perfil';
    } else if (nameLower.contains('tornillo') ||
        nameLower.contains('perno') ||
        nameLower.contains('tuerca')) {
      guessedCategory = 'tornilleria';
    } else if (nameLower.contains('soldadura') ||
        nameLower.contains('electrodo')) {
      guessedCategory = 'soldadura';
    } else if (nameLower.contains('pintura') ||
        nameLower.contains('anticorrosivo')) {
      guessedCategory = 'pintura';
    }

    final newMaterial = await MaterialFormDialog.show(
      context,
      suggestedName: name,
      suggestedCostPrice: si.unitPrice,
      suggestedUnitPrice: si.unitPrice,
      suggestedUnit: si.unit.isNotEmpty ? si.unit : null,
      suggestedCategory: guessedCategory,
    );

    if (newMaterial != null) {
      _allMaterials.add(newMaterial);
      setState(() {
        itemMatch.matchedMaterial = newMaterial;
        itemMatch.matchedProduct = null;
      });
    }
  }

  /// Muestra diálogo para elegir tipo (Producto o Material) por cada item
  Future<void> _showAutoCreateDialog(_BatchItem batchItem) async {
    final unmatched = batchItem.itemMatches
        .where((im) => !im.hasMatch)
        .toList();
    if (unmatched.isEmpty) return;

    // Map: true = Producto, false = Material
    final choices = {for (final im in unmatched) im: true};

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) {
          final productCount = choices.values.where((v) => v).length;
          final materialCount = choices.values.where((v) => !v).length;
          final dialogNarrow = MediaQuery.of(ctx).size.width < 500;
          return AlertDialog(
            title: const Text(
              'Crear items sin asociar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: dialogNarrow ? double.maxFinite : 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selecciona si cada item es Producto o Material:',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setInnerState(() {
                          for (final k in choices.keys) {
                            choices[k] = true;
                          }
                        }),
                        icon: const Icon(Icons.category, size: 14),
                        label: const Text(
                          'Todos Producto',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1565C0),
                          side: const BorderSide(color: Color(0xFF1565C0)),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setInnerState(() {
                          for (final k in choices.keys) {
                            choices[k] = false;
                          }
                        }),
                        icon: const Icon(Icons.inventory_2, size: 14),
                        label: const Text(
                          'Todos Material',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 30),
                        ),
                      ),
                      Text(
                        '$productCount prod., $materialCount mat.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 350),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: unmatched.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final im = unmatched[i];
                        final isProduct = choices[im] ?? true;
                        if (dialogNarrow) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  im.scannedItem.description,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cant: ${im.scannedItem.quantity.toStringAsFixed(0)} · '
                                  '\$${im.scannedItem.total.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SegmentedButton<bool>(
                                  segments: const [
                                    ButtonSegment(
                                      value: true,
                                      label: Text(
                                        'Producto',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      icon: Icon(Icons.category, size: 14),
                                    ),
                                    ButtonSegment(
                                      value: false,
                                      label: Text(
                                        'Material',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      icon: Icon(Icons.inventory_2, size: 14),
                                    ),
                                  ],
                                  selected: {isProduct},
                                  onSelectionChanged: (v) {
                                    setInnerState(() => choices[im] = v.first);
                                  },
                                  style: ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      im.scannedItem.description,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Cant: ${im.scannedItem.quantity.toStringAsFixed(0)} · '
                                      '\$${im.scannedItem.total.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: true,
                                    label: Text(
                                      'Producto',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    icon: Icon(Icons.category, size: 14),
                                  ),
                                  ButtonSegment(
                                    value: false,
                                    label: Text(
                                      'Material',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    icon: Icon(Icons.inventory_2, size: 14),
                                  ),
                                ],
                                selected: {isProduct},
                                onSelectionChanged: (v) {
                                  setInnerState(() => choices[im] = v.first);
                                },
                                style: ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check, size: 16),
                label: Text(
                  'Crear ${unmatched.length} item(s)',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    // Crear según la elección de cada item
    int createdP = 0, createdM = 0;
    for (final im in unmatched) {
      if (choices[im] == true) {
        await _createProductFromItem(im);
        if (im.hasMatch) createdP++;
      } else {
        await _createMaterialFromItem(im);
        if (im.hasMatch) createdM++;
      }
    }

    if (mounted) {
      final parts = <String>[];
      if (createdP > 0) parts.add('$createdP producto(s)');
      if (createdM > 0) parts.add('$createdM material(es)');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${parts.join(' y ')} creado(s)'),
          backgroundColor: const Color(0xFF1565C0),
        ),
      );
    }
  }

  // ─── Logic: Add more photos from review ────────────────────────
  Future<void> _addMorePhotos() async {
    final showCamera = !kIsWeb;
    if (!showCamera) {
      // En web, solo picker de archivos
      await _pickFiles();
      return;
    }
    // En móvil, mostrar bottom sheet para elegir
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFE65100)),
              title: const Text('Tomar foto'),
              subtitle: const Text('Usar la cámara del celular'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería / Archivos'),
              subtitle: const Text('Seleccionar imágenes existentes'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'camera') {
      await _takePhoto();
    } else {
      await _pickFiles();
      // Si hay items nuevos sin procesar, escanearlos
      final pendingItems = _items
          .where((i) => i.status == _BatchStatus.pending)
          .toList();
      for (final item in pendingItems) {
        await _scanSingleItem(item);
      }
    }
  }

  // ─── Logic: Reset for new scan ─────────────────────────────────
  void _resetForNewScan() {
    setState(() {
      _items.clear();
      _step = _ScanStep.selectImage;
      _savingIndex = 0;
    });
  }

  // ─── Logic: Save All ───────────────────────────────────────────
  Future<void> _saveAll() async {
    final toSave = _items
        .where((i) => i.selected && i.status == _BatchStatus.done)
        .toList();
    if (toSave.isEmpty) return;

    // Verificar que todos los items estén asociados a producto/material
    final unmatchedItems = <_BatchItem>[];
    for (final item in toSave) {
      if (item.itemMatches.any((im) => !im.hasMatch)) {
        unmatchedItems.add(item);
      }
    }
    if (unmatchedItems.isNotEmpty) {
      // Mostrar auto-crear para cada factura con items sin asociar
      for (final item in unmatchedItems) {
        await _showAutoCreateDialog(item);
      }
      // Verificar de nuevo si quedaron sin asociar
      final stillUnmatched = toSave.any(
        (item) => item.itemMatches.any((im) => !im.hasMatch),
      );
      if (stillUnmatched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Todos los items deben estar asociados a un producto o material para poder guardar.',
              ),
              backgroundColor: Color(0xFFD32F2F),
            ),
          );
        }
        return;
      }
    }

    // Verificar que todos tengan cliente
    final sinCliente = toSave.where((i) => i.matchedCustomer == null).toList();
    if (sinCliente.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Facturas sin cliente'),
          content: Text(
            '${sinCliente.length} factura(s) no tienen cliente asociado.\n\n'
            'Si continúas, se crearán clientes nuevos automáticamente con los datos extraídos.\n\n'
            '¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear clientes y continuar'),
            ),
          ],
        ),
      );
      if (proceed != true) return;

      // Crear los clientes faltantes
      for (final item in sinCliente) {
        await _createCustomerFromScan(item);
      }
    }

    setState(() {
      _step = _ScanStep.saving;
      _savingIndex = 0;
    });

    for (int i = 0; i < toSave.length; i++) {
      final item = toSave[i];
      setState(() => _savingIndex = i);
      try {
        await _saveOneInvoice(item);
        setState(() => item.saved = true);
      } catch (e) {
        setState(() => item.saveError = e.toString());
      }
    }

    setState(() => _savingIndex = toSave.length);
    if (!mounted) return;

    final savedCount = toSave.where((i) => i.saved).length;
    final errorCount = toSave.where((i) => i.saveError != null).length;

    // Refrescar providers
    try {
      ref.read(invoicesProvider.notifier).refresh();
      ref.read(customersProvider.notifier).loadCustomers();
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          savedCount > 0
              ? '$savedCount factura(s) reconciliada(s) con deuda asociada'
                    '${errorCount > 0 ? ' · $errorCount con error' : ''}'
              : 'No se pudo reconciliar ninguna factura',
        ),
        backgroundColor: savedCount > 0
            ? const Color(0xFF388E3C)
            : const Color(0xFFD32F2F),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ─── Logic: Save One Invoice ───────────────────────────────────
  Future<void> _saveOneInvoice(_BatchItem item) async {
    final customer = item.matchedCustomer;
    if (customer == null) {
      throw Exception('Sin cliente asociado');
    }

    // Parsear datos
    DateTime issueDate = DateTime.now();
    if (item.invoiceDateCtrl.text.isNotEmpty) {
      try {
        issueDate = _dateFormat.parse(item.invoiceDateCtrl.text);
      } catch (_) {}
    }

    final total = double.tryParse(item.totalCtrl.text) ?? 0;
    final originalNumber = item.invoiceNumberCtrl.text.trim();

    // Verificar duplicados antes de crear
    final duplicate = await InvoicesDataSource.findDuplicate(
      customerId: customer.id,
      total: total,
      issueDate: issueDate,
      originalInvoiceNumber: originalNumber.isNotEmpty ? originalNumber : null,
    );

    if (duplicate != null) {
      throw Exception(
        'Factura duplicada: ${duplicate.fullNumber} '
        '(${duplicate.customerName}, '
        '\$${duplicate.total.toStringAsFixed(0)}, '
        '${duplicate.issueDate.day}/${duplicate.issueDate.month}/${duplicate.issueDate.year})',
      );
    }

    DateTime? dueDate;
    if (item.dueDateCtrl.text.isNotEmpty) {
      try {
        dueDate = _dateFormat.parse(item.dueDateCtrl.text);
      } catch (_) {}
    }
    // Si no hay fecha de vencimiento, 30 días después
    dueDate ??= issueDate.add(const Duration(days: 30));

    final subtotal = double.tryParse(item.subtotalCtrl.text) ?? 0;
    final taxAmount = double.tryParse(item.taxAmountCtrl.text) ?? 0;
    final taxRate = double.tryParse(item.taxRateCtrl.text) ?? 0;

    // Preparar items de factura con product_id / material_id
    // TODOS los items se guardan siempre (para estadísticas de ventas)
    final invoiceItems = item.itemMatches.map((im) {
      final si = im.scannedItem;
      final st = si.quantity * si.unitPrice;
      final ta = st * (si.taxRate / 100);
      return InvoiceItem(
        id: '',
        invoiceId: '',
        productId: im.matchedProduct?.id,
        materialId: im.matchedMaterial?.id,
        productCode: im.matchedProduct?.code ?? im.matchedMaterial?.code,
        productName: si.description,
        description: si.referenceCode,
        quantity: si.quantity,
        unit: si.unit,
        unitPrice: si.unitPrice,
        discount: si.discount,
        taxRate: si.taxRate,
        subtotal: st,
        taxAmount: ta,
        total: si.total > 0 ? si.total : st + ta,
      );
    }).toList();

    // Si no hay items escaneados, crear un item genérico con el total
    if (invoiceItems.isEmpty) {
      invoiceItems.add(
        InvoiceItem(
          id: '',
          invoiceId: '',
          productName: 'Venta según factura ${item.invoiceNumberCtrl.text}',
          quantity: 1,
          unitPrice: subtotal > 0 ? subtotal : total,
          subtotal: subtotal > 0 ? subtotal : total,
          taxRate: taxRate,
          taxAmount: taxAmount,
          total: total,
        ),
      );
    }

    // Notas con referencia al número original de la factura física
    final notes = [
      if (originalNumber.isNotEmpty) 'Factura física: $originalNumber',
      if (item.notesCtrl.text.trim().isNotEmpty) item.notesCtrl.text.trim(),
      'Registrada por escaneo IA',
    ].join(' · ');

    // 1. Crear la factura real (serie VTA)
    final invoice = await InvoicesDataSource.createWithItems(
      type: 'invoice',
      series: 'VTA',
      customer: customer,
      issueDate: issueDate,
      dueDate: dueDate,
      salePaymentType: item.paymentType,
      items: invoiceItems,
      taxRate: taxRate,
      notes: notes,
    );

    // 2. Emitir factura
    if (item.deductInventory) {
      // Factura reciente → descontar stock + recalcular balance CxC
      await InvoicesDataSource.updateStatus(invoice.id, 'issued');
    } else {
      // Factura histórica → solo cambiar status sin mover inventario
      await InvoicesDataSource.setStatusDirect(invoice.id, 'issued');
      // Pero SÍ recalcular balance del cliente (genera deuda CxC)
      if (customer.id.isNotEmpty) {
        await CustomersDataSource.recalculateBalance(customer.id);
      }
    }

    // 3. También registrar en iva_invoices para declaración de IVA
    try {
      final period = _getBimonthlyPeriod(issueDate);
      await IvaDataSource.createInvoice(
        IvaInvoice(
          invoiceNumber: invoice.number,
          invoiceDate: issueDate,
          company: customer.displayName,
          invoiceType: 'VENTA',
          baseAmount: subtotal > 0 ? subtotal : total / (1 + taxRate / 100),
          ivaAmount: taxAmount,
          totalAmount: total,
          hasReteiva: false,
          reteivaAmount: 0,
          bimonthlyPeriod: period,
          notes: notes,
          companyDocument: customer.documentNumber,
        ),
      );
    } catch (_) {
      // No fallar la factura por error en IVA
    }

    // Guardar correcciones para aprendizaje IA
    if (item.result != null) {
      try {
        await ScanCorrectionsDataSource.saveCorrection(
          correctionType: 'sale',
          originalResult: item.result!,
          correctedTotal: total,
          correctedSubtotal: subtotal,
          correctedTaxRate: taxRate,
          correctedTaxAmount: taxAmount,
          correctedInvoiceNumber: originalNumber.isNotEmpty
              ? originalNumber
              : 'SIN-NUM',
          supplierName: customer.displayName,
          imageRef: item.result!.imagePath,
        );
      } catch (_) {
        // No fallar la factura por error guardando corrección
      }
    }
  }

  String _getBimonthlyPeriod(DateTime date) {
    final y = date.year;
    final m = date.month;
    // Bimestres: Ene-Feb, Mar-Abr, May-Jun, Jul-Ago, Sep-Oct, Nov-Dic
    final bimester = ((m - 1) ~/ 2) + 1;
    const labels = [
      '',
      'Ene-Feb',
      'Mar-Abr',
      'May-Jun',
      'Jul-Ago',
      'Sep-Oct',
      'Nov-Dic',
    ];
    return '${labels[bimester]} $y';
  }
}
