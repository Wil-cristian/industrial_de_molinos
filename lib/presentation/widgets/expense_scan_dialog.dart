import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/datasources/expense_scanner_service.dart';
import '../../data/datasources/supabase_datasource.dart';
import '../../data/datasources/suppliers_datasource.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/cash_movement.dart';
import '../../domain/entities/supplier.dart'; // ═══════════════════════════════════════════════════════════════
//  EXPENSE SCAN DIALOG
// ═══════════════════════════════════════════════════════════════
// Flujo:
//  0. Seleccionar/tomar foto del recibo
//  1. IA procesa la imagen (loading)
//  2. Revisar datos extraídos + categoría + seleccionar cuenta
//  3. Confirmar y registrar el gasto
// ═══════════════════════════════════════════════════════════════

class ExpenseScanDialog extends StatefulWidget {
  const ExpenseScanDialog({super.key});

  /// Muestra el diálogo y retorna `true` si se registró un gasto
  static Future<bool?> show(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      return Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const ExpenseScanDialog(),
        ),
      );
    }
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ExpenseScanDialog(),
    );
  }

  @override
  State<ExpenseScanDialog> createState() => _ExpenseScanDialogState();
}

class _ExpenseScanDialogState extends State<ExpenseScanDialog> {
  // Steps: 0=select, 1=scanning, 2=review, 3=saving, 4=done
  int _step = 0;

  // File data
  String? _fileName;

  // Scan result
  ExpenseScanResult? _scanResult;
  String? _error;

  // Editable fields (populated from scan)
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _personController = TextEditingController();
  MovementCategory _selectedCategory = MovementCategory.gastos_reducibles;
  String? _selectedCustomName;
  String? _selectedAccountId;
  String _categoryReason = '';

  // Accounts
  List<Account> _accounts = [];
  List<Map<String, dynamic>> _customCategories = [];

  // Suppliers
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;

  // Formatter for amount
  static final _currencyFormat = NumberFormat('#,###', 'es_CO');

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadCustomCategories();
    _loadSuppliers();
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _descriptionController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    _personController.dispose();
    super.dispose();
  }

  // ─── Amount formatting ───────────────────────────────────
  bool _isFormattingAmount = false;

  void _onAmountChanged() {
    if (_isFormattingAmount) return;
    _isFormattingAmount = true;

    final text = _amountController.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');
    final number = int.tryParse(text);
    if (number != null && text.isNotEmpty) {
      final formatted = _currencyFormat.format(number);
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    _isFormattingAmount = false;
  }

  double? _parseAmount() {
    final text = _amountController.text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');
    return double.tryParse(text);
  }

  Future<void> _loadAccounts() async {
    try {
      final all = await AccountsDataSource.getAllAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = all.where((a) => a.isActive).toList();
        if (_accounts.isNotEmpty) {
          _selectedAccountId = _accounts.first.id;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadSuppliers() async {
    try {
      final all = await SuppliersDataSource.getAll();
      if (!mounted) return;
      setState(() => _suppliers = all);
    } catch (_) {}
  }

  Future<void> _loadCustomCategories() async {
    try {
      final data = await SupabaseDataSource.client
          .from('custom_categories')
          .select()
          .eq('type', 'expense')
          .order('name');
      if (mounted) {
        setState(() {
          _customCategories = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (_) {}
  }

  Future<void> _addCustomCategory() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Categoría'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre de la categoría',
            border: OutlineInputBorder(),
            hintText: 'Ej: Mantenimiento',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) Navigator.pop(ctx, name);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        await SupabaseDataSource.client.from('custom_categories').insert({
          'name': result,
          'type': 'expense',
        });
        await _loadCustomCategories();
        if (mounted) {
          setState(() {
            _selectedCategory = MovementCategory.custom;
            _selectedCustomName = result;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().contains('idx_custom_categories_name_type')
                    ? 'Ya existe una categoría con ese nombre'
                    : 'Error al crear categoría',
              ),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
      }
    }
  }

  // ─── Step 0: Pick File / Take Photo ──────────────────────

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
    final fileName = 'gasto_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final file = PlatformFile(
      name: fileName,
      size: bytes.length,
      bytes: Uint8List.fromList(bytes),
    );

    setState(() {
      _fileName = fileName;
      _step = 1;
      _error = null;
    });

    _scanExpense(file);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    if (file.bytes == null && file.path == null) {
      setState(() => _error = 'No se pudo leer el archivo');
      return;
    }

    setState(() {
      _fileName = file.name;
      _step = 1;
      _error = null;
    });

    _scanExpense(file);
  }

  // ─── Step 1: Scan ────────────────────────────────────────

  Future<void> _scanExpense(PlatformFile file) async {
    try {
      final response = await ExpenseScannerService.scanFromFile(file);

      if (!mounted) return;

      if (response.success && response.data != null) {
        final data = response.data!;
        setState(() {
          _scanResult = data;
          _selectedCategory = data.category;
          _categoryReason = data.categoryReason;
          _descriptionController.text = data.description;
          _isFormattingAmount = true;
          _amountController.text = data.total > 0
              ? _currencyFormat.format(data.total.toInt())
              : '';
          _isFormattingAmount = false;
          // Try to match supplier by name
          if (data.supplier.name != null && data.supplier.name!.isNotEmpty) {
            final match = _suppliers
                .where(
                  (s) =>
                      s.displayName.toLowerCase().contains(
                        data.supplier.name!.toLowerCase(),
                      ) ||
                      data.supplier.name!.toLowerCase().contains(
                        s.displayName.toLowerCase(),
                      ),
                )
                .toList();
            if (match.isNotEmpty) {
              _selectedSupplier = match.first;
              _personController.text = match.first.displayName;
            }
          }
          _referenceController.text = data.reference ?? '';
          _personController.text = data.supplier.name ?? '';
          _step = 2;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Error al escanear el gasto';
          _step = 0;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error de conexión: $e';
        _step = 0;
      });
    }
  }

  // ─── Step 3: Save ────────────────────────────────────────

  Future<void> _saveExpense() async {
    final description = _descriptionController.text.trim();
    final reference = _referenceController.text.trim();
    final person = _personController.text.trim();

    if (description.isEmpty) {
      _showSnack('Ingresa una descripción');
      return;
    }
    final amount = _parseAmount();
    if (amount == null || amount <= 0) {
      _showSnack('Ingresa un monto válido');
      return;
    }
    if (_selectedAccountId == null) {
      _showSnack('Selecciona una cuenta');
      return;
    }

    setState(() => _step = 3);

    try {
      final movement = CashMovement(
        id: '',
        accountId: _selectedAccountId!,
        type: MovementType.expense,
        category: _selectedCategory,
        customCategoryName: _selectedCustomName,
        amount: amount,
        description: description,
        personName: person.isNotEmpty ? person : null,
        reference: reference.isNotEmpty ? reference : null,
        date: DateTime.now(),
      );

      final created = await AccountsDataSource.createMovementWithBalanceUpdate(
        movement,
      );

      if (!mounted) return;

      if (created.id.isNotEmpty) {
        setState(() => _step = 4);
      } else {
        setState(() {
          _error = 'Error al registrar el gasto';
          _step = 2;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _step = 2;
      });
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    if (isMobile) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _buildDialogHeader(),
              Expanded(child: _buildStepContent()),
            ],
          ),
        ),
      );
    }

    final dialogWidth = width > 700 ? 580.0 : width * 0.92;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogHeader(),
            Flexible(child: _buildStepContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    final compact = MediaQuery.of(context).size.width < 600;
    final titles = [
      'Seleccionar imagen',
      'Escaneando gasto...',
      'Revisar datos',
      'Registrando...',
      '¡Gasto registrado!',
    ];
    final subtitles = [
      'Foto o PDF del recibo/factura',
      'La IA está analizando el documento',
      'Confirma la información extraída',
      'Guardando en el sistema',
      'Se registró correctamente',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.08),
        borderRadius: compact
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          if (compact) ...[
            IconButton(
              onPressed: () =>
                  Navigator.of(context).pop(_step == 4 ? true : null),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _step == 4 ? Icons.check_circle : Icons.receipt_long,
              color: _step == 4 ? Colors.green : Colors.deepPurple,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_step],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitles[_step],
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!compact && _step != 1 && _step != 3)
            IconButton(
              onPressed: () =>
                  Navigator.of(context).pop(_step == 4 ? true : null),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildSelectStep();
      case 1:
        return _buildScanningStep();
      case 2:
        return _buildReviewStep();
      case 3:
        return _buildSavingStep();
      case 4:
        return _buildSuccessStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 0: Select Image ────────────────────────────────

  Widget _buildSelectStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Icon(
            Icons.document_scanner,
            size: 64,
            color: Colors.deepPurple.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Escanea un recibo o factura de gasto',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'La IA clasificará automáticamente la categoría,\n'
            'extraerá el monto y te pedirá la cuenta.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!kIsWeb) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text('Tomar Foto'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file, size: 20),
              label: const Text('Seleccionar archivo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'JPG, PNG, WebP o PDF',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 1: Scanning ────────────────────────────────────

  Widget _buildScanningStep() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Analizando: ${_fileName ?? "documento"}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'La IA está leyendo el documento,\n'
            'extrayendo datos y clasificando el gasto...',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Review ──────────────────────────────────────

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error banner
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // AI Category badge
          if (_categoryReason.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.deepPurple.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Colors.deepPurple,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🤖 $_categoryReason',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Confidence
          if (_scanResult != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    _scanResult!.confidence >= 0.8
                        ? Icons.verified
                        : Icons.info_outline,
                    size: 16,
                    color: _scanResult!.confidence >= 0.8
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Confianza: ${(_scanResult!.confidence * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: _scanResult!.confidence >= 0.8
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_scanResult!.documentType != 'OTRO') ...[
                    const SizedBox(width: 12),
                    Text(
                      _scanResult!.documentType,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Category dropdown
          _buildLabel('Categoría del gasto'),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory == MovementCategory.custom
                      ? 'custom_${_selectedCustomName ?? ''}'
                      : _selectedCategory.name,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    ..._expenseCategories.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat.name,
                        child: Row(
                          children: [
                            Icon(
                              _categoryIcons[cat],
                              size: 18,
                              color: _categoryColors[cat],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _categoryLabel(cat),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_customCategories.isNotEmpty)
                      const DropdownMenuItem<String>(
                        enabled: false,
                        value: '__divider__',
                        child: Divider(),
                      ),
                    ..._customCategories.map((c) {
                      final name = c['name'] as String;
                      return DropdownMenuItem<String>(
                        value: 'custom_$name',
                        child: Row(
                          children: [
                            Icon(
                              Icons.label_outline,
                              size: 18,
                              color: const Color(0xFF757575),
                            ),
                            const SizedBox(width: 8),
                            Text(name, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    if (value == null || value == '__divider__') return;
                    setState(() {
                      if (value.startsWith('custom_')) {
                        _selectedCategory = MovementCategory.custom;
                        _selectedCustomName = value.substring(7);
                      } else {
                        _selectedCategory = MovementCategory.values.firstWhere(
                          (c) => c.name == value,
                          orElse: () => MovementCategory.gastos_reducibles,
                        );
                        _selectedCustomName = null;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addCustomCategory,
                icon: const Icon(Icons.add),
                tooltip: 'Crear categoría',
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Account dropdown
          _buildLabel('Cuenta a debitar'),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _selectedAccountId,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: _accounts.map((acc) {
              final icon = acc.type == AccountType.cash
                  ? Icons.payments
                  : Icons.account_balance;
              return DropdownMenuItem(
                value: acc.id,
                child: Row(
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(acc.name, style: const TextStyle(fontSize: 14)),
                    const Spacer(),
                    Text(
                      Formatters.currency(acc.balance),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedAccountId = v),
          ),
          const SizedBox(height: 14),

          // Amount
          _buildLabel('Monto total'),
          const SizedBox(height: 4),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              prefixText: '\$ ',
              prefixStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: Colors.grey[400],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Description
          _buildLabel('Descripción'),
          const SizedBox(height: 4),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              hintText: 'Descripción del gasto',
            ),
          ),
          const SizedBox(height: 14),

          // Reference
          _buildLabel('Referencia'),
          const SizedBox(height: 4),
          TextField(
            controller: _referenceController,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              hintText: 'N° factura/recibo',
            ),
          ),
          const SizedBox(height: 14),

          // Supplier
          _buildLabel('Proveedor'),
          const SizedBox(height: 4),
          InkWell(
            onTap: _openSupplierSelector,
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedSupplier != null ||
                        _personController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _selectedSupplier = null;
                            _personController.clear();
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
              child: Text(
                _selectedSupplier?.displayName ??
                    (_personController.text.isNotEmpty
                        ? _personController.text
                        : 'Seleccionar proveedor'),
                style: TextStyle(
                  fontSize: 14,
                  color:
                      (_selectedSupplier != null ||
                          _personController.text.isNotEmpty)
                      ? null
                      : Theme.of(context).hintColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saveExpense,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Registrar gasto'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── Step 3: Saving ──────────────────────────────────────

  Widget _buildSavingStep() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.deepPurple,
            ),
          ),
          SizedBox(height: 16),
          Text('Registrando gasto...', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // ─── Step 4: Success ─────────────────────────────────────

  Widget _buildSuccessStep() {
    final amount = _parseAmount() ?? 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          const Text(
            '¡Gasto registrado!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${Formatters.currency(amount)} — ${_descriptionController.text}',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedCategory == MovementCategory.custom
                    ? Icons.label_outline
                    : _categoryIcons[_selectedCategory],
                size: 16,
                color: _selectedCategory == MovementCategory.custom
                    ? const Color(0xFF757575)
                    : _categoryColors[_selectedCategory],
              ),
              const SizedBox(width: 6),
              Text(
                _selectedCategory == MovementCategory.custom
                    ? (_selectedCustomName ?? 'Personalizada')
                    : _categoryLabel(_selectedCategory),
                style: TextStyle(
                  fontSize: 13,
                  color: _selectedCategory == MovementCategory.custom
                      ? const Color(0xFF757575)
                      : _categoryColors[_selectedCategory],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _step = 0;
                    _error = null;
                    _scanResult = null;
                    _fileName = null;
                    _descriptionController.clear();
                    _amountController.clear();
                    _referenceController.clear();
                    _personController.clear();
                    _categoryReason = '';
                    _selectedCategory = MovementCategory.gastos_reducibles;
                    _selectedCustomName = null;
                  });
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Escanear otro'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Listo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Supplier Selector ────────────────────────────────────

  Future<void> _openSupplierSelector() async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<dynamic>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _SupplierSelectorPage(
              suppliers: _suppliers,
              currentText: _personController.text,
              onRefresh: () async {
                await _loadSuppliers();
                return _suppliers;
              },
            ),
          ),
        );

    if (!mounted || result == null) return;

    if (result is Supplier) {
      setState(() {
        _selectedSupplier = result;
        _personController.text = result.displayName;
      });
    } else if (result is String) {
      setState(() {
        _selectedSupplier = null;
        _personController.text = result;
      });
    }
  }

  // ─── Helpers ─────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  // Category config (same as expenses_page)
  static const _expenseCategories = [
    MovementCategory.consumibles,
    MovementCategory.servicios_publicos,
    MovementCategory.papeleria,
    MovementCategory.nomina,
    MovementCategory.impuestos,
    MovementCategory.cuidado_personal,
    MovementCategory.transporte,
    MovementCategory.gastos_reducibles,
  ];

  static const _categoryIcons = <MovementCategory, IconData>{
    MovementCategory.consumibles: Icons.inventory_2,
    MovementCategory.servicios_publicos: Icons.electrical_services,
    MovementCategory.papeleria: Icons.description,
    MovementCategory.nomina: Icons.badge,
    MovementCategory.impuestos: Icons.account_balance,
    MovementCategory.cuidado_personal: Icons.health_and_safety,
    MovementCategory.transporte: Icons.local_shipping,
    MovementCategory.gastos_reducibles: Icons.receipt_long,
  };

  static const _categoryColors = <MovementCategory, Color>{
    MovementCategory.consumibles: Color(0xFF5C6BC0),
    MovementCategory.servicios_publicos: Color(0xFF26A69A),
    MovementCategory.papeleria: Color(0xFFEF5350),
    MovementCategory.nomina: Color(0xFF42A5F5),
    MovementCategory.impuestos: Color(0xFFAB47BC),
    MovementCategory.cuidado_personal: Color(0xFF66BB6A),
    MovementCategory.transporte: Color(0xFFFFA726),
    MovementCategory.gastos_reducibles: Color(0xFF78909C),
  };

  String _categoryLabel(MovementCategory cat) {
    switch (cat) {
      case MovementCategory.consumibles:
        return 'Consumibles';
      case MovementCategory.servicios_publicos:
        return 'Servicios Públicos';
      case MovementCategory.papeleria:
        return 'Papelería';
      case MovementCategory.nomina:
        return 'Nómina';
      case MovementCategory.impuestos:
        return 'Impuestos';
      case MovementCategory.cuidado_personal:
        return 'Cuidado Personal';
      case MovementCategory.transporte:
        return 'Transporte';
      case MovementCategory.gastos_reducibles:
        return 'Gastos Reducibles';
      default:
        return cat.name;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  SUPPLIER SELECTOR PAGE (Full Screen)
// ═══════════════════════════════════════════════════════════════

class _SupplierSelectorPage extends StatefulWidget {
  final List<Supplier> suppliers;
  final String currentText;
  final Future<List<Supplier>> Function() onRefresh;

  const _SupplierSelectorPage({
    required this.suppliers,
    required this.currentText,
    required this.onRefresh,
  });

  @override
  State<_SupplierSelectorPage> createState() => _SupplierSelectorPageState();
}

class _SupplierSelectorPageState extends State<_SupplierSelectorPage> {
  final _searchController = TextEditingController();
  final _newNameController = TextEditingController();
  late List<Supplier> _allSuppliers;
  List<Supplier> _filtered = [];
  bool _showCreateForm = false;

  @override
  void initState() {
    super.initState();
    _allSuppliers = List.from(widget.suppliers);
    _filtered = _allSuppliers;
    if (widget.currentText.isNotEmpty) {
      _searchController.text = widget.currentText;
      _filterList(widget.currentText);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newNameController.dispose();
    super.dispose();
  }

  void _filterList(String query) {
    if (query.isEmpty) {
      setState(() => _filtered = _allSuppliers);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filtered = _allSuppliers.where((s) {
        return s.displayName.toLowerCase().contains(q) ||
            s.name.toLowerCase().contains(q) ||
            s.documentNumber.toLowerCase().contains(q) ||
            (s.tradeName?.toLowerCase().contains(q) ?? false);
      }).toList();
    });
  }

  Future<void> _createSupplier() async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) return;

    try {
      final supplier = Supplier(
        id: '',
        type: SupplierType.business,
        documentType: 'NIT',
        documentNumber: '',
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final created = await SuppliersDataSource.create(supplier);
      if (mounted) {
        Navigator.of(context).pop(created);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear proveedor: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Proveedor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar lista',
            onPressed: () async {
              final updated = await widget.onRefresh();
              setState(() {
                _allSuppliers = updated;
                _filterList(_searchController.text);
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar proveedor por nombre o NIT...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterList('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              onChanged: _filterList,
            ),
          ),

          // Create new supplier toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: () => setState(() => _showCreateForm = !_showCreateForm),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _showCreateForm
                          ? Icons.remove_circle_outline
                          : Icons.add_circle_outline,
                      size: 20,
                      color: Colors.deepPurple,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Crear nuevo proveedor',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      _showCreateForm
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.deepPurple,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Create form
          if (_showCreateForm)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newNameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Nombre del proveedor',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _createSupplier,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Crear'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Use typed text as-is option
          if (_searchController.text.isNotEmpty && _filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                color: const Color(0xFFFFF8E1),
                child: ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFFF9A825)),
                  title: Text(
                    'Usar "${_searchController.text}" como proveedor',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Sin registrar en el sistema',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_searchController.text),
                ),
              ),
            ),

          // Supplier list
          Expanded(
            child: _filtered.isEmpty && _searchController.text.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text(
                          'No hay proveedores registrados',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = _filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.withOpacity(0.1),
                          child: Text(
                            s.displayName.isNotEmpty
                                ? s.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          s.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Row(
                          children: [
                            if (s.documentNumber.isNotEmpty) ...[
                              Text(
                                '${s.documentType}: ${s.documentNumber}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (s.hasDebt)
                              Text(
                                'Deuda: ${Formatters.currency(s.currentDebt)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).pop(s),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
