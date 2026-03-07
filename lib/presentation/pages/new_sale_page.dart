import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/logger.dart';
import '../../data/providers/providers.dart';
import '../../data/datasources/invoices_datasource.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/datasources/composite_products_datasource.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/material.dart' as domain;
import '../widgets/weight_calculator_dialog.dart';

// ═══════════════════════════════════════════════════════════════
// Color de tema para la página de ventas (azul claro)
// ═══════════════════════════════════════════════════════════════
const Color _saleThemeColor = Color(0xFF1E88E5); // Azul medio

class NewSalePage extends ConsumerStatefulWidget {
  const NewSalePage({super.key});

  @override
  ConsumerState<NewSalePage> createState() => _NewSalePageState();
}

class _NewSalePageState extends ConsumerState<NewSalePage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Datos del cliente
  String? _selectedCustomerId;

  // Lista de items/componentes (misma estructura que cotización)
  final List<Map<String, dynamic>> _items = [];

  // Costos adicionales
  final _laborPercentController = TextEditingController(text: '15');
  final _indirectCostsController = TextEditingController(text: '0');
  final _profitMarginController = TextEditingController(text: '20');
  final _discountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  // Forma de pago
  String _paymentType = 'cash'; // 'cash' o 'credit'
  String _paymentMethod = 'cash'; // cash, transfer, card
  Account? _selectedAccount;
  List<Account> _accounts = [];
  int _creditDays = 30;
  int _installments = 1;

  // Estado
  bool _isSaving = false;
  bool _loadingStock = false;
  List<Map<String, dynamic>>? _consolidatedStock;

  // Clientes del provider
  List<Map<String, dynamic>> get _customers {
    final state = ref.watch(customersProvider);
    return state.customers
        .map(
          (c) => <String, dynamic>{
            'id': c.id,
            'name': c.name,
            'ruc': c.documentNumber,
          },
        )
        .toList();
  }

  List<Product> get _products {
    final state = ref.watch(productsProvider);
    return state.products;
  }

  List<Category> get _categories {
    final state = ref.watch(productsProvider);
    return state.categories;
  }

  // ════════════════════════ CÁLCULOS ════════════════════════
  double get _materialsCost => _items.fold(
    0.0,
    (sum, item) => sum + (item['totalPrice'] as double? ?? 0),
  );
  double get _totalWeight => _items.fold(
    0.0,
    (sum, item) => sum + (item['totalWeight'] as double? ?? 0),
  );
  double get _laborCost {
    final percent = double.tryParse(_laborPercentController.text) ?? 0;
    return _materialsCost * (percent / 100);
  }

  double get _indirectCosts =>
      double.tryParse(_indirectCostsController.text) ?? 0;
  double get _subtotal => _materialsCost + _laborCost + _indirectCosts;
  double get _profitAmount {
    final margin = double.tryParse(_profitMarginController.text) ?? 0;
    return _subtotal * (margin / 100);
  }

  double get _discountAmount {
    final discount = double.tryParse(_discountController.text) ?? 0;
    return (_subtotal + _profitAmount) * (discount / 100);
  }

  double get _total => _subtotal + _profitAmount - _discountAmount;

  // Stock consolidado
  List<Map<String, dynamic>> _getStockIssues() {
    if (_consolidatedStock == null) return [];
    return _consolidatedStock!.where((m) => m['has_stock'] != true).toList();
  }

  List<Map<String, dynamic>> get _allConsolidatedMaterials =>
      _consolidatedStock ?? [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).clearSnackBars();
    });
    Future.microtask(() {
      ref.read(customersProvider.notifier).loadCustomers();
      ref.read(productsProvider.notifier).loadProducts();
      ref.read(inventoryProvider.notifier).loadMaterials();
    });
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AccountsDataSource.getAllAccounts(activeOnly: true);
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _selectedAccount = accounts.firstWhere(
          (a) => a.name.toLowerCase().contains('caja'),
          orElse: () => accounts.isNotEmpty
              ? accounts.first
              : Account(id: '', name: '', type: AccountType.cash, balance: 0),
        );
      });
    }
  }

  @override
  void dispose() {
    _laborPercentController.dispose();
    _indirectCostsController.dispose();
    _profitMarginController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ════════════════════════ STOCK CONSOLIDADO ════════════════════════
  Future<void> _refreshConsolidatedStock() async {
    if (_items.isEmpty) {
      setState(() => _consolidatedStock = []);
      return;
    }
    setState(() => _loadingStock = true);
    try {
      final inventoryState = ref.read(inventoryProvider);
      final Map<String, Map<String, dynamic>> aggregated = {};

      // 1. Materiales directos
      for (final item in _items) {
        if (item['isRecipe'] == true) continue;
        final materialId = item['materialId'] ?? item['inv_material_id'];
        if (materialId == null) continue;
        final requiredQty =
            (item['totalWeight'] as num?)?.toDouble() ??
            (item['quantity'] as num?)?.toDouble() ??
            0;
        if (aggregated.containsKey(materialId)) {
          aggregated[materialId]!['required_qty'] =
              (aggregated[materialId]!['required_qty'] as double) + requiredQty;
        } else {
          final material = inventoryState.materials
              .where((m) => m.id == materialId)
              .firstOrNull;
          aggregated[materialId] = {
            'material_id': materialId,
            'material_name': material?.name ?? item['name'] ?? '',
            'material_code': material?.code ?? item['material'] ?? '',
            'unit': material?.unit ?? item['unit'] ?? 'KG',
            'required_qty': requiredQty,
            'available_stock': material?.stock ?? 0.0,
            'source_items': item['name'] ?? '',
          };
        }
      }

      // 2. Recetas → expandir componentes
      final recipeItems = _items.where((i) => i['isRecipe'] == true).toList();
      if (recipeItems.isNotEmpty) {
        final compositeProducts = await CompositeProductsDataSource.getAll();
        final cpMap = {for (final cp in compositeProducts) cp.id: cp};
        for (final item in recipeItems) {
          final productId = item['productId'] as String?;
          if (productId == null) continue;
          final cp = cpMap[productId];
          if (cp == null) continue;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
          for (final comp in cp.components) {
            final matId = comp.materialId;
            if (matId.isEmpty) continue;
            final requiredKg = comp.weightPerUnit * comp.quantity * qty;
            if (aggregated.containsKey(matId)) {
              aggregated[matId]!['required_qty'] =
                  (aggregated[matId]!['required_qty'] as double) + requiredKg;
              final existing = aggregated[matId]!['source_items'] as String;
              if (!existing.contains(cp.name)) {
                aggregated[matId]!['source_items'] = '$existing, ${cp.name}';
              }
            } else {
              final material = inventoryState.materials
                  .where((m) => m.id == matId)
                  .firstOrNull;
              aggregated[matId] = {
                'material_id': matId,
                'material_name': material?.name ?? comp.materialName ?? '',
                'material_code': material?.code ?? comp.materialCode ?? '',
                'unit': material?.unit ?? 'KG',
                'required_qty': requiredKg,
                'available_stock': material?.stock ?? 0.0,
                'source_items': cp.name,
              };
            }
          }
        }
      }

      // 3. Calcular has_stock y shortage
      final result = aggregated.values.map((m) {
        final required = (m['required_qty'] as double?) ?? 0;
        final available = (m['available_stock'] as double?) ?? 0;
        return {
          ...m,
          'has_stock': available >= required,
          'shortage': (required - available).clamp(0, double.infinity),
        };
      }).toList();

      result.sort((a, b) {
        final aOk = a['has_stock'] == true ? 1 : 0;
        final bOk = b['has_stock'] == true ? 1 : 0;
        if (aOk != bOk) return aOk - bOk;
        return (a['material_name'] as String).compareTo(
          b['material_name'] as String,
        );
      });

      if (mounted) {
        setState(() {
          _consolidatedStock = result;
          _loadingStock = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStock = false);
    }
  }

  // ════════════════════════ BUILD ════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Panel lateral con resumen
          Container(
            width: 280,
            color: Colors.white,
            child: _buildSummaryPanel(),
          ),
          // Contenido principal
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: Stepper(
                      currentStep: _currentStep,
                      onStepContinue: _onStepContinue,
                      onStepCancel: _onStepCancel,
                      onStepTapped: (step) =>
                          setState(() => _currentStep = step),
                      controlsBuilder: (context, details) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            children: [
                              if (_currentStep < 3)
                                ElevatedButton(
                                  onPressed: details.onStepContinue,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _saleThemeColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text('Continuar'),
                                ),
                              if (_currentStep == 3) ...[
                                ElevatedButton.icon(
                                  onPressed: _isSaving
                                      ? null
                                      : _showSalePreview,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _saleThemeColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.receipt_long),
                                  label: Text(
                                    _isSaving
                                        ? 'Procesando...'
                                        : 'Previsualizar Venta',
                                  ),
                                ),
                              ],
                              const SizedBox(width: 12),
                              if (_currentStep > 0)
                                TextButton(
                                  onPressed: details.onStepCancel,
                                  child: const Text('Atrás'),
                                ),
                            ],
                          ),
                        );
                      },
                      steps: [
                        Step(
                          title: const Text('Cliente'),
                          subtitle: Text(
                            _selectedCustomerId != null
                                ? _customers.firstWhere(
                                    (c) => c['id'] == _selectedCustomerId,
                                    orElse: () => <String, dynamic>{
                                      'name': '...',
                                    },
                                  )['name']
                                : 'Selecciona un cliente',
                          ),
                          isActive: _currentStep >= 0,
                          state: _currentStep > 0
                              ? StepState.complete
                              : StepState.indexed,
                          content: _buildCustomerStep(),
                        ),
                        Step(
                          title: const Text('Productos'),
                          subtitle: Text(
                            '${_items.length} items - ${Helpers.formatNumber(_totalWeight)} kg',
                          ),
                          isActive: _currentStep >= 1,
                          state: _currentStep > 1
                              ? StepState.complete
                              : StepState.indexed,
                          content: _buildComponentsStep(),
                        ),
                        Step(
                          title: const Text('Costos y Precios'),
                          subtitle: Text(
                            'M.O. + Indirectos: ${Helpers.formatCurrency(_laborCost + _indirectCosts)}',
                          ),
                          isActive: _currentStep >= 2,
                          state: _currentStep > 2
                              ? StepState.complete
                              : StepState.indexed,
                          content: _buildCostsStep(),
                        ),
                        Step(
                          title: const Text('Pago y Confirmación'),
                          subtitle: Text(
                            'Total: ${Helpers.formatCurrency(_total)}',
                          ),
                          isActive: _currentStep >= 3,
                          state: _currentStep == 3
                              ? StepState.indexed
                              : StepState.indexed,
                          content: _buildPaymentStep(),
                        ),
                      ],
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

  // ════════════════════════ HEADER ════════════════════════
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/invoices'),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nueva Venta',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _saleThemeColor,
                  ),
                ),
                Text(
                  'Complete los pasos para registrar la venta',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('/invoices'),
            icon: const Icon(Icons.close),
            label: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════ PANEL LATERAL ════════════════════════
  Widget _buildSummaryPanel() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(color: _saleThemeColor),
          child: Row(
            children: [
              const Icon(Icons.point_of_sale, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Venta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _paymentType == 'cash' ? 'Contado' : 'Crédito',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildSummarySection(
                'Cliente',
                _selectedCustomerId != null
                    ? _customers.firstWhere(
                        (c) => c['id'] == _selectedCustomerId,
                        orElse: () => <String, dynamic>{
                          'name': 'No seleccionado',
                        },
                      )['name']
                    : 'No seleccionado',
                Icons.person,
              ),
              const SizedBox(height: 12),
              _buildSummarySection(
                'Productos',
                '${_items.length} items',
                Icons.inventory_2,
              ),
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 4),
                ..._items
                    .take(3)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(left: 28, bottom: 2),
                        child: Text(
                          '• ${item['name']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                if (_items.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      '+ ${_items.length - 3} más...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildCostLine('Materiales', _materialsCost),
              _buildCostLine('Mano de Obra', _laborCost),
              _buildCostLine('Costos Indirectos', _indirectCosts),
              const SizedBox(height: 8),
              const Divider(),
              _buildCostLine('Subtotal', _subtotal),
              _buildCostLine(
                'Margen (${_profitMarginController.text}%)',
                _profitAmount,
              ),
              if (_discountAmount > 0)
                _buildCostLine(
                  'Descuento (${_discountController.text}%)',
                  -_discountAmount,
                  color: Colors.red,
                ),
              const Divider(thickness: 2),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    Helpers.formatCurrency(_total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: _saleThemeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Peso total
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.scale, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Peso Total:',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                    const Spacer(),
                    Text(
                      '${Helpers.formatNumber(_totalWeight)} kg',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStockVerificationCard(),
              const SizedBox(height: 12),
              // Forma de pago en sidebar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _paymentType == 'cash'
                      ? Colors.green[50]
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _paymentType == 'cash'
                        ? Colors.green[300]!
                        : Colors.orange[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _paymentType == 'cash'
                              ? Icons.payments
                              : Icons.calendar_month,
                          color: _paymentType == 'cash'
                              ? Colors.green[700]
                              : Colors.orange[700],
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _paymentType == 'cash'
                              ? 'Pago de Contado'
                              : 'Crédito ($_creditDays días)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _paymentType == 'cash'
                                ? Colors.green[800]
                                : Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                    if (_paymentType == 'cash' && _selectedAccount != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${_getPaymentMethodLabel()} → ${_selectedAccount!.name}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green[600],
                          ),
                        ),
                      ),
                    if (_paymentType == 'credit' && _installments > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$_installments cuotas de ${Helpers.formatCurrency(_total / _installments)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getPaymentMethodLabel() {
    switch (_paymentMethod) {
      case 'cash':
        return 'Efectivo';
      case 'transfer':
        return 'Transferencia';
      case 'card':
        return 'Tarjeta';
      default:
        return 'Efectivo';
    }
  }

  Widget _buildStockVerificationCard() {
    if (_items.isEmpty) return const SizedBox.shrink();
    final allMaterials = _allConsolidatedMaterials;
    final issues = _getStockIssues();
    final hasIssues = issues.isNotEmpty;
    final totalMaterials = allMaterials.length;

    String fmtQty(num v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _loadingStock
            ? Colors.blue[50]
            : (hasIssues ? Colors.orange[50] : Colors.green[50]),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _loadingStock
              ? Colors.blue[200]!
              : (hasIssues ? Colors.orange[300]! : Colors.green[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_loadingStock)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.blue[600],
                  ),
                )
              else
                Icon(
                  hasIssues ? Icons.warning_amber : Icons.check_circle,
                  color: hasIssues ? Colors.orange[700] : Colors.green[700],
                  size: 14,
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _loadingStock
                      ? 'Verificando stock...'
                      : (hasIssues ? 'Stock Insuficiente' : 'Stock Completo'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: _loadingStock
                        ? Colors.blue[700]
                        : (hasIssues ? Colors.orange[800] : Colors.green[800]),
                  ),
                ),
              ),
              if (!_loadingStock && totalMaterials > 0)
                Text(
                  '${totalMaterials - issues.length}/$totalMaterials',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: hasIssues ? Colors.orange[600] : Colors.green[600],
                  ),
                ),
            ],
          ),
          if (!_loadingStock && allMaterials.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...allMaterials.take(6).map((m) {
              final hasStock = m['has_stock'] == true;
              final shortage = (m['shortage'] as num?)?.toDouble() ?? 0;
              final required = (m['required_qty'] as num?)?.toDouble() ?? 0;
              final available = (m['available_stock'] as num?)?.toDouble() ?? 0;
              final unit = m['unit'] ?? 'KG';
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(
                      hasStock ? Icons.check_circle : Icons.cancel,
                      size: 10,
                      color: hasStock ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        m['material_name'] ?? '',
                        style: TextStyle(
                          fontSize: 9,
                          color: hasStock ? Colors.grey[700] : Colors.red[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      fmtQty(required),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: hasStock ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                    Text(
                      '/${fmtQty(available)} $unit',
                      style: TextStyle(fontSize: 8, color: Colors.grey[500]),
                    ),
                    if (!hasStock) ...[
                      const SizedBox(width: 2),
                      Text(
                        '-${fmtQty(shortage)}',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            if (allMaterials.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+ ${allMaterials.length - 6} más...',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummarySection(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCostLine(String label, double value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: color ?? Colors.grey[700], fontSize: 12),
          ),
          Text(
            Helpers.formatCurrency(value),
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  // ════════════════════════ PASO 1: CLIENTE ════════════════════════
  Widget _buildCustomerStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona el cliente para esta venta',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCustomerId,
          decoration: InputDecoration(
            labelText: 'Cliente',
            prefixIcon: const Icon(Icons.person),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: _customers
              .map(
                (c) => DropdownMenuItem(
                  value: c['id'] as String,
                  child: Text('${c['name']} - RUC: ${c['ruc']}'),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedCustomerId = value),
          validator: (value) => value == null ? 'Seleccione un cliente' : null,
        ),
      ],
    );
  }

  // ════════════════════════ PASO 2: PRODUCTOS ════════════════════════
  Widget _buildComponentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Productos / Servicios',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  _showAddMaterialDialog(ref.read(inventoryProvider).materials),
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('Agregar Material'),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _showSelectProductDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar Producto'),
              style: FilledButton.styleFrom(backgroundColor: _saleThemeColor),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No hay productos agregados',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Haz clic en "Agregar" para añadir productos',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Producto',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Material',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Cant.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Peso',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'P/kg',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(width: 36),
                    ],
                  ),
                ),
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isRecipe = item['isRecipe'] == true;
                  final List<dynamic> components = item['components'] ?? [];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isRecipe) ...[
                                        Icon(
                                          Icons.receipt_long,
                                          size: 14,
                                          color: Colors.purple[600],
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          item['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        item['dimensions'] ?? '',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (isRecipe &&
                                          item['livePricingUsed'] == true) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green[50],
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.sync,
                                                size: 8,
                                                color: Colors.green[600],
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                'EN VIVO',
                                                style: TextStyle(
                                                  fontSize: 7,
                                                  color: Colors.green[700],
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                item['material'] ?? '-',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${item['quantity']}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${Helpers.formatNumber(item['totalWeight'] as double? ?? 0)} kg',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                Helpers.formatCurrency(
                                  item['pricePerKg'] as double? ??
                                      item['unitSalePrice'] as double? ??
                                      0,
                                ),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                Helpers.formatCurrency(
                                  item['totalPrice'] as double? ?? 0,
                                ),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() => _items.removeAt(index));
                                  _refreshConsolidatedStock();
                                },
                              ),
                            ),
                          ],
                        ),
                        // Sub-items: componentes de la receta
                        if (isRecipe && components.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            margin: const EdgeInsets.only(left: 18, right: 36),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Componentes (${components.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...components.take(5).map((c) {
                                  final compName =
                                      c['name'] ??
                                      c['material_name'] ??
                                      'Material';
                                  final compQty =
                                      (c['quantity'] ?? c['required_qty'] ?? 0)
                                          as num;
                                  final weightTotal =
                                      (c['weight_total'] as num?)?.toDouble() ??
                                      0;
                                  final hasStock = c['has_stock'] ?? true;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            '$compQty× $compName',
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (weightTotal > 0)
                                          Expanded(
                                            child: Text(
                                              '${Helpers.formatNumber(weightTotal)} kg',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey[600],
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: hasStock == true
                                                ? Colors.green[100]
                                                : Colors.red[100],
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            hasStock == true
                                                ? 'OK'
                                                : 'Sin stock',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                              color: hasStock == true
                                                  ? Colors.green[700]
                                                  : Colors.red[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (components.length > 5)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '+${components.length - 5} componentes más',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.blue[700],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                // Total
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _saleThemeColor.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(5),
                    ),
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'TOTAL',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Expanded(flex: 2, child: SizedBox()),
                      Expanded(
                        child: Text(
                          '${_items.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${Helpers.formatNumber(_totalWeight)} kg',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                      Expanded(
                        child: Text(
                          Helpers.formatCurrency(_materialsCost),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _saleThemeColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 36),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ════════════════════════ PASO 3: COSTOS ════════════════════════
  Widget _buildCostsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mano de obra
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              const Icon(Icons.engineering, color: _saleThemeColor),
              const SizedBox(width: 8),
              const Text(
                'Mano de Obra',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _laborPercentController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    suffixText: '%',
                    hintText: '15',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'del costo de materiales',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  Helpers.formatCurrency(_laborCost),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Costos indirectos
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Costos Indirectos',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _indirectCostsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Total costos indirectos',
                  hintText: 'Energía, gas, insumos, etc.',
                  prefixText: '\$ ',
                  prefixIcon: const Icon(Icons.receipt_long),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Margen de ganancia
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Margen de Ganancia',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _profitMarginController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Porcentaje de ganancia',
                        suffixText: '%',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Slider(
                      value:
                          double.tryParse(_profitMarginController.text) ?? 20,
                      min: 0,
                      max: 50,
                      divisions: 50,
                      label: '${_profitMarginController.text}%',
                      onChanged: (value) {
                        setState(() {
                          _profitMarginController.text = value.toStringAsFixed(
                            0,
                          );
                        });
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Text('Ganancia', style: TextStyle(fontSize: 12)),
                        Text(
                          Helpers.formatCurrency(_profitAmount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Descuento
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.discount, color: Colors.red[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Descuento',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    '(Opcional)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Porcentaje de descuento',
                        suffixText: '%',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Slider(
                      value: double.tryParse(_discountController.text) ?? 0,
                      min: 0,
                      max: 30,
                      divisions: 30,
                      label: '${_discountController.text}%',
                      activeColor: Colors.red[400],
                      onChanged: (value) {
                        setState(() {
                          _discountController.text = value.toStringAsFixed(0);
                        });
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Text('Descuento', style: TextStyle(fontSize: 12)),
                        Text(
                          '- ${Helpers.formatCurrency(_discountAmount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════ PASO 4: PAGO Y CONFIRMACIÓN ════════════════════════
  Widget _buildPaymentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Forma de pago
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payment, color: _saleThemeColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Forma de Pago',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Selector Contado / Crédito
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentTypeCard(
                      'cash',
                      'Contado',
                      'Pago inmediato al confirmar',
                      Icons.payments,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPaymentTypeCard(
                      'credit',
                      'Crédito',
                      'Pago a plazos / cuotas',
                      Icons.calendar_month,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Opciones según tipo de pago
              if (_paymentType == 'cash') _buildCashOptions(),
              if (_paymentType == 'credit') _buildCreditOptions(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Notas
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.notes, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Notas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Notas adicionales de la venta...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Resumen final
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _saleThemeColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _saleThemeColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Resumen de Venta',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildFinalSummaryRow(
                'Cliente',
                _selectedCustomerId != null
                    ? _customers.firstWhere(
                        (c) => c['id'] == _selectedCustomerId,
                        orElse: () => <String, dynamic>{'name': '-'},
                      )['name']
                    : '-',
              ),
              _buildFinalSummaryRow('Productos', '${_items.length} items'),
              _buildFinalSummaryRow(
                'Peso Total',
                '${Helpers.formatNumber(_totalWeight)} kg',
              ),
              _buildFinalSummaryRow(
                'Pago',
                _paymentType == 'cash'
                    ? '${_getPaymentMethodLabel()} (contado)'
                    : 'Crédito $_creditDays días${_installments > 1 ? ' ($_installments cuotas)' : ''}',
              ),
              const Divider(height: 24),
              _buildFinalSummaryRow(
                'Materiales',
                Helpers.formatCurrency(_materialsCost),
              ),
              _buildFinalSummaryRow(
                'Mano de Obra',
                Helpers.formatCurrency(_laborCost),
              ),
              _buildFinalSummaryRow(
                'Costos Indirectos',
                Helpers.formatCurrency(_indirectCosts),
              ),
              _buildFinalSummaryRow(
                'Subtotal',
                Helpers.formatCurrency(_subtotal),
              ),
              _buildFinalSummaryRow(
                'Ganancia (${_profitMarginController.text}%)',
                Helpers.formatCurrency(_profitAmount),
              ),
              if (_discountAmount > 0)
                _buildFinalSummaryRow(
                  'Descuento',
                  '- ${Helpers.formatCurrency(_discountAmount)}',
                ),
              const Divider(height: 24, thickness: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    Helpers.formatCurrency(_total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: _saleThemeColor,
                    ),
                  ),
                ],
              ),
              // Stock consolidado
              const SizedBox(height: 16),
              if (_loadingStock)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Verificando stock...',
                        style: TextStyle(color: Colors.blue[800], fontSize: 12),
                      ),
                    ],
                  ),
                )
              else if (_consolidatedStock != null)
                Builder(
                  builder: (context) {
                    final allMaterials = _allConsolidatedMaterials;
                    final issues = _getStockIssues();
                    final allOk = issues.isEmpty;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: allOk ? Colors.green[50] : Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: allOk
                              ? Colors.green[300]!
                              : Colors.orange[300]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                allOk
                                    ? Icons.check_circle
                                    : Icons.warning_amber,
                                color: allOk
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                allOk
                                    ? 'Stock Completo (${allMaterials.length} materiales)'
                                    : '${issues.length} de ${allMaterials.length} materiales sin stock',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: allOk
                                      ? Colors.green[800]
                                      : Colors.orange[800],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...allMaterials.map((mat) {
                            final hasStock = mat['has_stock'] == true;
                            final name = mat['material_name'] ?? '';
                            final required =
                                (mat['required_qty'] as num?)?.toDouble() ?? 0;
                            final available =
                                (mat['available_stock'] as num?)?.toDouble() ??
                                0;
                            final unit = mat['unit'] ?? 'KG';
                            String fmt(double v) => v == v.roundToDouble()
                                ? v.toStringAsFixed(0)
                                : v.toStringAsFixed(1);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                children: [
                                  Icon(
                                    hasStock
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 14,
                                    color: hasStock
                                        ? Colors.green[600]
                                        : Colors.red[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${fmt(required)} $unit',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: hasStock
                                          ? Colors.green[700]
                                          : Colors.red[700],
                                    ),
                                  ),
                                  Text(
                                    ' / ${fmt(available)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  if (!hasStock) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Faltan ${fmt((mat['shortage'] as num?)?.toDouble() ?? 0)}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Colors.red[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTypeCard(
    String type,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    final isSelected = _paymentType == type;
    return InkWell(
      onTap: () => setState(() => _paymentType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[400], size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? color : Colors.grey[700],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? color : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCashOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Método de pago',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMethodChip('cash', 'Efectivo', Icons.money),
            const SizedBox(width: 8),
            _buildMethodChip('transfer', 'Transferencia', Icons.swap_horiz),
            const SizedBox(width: 8),
            _buildMethodChip('card', 'Tarjeta', Icons.credit_card),
          ],
        ),
        const SizedBox(height: 16),
        // Seleccionar cuenta
        Text(
          'Cuenta destino',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedAccount?.id,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.account_balance_wallet),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: _accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a.id,
                  child: Text(
                    '${a.name} (${Helpers.formatCurrency(a.balance)})',
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedAccount = _accounts.firstWhere((a) => a.id == value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildMethodChip(String method, String label, IconData icon) {
    final isSelected = _paymentMethod == method;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      onSelected: (_) => setState(() => _paymentMethod = method),
      selectedColor: Colors.green,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[800],
      ),
    );
  }

  Widget _buildCreditOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plazo de crédito',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildDaysChip(30),
            const SizedBox(width: 8),
            _buildDaysChip(60),
            const SizedBox(width: 8),
            _buildDaysChip(90),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Número de cuotas',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildInstallmentChip(1),
            const SizedBox(width: 8),
            _buildInstallmentChip(2),
            const SizedBox(width: 8),
            _buildInstallmentChip(3),
            const SizedBox(width: 8),
            _buildInstallmentChip(6),
          ],
        ),
        if (_installments > 1) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Monto por cuota:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      Helpers.formatCurrency(_total / _installments),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$_installments cuotas durante $_creditDays días',
                  style: TextStyle(fontSize: 12, color: Colors.orange[600]),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDaysChip(int days) {
    final isSelected = _creditDays == days;
    return ChoiceChip(
      selected: isSelected,
      label: Text('$days días'),
      onSelected: (_) => setState(() => _creditDays = days),
      selectedColor: Colors.orange,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[800],
      ),
    );
  }

  Widget _buildInstallmentChip(int n) {
    final isSelected = _installments == n;
    return ChoiceChip(
      selected: isSelected,
      label: Text(n == 1 ? '1 pago' : '$n cuotas'),
      onSelected: (_) => setState(() => _installments = n),
      selectedColor: Colors.orange,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[800],
      ),
    );
  }

  Widget _buildFinalSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ════════════════════════ NAVEGACIÓN ════════════════════════
  void _onStepContinue() {
    if (_currentStep == 0 && _selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un cliente'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_currentStep == 1 && _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agregue al menos un producto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // ════════════════════════ PREVISUALIZAR VENTA ════════════════════════
  void _showSalePreview() {
    if (_selectedCustomerId == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un cliente y agregue productos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_paymentType == 'cash' &&
        (_selectedAccount == null || _selectedAccount!.id.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione una cuenta destino para el pago'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final customer = _customers.firstWhere(
      (c) => c['id'] == _selectedCustomerId,
      orElse: () => <String, dynamic>{'name': 'Sin cliente', 'ruc': ''},
    );

    showDialog(
      context: context,
      builder: (context) => _SalePreviewDialog(
        customer: customer,
        items: _items,
        materialsCost: _materialsCost,
        laborCost: _laborCost,
        indirectCosts: _indirectCosts,
        subtotal: _subtotal,
        profitMargin: double.tryParse(_profitMarginController.text) ?? 0,
        profitAmount: _profitAmount,
        discount: _discountAmount,
        total: _total,
        totalWeight: _totalWeight,
        notes: _notesController.text,
        paymentType: _paymentType,
        paymentMethodLabel: _getPaymentMethodLabel(),
        accountName: _selectedAccount?.name ?? '',
        creditDays: _creditDays,
        installments: _installments,
        stockMaterials: _allConsolidatedMaterials,
        stockIssues: _getStockIssues(),
        onConfirm: () {
          Navigator.of(context).pop();
          _confirmSale();
        },
      ),
    );
  }

  // ════════════════════════ CONFIRMAR VENTA ════════════════════════
  Future<void> _confirmSale() async {
    if (_selectedCustomerId == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un cliente y agregue productos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_paymentType == 'cash' &&
        (_selectedAccount == null || _selectedAccount!.id.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione una cuenta destino para el pago'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Verificar stock
    final stockIssues = _getStockIssues();
    if (stockIssues.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[700], size: 22),
              const SizedBox(width: 8),
              const Text('Stock Insuficiente', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Materiales sin stock suficiente:',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 8),
                ...stockIssues
                    .take(6)
                    .map(
                      (issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 6, color: Colors.red[400]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                issue['material_name'] ?? '',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                const Text(
                  'El stock quedará negativo. ¿Continuar con la venta?',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Vender Igualmente'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    // Diálogo de confirmación final
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Confirmar Venta', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se creará una factura por ${Helpers.formatCurrency(_total)}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (_paymentType == 'cash') ...[
                Row(
                  children: [
                    const Icon(Icons.payments, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pago de contado: ${_getPaymentMethodLabel()} → ${_selectedAccount?.name ?? ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Crédito: $_creditDays días${_installments > 1 ? ', $_installments cuotas de ${Helpers.formatCurrency(_total / _installments)}' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.inventory, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Se descontará el inventario automáticamente',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Confirmar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // ═══════ EJECUTAR LA VENTA ═══════
    setState(() => _isSaving = true);

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final customersState = ref.read(customersProvider);
      final customer = customersState.customers.firstWhere(
        (c) => c.id == _selectedCustomerId,
      );

      // Fecha de vencimiento según tipo de pago
      final dueDate = _paymentType == 'credit'
          ? DateTime.now().add(Duration(days: _creditDays))
          : DateTime.now();

      // 1. Crear factura con items
      final invoice = await InvoicesDataSource.createWithItems(
        type: 'invoice',
        series: 'FAC',
        customer: customer,
        issueDate: DateTime.now(),
        dueDate: dueDate,
        taxRate: 0,
        items: _items
            .map(
              (item) => InvoiceItem(
                id: '',
                invoiceId: '',
                productId: item['productId'],
                materialId: item['materialId'],
                productCode: item['material'] ?? item['productCode'] ?? '',
                productName: item['name'] ?? '',
                description: item['dimensions'] ?? '',
                quantity: (item['quantity'] as num?)?.toDouble() ?? 1,
                unit: item['unit'] ?? 'und',
                unitPrice:
                    (item['totalPrice'] as double? ?? 0) /
                    ((item['quantity'] as num?)?.toDouble() ?? 1),
                discount: 0,
                taxRate: 0,
                subtotal: item['totalPrice'] as double? ?? 0,
                taxAmount: 0,
                total: item['totalPrice'] as double? ?? 0,
              ),
            )
            .toList(),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      AppLogger.info('📝 Factura creada: ${invoice.fullNumber}');

      // 2. Emitir factura (esto descuenta inventario automáticamente)
      await InvoicesDataSource.updateStatus(invoice.id, 'issued');
      AppLogger.info('📦 Inventario descontado para ${invoice.fullNumber}');

      // 3. Si es pago de contado, registrar pago
      if (_paymentType == 'cash' && _selectedAccount != null) {
        await InvoicesDataSource.registerPayment(
          invoiceId: invoice.id,
          amount: invoice.total,
          method: _paymentMethod,
          accountId: _selectedAccount!.id,
          reference: 'Pago de contado - ${invoice.fullNumber}',
        );
        AppLogger.info(
          '💰 Pago registrado: ${invoice.total} en ${_selectedAccount!.name}',
        );
      }

      // 4. Refrescar providers
      ref.read(invoicesProvider.notifier).refresh();
      ref.read(productsProvider.notifier).loadProducts();
      ref.read(inventoryProvider.notifier).loadMaterials();

      // Cerrar loading
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _paymentType == 'cash'
                      ? 'Venta ${invoice.fullNumber} completada y pagada'
                      : 'Venta ${invoice.fullNumber} creada a crédito',
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        context.go('/invoices');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // cerrar loading
      AppLogger.error('❌ Error en venta: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ════════════════════════ DIÁLOGOS DE PRODUCTOS ════════════════════════
  void _showAddMaterialDialog(List<domain.Material> materials) {
    showDialog(
      context: context,
      builder: (context) => _SaleAddMaterialDialog(
        materials: materials,
        onAdd: (materialData) {
          setState(() => _items.add(materialData));
          _refreshConsolidatedStock();
        },
      ),
    );
  }

  void _showSelectProductDialog() {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay productos en el inventario.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _SaleSelectProductDialog(
        products: _products,
        categories: _categories,
        onSelect: (product, quantity, recipeComponents, livePricing) {
          setState(() {
            final bool hasLivePricing =
                livePricing != null && livePricing['success'] == true;

            final unitWeight = hasLivePricing
                ? (livePricing['total_weight'] as num?)?.toDouble() ??
                      product.totalWeight
                : (product.totalWeight > 0 ? product.totalWeight : 0.0);
            final totalWeight = unitWeight * quantity;

            final double unitSalePrice;
            final double unitCostPrice;
            final double salePricePerKg;
            final double costPricePerKg;
            final double productProfit;
            final double productMargin;

            if (hasLivePricing) {
              unitSalePrice =
                  (livePricing['total_sale'] as num?)?.toDouble() ??
                  product.unitPrice;
              unitCostPrice =
                  (livePricing['total_cost'] as num?)?.toDouble() ??
                  product.costPrice;
              salePricePerKg =
                  (livePricing['sale_per_kg'] as num?)?.toDouble() ??
                  (unitWeight > 0 ? unitSalePrice / unitWeight : unitSalePrice);
              costPricePerKg =
                  (livePricing['cost_per_kg'] as num?)?.toDouble() ??
                  (unitWeight > 0 ? unitCostPrice / unitWeight : unitCostPrice);
              productProfit =
                  (livePricing['profit'] as num?)?.toDouble() ??
                  (unitSalePrice - unitCostPrice);
              productMargin =
                  (livePricing['profit_margin'] as num?)?.toDouble() ?? 0;
            } else {
              final productCost = product.totalCost > 0
                  ? product.totalCost
                  : product.costPrice;
              unitSalePrice = product.unitPrice;
              unitCostPrice = productCost;
              salePricePerKg = unitWeight > 0
                  ? product.unitPrice / unitWeight
                  : product.unitPrice;
              costPricePerKg = unitWeight > 0
                  ? productCost / unitWeight
                  : productCost;
              productProfit = product.unitPrice - productCost;
              productMargin = product.profitMargin;
            }

            // Convertir componentes de receta para almacenar
            final components = <Map<String, dynamic>>[];
            if (hasLivePricing && livePricing['components'] != null) {
              for (final c in (livePricing['components'] as List<dynamic>)) {
                components.add(<String, dynamic>{
                  'name': c['material_name'] ?? c['name'] ?? '',
                  'quantity': c['quantity'] ?? 0,
                  'calculated_weight': c['calculated_weight'] ?? 0,
                  'weight_total': c['weight_total'] ?? 0,
                  'unit': c['unit'] ?? 'KG',
                  'cost_per_kg': c['cost_per_kg'] ?? 0,
                  'sale_per_kg': c['sale_per_kg'] ?? 0,
                  'cost_total': c['cost_total'] ?? 0,
                  'sale_total': c['sale_total'] ?? 0,
                  'stock': c['stock'] ?? 0,
                  'has_stock':
                      (c['stock'] as num? ?? 0) >=
                      (c['weight_total'] as num? ?? 0),
                });
              }
            } else if (recipeComponents != null) {
              for (final c in recipeComponents) {
                components.add(<String, dynamic>{
                  'name': c['component_name'] ?? c['name'] ?? '',
                  'quantity': c['required_qty'] ?? c['quantity'] ?? 0,
                  'unit': c['unit'] ?? '',
                  'stock': c['current_stock'] ?? 0,
                  'has_stock': c['has_stock'] ?? true,
                });
              }
            }

            _items.add({
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'productId': product.id,
              'name': product.name,
              'type': 'product',
              'material': product.code,
              'dimensions':
                  product.description ?? (product.isRecipe ? 'Receta' : '-'),
              'quantity': quantity,
              'unitWeight': unitWeight,
              'totalWeight': totalWeight,
              'pricePerKg': salePricePerKg,
              'unitSalePrice': salePricePerKg,
              'unitCostPrice': costPricePerKg,
              'costPrice': costPricePerKg,
              'totalPrice': unitSalePrice * quantity,
              'totalCost': unitCostPrice * quantity,
              'unitProfit': productProfit,
              'totalProfit': productProfit * quantity,
              'profitMargin': productMargin,
              'productCode': product.code,
              'stock': product.stock,
              'unit': product.unit,
              'isRecipe': product.isRecipe,
              'components': components,
              'livePricingUsed': hasLivePricing,
            });
          });
          _refreshConsolidatedStock();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DIÁLOGO: Seleccionar producto del inventario
// (Versión simplificada para ventas - sin filtro de stock en recetas)
// ═══════════════════════════════════════════════════════════════
class _SaleSelectProductDialog extends StatefulWidget {
  final List<Product> products;
  final List<Category> categories;
  final Function(
    Product product,
    double quantity,
    List<Map<String, dynamic>>? components,
    Map<String, dynamic>? livePricing,
  )
  onSelect;

  const _SaleSelectProductDialog({
    required this.products,
    required this.categories,
    required this.onSelect,
  });

  @override
  State<_SaleSelectProductDialog> createState() =>
      _SaleSelectProductDialogState();
}

class _SaleSelectProductDialogState extends State<_SaleSelectProductDialog> {
  String _searchQuery = '';
  String? _selectedCategoryId;
  Product? _selectedProduct;
  final _quantityController = TextEditingController(text: '1');
  Map<String, dynamic>? _livePricing;
  bool _loadingPricing = false;

  // Stock check de recetas
  List<Map<String, dynamic>>? _recipeStockCheck;
  bool _isCheckingStock = false;

  // Precios EN VIVO de todas las recetas para la lista
  Map<String, double> _recipeLiveVentaPrices = {};
  bool _isLoadingRecipePrices = false;

  List<Product> get _filteredProducts {
    var list = widget.products;
    if (_selectedCategoryId != null) {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                p.code.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadRecipeLivePrices();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  /// Cargar precios EN VIVO de todas las recetas para la lista
  Future<void> _loadRecipeLivePrices() async {
    setState(() => _isLoadingRecipePrices = true);
    try {
      final compositeProducts = await CompositeProductsDataSource.getAll();
      final Map<String, double> prices = {};
      for (final cp in compositeProducts) {
        prices[cp.id] = cp.materialsCost;
      }
      if (mounted) {
        setState(() {
          _recipeLiveVentaPrices = prices;
          _isLoadingRecipePrices = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRecipePrices = false);
    }
  }

  Future<void> _loadLivePricing(Product product) async {
    if (!product.isRecipe) {
      setState(() => _livePricing = null);
      return;
    }
    setState(() => _loadingPricing = true);
    try {
      final pricing = await InventoryDataSource.getRecipeLivePricing(
        product.id,
      );
      if (mounted) {
        setState(() {
          _livePricing = pricing;
          _loadingPricing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPricing = false);
    }
  }

  Future<void> _checkRecipeStock(Product product, int quantity) async {
    if (!product.isRecipe) return;
    setState(() => _isCheckingStock = true);
    try {
      final stockCheck = await InventoryDataSource.checkRecipeStock(
        product.id,
        quantity: quantity,
      );
      if (mounted) {
        setState(() {
          _recipeStockCheck = stockCheck;
          _isCheckingStock = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recipeStockCheck = null;
          _isCheckingStock = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.shopping_bag,
                  color: _saleThemeColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Seleccionar Producto',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Filtros
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar producto...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: InputDecoration(
                      hintText: 'Categoría',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...widget.categories.map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Lista de productos
            Expanded(
              child: Row(
                children: [
                  // Lista
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final p = _filteredProducts[index];
                        final isSelected = _selectedProduct?.id == p.id;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: _saleThemeColor.withValues(
                            alpha: 0.1,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: p.isRecipe
                                ? Colors.purple[100]
                                : Colors.blue[100],
                            child: Icon(
                              p.isRecipe
                                  ? Icons.auto_fix_high
                                  : Icons.inventory_2,
                              size: 18,
                              color: p.isRecipe
                                  ? Colors.purple[700]
                                  : Colors.blue[700],
                            ),
                          ),
                          title: Text(
                            p.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.code,
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (p.isRecipe) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 12,
                                      color: Colors.purple[600],
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Receta',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.purple[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (p.totalWeight > 0) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.scale,
                                        size: 10,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${Helpers.formatNumber(p.totalWeight)} kg',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Icon(
                                      p.stock > 0
                                          ? Icons.check_circle
                                          : Icons.warning,
                                      size: 12,
                                      color: p.stock > 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Stock: ${p.stock.toStringAsFixed(0)} ${p.unit}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: p.stock > 0
                                            ? Colors.green[700]
                                            : Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: Builder(
                            builder: (context) {
                              final livePrice = p.isRecipe
                                  ? _recipeLiveVentaPrices[p.id]
                                  : null;
                              final displayPrice = livePrice ?? p.unitPrice;
                              final hasLivePrice = livePrice != null;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    Helpers.formatCurrency(displayPrice),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: hasLivePrice
                                          ? Colors.green[700]
                                          : _saleThemeColor,
                                    ),
                                  ),
                                  if (hasLivePrice)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.sync,
                                          size: 9,
                                          color: Colors.green[600],
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'EN VIVO',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.green[600],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (p.isRecipe &&
                                      _isLoadingRecipePrices &&
                                      livePrice == null)
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          onTap: () {
                            setState(() {
                              _selectedProduct = p;
                              _livePricing = null;
                              _recipeStockCheck = null;
                            });
                            _loadLivePricing(p);
                            if (p.isRecipe) {
                              _checkRecipeStock(
                                p,
                                int.tryParse(_quantityController.text) ?? 1,
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  // Detalle del producto seleccionado
                  if (_selectedProduct != null) ...[
                    const VerticalDivider(),
                    SizedBox(width: 320, child: _buildProductDetail()),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetail() {
    final product = _selectedProduct!;
    final isRecipe = product.isRecipe;
    final hasStock = isRecipe || product.stock > 0;
    final bool hasLive =
        _livePricing != null && _livePricing!['success'] == true;
    final livePrice = hasLive
        ? (_livePricing!['total_sale'] as num?)?.toDouble()
        : null;
    final liveCost = hasLive
        ? (_livePricing!['total_cost'] as num?)?.toDouble()
        : null;
    final liveWeight = hasLive
        ? (_livePricing!['total_weight'] as num?)?.toDouble()
        : null;
    final liveMargin = hasLive
        ? (_livePricing!['profit_margin'] as num?)?.toDouble()
        : null;
    final displayPrice = livePrice ?? product.unitPrice;
    final displayCost = liveCost ?? product.costPrice;
    final displayWeight = liveWeight ?? product.totalWeight;

    // Componentes del live pricing
    final List<dynamic> components =
        hasLive && _livePricing!['components'] != null
        ? (_livePricing!['components'] as List<dynamic>)
        : [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nombre y badge
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      product.code,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isRecipe)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 14,
                        color: Colors.purple[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Receta',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (product.description != null &&
              product.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              product.description!,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),

          // Precio y Peso / Stock en cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasLive ? Colors.green[50] : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasLive ? Colors.green[200]! : Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Precio Venta',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (hasLive) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.sync,
                              size: 10,
                              color: Colors.green[600],
                            ),
                          ],
                        ],
                      ),
                      if (_loadingPricing)
                        const SizedBox(
                          height: 2,
                          child: LinearProgressIndicator(),
                        )
                      else
                        Text(
                          Helpers.formatCurrency(displayPrice),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasLive ? Colors.red[50] : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasLive ? Colors.red[200]! : Colors.grey[200]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Costo',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      if (_loadingPricing)
                        const SizedBox(
                          height: 2,
                          child: LinearProgressIndicator(),
                        )
                      else
                        Text(
                          Helpers.formatCurrency(displayCost),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Peso y Stock/Componentes
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.scale, size: 12, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Peso Total',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${Helpers.formatNumber(displayWeight)} kg',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isRecipe
                        ? Colors.purple[50]
                        : (hasStock ? Colors.green[50] : Colors.red[50]),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isRecipe
                          ? Colors.purple[200]!
                          : (hasStock ? Colors.green[200]! : Colors.red[200]!),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRecipe ? 'Componentes' : 'Stock',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      if (isRecipe)
                        Text(
                          '${components.isNotEmpty ? components.length : (_recipeStockCheck?.length ?? '...')} materiales',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                            fontSize: 12,
                          ),
                        )
                      else
                        Text(
                          '${product.stock.toStringAsFixed(0)} ${product.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasStock
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Margen si hay live pricing
          if (hasLive && liveMargin != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.sync, size: 14, color: Colors.green[700]),
                  const SizedBox(width: 6),
                  Text(
                    'Precios en VIVO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Margen: ${liveMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Componentes / Sub-items de la receta
          if (isRecipe && components.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.list_alt, size: 14, color: Colors.blue[800]),
                      const SizedBox(width: 6),
                      Text(
                        'Componentes (${components.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Header row
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Material',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            'Cant.',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Peso',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 44,
                          child: Text(
                            'Stock',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey[300]),
                  ...components.map((c) {
                    final compName =
                        c['material_name'] ?? c['name'] ?? 'Material';
                    final qty = (c['quantity'] as num?)?.toDouble() ?? 0;
                    final weightTotal =
                        (c['weight_total'] as num?)?.toDouble() ?? 0;
                    final stock = (c['stock'] as num?)?.toDouble() ?? 0;
                    final hasEnough = stock >= weightTotal;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              compName.toString(),
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              qty.toStringAsFixed(
                                qty == qty.roundToDouble() ? 0 : 1,
                              ),
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${Helpers.formatNumber(weightTotal)} kg',
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 44,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: hasEnough
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                hasEnough ? 'OK' : 'Falta',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: hasEnough
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Stock check loading
          if (isRecipe && _isCheckingStock)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue[300],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verificando stock...',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Cantidad
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _saleThemeColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cantidad:',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            suffixText: product.unit,
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {});
                            if (product.isRecipe) {
                              _checkRecipeStock(
                                product,
                                int.tryParse(value) ?? 1,
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Subtotal:',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          Helpers.formatCurrency(
                            displayPrice *
                                (double.tryParse(_quantityController.text) ??
                                    1),
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _saleThemeColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Botón agregar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final qty = double.tryParse(_quantityController.text) ?? 1;
                if (qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingrese una cantidad válida'),
                    ),
                  );
                  return;
                }
                widget.onSelect(
                  _selectedProduct!,
                  qty,
                  _recipeStockCheck,
                  _livePricing,
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text('Agregar a Venta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _saleThemeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DIÁLOGO: Agregar material directo del inventario
// ═══════════════════════════════════════════════════════════════
class _SaleAddMaterialDialog extends StatefulWidget {
  final List<domain.Material> materials;
  final Function(Map<String, dynamic>) onAdd;

  const _SaleAddMaterialDialog({required this.materials, required this.onAdd});

  @override
  State<_SaleAddMaterialDialog> createState() => _SaleAddMaterialDialogState();
}

class _SaleAddMaterialDialogState extends State<_SaleAddMaterialDialog> {
  String _searchQuery = '';
  domain.Material? _selectedMaterial;
  final _quantityController = TextEditingController(text: '1');

  List<domain.Material> get _filteredMaterials {
    if (_searchQuery.isEmpty) return widget.materials;
    final q = _searchQuery.toLowerCase();
    return widget.materials
        .where(
          (m) =>
              m.name.toLowerCase().contains(q) ||
              m.code.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2, color: _saleThemeColor, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Agregar Material',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar material...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredMaterials.length,
                      itemBuilder: (context, index) {
                        final m = _filteredMaterials[index];
                        final isSelected = _selectedMaterial?.id == m.id;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: _saleThemeColor.withValues(
                            alpha: 0.1,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal[100],
                            child: Icon(
                              Icons.category,
                              size: 18,
                              color: Colors.teal[700],
                            ),
                          ),
                          title: Text(
                            m.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${m.code} · Stock: ${m.stock} ${m.unit} · ${Helpers.formatCurrency(m.effectivePrice)}/kg',
                            style: const TextStyle(fontSize: 10),
                          ),
                          onTap: () => setState(() => _selectedMaterial = m),
                        );
                      },
                    ),
                  ),
                  if (_selectedMaterial != null) ...[
                    const VerticalDivider(),
                    SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMaterial!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Venta: ${Helpers.formatCurrency(_selectedMaterial!.effectivePrice)}/kg',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Costo: ${Helpers.formatCurrency(_selectedMaterial!.effectiveCostPrice)}/kg',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Stock: ${_selectedMaterial!.stock} ${_selectedMaterial!.unit}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final result =
                                    await WeightCalculatorDialog.show(
                                      context,
                                      material: _selectedMaterial!,
                                      category: _selectedMaterial!.category,
                                    );
                                if (result != null) {
                                  setState(() {
                                    _quantityController.text = result.weight
                                        .toStringAsFixed(2);
                                  });
                                }
                              },
                              icon: const Icon(Icons.calculate, size: 14),
                              label: const Text(
                                'Calcular Peso',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _saleThemeColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText:
                                  'Cantidad (${_selectedMaterial!.unit})',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _addMaterial,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                'Agregar',
                                style: TextStyle(fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _saleThemeColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addMaterial() {
    if (_selectedMaterial == null) return;
    final m = _selectedMaterial!;
    final qty = double.tryParse(_quantityController.text) ?? 1;
    final totalPrice = m.effectivePrice * qty;
    final totalCost = m.effectiveCostPrice * qty;

    widget.onAdd({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': m.name,
      'type': 'material',
      'material': m.code,
      'materialId': m.id,
      'inv_material_id': m.id,
      'dimensions': '${m.category} - ${m.unit}',
      'quantity': qty.toInt() > 0 ? qty.toInt() : 1,
      'unitWeight': qty,
      'totalWeight': qty,
      'pricePerKg': m.effectivePrice,
      'unitSalePrice': m.effectivePrice,
      'unitCostPrice': m.effectiveCostPrice,
      'costPrice': m.effectiveCostPrice,
      'totalPrice': totalPrice,
      'totalCost': totalCost,
      'unitProfit': m.effectivePrice - m.effectiveCostPrice,
      'totalProfit': totalPrice - totalCost,
      'profitMargin': totalCost > 0
          ? ((totalPrice - totalCost) / totalCost * 100)
          : 0.0,
      'unit': m.unit,
      'isRecipe': false,
    });
    Navigator.pop(context);
  }
}

// ═══════════════════════════════════════════════════════════════
// PREVISUALIZACIÓN DE VENTA - Diálogo completo tipo cotización
// ═══════════════════════════════════════════════════════════════
class _SalePreviewDialog extends StatefulWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> items;
  final double materialsCost;
  final double laborCost;
  final double indirectCosts;
  final double subtotal;
  final double profitMargin;
  final double profitAmount;
  final double discount;
  final double total;
  final double totalWeight;
  final String notes;
  final String paymentType;
  final String paymentMethodLabel;
  final String accountName;
  final int creditDays;
  final int installments;
  final List<Map<String, dynamic>> stockMaterials;
  final List<Map<String, dynamic>> stockIssues;
  final VoidCallback onConfirm;

  const _SalePreviewDialog({
    required this.customer,
    required this.items,
    required this.materialsCost,
    required this.laborCost,
    required this.indirectCosts,
    required this.subtotal,
    required this.profitMargin,
    required this.profitAmount,
    required this.discount,
    required this.total,
    required this.totalWeight,
    required this.notes,
    required this.paymentType,
    required this.paymentMethodLabel,
    required this.accountName,
    required this.creditDays,
    required this.installments,
    required this.stockMaterials,
    required this.stockIssues,
    required this.onConfirm,
  });

  @override
  State<_SalePreviewDialog> createState() => _SalePreviewDialogState();
}

class _SalePreviewDialogState extends State<_SalePreviewDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _saleNumber =
      'VTA-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 1100,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 24),
          ],
        ),
        child: Column(
          children: [
            // ══════ HEADER OSCURO ══════
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0D47A1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PREVISUALIZACIÓN DE VENTA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          _saleNumber,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTab(0, 'Cliente', Icons.person),
                        _buildTab(1, 'Empresa', Icons.business),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Total
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'TOTAL',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${Helpers.formatNumber(widget.total)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Cerrar
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ══════ CONTENIDO ══════
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildClientView(), _buildEnterpriseView()],
              ),
            ),
            // ══════ FOOTER ══════
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  // Info de pago
                  Icon(
                    widget.paymentType == 'cash'
                        ? Icons.payments
                        : Icons.calendar_month,
                    color: widget.paymentType == 'cash'
                        ? Colors.green
                        : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.paymentType == 'cash'
                          ? 'Pago de contado: ${widget.paymentMethodLabel} → ${widget.accountName}'
                          : 'Crédito: ${widget.creditDays} días${widget.installments > 1 ? ', ${widget.installments} cuotas de \$${Helpers.formatNumber(widget.total / widget.installments)}' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  // Stock badge
                  if (widget.stockIssues.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber,
                            size: 14,
                            color: Colors.orange[800],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.stockIssues.length} sin stock',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.stockIssues.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Colors.green[800],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Stock OK',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Botones
                  _buildFooterButton(
                    'Editar',
                    Icons.edit,
                    Colors.grey[700]!,
                    () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  _buildFooterButton(
                    'Confirmar Venta',
                    Icons.check_circle,
                    Colors.green,
                    widget.onConfirm,
                    filled: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isActive = _tabController.index == index;
    return InkWell(
      onTap: () => setState(() => _tabController.animateTo(index)),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool filled = false,
  }) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: color.withOpacity(0.4)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // VISTA CLIENTE - Factura limpia
  // ══════════════════════════════════════════════════════
  Widget _buildClientView() {
    return Container(
      color: const Color(0xFFF1F4F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            width: 800,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Barra azul superior
                Container(
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D47A1),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Encabezado empresa ───
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                'lib/photo/logo_empresa.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFF0D47A1),
                                  child: const Icon(
                                    Icons.business,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Industrial de Molinos S.A.S.',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111418),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'NIT: 901946675-1',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Número de factura
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D47A1).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF0D47A1).withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'FACTURA DE VENTA',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF0D47A1),
                                  ),
                                ),
                                Text(
                                  _saleNumber,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // ─── Info del cliente + Pago ───
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Datos del cliente
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CLIENTE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[500],
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.customer['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111418),
                                    ),
                                  ),
                                  if ((widget.customer['ruc'] ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'RUC/NIT: ${widget.customer['ruc']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Datos de pago y fechas
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildDateRow(
                                  'Fecha:',
                                  _formatDate(DateTime.now()),
                                ),
                                const SizedBox(height: 6),
                                if (widget.paymentType == 'credit')
                                  _buildDateRow(
                                    'Vencimiento:',
                                    _formatDate(
                                      DateTime.now().add(
                                        Duration(days: widget.creditDays),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.paymentType == 'cash'
                                        ? Colors.green[100]
                                        : Colors.orange[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    widget.paymentType == 'cash'
                                        ? 'CONTADO - ${widget.paymentMethodLabel}'
                                        : 'CRÉDITO ${widget.creditDays} días${widget.installments > 1 ? ' (${widget.installments} cuotas)' : ''}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: widget.paymentType == 'cash'
                                          ? Colors.green[800]
                                          : Colors.orange[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ─── Tabla de productos ───
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF0D47A1,
                                ).withOpacity(0.06),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Descripción',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      'Cant.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      'Peso',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      'Total',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...widget.items.map((item) {
                              final qty =
                                  (item['quantity'] as num?)?.toInt() ?? 1;
                              final weight =
                                  (item['totalWeight'] as num?)?.toDouble() ??
                                  0;
                              final total =
                                  (item['totalPrice'] as num?)?.toDouble() ?? 0;
                              final components =
                                  item['components'] as List<dynamic>? ?? [];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[100]!,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'] ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (item['productCode'] != null)
                                                Text(
                                                  'Código: ${item['productCode']}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            '$qty',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 80,
                                          child: Text(
                                            '${Helpers.formatNumber(weight)} kg',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            '\$${Helpers.formatNumber(total)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Sub-items / components
                                    if (components.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6,
                                          left: 12,
                                        ),
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: components.take(4).map((c) {
                                            final cName =
                                                c['component_name'] ??
                                                c['name'] ??
                                                '';
                                            final cQty =
                                                c['quantity'] ??
                                                c['required_qty'] ??
                                                0;
                                            final cUnit = c['unit'] ?? '';
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue[50],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '$cQty× $cName $cUnit',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.blue[800],
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ─── Totales ───
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: 320,
                          child: Column(
                            children: [
                              if (widget.discount > 0)
                                _buildTotalRow('Descuento', -widget.discount),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'TOTAL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    '\$${Helpers.formatNumber(widget.total)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 24,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Peso total
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.scale,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Peso Total: ${Helpers.formatNumber(widget.totalWeight)} kg',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Notas
                      if (widget.notes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notas:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.notes,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // VISTA EMPRESA - ERP con BOM y análisis
  // ══════════════════════════════════════════════════════
  Widget _buildEnterpriseView() {
    return Container(
      color: const Color(0xFFF1F4F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con info + badges
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'lib/photo/logo_empresa.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                            ),
                          ),
                          child: const Icon(
                            Icons.business,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DOCUMENTO INTERNO - VENTA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111418),
                          ),
                        ),
                        Text(
                          _saleNumber,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: Colors.blue[800],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'USO INTERNO',
                          style: TextStyle(
                            color: Colors.blue[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tarjetas de resumen
            Row(
              children: [
                _buildStatCard(
                  'Materiales',
                  '\$${Helpers.formatNumber(widget.materialsCost)}',
                  Icons.inventory_2,
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Mano Obra',
                  '\$${Helpers.formatNumber(widget.laborCost)}',
                  Icons.engineering,
                  Colors.purple,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Costos Ind.',
                  '\$${Helpers.formatNumber(widget.indirectCosts)}',
                  Icons.electrical_services,
                  Colors.orange,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Margen',
                  '${widget.profitMargin.toStringAsFixed(0)}%',
                  Icons.trending_up,
                  Colors.green,
                ),
                if (widget.discount > 0) ...[
                  const SizedBox(width: 12),
                  _buildStatCard(
                    'Descuento',
                    '-\$${Helpers.formatNumber(widget.discount)}',
                    Icons.discount,
                    Colors.red,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // Stock status
            if (widget.stockMaterials.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.stockIssues.isEmpty
                              ? Icons.check_circle
                              : Icons.warning_amber,
                          color: widget.stockIssues.isEmpty
                              ? Colors.green
                              : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.stockIssues.isEmpty
                              ? 'Stock Completo (${widget.stockMaterials.length} materiales)'
                              : '${widget.stockIssues.length} de ${widget.stockMaterials.length} materiales sin stock',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: widget.stockIssues.isEmpty
                                ? Colors.green[800]
                                : Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                    if (widget.stockIssues.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...widget.stockIssues.take(5).map((mat) {
                        final name = mat['material_name'] ?? '';
                        final required =
                            (mat['required_qty'] as num?)?.toDouble() ?? 0;
                        final available =
                            (mat['available_stock'] as num?)?.toDouble() ?? 0;
                        final unit = mat['unit'] ?? 'KG';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.cancel,
                                size: 14,
                                color: Colors.red[600],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                'Necesita: ${required.toStringAsFixed(0)} $unit | Disp: ${available.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // BOM - Lista de Materiales
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.list_alt, color: _saleThemeColor),
                        const SizedBox(width: 10),
                        const Text(
                          'Lista de Materiales (BOM)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.items.length} producto(s)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // BOM Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 200,
                          child: Text(
                            'Producto (Kilos)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Compra/kg',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Venta/kg',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Ganancia',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Total Venta',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // BOM Rows
                  ...widget.items.map((item) => _buildBOMRow(item)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Análisis de costos
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined),
                      const SizedBox(width: 10),
                      const Text(
                        'Análisis de Costos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Margen: ${widget.profitMargin.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Barra de costos
                  if (widget.subtotal > 0)
                    Row(
                      children: [
                        Expanded(
                          flex: (widget.materialsCost / widget.subtotal * 100)
                              .round()
                              .clamp(1, 100),
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.blue[400],
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(4),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'Mat.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: (widget.laborCost / widget.subtotal * 100)
                              .round()
                              .clamp(1, 100),
                          child: Container(
                            height: 24,
                            color: Colors.purple[400],
                            child: const Center(
                              child: Text(
                                'M.O.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (widget.indirectCosts > 0)
                          Expanded(
                            flex: (widget.indirectCosts / widget.subtotal * 100)
                                .round()
                                .clamp(1, 100),
                            child: Container(
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.orange[400],
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(4),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'C.I.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  _buildCostLine(
                    'Materiales',
                    widget.materialsCost,
                    Colors.blue,
                  ),
                  _buildCostLine(
                    'Mano de Obra',
                    widget.laborCost,
                    Colors.purple,
                  ),
                  _buildCostLine(
                    'Costos Indirectos',
                    widget.indirectCosts,
                    Colors.orange,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${Helpers.formatNumber(widget.subtotal)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: Colors.green[700],
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ganancia (${widget.profitMargin.toStringAsFixed(0)}%)',
                              style: TextStyle(color: Colors.green[700]),
                            ),
                          ],
                        ),
                        Text(
                          '+\$${Helpers.formatNumber(widget.profitAmount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Total box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _saleThemeColor.withOpacity(0.1),
                          _saleThemeColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _saleThemeColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.payments, size: 28),
                            SizedBox(width: 12),
                            Text(
                              'TOTAL VENTA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '\$${Helpers.formatNumber(widget.total)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: _saleThemeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Peso total
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.scale, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Peso Total: ${Helpers.formatNumber(widget.totalWeight)} kg',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Forma de pago
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.paymentType == 'cash'
                          ? Colors.green[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.paymentType == 'cash'
                            ? Colors.green[200]!
                            : Colors.orange[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.paymentType == 'cash'
                              ? Icons.payments
                              : Icons.calendar_month,
                          color: widget.paymentType == 'cash'
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.paymentType == 'cash'
                                    ? 'Pago de Contado'
                                    : 'Pago a Crédito',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: widget.paymentType == 'cash'
                                      ? Colors.green[800]
                                      : Colors.orange[800],
                                ),
                              ),
                              Text(
                                widget.paymentType == 'cash'
                                    ? '${widget.paymentMethodLabel} → ${widget.accountName}'
                                    : '${widget.creditDays} días${widget.installments > 1 ? ' | ${widget.installments} cuotas de \$${Helpers.formatNumber(widget.total / widget.installments)}' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
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
          ],
        ),
      ),
    );
  }

  // ══════ HELPERS ══════

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBOMRow(Map<String, dynamic> item) {
    final components = item['components'] as List<dynamic>? ?? [];
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final totalWeight = (item['totalWeight'] as num?)?.toDouble() ?? 0;
    final totalSalePrice = (item['totalPrice'] as num?)?.toDouble() ?? 0;
    final totalCost = (item['totalCost'] as num?)?.toDouble() ?? 0;

    final unitSalePrice = totalWeight > 0
        ? totalSalePrice / totalWeight
        : (item['unitSalePrice'] as num?)?.toDouble() ??
              (item['pricePerKg'] as num?)?.toDouble() ??
              0;
    final unitCostPrice = totalWeight > 0 && totalCost > 0
        ? totalCost / totalWeight
        : (item['unitCostPrice'] as num?)?.toDouble() ?? 0;

    final totalProfit =
        (item['totalProfit'] as num?)?.toDouble() ??
        (totalSalePrice - totalCost);
    final profitMargin = totalCost > 0
        ? ((totalProfit / totalCost) * 100)
        : (item['profitMargin'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.precision_manufacturing,
                          size: 16,
                          color: _saleThemeColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cant: $qty | Peso: ${Helpers.formatNumber(totalWeight)} kg',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  '\$${Helpers.formatNumber(unitCostPrice)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '\$${Helpers.formatNumber(unitSalePrice)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${Helpers.formatNumber(totalProfit)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: totalProfit >= 0 ? Colors.blue : Colors.red,
                      ),
                    ),
                    if (profitMargin > 0)
                      Text(
                        '${profitMargin.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                child: Text(
                  '\$${Helpers.formatNumber(totalSalePrice)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (components.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Componentes (${components.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...components.take(4).map((c) {
                    if (c == null) return const SizedBox.shrink();
                    final compName =
                        c['component_name'] ?? c['name'] ?? 'Componente';
                    final compQty =
                        (c['quantity'] ?? c['required_qty'] ?? 0) as num;
                    final compUnit = c['unit'] ?? '';
                    final hasStock = c['has_stock'] ?? c['hasStock'] ?? true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            hasStock ? Icons.check_circle : Icons.cancel,
                            size: 12,
                            color: hasStock
                                ? Colors.green[600]
                                : Colors.red[600],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$compQty× $compName ($compUnit)',
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: hasStock
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              hasStock ? 'OK' : 'Falta',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: hasStock
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (components.length > 4)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${components.length - 4} componentes más',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.blue[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostLine(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
          ),
          Text(
            '\$${Helpers.formatNumber(value)}',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF111418),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            '${value < 0 ? '-' : ''}\$${Helpers.formatNumber(value.abs())}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
