import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/weight_calculator.dart';
import '../../data/providers/customers_provider.dart';
import '../../data/providers/products_provider.dart';
import '../../data/providers/quotations_provider.dart';
import '../../data/providers/inventory_provider.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/quotation.dart';
import '../../domain/entities/material.dart' as domain;

class NewQuotationPage extends ConsumerStatefulWidget {
  const NewQuotationPage({super.key});

  @override
  ConsumerState<NewQuotationPage> createState() => _NewQuotationPageState();
}

class _NewQuotationPageState extends ConsumerState<NewQuotationPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Datos del cliente
  String? _selectedCustomerId;
  final _customerController = TextEditingController();

  // Lista de items/componentes
  final List<Map<String, dynamic>> _items = [];

  // Costos adicionales
  final _laborPercentController = TextEditingController(text: '15');
  final _indirectCostsController = TextEditingController(text: '0');
  final _profitMarginController = TextEditingController(text: '20');
  final _discountController = TextEditingController(text: '0'); // Descuento
  final _notesController = TextEditingController();
  final _validDaysController = TextEditingController(text: '15');

  // Los clientes vienen del provider (Supabase)
  List<Map<String, dynamic>> get _customers {
    final state = ref.watch(customersProvider);
    return state.customers
        .map((c) => {'id': c.id, 'name': c.name, 'ruc': c.documentNumber})
        .toList();
  }

  // Los materiales vienen del provider de Inventario (tabla materials)
  // ignore: unused_element - Reserved for material pricing
  List<Map<String, dynamic>> get _materialPrices {
    final state = ref.watch(inventoryProvider);
    return state.materials
        .map(
          (m) => {
            'id': m.id,
            'name': m.name,
            'code': m.code,
            'category': m.category,
            'pricePerKg': m.effectivePrice, // Precio de VENTA
            'costPrice': m.effectiveCostPrice, // Precio de COMPRA
            'density': m.density,
            'stock': m.stock,
            'unit': m.unit,
          },
        )
        .toList();
  }

  // Productos completos del inventario (Supabase)
  List<Product> get _products {
    final state = ref.watch(productsProvider);
    return state.products;
  }

  // Categorías de productos
  List<Category> get _categories {
    final state = ref.watch(productsProvider);
    return state.categories;
  }

  // Cálculos
  double get _materialsCost =>
      _items.fold(0.0, (sum, item) => sum + (item['totalPrice'] as double? ?? 0));
  double get _totalWeight =>
      _items.fold(0.0, (sum, item) => sum + (item['totalWeight'] as double? ?? 0));
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

  // Precio de venta de materiales (suma de totalPrice de items)
  double get _materialSalePrice => _items.fold(0.0, (sum, item) => sum + (item['totalPrice'] as double? ?? 0));
  
  // Costo de compra de materiales (suma de totalCost de items)
  double get _materialCostPrice => _items.fold(0.0, (sum, item) {
    final totalCost = item['totalCost'] as double? ?? 0.0;
    if (totalCost > 0) return sum + totalCost;
    
    // Fallback para items manuales
    final costPrice = item['unitCostPrice'] as double? ?? item['costPrice'] as double? ?? 0.0;
    final qty = item['quantity'] as int? ?? 1;
    return sum + (costPrice * qty);
  });

  @override
  void initState() {
    super.initState();
    // Cargar clientes, productos y materiales desde Supabase
    Future.microtask(() {
      ref.read(customersProvider.notifier).loadCustomers();
      ref.read(productsProvider.notifier).loadProducts();
      ref.read(inventoryProvider.notifier).loadMaterials();
    });
  }

  @override
  void dispose() {
    _customerController.dispose();
    _laborPercentController.dispose();
    _indirectCostsController.dispose();
    _profitMarginController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    _validDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Row(
        children: [
          // Panel lateral con resumen - REDUCIDO A 280
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
                                    backgroundColor: AppTheme.primaryColor,
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
                                  onPressed: _showPreviewDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  icon: const Icon(Icons.preview),
                                  label: const Text('Previsualizar'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _saveQuotation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  icon: const Icon(Icons.save),
                                  label: const Text('Guardar Cotización'),
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
                          title: const Text('Componentes'),
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
                          title: const Text('Costos Adicionales'),
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
                          title: const Text('Resumen y Confirmación'),
                          subtitle: Text(
                            'Total: ${Helpers.formatCurrency(_total)}',
                          ),
                          isActive: _currentStep >= 3,
                          state: _currentStep == 3
                              ? StepState.indexed
                              : StepState.indexed,
                          content: _buildSummaryStep(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/quotations'),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nueva Cotización',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  'Complete los pasos para crear la cotización',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('/quotations'),
            icon: const Icon(Icons.close),
            label: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel() {
    return Column(
      children: [
        // Header del resumen - MÁS COMPACTO
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: AppTheme.primaryColor),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Resumen',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Borrador',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        // Contenido del resumen
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Cliente
              _buildSummarySection(
                'Cliente',
                _selectedCustomerId != null
                    ? _customers.firstWhere(
                        (c) => c['id'] == _selectedCustomerId,
                      )['name']
                    : 'No seleccionado',
                Icons.person,
              ),
              const SizedBox(height: 12),
              // Items
              _buildSummarySection(
                'Componentes',
                '${_items.length} items',
                Icons.inventory_2,
              ),
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...(_items
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
                    )),
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
              // Desglose de costos
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
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    Helpers.formatCurrency(_total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: AppTheme.primaryColor,
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
              // Análisis de rentabilidad
              _buildProfitAnalysisCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfitAnalysisCard() {
    // Sumar datos de cada item (vienen de la receta)
    double totalSalePrice = 0;
    double totalCostPrice = 0;
    double totalItemProfit = 0;
    
    for (final item in _items) {
      totalSalePrice += (item['totalPrice'] as double? ?? 0);
      totalCostPrice += (item['totalCost'] as double? ?? 0);
      totalItemProfit += (item['totalProfit'] as double? ?? 0);
    }
    
    // Si no hay totalCost, calcular desde costPrice
    if (totalCostPrice == 0) {
      totalCostPrice = _items.fold(0.0, (sum, item) {
        final costPrice = item['unitCostPrice'] as double? ?? item['costPrice'] as double? ?? 0.0;
        final qty = item['quantity'] as int? ?? 1;
        return sum + (costPrice * qty);
      });
    }
    
    // Mano de obra ES UN COSTO real
    final laborCostReal = _laborCost;
    
    // COSTO TOTAL = Materiales + Mano de Obra + Costos Indirectos
    final totalCost = totalCostPrice + laborCostReal + _indirectCosts;
    
    // Ganancia de productos (ya viene de las recetas)
    final productMarkup = totalCostPrice > 0 ? (totalItemProfit / totalCostPrice * 100) : 0.0;
    
    // GANANCIA NETA = Total cotización - Costo Total
    final netProfit = _total - totalCost;
    final netMarkup = totalCost > 0 ? (netProfit / totalCost * 100) : 0.0;
    
    // Color según ganancia neta
    Color marginColor;
    IconData marginIcon;
    String marginLabel;
    if (netMarkup >= 40) {
      marginColor = Colors.green;
      marginIcon = Icons.trending_up;
      marginLabel = 'Excelente';
    } else if (netMarkup >= 20) {
      marginColor = Colors.orange;
      marginIcon = Icons.trending_flat;
      marginLabel = 'Bueno';
    } else {
      marginColor = Colors.red;
      marginIcon = Icons.trending_down;
      marginLabel = 'Bajo';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            marginColor.withValues(alpha: 0.1),
            marginColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: marginColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: marginColor, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Análisis de Rentabilidad',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: marginColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: marginColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(marginIcon, size: 10, color: marginColor),
                    const SizedBox(width: 2),
                    Text(
                      marginLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: marginColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Fila 1: Costos
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'Costo Mat.',
                  Helpers.formatCurrency(totalCostPrice),
                  Colors.grey[700]!,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricBox(
                  'Costo Total',
                  Helpers.formatCurrency(totalCost),
                  Colors.blueGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Fila 2: Ganancias
          Row(
            children: [
              Expanded(
                child: _buildMetricBox(
                  'Gan. Productos',
                  Helpers.formatCurrency(totalItemProfit),
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricBox(
                  'Ganancia Neta',
                  Helpers.formatCurrency(netProfit),
                  netProfit >= 0 ? Colors.green[700]! : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Fila 3: Markup
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${productMarkup.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                      ),
                      Text('Markup Prod.', style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: marginColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(marginIcon, size: 12, color: marginColor),
                      const SizedBox(width: 4),
                      Text(
                        '${netMarkup.toStringAsFixed(1)}%',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: marginColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
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
          Text(label, style: TextStyle(color: color ?? Colors.grey[700], fontSize: 12)),
          Text(
            Helpers.formatCurrency(value),
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  // PASO 1: Selección de cliente
  Widget _buildCustomerStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona el cliente para esta cotización',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedCustomerId,
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _validDaysController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Días de validez',
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixText: 'días',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Válida hasta',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          Helpers.formatDate(
                            DateTime.now().add(
                              Duration(
                                days:
                                    int.tryParse(_validDaysController.text) ??
                                    15,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _showNewCustomerDialog,
          icon: const Icon(Icons.person_add),
          label: const Text('Agregar nuevo cliente'),
        ),
      ],
    );
  }

  // PASO 2: Agregar componentes
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
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
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
                // Header de la tabla - COMPACTO
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
                          'Componente',
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
                // Items - COMPACTO
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                item['dimensions'] ?? '',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                            Helpers.formatNumber(item['totalWeight'] as double? ?? 0),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            Helpers.formatCurrency(item['pricePerKg'] as double? ?? item['unitSalePrice'] as double? ?? 0),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            Helpers.formatCurrency(item['totalPrice'] as double? ?? 0),
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
                            onPressed: () =>
                                setState(() => _items.removeAt(index)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                // Total - COMPACTO
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
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
                            color: AppTheme.primaryColor,
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

  // PASO 3: Costos adicionales
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
              Icon(Icons.engineering, color: AppTheme.primaryColor),
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
                      value:
                          double.tryParse(_discountController.text) ?? 0,
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

  // PASO 4: Resumen final
  Widget _buildSummaryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    'Notas y Condiciones',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Condiciones de pago, tiempo de entrega, garantías, etc.',
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
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Resumen de Cotización',
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
                      )['name']
                    : '-',
              ),
              _buildFinalSummaryRow('Componentes', '${_items.length} items'),
              _buildFinalSummaryRow(
                'Peso Total',
                '${Helpers.formatNumber(_totalWeight)} kg',
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: AppTheme.primaryColor,
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
          content: Text('Agregue al menos un componente'),
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
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _saveQuotation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccione un cliente'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agregue al menos un item'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final customer = _customers.firstWhere(
        (c) => c['id'] == _selectedCustomerId,
      );
      final validDays = int.tryParse(_validDaysController.text) ?? 15;

      // Convertir items a QuotationItem
      final quotationItems = _items
          .map(
            (item) => QuotationItem(
              id:
                  item['id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              name: item['name'] ?? '',
              description: item['dimensions'] ?? '',
              type: item['type'] ?? 'custom',
              productId: item['productId'],
              materialId:
                  item['materialId'] ??
                  item['inv_material_id'], // Buscar en ambas claves
              quantity: (item['quantity'] ?? 1).toInt(),
              unitWeight: (item['unitWeight'] ?? 0).toDouble(),
              pricePerKg: (item['pricePerKg'] ?? item['unitSalePrice'] ?? 0).toDouble(),
              costPerKg: (item['costPrice'] ?? item['unitCostPrice'] ?? 0).toDouble(),
              unitPrice:
                  (item['totalPrice'] ?? 0).toDouble() /
                  (item['quantity'] ?? 1),
              unitCost:
                  (item['totalCost'] ?? 0).toDouble() /
                  (item['quantity'] ?? 1),
              materialType: item['material'] ?? '',
            ),
          )
          .toList();

      // Crear cotización
      final quotation = Quotation(
        id: '', // Se genera en el servidor
        number: '', // Se genera en el servidor
        date: DateTime.now(),
        validUntil: DateTime.now().add(Duration(days: validDays)),
        customerId: _selectedCustomerId!,
        customerName: customer['name'] ?? '',
        status: 'Borrador',
        items: quotationItems,
        laborCost: _laborCost,
        energyCost: 0,
        gasCost: 0,
        suppliesCost: 0,
        otherCosts: _indirectCosts,
        profitMargin: double.tryParse(_profitMarginController.text) ?? 20,
        notes: _notesController.text,
        createdAt: DateTime.now(),
      );

      // Guardar en Supabase
      final created = await ref
          .read(quotationsProvider.notifier)
          .createQuotation(quotation);

      // Cerrar indicador de carga
      if (mounted) Navigator.of(context).pop();

      if (created != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Cotización ${created.number} guardada exitosamente',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Usar go en lugar de pop para evitar errores de Navigator
          context.go('/quotations');
        }
      } else {
        if (mounted) {
          final errorMsg =
              ref.read(quotationsProvider).error ?? 'Error desconocido';
          print('❌ Error al guardar: $errorMsg');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar indicador de carga
      if (mounted) Navigator.of(context).pop();
      print('❌ Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  void _showNewCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Cliente'),
        content: const Text(
          'Funcionalidad por implementar.\nPor ahora, seleccione un cliente existente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showAddMaterialDialog(List<domain.Material> materials) {
    showDialog(
      context: context,
      builder: (context) => _AddMaterialFromInventoryDialog(
        materials: materials,
        onAdd: (materialData) {
          setState(() => _items.add(materialData));
        },
      ),
    );
  }

  void _showPreviewDialog() {
    final customer = _selectedCustomerId != null
        ? _customers.firstWhere((c) => c['id'] == _selectedCustomerId)
        : {'name': 'Sin cliente', 'ruc': ''};

    showDialog(
      context: context,
      builder: (context) => _QuotationPreviewDialog(
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
        validDays: int.tryParse(_validDaysController.text) ?? 15,
        materialSalePrice: _materialSalePrice,
        materialCostPrice: _materialCostPrice,
      ),
    );
  }

  void _showSelectProductDialog() {
    // Verificar si hay productos cargados
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay productos en el inventario. Agregue productos primero.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _SelectProductDialog(
        products: _products,
        categories: _categories,
        onSelect: (product, quantity, recipeComponents) {
          setState(() {
            // Calcular peso: usar totalWeight del producto (receta) o 0 si no tiene
            final unitWeight = product.totalWeight > 0
                ? product.totalWeight
                : 0.0;
            final totalWeight = unitWeight * quantity;

            // Convertir los ingredientes de la receta a formato components
            final components = recipeComponents?.map((c) => {
              'name': c['component_name'] ?? c['name'] ?? '',
              'quantity': c['required_qty'] ?? c['quantity'] ?? 0,
              'unit': c['unit'] ?? '',
              'stock': c['current_stock'] ?? 0,
              'hasStock': c['has_stock'] ?? true,
            }).toList() ?? [];

            // Costo del producto (totalCost si es receta, costPrice si no)
            final productCost = product.totalCost > 0 
                ? product.totalCost 
                : product.costPrice;
            
            // Ganancia del producto (ya calculada en la receta)
            final productProfit = product.unitPrice - productCost;
            final productMargin = product.profitMargin; // Viene de la receta

            // Agregar producto del inventario como item
            _items.add({
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'productId': product.id,
              'name': product.name,
              'type': 'product', // Tipo válido del ENUM
              'material': product.code,
              'dimensions':
                  product.description ?? (product.isRecipe ? 'Receta' : '-'),
              'quantity': quantity,
              'unitWeight': unitWeight,
              'totalWeight': totalWeight,
              // Precios del producto
              'pricePerKg': product.unitPrice, // Mantener para compatibilidad
              'unitSalePrice': product.unitPrice, // Precio venta unitario
              'unitCostPrice': productCost, // Precio costo unitario
              'totalPrice': product.unitPrice * quantity, // Precio venta total
              'totalCost': productCost * quantity, // Costo total
              // Ganancia del item
              'unitProfit': productProfit, // Ganancia unitaria
              'totalProfit': productProfit * quantity, // Ganancia total del item
              'profitMargin': productMargin, // % de margen de la receta
              // Info adicional
              'productCode': product.code,
              'stock': product.stock,
              'unit': product.unit,
              'isRecipe': product.isRecipe,
              'components': components,
            });
          });
        },
      ),
    );
  }
}

// Diálogo para agregar componentes
class _AddComponentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> materialPrices;
  final Function(Map<String, dynamic>) onAdd;

  const _AddComponentDialog({
    required this.materialPrices,
    required this.onAdd,
  });

  @override
  State<_AddComponentDialog> createState() => _AddComponentDialogState();
}

class _AddComponentDialogState extends State<_AddComponentDialog> {
  String _componentType = 'cylinder';
  String? _selectedMaterialId;
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  // Dimensiones para cilindro
  final _outerDiameterController = TextEditingController();
  final _thicknessController = TextEditingController();
  final _lengthController = TextEditingController();

  // Dimensiones para placa circular
  final _diameterController = TextEditingController();

  // Dimensiones para placa rectangular
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  // Peso manual
  final _manualWeightController = TextEditingController();

  double _calculatedWeight = 0;
  double _pricePerKg = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _outerDiameterController.dispose();
    _thicknessController.dispose();
    _lengthController.dispose();
    _diameterController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _manualWeightController.dispose();
    super.dispose();
  }

  void _calculateWeight() {
    double weight = 0;
    double density = 7.85;

    if (_selectedMaterialId != null) {
      final material = widget.materialPrices.firstWhere(
        (m) => m['id'] == _selectedMaterialId,
        orElse: () => {'density': 7.85, 'pricePerKg': 0},
      );
      density = (material['density'] as num).toDouble();
      _pricePerKg = (material['pricePerKg'] as num).toDouble();
    }

    switch (_componentType) {
      case 'cylinder':
        final outerDiameter =
            double.tryParse(_outerDiameterController.text) ?? 0;
        final thickness = double.tryParse(_thicknessController.text) ?? 0;
        final length = double.tryParse(_lengthController.text) ?? 0;
        weight = WeightCalculator.calculateCylinderWeight(
          outerDiameter: outerDiameter,
          thickness: thickness,
          length: length,
          density: density,
        );
        break;
      case 'circular_plate':
        final diameter = double.tryParse(_diameterController.text) ?? 0;
        final thickness = double.tryParse(_thicknessController.text) ?? 0;
        weight = WeightCalculator.calculateCircularPlateWeight(
          diameter: diameter,
          thickness: thickness,
          density: density,
        );
        break;
      case 'rectangular_plate':
        final width = double.tryParse(_widthController.text) ?? 0;
        final height = double.tryParse(_heightController.text) ?? 0;
        final thickness = double.tryParse(_thicknessController.text) ?? 0;
        weight = WeightCalculator.calculateRectangularPlateWeight(
          width: width,
          height: height,
          thickness: thickness,
          density: density,
        );
        break;
      case 'shaft':
        final diameter = double.tryParse(_diameterController.text) ?? 0;
        final length = double.tryParse(_lengthController.text) ?? 0;
        weight = WeightCalculator.calculateShaftWeight(
          diameter: diameter,
          length: length,
          density: density,
        );
        break;
      case 'custom':
        weight = double.tryParse(_manualWeightController.text) ?? 0;
        break;
    }

    setState(() => _calculatedWeight = weight);
  }

  String _getDimensionsString() {
    switch (_componentType) {
      case 'cylinder':
        return 'Ø${_outerDiameterController.text}mm × ${_thicknessController.text}mm × ${_lengthController.text}mm';
      case 'circular_plate':
        return 'Ø${_diameterController.text}mm × ${_thicknessController.text}mm';
      case 'rectangular_plate':
        return '${_widthController.text}mm × ${_heightController.text}mm × ${_thicknessController.text}mm';
      case 'shaft':
        return 'Ø${_diameterController.text}mm × ${_lengthController.text}mm';
      default:
        return 'Peso manual';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_box, color: AppTheme.primaryColor, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Agregar Componente',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Tipo de componente
              const Text(
                'Tipo de componente',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'cylinder',
                    label: Text('Cilindro'),
                    icon: Icon(Icons.circle_outlined),
                  ),
                  ButtonSegment(
                    value: 'circular_plate',
                    label: Text('Tapa'),
                    icon: Icon(Icons.lens),
                  ),
                  ButtonSegment(
                    value: 'rectangular_plate',
                    label: Text('Lámina'),
                    icon: Icon(Icons.rectangle_outlined),
                  ),
                  ButtonSegment(
                    value: 'shaft',
                    label: Text('Eje'),
                    icon: Icon(Icons.horizontal_rule),
                  ),
                  ButtonSegment(
                    value: 'custom',
                    label: Text('Manual'),
                    icon: Icon(Icons.edit),
                  ),
                ],
                selected: {_componentType},
                onSelectionChanged: (selection) {
                  setState(() {
                    _componentType = selection.first;
                    _calculatedWeight = 0;
                  });
                },
              ),
              const SizedBox(height: 20),
              // Nombre del componente
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre del componente',
                  hintText: _getHintForType(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Material
              DropdownButtonFormField<String>(
                initialValue: _selectedMaterialId,
                decoration: InputDecoration(
                  labelText: 'Material',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: widget.materialPrices
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['id'] as String,
                        child: Text('${m['name']} - \$ ${m['pricePerKg']}/kg'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedMaterialId = value);
                  _calculateWeight();
                },
              ),
              const SizedBox(height: 16),
              // Dimensiones según tipo
              _buildDimensionsFields(),
              const SizedBox(height: 16),
              // Cantidad
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Cantidad',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: (_) => _calculateWeight(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _calculateWeight,
                    icon: const Icon(Icons.calculate),
                    label: const Text('Calcular'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Resultado del cálculo
              if (_calculatedWeight > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Peso unitario:'),
                          Text(
                            '${Helpers.formatNumber(_calculatedWeight)} kg',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Peso total (×${_quantityController.text}):'),
                          Text(
                            '${Helpers.formatNumber(_calculatedWeight * (int.tryParse(_quantityController.text) ?? 1))} kg',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Precio Total:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            Helpers.formatCurrency(
                              _calculatedWeight *
                                  (int.tryParse(_quantityController.text) ??
                                      1) *
                                  _pricePerKg,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _calculatedWeight > 0 ? _addComponent : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDimensionsFields() {
    switch (_componentType) {
      case 'cylinder':
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _outerDiameterController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Diámetro exterior',
                  suffixText: 'mm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => _calculateWeight(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _thicknessController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Espesor',
                  suffixText: 'mm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => _calculateWeight(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lengthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Largo',
                  suffixText: 'mm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => _calculateWeight(),
              ),
            ),
          ],
        );
      case 'circular_plate':
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _diameterController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Diámetro',
                  suffixText: 'mm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => _calculateWeight(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _thicknessController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Espesor',
                  suffixText: 'mm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => _calculateWeight(),
              ),
            ),
          ],
        );
      case 'rectangular_plate':
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _widthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Ancho',
                  suffixText: 'mm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => _calculateWeight(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Alto',
                  suffixText: 'mm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => _calculateWeight(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _thicknessController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Espesor',
                  suffixText: 'mm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => _calculateWeight(),
              ),
            ),
          ],
        );
      case 'shaft':
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _diameterController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Diámetro',
                  suffixText: 'mm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => _calculateWeight(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lengthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Largo',
                  suffixText: 'mm',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (_) => _calculateWeight(),
              ),
            ),
          ],
        );
      case 'custom':
        return TextFormField(
          controller: _manualWeightController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Peso manual',
            suffixText: 'kg',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (_) => _calculateWeight(),
        );
      default:
        return const SizedBox();
    }
  }

  String _getHintForType() {
    switch (_componentType) {
      case 'cylinder':
        return 'Ej: Cilindro principal del molino';
      case 'circular_plate':
        return 'Ej: Tapa frontal';
      case 'rectangular_plate':
        return 'Ej: Lámina de refuerzo';
      case 'shaft':
        return 'Ej: Eje de transmisión';
      default:
        return 'Nombre del componente';
    }
  }

  void _addComponent() {
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final totalWeight = _calculatedWeight * quantity;
    final material = _selectedMaterialId != null
        ? widget.materialPrices.firstWhere(
            (m) => m['id'] == _selectedMaterialId,
          )
        : null;

    // Obtener costPrice del material (precio de compra)
    final costPrice = material != null ? (material['costPrice'] as num?)?.toDouble() ?? 0.0 : 0.0;
    
    // Calcular ganancia
    final totalSale = totalWeight * _pricePerKg;
    final totalCost = totalWeight * costPrice;
    final totalProfit = totalSale - totalCost;
    final profitMargin = totalCost > 0 ? ((totalProfit / totalCost) * 100) : 0.0;

    final component = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': _nameController.text.isNotEmpty
          ? _nameController.text
          : _getDefaultName(),
      'type': _componentType,
      'material': material?['name'] ?? 'No especificado',
      'materialId': _selectedMaterialId,
      'dimensions': _getDimensionsString(),
      'quantity': quantity,
      'unitWeight': _calculatedWeight,
      'totalWeight': totalWeight,
      // Precios
      'pricePerKg': _pricePerKg, // Precio venta por kg
      'costPrice': costPrice, // Precio compra por kg
      'unitSalePrice': _pricePerKg, // Alias para compatibilidad
      'unitCostPrice': costPrice, // Alias para compatibilidad
      'totalPrice': totalSale, // Total venta
      'totalCost': totalCost, // Total costo
      // Ganancia
      'unitProfit': _pricePerKg - costPrice, // Ganancia por kg
      'totalProfit': totalProfit, // Ganancia total
      'profitMargin': profitMargin, // % de margen
    };

    widget.onAdd(component);
    Navigator.pop(context);
  }

  String _getDefaultName() {
    switch (_componentType) {
      case 'cylinder':
        return 'Cilindro';
      case 'circular_plate':
        return 'Tapa circular';
      case 'rectangular_plate':
        return 'Lámina rectangular';
      case 'shaft':
        return 'Eje';
      default:
        return 'Componente';
    }
  }
}

// Diálogo para seleccionar producto del inventario (Supabase)
class _SelectProductDialog extends StatefulWidget {
  final List<Product> products;
  final List<Category> categories;
  final Function(Product product, double quantity, List<Map<String, dynamic>>? components) onSelect;

  const _SelectProductDialog({
    required this.products,
    required this.categories,
    required this.onSelect,
  });

  @override
  State<_SelectProductDialog> createState() => _SelectProductDialogState();
}

class _SelectProductDialogState extends State<_SelectProductDialog> {
  String _searchQuery = '';
  String? _selectedCategoryId;
  Product? _selectedProduct;
  final _quantityController = TextEditingController(text: '1');

  // Para verificar stock de recetas
  List<Map<String, dynamic>>? _recipeStockCheck;
  bool _isCheckingStock = false;

  List<Product> get _filteredProducts {
    return widget.products.where((p) {
      final matchesSearch =
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.code.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategoryId == null || p.categoryId == _selectedCategoryId;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  // Verificar stock de materiales para una receta
  Future<void> _checkRecipeStock(Product product, int quantity) async {
    if (!product.isRecipe) return;

    setState(() => _isCheckingStock = true);
    try {
      final stockCheck = await InventoryDataSource.checkRecipeStock(
        product.id,
        quantity: quantity,
      );
      setState(() {
        _recipeStockCheck = stockCheck;
        _isCheckingStock = false;
      });
    } catch (e) {
      setState(() {
        _recipeStockCheck = null;
        _isCheckingStock = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 900,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.inventory_2, color: AppTheme.primaryColor, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Seleccionar Producto del Inventario',
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
                      hintText: 'Buscar por nombre o código...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ...widget.categories.map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedCategoryId = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contenido principal
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lista de productos
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No se encontraron productos',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Agregue productos desde el módulo de Inventario',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _filteredProducts.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: Colors.grey[200]),
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                final isSelected =
                                    _selectedProduct?.id == product.id;
                                final isRecipe = product.isRecipe;
                                // Para recetas, no mostramos stock (no tiene sentido)
                                // Para productos simples, sí mostramos stock
                                final hasStock = isRecipe || product.stock > 0;
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: AppTheme.primaryColor
                                      .withOpacity(0.1),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isRecipe
                                          ? Colors.blue.withOpacity(0.1)
                                          : (hasStock
                                                ? AppTheme.primaryColor
                                                      .withOpacity(0.1)
                                                : Colors.red.withOpacity(0.1)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isRecipe
                                          ? Icons.receipt_long
                                          : Icons.inventory_2,
                                      color: isRecipe
                                          ? Colors.blue
                                          : (hasStock
                                                ? AppTheme.primaryColor
                                                : Colors.red),
                                    ),
                                  ),
                                  title: Text(
                                    product.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(product.code),
                                      if (isRecipe) ...[
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.receipt_long,
                                              size: 14,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Receta Compuesta',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        Row(
                                          children: [
                                            Icon(
                                              hasStock
                                                  ? Icons.check_circle
                                                  : Icons.warning,
                                              size: 14,
                                              color: hasStock
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Stock: ${product.stock.toStringAsFixed(0)} ${product.unit}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: hasStock
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Text(
                                    '\$ ${Helpers.formatNumber(product.unitPrice)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() => _selectedProduct = product);
                                    // Si es receta, verificar stock de componentes
                                    if (product.isRecipe) {
                                      _checkRecipeStock(
                                        product,
                                        int.tryParse(
                                              _quantityController.text,
                                            ) ??
                                            1,
                                      );
                                    } else {
                                      _recipeStockCheck = null;
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Detalle del producto seleccionado
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _selectedProduct == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.touch_app,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Selecciona un producto',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : _buildProductDetail(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Botones de acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                if (_selectedProduct != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      final qty =
                          double.tryParse(_quantityController.text) ?? 1;
                      if (qty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ingrese una cantidad válida'),
                          ),
                        );
                        return;
                      }
                      widget.onSelect(_selectedProduct!, qty, _recipeStockCheck);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Agregar a Cotización'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
              ],
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

    // Para recetas, verificar si todos los materiales están disponibles
    bool allMaterialsAvailable = true;
    int missingCount = 0;
    if (isRecipe && _recipeStockCheck != null) {
      for (var item in _recipeStockCheck!) {
        if (item['has_stock'] == false) {
          allMaterialsAvailable = false;
          missingCount++;
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nombre y código
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
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 14,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Receta',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Descripción (compacta)
          if (product.description != null && product.description!.isNotEmpty)
            Text(
              product.description!,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),

          // Info compacta: Precio y Stock/Materiales en una fila
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Precio',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      Text(
                        '\$ ${Helpers.formatNumber(product.unitPrice)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
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
                        ? (allMaterialsAvailable
                              ? Colors.green[50]
                              : Colors.orange[50])
                        : (hasStock ? Colors.green[50] : Colors.red[50]),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isRecipe
                          ? (allMaterialsAvailable
                                ? Colors.green[200]!
                                : Colors.orange[200]!)
                          : (hasStock ? Colors.green[200]! : Colors.red[200]!),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRecipe ? 'Materiales' : 'Stock',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                      if (isRecipe) ...[
                        if (_isCheckingStock)
                          const SizedBox(
                            height: 2,
                            child: LinearProgressIndicator(),
                          )
                        else if (_recipeStockCheck != null)
                          Text(
                            allMaterialsAvailable
                                ? '✓ Completos'
                                : '⚠ Faltan $missingCount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: allMaterialsAvailable
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                            ),
                          )
                        else
                          Text(
                            'Verificando...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ] else
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

          // Para recetas: mostrar lista de materiales requeridos
          if (isRecipe &&
              _recipeStockCheck != null &&
              _recipeStockCheck!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.checklist, size: 16, color: Colors.grey[700]),
                      const SizedBox(width: 6),
                      Text(
                        'Materiales Requeridos',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._recipeStockCheck!.map((item) {
                    final hasItemStock = item['has_stock'] == true;
                    final shortage =
                        (item['shortage'] as num?)?.toDouble() ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            hasItemStock ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: hasItemStock ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item['component_name'] ?? '',
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(item['required_qty'] as num?)?.toStringAsFixed(1) ?? '0'} ${item['unit'] ?? ''}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (!hasItemStock) ...[
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
                                '-${shortage.toStringAsFixed(1)}',
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
            ),
          ],
          const SizedBox(height: 12),

          // Cantidad a agregar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
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
                            // Si es receta, re-verificar stock con nueva cantidad
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
                          '\$ ${Helpers.formatNumber(product.unitPrice * (double.tryParse(_quantityController.text) ?? 1))}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// DIÁLOGO DE PREVISUALIZACIÓN DE COTIZACIÓN
// ============================================
class _QuotationPreviewDialog extends StatefulWidget {
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
  final int validDays;
  final double materialSalePrice;
  final double materialCostPrice;

  const _QuotationPreviewDialog({
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
    required this.validDays,
    required this.materialSalePrice,
    required this.materialCostPrice,
  });

  @override
  State<_QuotationPreviewDialog> createState() =>
      _QuotationPreviewDialogState();
}

class _QuotationPreviewDialogState extends State<_QuotationPreviewDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _quotationNumber =
      'COT-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 11)}';

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
    const headerColor = Color(0xFF1e293b);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1100,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header compacto
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: headerColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Previsualización de Cotización',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(_quotationNumber, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(
                      '\$ ${Helpers.formatNumber(widget.total)}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey[400], size: 28),
                    hoverColor: Colors.white.withOpacity(0.1),
                  ),
                ],
              ),
            ),
            // Tabs
            Container(
              color: headerColor,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildTab(0, Icons.person, 'Recibo Cliente'),
                  const SizedBox(width: 16),
                  _buildTab(1, Icons.domain, 'Recibo Empresa'),
                ],
              ),
            ),
            // Contenido
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildClientView(), _buildEnterpriseView()],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Text(
                        'Válida hasta: ${_formatDate(DateTime.now().add(Duration(days: widget.validDays)))}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildFooterButton(Icons.print, 'Imprimir', () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Preparando impresión...'), backgroundColor: Colors.blue),
                        );
                      }),
                      const SizedBox(width: 12),
                      _buildFooterButton(Icons.edit, 'Editar', () => Navigator.pop(context)),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cotización confirmada'), backgroundColor: Colors.green),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4caf50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.animateTo(index)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey[500], size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[500],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterButton(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  // ==========================================
  // VISTA CLIENTE - Diseño moderno espacioso
  // ==========================================
  Widget _buildClientView() {
    const headerColor = Color(0xFF1e293b);
    
    return Container(
      color: const Color(0xFFF1F5F9).withOpacity(0.5),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra superior de acento
                Container(
                  height: 8,
                  decoration: const BoxDecoration(
                    color: headerColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
                // Contenido principal
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header con título y empresa
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Título con icono
                          Row(
                            children: [
                              Icon(Icons.verified, color: AppTheme.primaryColor, size: 48),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'COTIZACIÓN',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1e293b),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    '#$_quotationNumber',
                                    style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500, fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Logo empresa
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'Industrial de Molinos S.A.S.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1e293b)),
                                  ),
                                  Text('NIT: 901946675-1', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Icon(Icons.precision_manufacturing, color: AppTheme.primaryColor, size: 24),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      // Sección Cliente
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[100]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CLIENTE',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.5),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.customer['name'] ?? '',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111418)),
                                ),
                                if (widget.customer['ruc'] != null)
                                  Text('ID: ${widget.customer['ruc']}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildDateRow('Fecha Emisión:', _formatDate(DateTime.now())),
                                const SizedBox(height: 6),
                                _buildDateRow('Vencimiento:', _formatDate(DateTime.now().add(Duration(days: widget.validDays)))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Tabla de productos
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            // Header de tabla
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text('Descripción', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text('Cant.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]), textAlign: TextAlign.right),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text('Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]), textAlign: TextAlign.right),
                                  ),
                                ],
                              ),
                            ),
                            // Items
                            ...widget.items.map((item) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111418))),
                                        if (item['productCode'] != null)
                                          Text('Código: ${item['productCode']}', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text('${item['quantity']}', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700], fontSize: 14), textAlign: TextAlign.right),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      '\$${Helpers.formatNumber(item['totalPrice'] * (item['quantity'] as int))}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF111418)),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Totales
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 340,
                            child: Column(
                              children: [
                                _buildTotalRow('Subtotal', widget.subtotal),
                                _buildTotalRow('Mano de Obra', widget.laborCost),
                                _buildTotalRow('Costos Indirectos', widget.indirectCosts),
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 12),
                                  height: 1,
                                  color: Colors.grey[200],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111418))),
                                    Text('\$${Helpers.formatNumber(widget.total)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primaryColor)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Notas/Validez
                      const SizedBox(height: 48),
                      Text(
                        'Esta cotización es válida hasta el ${_formatDate(DateTime.now().add(Duration(days: widget.validDays)))}. Sujeta a cambios si no se confirma antes de la fecha límite.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[400], fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
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

  Widget _buildDateRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        const SizedBox(width: 16),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF111418), fontSize: 13)),
      ],
    );
  }

  Widget _buildTotalRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text('\$${Helpers.formatNumber(value)}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  // ignore: unused_element - Reserved for totals display
  Widget _buildTotalLine(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            '\$${Helpers.formatNumber(value)}',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VISTA EMPRESA - ERP Style con BOM
  // ==========================================
  Widget _buildEnterpriseView() {
    return Container(
      color: const Color(0xFFF1F4F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con información y badges
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
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.orange.shade400,
                                Colors.deepOrange,
                              ],
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
                          'DOCUMENTO INTERNO',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111418),
                          ),
                        ),
                        Text(
                          _quotationNumber,
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
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: Colors.orange[800],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'USO INTERNO',
                          style: TextStyle(
                            color: Colors.orange[800],
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
            // Tarjetas de resumen rápido
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
            // Análisis de Rentabilidad
            _buildProfitAnalysisSection(),
            const SizedBox(height: 20),
            // Bill of Materials (BOM)
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
                        Icon(Icons.list_alt, color: AppTheme.primaryColor),
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
                  // Tabla BOM Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 220,
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
                            'Ganancia Total (% y /kg)',
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
                  // Items BOM
                  ...widget.items.map((item) => _buildBOMRow(item)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Resumen de costos moderno
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
                  Row(
                    children: [
                      Expanded(
                        flex: (widget.materialsCost / widget.subtotal * 100)
                            .round(),
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
                  // Detalle de costos
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.1),
                          AppTheme.primaryColor.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
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
                              'TOTAL COTIZACIÓN',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '\$${Helpers.formatNumber(widget.total)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryColor,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildProfitAnalysisSection() {
    final grossProfit = widget.materialSalePrice - widget.materialCostPrice;
    final grossMarginPercent = widget.materialCostPrice > 0 
        ? (grossProfit / widget.materialCostPrice * 100) 
        : 0.0;
    final netProfit = widget.total - widget.subtotal;
    final netMarginPercent = widget.subtotal > 0 
        ? (netProfit / widget.subtotal * 100) 
        : 0.0;

    return Container(
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
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Análisis de Rentabilidad',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildProfitItem(
                  'Ganancia Bruta',
                  '(Precio Venta - Costo Material)',
                  grossProfit,
                  grossMarginPercent,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildProfitItem(
                  'Ganancia Neta',
                  '(Total - Subtotal)',
                  netProfit,
                  netMarginPercent,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfitItem(String title, String subtitle, double value, double percent, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          Text(subtitle, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${Helpers.formatNumber(value)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: value >= 0 ? color : Colors.red),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: percent >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: percent >= 0 ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBOMRow(Map<String, dynamic> item) {
    final components = item['components'] as List<dynamic>? ?? [];
    final unitCostPrice = item['unitCostPrice'] as double? ?? 0;
    final unitSalePrice = item['unitSalePrice'] as double? ?? item['pricePerKg'] as double? ?? 0;
    final totalProfit = item['totalProfit'] as double? ?? 0;
    final profitMargin = item['profitMargin'] as double? ?? 0;
    final qty = item['quantity'] as int? ?? 1;
    final totalWeight = item['totalWeight'] as double? ?? 0;
    final unitProfit = totalProfit > 0 && totalWeight > 0 ? (totalProfit / totalWeight) : 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila principal con nombre y datos
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre del producto
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.precision_manufacturing,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['name'],
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
                      'Código: ${item['productCode'] ?? 'N/A'} | Cant: $qty',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Peso: ${Helpers.formatNumber(totalWeight)} kg',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
              // Precio de Compra (por kg)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Compra/kg',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      '\$${Helpers.formatNumber(unitCostPrice)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Precio de Venta (por kg)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Venta/kg',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      '\$${Helpers.formatNumber(unitSalePrice)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Ganancia
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Ganancia Total',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
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
                        '${profitMargin.toStringAsFixed(1)}% | \$${Helpers.formatNumber(unitProfit as double)}/kg',
                        style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Total
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Venta',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      '\$${Helpers.formatNumber(item['totalPrice'] as double? ?? 0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Componentes si existen
          if (components.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
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
                      fontSize: 11,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...components.take(3).map((c) {
                    if (c == null) return const SizedBox.shrink();
                    
                    final compQty = (c['quantity'] ?? c['required_qty'] ?? 0) as num? ?? 0;
                    final compName = c['component_name'] ?? c['name'] ?? 'Componente';
                    final compUnit = c['unit'] ?? '';
                    final hasStock = c['has_stock'] ?? c['hasStock'] ?? true;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$compQty× $compName ($compUnit)',
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: hasStock ? Colors.green[100] : Colors.red[100],
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              hasStock ? 'OK' : 'Sin stock',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: hasStock ? Colors.green[700] : Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  if (components.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '+${components.length - 3} componentes más',
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// Diálogo para agregar material del inventario (como en facturas)
class _AddMaterialFromInventoryDialog extends StatefulWidget {
  final List<domain.Material> materials;
  final Function(Map<String, dynamic>) onAdd;

  const _AddMaterialFromInventoryDialog({
    required this.materials,
    required this.onAdd,
  });

  @override
  State<_AddMaterialFromInventoryDialog> createState() =>
      _AddMaterialFromInventoryDialogState();
}

class _AddMaterialFromInventoryDialogState
    extends State<_AddMaterialFromInventoryDialog> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String? _selectedCategory;
  domain.Material? _selectedMaterial;
  double _quantity = 1;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(double newQty) {
    if (newQty > 0) {
      setState(() => _quantity = newQty);
      _quantityController.text = newQty == newQty.truncate()
          ? newQty.toStringAsFixed(0)
          : newQty.toStringAsFixed(2);
    }
  }

  List<String> get _categories {
    final cats = widget.materials.map((m) => m.category).toSet().toList();
    cats.sort();
    return cats;
  }

  List<domain.Material> get _filteredMaterials {
    var filtered = widget.materials;

    // Filtrar por categoría
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((m) => m.category == _selectedCategory)
          .toList();
    }

    // Filtrar por búsqueda
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where(
            (m) =>
                m.name.toLowerCase().contains(query) ||
                m.code.toLowerCase().contains(query),
          )
          .toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar Material del Inventario'),
      content: SizedBox(
        width: 550,
        height: 450,
        child: Column(
          children: [
            // Barra de búsqueda y filtro de categoría
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar material',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ..._categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredMaterials.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No hay materiales',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredMaterials.length,
                      itemBuilder: (context, index) {
                        final material = _filteredMaterials[index];
                        final isSelected = _selectedMaterial?.id == material.id;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: Colors.orange.withValues(
                            alpha: 0.1,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(
                              Icons.inventory_2,
                              color: Colors.orange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            material.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${material.code} • Stock: ${material.stock.toStringAsFixed(0)} ${material.unit}',
                          ),
                          trailing: Text(
                            Helpers.formatCurrency(
                              material.pricePerKg > 0
                                  ? material.pricePerKg
                                  : material.unitPrice,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () =>
                              setState(() => _selectedMaterial = material),
                        );
                      },
                    ),
            ),
            if (_selectedMaterial != null) ...[
              const Divider(),
              Row(
                children: [
                  Text(
                    'Cantidad (${_selectedMaterial!.unit}):',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _quantity > 1
                        ? () => _updateQuantity(_quantity - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (v) {
                        final qty = double.tryParse(v);
                        if (qty != null && qty > 0) {
                          setState(() => _quantity = qty);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _updateQuantity(_quantity + 1),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${Helpers.formatCurrency((_selectedMaterial!.pricePerKg > 0 ? _selectedMaterial!.pricePerKg : _selectedMaterial!.unitPrice) * _quantity)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selectedMaterial == null
              ? null
              : () {
                  final price = _selectedMaterial!.pricePerKg > 0
                      ? _selectedMaterial!.pricePerKg
                      : _selectedMaterial!.unitPrice;
                  final totalPrice = price * _quantity;
                  // Usar effectiveCostPrice para obtener el precio de compra correcto
                  final costPrice = _selectedMaterial!.effectiveCostPrice;
                  final totalCost = costPrice * _quantity;
                  
                  // Calcular ganancia
                  final totalProfit = totalPrice - totalCost;
                  final profitMargin = totalCost > 0 ? ((totalProfit / totalCost) * 100) : 0.0;

                  // Crear item compatible con la estructura de cotización
                  widget.onAdd({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'materialId':
                        _selectedMaterial!.id, // ID del material del inventario
                    'inv_material_id': _selectedMaterial!
                        .id, // También guardarlo aquí para compatibilidad
                    'name': _selectedMaterial!.name,
                    'type':
                        'custom', // Usar 'custom' porque el ENUM no incluye 'material'
                    'material': _selectedMaterial!.code,
                    'dimensions': _selectedMaterial!.category,
                    'quantity': _quantity.toInt(),
                    'unitWeight': 1.0,
                    'totalWeight': _quantity,
                    // Precios
                    'pricePerKg': price, // Precio venta por kg/unidad
                    'costPrice': costPrice, // Precio compra por kg/unidad
                    'unitSalePrice': price, // Alias para compatibilidad
                    'unitCostPrice': costPrice, // Alias para compatibilidad
                    'totalPrice': totalPrice, // Total venta
                    'totalCost': totalCost, // Total costo
                    // Ganancia
                    'unitProfit': price - costPrice, // Ganancia por unidad
                    'totalProfit': totalProfit, // Ganancia total
                    'profitMargin': profitMargin, // % margen
                    // Info del material
                    'productCode': _selectedMaterial!.code,
                    'stock': _selectedMaterial!.stock,
                    'unit': _selectedMaterial!.unit,
                  });
                  Navigator.pop(context);
                },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
