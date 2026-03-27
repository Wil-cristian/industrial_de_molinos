import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/datasources/expense_scanner_service.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/cash_movement.dart'; // ═══════════════════════════════════════════════════════════════
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
  String? _selectedAccountId;
  String _categoryReason = '';

  // Accounts
  List<Account> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _referenceController.dispose();
    _personController.dispose();
    super.dispose();
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

  // ─── Step 0: Pick File ───────────────────────────────────

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
          _amountController.text = data.total > 0
              ? data.total.toStringAsFixed(0)
              : '';
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
    final amountText = _amountController.text.trim();
    final reference = _referenceController.text.trim();
    final person = _personController.text.trim();

    if (description.isEmpty) {
      _showSnack('Ingresa una descripción');
      return;
    }
    final amount = double.tryParse(amountText.replaceAll(',', '.'));
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
    final dialogWidth = width > 700 ? 560.0 : width * 0.92;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 680),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
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
          if (_step != 1 && _step != 3)
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file, size: 20),
              label: const Text('Seleccionar archivo'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurple,
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
          DropdownButtonFormField<MovementCategory>(
            value: _selectedCategory,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: _expenseCategories.map((cat) {
              return DropdownMenuItem(
                value: cat,
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
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedCategory = v);
            },
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              prefixText: '\$ ',
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

          // Row: Reference + Person
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Proveedor'),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _personController,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        hintText: 'Nombre',
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

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
                _categoryIcons[_selectedCategory],
                size: 16,
                color: _categoryColors[_selectedCategory],
              ),
              const SizedBox(width: 6),
              Text(
                _categoryLabel(_selectedCategory),
                style: TextStyle(
                  fontSize: 13,
                  color: _categoryColors[_selectedCategory],
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
