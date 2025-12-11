import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/weight_calculator.dart';

class NewQuotationPage extends StatefulWidget {
  const NewQuotationPage({super.key});

  @override
  State<NewQuotationPage> createState() => _NewQuotationPageState();
}

class _NewQuotationPageState extends State<NewQuotationPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  // Datos del cliente
  String? _selectedCustomerId;
  final _customerController = TextEditingController();

  // Lista de items/componentes
  final List<Map<String, dynamic>> _items = [];

  // Costos adicionales
  final _laborHoursController = TextEditingController(text: '0');
  final _laborRateController = TextEditingController(text: '25');
  final _energyCostController = TextEditingController(text: '0');
  final _gasCostController = TextEditingController(text: '0');
  final _suppliesCostController = TextEditingController(text: '0');
  final _otherCostsController = TextEditingController(text: '0');
  final _profitMarginController = TextEditingController(text: '20');
  final _notesController = TextEditingController();
  final _validDaysController = TextEditingController(text: '15');

  // Clientes de ejemplo
  final List<Map<String, dynamic>> _customers = [
    {'id': '1', 'name': 'Minera San Martín S.A.', 'ruc': '20123456789'},
    {'id': '2', 'name': 'Procesadora de Minerales del Norte', 'ruc': '20234567890'},
    {'id': '3', 'name': 'Cementos Pacífico', 'ruc': '20345678901'},
    {'id': '4', 'name': 'Industrias Metalúrgicas Sur', 'ruc': '20456789012'},
    {'id': '5', 'name': 'Minera Los Andes', 'ruc': '20567890123'},
  ];

  // Precios de materiales de ejemplo
  final List<Map<String, dynamic>> _materialPrices = [
    {'id': '1', 'name': 'Acero A36', 'category': 'lamina', 'pricePerKg': 4.50, 'density': 7.85},
    {'id': '2', 'name': 'Acero Inoxidable 304', 'category': 'lamina', 'pricePerKg': 12.00, 'density': 8.0},
    {'id': '3', 'name': 'Acero Inoxidable 316', 'category': 'lamina', 'pricePerKg': 15.00, 'density': 8.0},
    {'id': '4', 'name': 'Acero al Carbono', 'category': 'tubo', 'pricePerKg': 5.00, 'density': 7.85},
    {'id': '5', 'name': 'Acero SAE 1045', 'category': 'eje', 'pricePerKg': 6.50, 'density': 7.85},
    {'id': '6', 'name': 'Acero SAE 4140', 'category': 'eje', 'pricePerKg': 8.00, 'density': 7.85},
    {'id': '7', 'name': 'Fundición Gris', 'category': 'otros', 'pricePerKg': 3.50, 'density': 7.2},
  ];

  // Productos compuestos de ejemplo (BOM)
  final List<Map<String, dynamic>> _compositeProducts = [
    {
      'id': 'PROD-001',
      'code': 'MOL-44M',
      'name': 'Molino 44m',
      'category': 'molino',
      'totalWeight': 850.5,
      'totalPrice': 4500.00,
      'components': [
        {'name': 'Cilindro principal', 'material': 'Acero A36', 'dimensions': 'Ø508mm × 12mm × 1000mm', 'weight': 150.2, 'price': 675.90, 'quantity': 1},
        {'name': 'Tapa frontal', 'material': 'Acero A36', 'dimensions': 'Ø508mm × 12mm', 'weight': 18.5, 'price': 83.25, 'quantity': 2},
        {'name': 'Eje de transmisión', 'material': 'Acero SAE 4140', 'dimensions': 'Ø100mm × 1200mm', 'weight': 74.0, 'price': 592.00, 'quantity': 1},
        {'name': 'Base metálica', 'material': 'Acero A36', 'dimensions': '1500mm × 800mm × 10mm', 'weight': 94.2, 'price': 423.90, 'quantity': 1},
        {'name': 'Rodamiento principal', 'material': 'SKF 6310', 'dimensions': 'Estándar', 'weight': 1.2, 'price': 85.00, 'quantity': 2},
      ],
    },
    {
      'id': 'PROD-002',
      'code': 'MOL-36M',
      'name': 'Molino 36m',
      'category': 'molino',
      'totalWeight': 620.0,
      'totalPrice': 3200.00,
      'components': [
        {'name': 'Cilindro principal', 'material': 'Acero A36', 'dimensions': 'Ø406mm × 10mm × 800mm', 'weight': 95.5, 'price': 429.75, 'quantity': 1},
        {'name': 'Tapa frontal', 'material': 'Acero A36', 'dimensions': 'Ø406mm × 10mm', 'weight': 10.2, 'price': 45.90, 'quantity': 2},
        {'name': 'Eje de transmisión', 'material': 'Acero SAE 4140', 'dimensions': 'Ø80mm × 1000mm', 'weight': 39.4, 'price': 315.20, 'quantity': 1},
      ],
    },
    {
      'id': 'PROD-003',
      'code': 'TRANS-001',
      'name': 'Transportador de banda 5m',
      'category': 'transportador',
      'totalWeight': 320.0,
      'totalPrice': 1800.00,
      'components': [
        {'name': 'Estructura lateral', 'material': 'Acero A36', 'dimensions': '5000mm × 150mm × 6mm', 'weight': 35.3, 'price': 158.85, 'quantity': 2},
        {'name': 'Rodillo tensor', 'material': 'Acero al Carbono', 'dimensions': 'Ø89mm × 500mm', 'weight': 15.2, 'price': 76.00, 'quantity': 3},
        {'name': 'Tambor motriz', 'material': 'Acero A36', 'dimensions': 'Ø200mm × 500mm', 'weight': 45.0, 'price': 202.50, 'quantity': 1},
      ],
    },
    {
      'id': 'PROD-004',
      'code': 'TAN-500L',
      'name': 'Tanque 500 litros',
      'category': 'tanque',
      'totalWeight': 180.0,
      'totalPrice': 950.00,
      'components': [
        {'name': 'Cuerpo cilíndrico', 'material': 'Acero Inoxidable 304', 'dimensions': 'Ø800mm × 3mm × 1000mm', 'weight': 60.5, 'price': 726.00, 'quantity': 1},
        {'name': 'Tapa superior', 'material': 'Acero Inoxidable 304', 'dimensions': 'Ø800mm × 3mm', 'weight': 12.0, 'price': 144.00, 'quantity': 1},
        {'name': 'Fondo cónico', 'material': 'Acero Inoxidable 304', 'dimensions': 'Ø800mm × 3mm', 'weight': 15.0, 'price': 180.00, 'quantity': 1},
      ],
    },
  ];

  // Cálculos
  double get _materialsCost => _items.fold(0.0, (sum, item) => sum + (item['totalPrice'] as double));
  double get _totalWeight => _items.fold(0.0, (sum, item) => sum + (item['totalWeight'] as double));
  double get _laborCost {
    final hours = double.tryParse(_laborHoursController.text) ?? 0;
    final rate = double.tryParse(_laborRateController.text) ?? 0;
    return hours * rate;
  }
  double get _indirectCosts {
    final energy = double.tryParse(_energyCostController.text) ?? 0;
    final gas = double.tryParse(_gasCostController.text) ?? 0;
    final supplies = double.tryParse(_suppliesCostController.text) ?? 0;
    final others = double.tryParse(_otherCostsController.text) ?? 0;
    return energy + gas + supplies + others;
  }
  double get _subtotal => _materialsCost + _laborCost + _indirectCosts;
  double get _profitAmount {
    final margin = double.tryParse(_profitMarginController.text) ?? 0;
    return _subtotal * (margin / 100);
  }
  double get _total => _subtotal + _profitAmount;

  @override
  void dispose() {
    _customerController.dispose();
    _laborHoursController.dispose();
    _laborRateController.dispose();
    _energyCostController.dispose();
    _gasCostController.dispose();
    _suppliesCostController.dispose();
    _otherCostsController.dispose();
    _profitMarginController.dispose();
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
          // Panel lateral con resumen
          Container(
            width: 320,
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
                      onStepTapped: (step) => setState(() => _currentStep = step),
                      controlsBuilder: (context, details) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Row(
                            children: [
                              if (_currentStep < 3)
                                ElevatedButton(
                                  onPressed: details.onStepContinue,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  child: const Text('Continuar'),
                                ),
                              if (_currentStep == 3)
                                ElevatedButton.icon(
                                  onPressed: _saveQuotation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  icon: const Icon(Icons.save),
                                  label: const Text('Guardar Cotización'),
                                ),
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
                          subtitle: Text(_selectedCustomerId != null 
                              ? _customers.firstWhere((c) => c['id'] == _selectedCustomerId)['name']
                              : 'Selecciona un cliente'),
                          isActive: _currentStep >= 0,
                          state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                          content: _buildCustomerStep(),
                        ),
                        Step(
                          title: const Text('Componentes'),
                          subtitle: Text('${_items.length} items - ${Helpers.formatNumber(_totalWeight)} kg'),
                          isActive: _currentStep >= 1,
                          state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                          content: _buildComponentsStep(),
                        ),
                        Step(
                          title: const Text('Costos Adicionales'),
                          subtitle: Text('M.O. + Indirectos: ${Helpers.formatCurrency(_laborCost + _indirectCosts)}'),
                          isActive: _currentStep >= 2,
                          state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                          content: _buildCostsStep(),
                        ),
                        Step(
                          title: const Text('Resumen y Confirmación'),
                          subtitle: Text('Total: ${Helpers.formatCurrency(_total)}'),
                          isActive: _currentStep >= 3,
                          state: _currentStep == 3 ? StepState.indexed : StepState.indexed,
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
        // Header del resumen
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Resumen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'Cotización en borrador',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        // Contenido del resumen
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Cliente
              _buildSummarySection(
                'Cliente',
                _selectedCustomerId != null
                    ? _customers.firstWhere((c) => c['id'] == _selectedCustomerId)['name']
                    : 'No seleccionado',
                Icons.person,
              ),
              const SizedBox(height: 16),
              // Items
              _buildSummarySection(
                'Componentes',
                '${_items.length} items',
                Icons.inventory_2,
              ),
              if (_items.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...(_items.take(3).map((item) => Padding(
                  padding: const EdgeInsets.only(left: 32, bottom: 4),
                  child: Text(
                    '• ${item['name']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ))),
                if (_items.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      '+ ${_items.length - 3} más...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
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
              const Divider(thickness: 2),
              const SizedBox(height: 8),
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildCostLine(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          Text(Helpers.formatCurrency(value), style: const TextStyle(fontSize: 13)),
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
          items: _customers.map((c) => DropdownMenuItem(
            value: c['id'] as String,
            child: Text('${c['name']} - RUC: ${c['ruc']}'),
          )).toList(),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                        Text('Válida hasta', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        Text(
                          Helpers.formatDate(DateTime.now().add(
                            Duration(days: int.tryParse(_validDaysController.text) ?? 15),
                          )),
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
                'Agrega los componentes a cotizar',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'new_component') {
                  _showAddComponentDialog();
                } else if (value == 'from_product') {
                  _showSelectProductDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'new_component',
                  child: ListTile(
                    leading: Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                    title: Text('Nuevo Componente'),
                    subtitle: Text('Crear con dimensiones'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'from_product',
                  child: ListTile(
                    leading: Icon(Icons.inventory_2, color: Colors.green),
                    title: Text('Desde Producto'),
                    subtitle: Text('Seleccionar del inventario'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              child: ElevatedButton.icon(
                onPressed: null, // El popup se abre con el onTap del PopupMenuButton
                icon: const Icon(Icons.add, size: 18),
                label: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Agregar'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.primaryColor,
                  disabledForegroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No hay componentes agregados',
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Agrega cilindros, tapas, ejes u otros componentes',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Header de la tabla
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(flex: 3, child: Text('Componente', style: TextStyle(fontWeight: FontWeight.bold))),
                      const Expanded(flex: 2, child: Text('Material', style: TextStyle(fontWeight: FontWeight.bold))),
                      const Expanded(child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      const Expanded(child: Text('Peso (kg)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      const Expanded(child: Text('Precio/kg', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Items
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              Text(item['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text(
                                item['dimensions'] ?? '',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Expanded(flex: 2, child: Text(item['material'] ?? '-')),
                        Expanded(child: Text('${item['quantity']}', textAlign: TextAlign.center)),
                        Expanded(child: Text(Helpers.formatNumber(item['totalWeight']), textAlign: TextAlign.right)),
                        Expanded(child: Text(Helpers.formatCurrency(item['pricePerKg']), textAlign: TextAlign.right)),
                        Expanded(
                          child: Text(
                            Helpers.formatCurrency(item['totalPrice']),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => setState(() => _items.removeAt(index)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                // Total
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(flex: 3, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                      const Expanded(flex: 2, child: SizedBox()),
                      Expanded(child: Text('${_items.length}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                        child: Text(
                          '${Helpers.formatNumber(_totalWeight)} kg',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                      Expanded(
                        child: Text(
                          Helpers.formatCurrency(_materialsCost),
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ),
                      const SizedBox(width: 48),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.engineering, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text('Mano de Obra', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _laborHoursController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Horas estimadas',
                        suffixText: 'hrs',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _laborRateController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Tarifa por hora',
                        prefixText: 'S/ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        const Text('Total M.O.', style: TextStyle(fontSize: 12)),
                        Text(
                          Helpers.formatCurrency(_laborCost),
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
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
                  const Text('Costos Indirectos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _energyCostController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Energía eléctrica',
                        prefixText: 'S/ ',
                        prefixIcon: const Icon(Icons.bolt),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _gasCostController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Gas',
                        prefixText: 'S/ ',
                        prefixIcon: const Icon(Icons.local_fire_department),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _suppliesCostController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Insumos (soldadura, pintura, etc.)',
                        prefixText: 'S/ ',
                        prefixIcon: const Icon(Icons.handyman),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _otherCostsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Otros costos',
                        prefixText: 'S/ ',
                        prefixIcon: const Icon(Icons.more_horiz),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
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
                  const Text('Margen de Ganancia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Slider(
                      value: double.tryParse(_profitMarginController.text) ?? 20,
                      min: 0,
                      max: 50,
                      divisions: 50,
                      label: '${_profitMarginController.text}%',
                      onChanged: (value) {
                        setState(() {
                          _profitMarginController.text = value.toStringAsFixed(0);
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
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
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
                  const Text('Notas y Condiciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Condiciones de pago, tiempo de entrega, garantías, etc.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
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
              _buildFinalSummaryRow('Cliente', 
                _selectedCustomerId != null 
                  ? _customers.firstWhere((c) => c['id'] == _selectedCustomerId)['name']
                  : '-'),
              _buildFinalSummaryRow('Componentes', '${_items.length} items'),
              _buildFinalSummaryRow('Peso Total', '${Helpers.formatNumber(_totalWeight)} kg'),
              const Divider(height: 24),
              _buildFinalSummaryRow('Materiales', Helpers.formatCurrency(_materialsCost)),
              _buildFinalSummaryRow('Mano de Obra', Helpers.formatCurrency(_laborCost)),
              _buildFinalSummaryRow('Costos Indirectos', Helpers.formatCurrency(_indirectCosts)),
              _buildFinalSummaryRow('Subtotal', Helpers.formatCurrency(_subtotal)),
              _buildFinalSummaryRow('Ganancia (${_profitMarginController.text}%)', Helpers.formatCurrency(_profitAmount)),
              const Divider(height: 24, thickness: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
        const SnackBar(content: Text('Seleccione un cliente'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_currentStep == 1 && _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregue al menos un componente'), backgroundColor: Colors.orange),
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

  void _saveQuotation() {
    if (_formKey.currentState!.validate()) {
      // Aquí se guardaría en la base de datos
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cotización guardada exitosamente!'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/quotations');
    }
  }

  void _showNewCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Cliente'),
        content: const Text('Funcionalidad por implementar.\nPor ahora, seleccione un cliente existente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showAddComponentDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddComponentDialog(
        materialPrices: _materialPrices,
        onAdd: (component) {
          setState(() => _items.add(component));
        },
      ),
    );
  }

  void _showSelectProductDialog() {
    showDialog(
      context: context,
      builder: (context) => _SelectProductDialog(
        products: _compositeProducts,
        onSelect: (product, addComponents) {
          setState(() {
            if (addComponents) {
              // Agregar todos los componentes del producto
              final components = product['components'] as List<dynamic>;
              for (final comp in components) {
                _items.add({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': comp['name'],
                  'type': 'from_product',
                  'material': comp['material'],
                  'dimensions': comp['dimensions'],
                  'quantity': comp['quantity'],
                  'unitWeight': comp['weight'] / (comp['quantity'] as int),
                  'totalWeight': comp['weight'],
                  'pricePerKg': 0,
                  'totalPrice': comp['price'],
                  'productCode': product['code'],
                  'productName': product['name'],
                });
              }
            } else {
              // Agregar como producto único
              _items.add({
                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                'name': product['name'],
                'type': 'composite_product',
                'material': 'Producto compuesto',
                'dimensions': '${product['code']} - Ver desglose',
                'quantity': 1,
                'unitWeight': product['totalWeight'],
                'totalWeight': product['totalWeight'],
                'pricePerKg': 0,
                'totalPrice': product['totalPrice'],
                'productCode': product['code'],
                'components': product['components'],
              });
            }
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
        final outerDiameter = double.tryParse(_outerDiameterController.text) ?? 0;
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
              const Text('Tipo de componente', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cylinder', label: Text('Cilindro'), icon: Icon(Icons.circle_outlined)),
                  ButtonSegment(value: 'circular_plate', label: Text('Tapa'), icon: Icon(Icons.lens)),
                  ButtonSegment(value: 'rectangular_plate', label: Text('Lámina'), icon: Icon(Icons.rectangle_outlined)),
                  ButtonSegment(value: 'shaft', label: Text('Eje'), icon: Icon(Icons.horizontal_rule)),
                  ButtonSegment(value: 'custom', label: Text('Manual'), icon: Icon(Icons.edit)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              // Material
              DropdownButtonFormField<String>(
                initialValue: _selectedMaterialId,
                decoration: InputDecoration(
                  labelText: 'Material',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: widget.materialPrices.map((m) => DropdownMenuItem(
                  value: m['id'] as String,
                  child: Text('${m['name']} - S/ ${m['pricePerKg']}/kg'),
                )).toList(),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          Text('${Helpers.formatNumber(_calculatedWeight)} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          const Text('Precio Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            Helpers.formatCurrency(
                              _calculatedWeight * (int.tryParse(_quantityController.text) ?? 1) * _pricePerKg,
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
      case 'cylinder': return 'Ej: Cilindro principal del molino';
      case 'circular_plate': return 'Ej: Tapa frontal';
      case 'rectangular_plate': return 'Ej: Lámina de refuerzo';
      case 'shaft': return 'Ej: Eje de transmisión';
      default: return 'Nombre del componente';
    }
  }

  void _addComponent() {
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final totalWeight = _calculatedWeight * quantity;
    final material = _selectedMaterialId != null
        ? widget.materialPrices.firstWhere((m) => m['id'] == _selectedMaterialId)
        : null;

    final component = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': _nameController.text.isNotEmpty ? _nameController.text : _getDefaultName(),
      'type': _componentType,
      'material': material?['name'] ?? 'No especificado',
      'dimensions': _getDimensionsString(),
      'quantity': quantity,
      'unitWeight': _calculatedWeight,
      'totalWeight': totalWeight,
      'pricePerKg': _pricePerKg,
      'totalPrice': totalWeight * _pricePerKg,
    };

    widget.onAdd(component);
    Navigator.pop(context);
  }

  String _getDefaultName() {
    switch (_componentType) {
      case 'cylinder': return 'Cilindro';
      case 'circular_plate': return 'Tapa circular';
      case 'rectangular_plate': return 'Lámina rectangular';
      case 'shaft': return 'Eje';
      default: return 'Componente';
    }
  }
}
// Diálogo para seleccionar producto del inventario
class _SelectProductDialog extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic> product, bool addComponents) onSelect;

  const _SelectProductDialog({
    required this.products,
    required this.onSelect,
  });

  @override
  State<_SelectProductDialog> createState() => _SelectProductDialogState();
}

class _SelectProductDialogState extends State<_SelectProductDialog> {
  String _searchQuery = '';
  String _selectedCategory = 'todos';
  Map<String, dynamic>? _selectedProduct;
  bool _showComponents = false;

  List<Map<String, dynamic>> get _filteredProducts {
    return widget.products.where((p) {
      final matchesSearch = p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p['code'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'todos' || p['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 900,
        height: MediaQuery.of(context).size.height * 0.85,
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
                      hintText: 'Buscar por nombre o código...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(value: 'molino', child: Text('Molinos')),
                      DropdownMenuItem(value: 'transportador', child: Text('Transportadores')),
                      DropdownMenuItem(value: 'tanque', child: Text('Tanques')),
                      DropdownMenuItem(value: 'estructura', child: Text('Estructuras')),
                    ],
                    onChanged: (value) => setState(() => _selectedCategory = value!),
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
                                  Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text('No se encontraron productos', style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _filteredProducts.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                final isSelected = _selectedProduct?['id'] == product['id'];
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: AppTheme.primaryColor.withOpacity(0.1),
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(product['category']).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(product['category']),
                                      color: _getCategoryColor(product['category']),
                                    ),
                                  ),
                                  title: Text(
                                    product['name'],
                                    style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                  ),
                                  subtitle: Text('${product['code']} • ${product['totalWeight']} kg'),
                                  trailing: Text(
                                    'S/ ${Helpers.formatNumber(product['totalPrice'])}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _selectedProduct = product;
                                      _showComponents = true;
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Detalle del producto seleccionado
                  Expanded(
                    flex: 3,
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
                                  Icon(Icons.touch_app, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  Text('Selecciona un producto', style: TextStyle(color: Colors.grey[600])),
                                  const SizedBox(height: 4),
                                  Text('para ver sus componentes', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
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
                if (_selectedProduct != null) ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.onSelect(_selectedProduct!, true);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: const Text('Agregar Componentes Separados'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      widget.onSelect(_selectedProduct!, false);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Agregar como Producto'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetail() {
    final product = _selectedProduct!;
    final components = product['components'] as List<dynamic>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header del producto
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${product['code']}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S/ ${Helpers.formatNumber(product['totalPrice'])}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    '${Helpers.formatNumber(product['totalWeight'])} kg',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Título de componentes
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.list_alt, size: 20),
              const SizedBox(width: 8),
              Text(
                'Componentes (${components.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                'Para factura empresa',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
        
        // Lista de componentes
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: components.length,
            itemBuilder: (context, index) {
              final comp = components[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${comp['quantity']}×',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comp['name'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${comp['material']} • ${comp['dimensions']}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'S/ ${Helpers.formatNumber(comp['price'])}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${Helpers.formatNumber(comp['weight'])} kg',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Resumen
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'El cliente verá: "${product['name']}"',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  Text('Total: ', style: TextStyle(color: Colors.grey[600])),
                  Text(
                    'S/ ${Helpers.formatNumber(product['totalPrice'])}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'molino': return Colors.blue;
      case 'transportador': return Colors.green;
      case 'tanque': return Colors.orange;
      case 'estructura': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'molino': return Icons.settings;
      case 'transportador': return Icons.conveyor_belt;
      case 'tanque': return Icons.local_drink;
      case 'estructura': return Icons.foundation;
      default: return Icons.category;
    }
  }
}