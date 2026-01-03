import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart' as helpers;
import '../../domain/entities/material.dart' as mat;
import '../../data/providers/providers.dart';

/// Pantalla moderna para crear recetas con calculadora de peso integrada
class RecipeBuilderPage extends ConsumerStatefulWidget {
  const RecipeBuilderPage({super.key});

  @override
  ConsumerState<RecipeBuilderPage> createState() => _RecipeBuilderPageState();
}

class _RecipeBuilderPageState extends ConsumerState<RecipeBuilderPage> {
  // Controladores para el formulario principal
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Lista de componentes agregados
  final List<RecipeComponent> _components = [];
  
  // Totales
  double get _totalWeight => _components.fold(0.0, (sum, c) => sum + c.weight);
  double get _totalCost => _components.fold(0.0, (sum, c) => sum + (c.weight * c.pricePerKg));
  double _manualLaborCost = 0.0;
  double _wastePercentage = 5.0; // 5% de pérdidas por defecto
  
  double get _totalWithWaste => _totalCost * (1 + _wastePercentage / 100);
  double get _grandTotal => _totalWithWaste + _manualLaborCost;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesState = ref.watch(recipesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Receta'),
        centerTitle: true,
        actions: [
          if (recipesState.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _components.isEmpty ? null : _saveRecipe,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Panel izquierdo: Calculadora y lista de materiales
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  // Calculadora de peso
                  Expanded(
                    child: _buildWeightCalculator(),
                  ),
                  // Botón para agregar del inventario
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showMaterialSelector,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Agregar Material del Inventario'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Panel derecho: Información de la receta y componentes
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Encabezado de la receta
                  _buildRecipeHeader(),
                  const Divider(height: 1),
                  // Lista de componentes agregados
                  Expanded(
                    child: _buildComponentsList(),
                  ),
                  const Divider(height: 1),
                  // Resumen de costos
                  _buildCostSummary(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información de la Receta',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Título / Nombre del Producto',
              hintText: 'Ej: Molino de Martillos 44"',
              prefixIcon: Icon(Icons.title),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              hintText: 'Descripción detallada del producto',
              prefixIcon: Icon(Icons.description),
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildWeightCalculator() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Calculadora de Peso',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Calcula el peso mediante las dimensiones del material',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _WeightCalculatorWidget(
            onAddComponent: (component) {
              setState(() {
                _components.add(component);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildComponentsList() {
    if (_components.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay componentes agregados',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega materiales del panel izquierdo',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _components.length,
      itemBuilder: (context, index) {
        final component = _components[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getComponentColor(component.category),
              child: Icon(
                _getComponentIcon(component.category),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              component.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (component.description != null)
                  Text(component.description!),
                const SizedBox(height: 4),
                Text(
                  'Peso: ${component.weight.toStringAsFixed(2)} kg • ${helpers.Helpers.formatCurrency(component.weight * component.pricePerKg)}',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  _components.removeAt(index);
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCostSummary() {
    // Precio de venta sugerido con margen del 30%
    final suggestedPriceMargin30 = _grandTotal * 1.30;
    final suggestedPriceMargin50 = _grandTotal * 1.50;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Resumen de Costos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Indicador de costo de fabricación
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.precision_manufacturing, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      'Costo Fabricación: ${helpers.Helpers.formatCurrency(_grandTotal)}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Materiales:', _totalWeight, helpers.Helpers.formatCurrency(_totalCost)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Pérdidas Material (${_wastePercentage.toStringAsFixed(0)}%):'),
              ),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: _wastePercentage.toStringAsFixed(0),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    isDense: true,
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _wastePercentage = double.tryParse(value) ?? 5.0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                helpers.Helpers.formatCurrency(_totalWithWaste - _totalCost),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text('Mano de Obra:'),
              ),
              SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: '0',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _manualLaborCost = double.tryParse(value) ?? 0.0;
                    });
                  },
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // Precio de venta sugerido con márgenes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.trending_up, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'PRECIO DE VENTA SUGERIDO',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMarginOption('30% margen', suggestedPriceMargin30, Colors.orange),
                    _buildMarginOption('50% margen', suggestedPriceMargin50, Colors.green),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Costo base: ${helpers.Helpers.formatCurrency(_grandTotal)} • Peso total: ${_totalWeight.toStringAsFixed(2)} kg',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarginOption(String label, double price, Color color) {
    final profit = price - _grandTotal;
    return Column(
      children: [
        Text(
          helpers.Helpers.formatCurrency(price),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          'Ganancia: ${helpers.Helpers.formatCurrency(profit)}',
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double weight, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Row(
          children: [
            if (!isTotal)
              Text(
                '${weight.toStringAsFixed(2)} kg • ',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTotal ? 20 : 14,
                color: isTotal ? AppTheme.primaryColor : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getComponentColor(String category) {
    switch (category.toLowerCase()) {
      case 'tubo':
        return Colors.blue;
      case 'lamina':
      case 'lámina':
        return Colors.green;
      case 'eje':
        return Colors.purple;
      case 'rodamiento':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getComponentIcon(String category) {
    switch (category.toLowerCase()) {
      case 'tubo':
        return Icons.circle_outlined;
      case 'lamina':
      case 'lámina':
        return Icons.crop_square;
      case 'eje':
        return Icons.horizontal_rule;
      case 'rodamiento':
        return Icons.settings;
      default:
        return Icons.category;
    }
  }

  Future<void> _showMaterialSelector() async {
    final materialsState = ref.read(materialsProvider);
    
    await showDialog(
      context: context,
      builder: (context) => _MaterialSelectorDialog(
        materials: materialsState.materials.cast<mat.Material>(),
        onSelect: (material, quantity) {
          // Agregar material con cantidad especificada
          setState(() {
            _components.add(RecipeComponent(
              materialId: material.id,
              name: material.name,
              description: '${quantity.toStringAsFixed(2)} ${material.unit}',
              category: material.category,
              weight: quantity,
              pricePerKg: material.pricePerKg,
            ));
          });
        },
      ),
    );
  }

  Future<void> _saveRecipe() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingrese un título')),
      );
      return;
    }

    if (_components.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregue al menos un componente')),
      );
      return;
    }

    // Convertir componentes al formato del provider
    final recipeComponents = _components
        .map((c) => RecipeComponent(
              materialId: c.materialId,
              name: c.name,
              description: c.description,
              category: c.category,
              weight: c.weight,
              pricePerKg: c.pricePerKg,
            ))
        .toList();

    // Guardar usando el provider
    final success = await ref.read(recipesProvider.notifier).saveRecipe(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          components: recipeComponents,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receta guardada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/products');
    } else {
      final error = ref.read(recipesProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ==================== CALCULADORA DE PESO ====================

class _WeightCalculatorWidget extends StatefulWidget {
  final Function(RecipeComponent) onAddComponent;

  const _WeightCalculatorWidget({required this.onAddComponent});

  @override
  State<_WeightCalculatorWidget> createState() => _WeightCalculatorWidgetState();
}

class _WeightCalculatorWidgetState extends State<_WeightCalculatorWidget> {
  String _selectedType = 'lamina'; // lamina, tubo, eje
  final _nameController = TextEditingController();
  
  // Dimensiones
  final _largoController = TextEditingController(text: '100');
  final _anchoController = TextEditingController(text: '100');
  final _espesorController = TextEditingController(text: '1/2');
  final _diametroController = TextEditingController(text: '4');
  final _precioKgController = TextEditingController(text: '5.00');
  
  double _calculatedWeight = 0.0;
  
  // Densidad fija del acero
  static const double steelDensity = 7.85; // kg/dm³ o g/cm³
  
  @override
  void initState() {
    super.initState();
    _calculateWeight();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de tipo de material
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _buildTypeButton('Lámina', 'lamina', Icons.crop_square),
              _buildTypeButton('Tubo', 'tubo', Icons.circle_outlined),
              _buildTypeButton('Eje', 'eje', Icons.horizontal_rule),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Nombre del componente
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre del Componente',
            hintText: 'Ej: Cilindro Principal',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 16),
        
        // Campos según el tipo seleccionado
        if (_selectedType == 'lamina') ..._buildLaminaFields(),
        if (_selectedType == 'tubo') ..._buildTuboFields(),
        if (_selectedType == 'eje') ..._buildEjeFields(),
        
        const SizedBox(height: 16),
        
        // Precio por kilo
        TextField(
          controller: _precioKgController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Precio por Kilo (\$)',
            border: OutlineInputBorder(),
            isDense: true,
            prefixText: '\$ ',
          ),
          onChanged: (_) => _calculateWeight(),
        ),
        
        const SizedBox(height: 24),
        
        // Resultado
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Peso Calculado:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_calculatedWeight.toStringAsFixed(2)} kg',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Costo estimado:'),
                  Text(
                    helpers.Helpers.formatCurrency(_calculatedWeight * (double.tryParse(_precioKgController.text) ?? 0)),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Botón agregar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _calculatedWeight > 0 ? _addComponent : null,
            icon: const Icon(Icons.add),
            label: const Text('Agregar Componente'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeButton(String label, String value, IconData icon) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = value;
            _calculateWeight();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLaminaFields() {
    return [
      const Text(
        'Dimensiones de la Lámina',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _largoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Largo (cm)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _calculateWeight(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _anchoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ancho (cm)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _calculateWeight(),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _espesorController,
        decoration: const InputDecoration(
          labelText: 'Espesor (pulgadas)',
          hintText: 'Ej: 1/2, 3/4, 1/4',
          border: OutlineInputBorder(),
          isDense: true,
          helperText: 'Puede usar fracciones como 1/2 o decimales',
        ),
        onChanged: (_) => _calculateWeight(),
      ),
    ];
  }

  List<Widget> _buildTuboFields() {
    return [
      const Text(
        'Dimensiones del Tubo',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _diametroController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Diámetro Exterior (pulgadas)',
          hintText: 'Ej: 4, 6, 8',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => _calculateWeight(),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _espesorController,
        decoration: const InputDecoration(
          labelText: 'Espesor de Pared (pulgadas)',
          hintText: 'Ej: 1/8, 1/4, 3/16',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => _calculateWeight(),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _largoController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Largo (cm)',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => _calculateWeight(),
      ),
    ];
  }

  List<Widget> _buildEjeFields() {
    return [
      const Text(
        'Dimensiones del Eje',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _diametroController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Diámetro (pulgadas)',
          hintText: 'Ej: 2, 3, 4',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => _calculateWeight(),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _largoController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Largo (cm)',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => _calculateWeight(),
      ),
    ];
  }

  void _calculateWeight() {
    setState(() {
      try {
        if (_selectedType == 'lamina') {
          // Lámina: largo (cm) × ancho (cm) × espesor (pulgadas)
          final largo = double.tryParse(_largoController.text) ?? 0;
          final ancho = double.tryParse(_anchoController.text) ?? 0;
          final espesorInches = _parseFraction(_espesorController.text);
          
          // Convertir espesor de pulgadas a cm
          final espesorCm = espesorInches * 2.54;
          
          // Volumen en cm³ = largo × ancho × espesor
          final volumenCm3 = largo * ancho * espesorCm;
          
          // Peso = volumen × densidad (7.85 g/cm³ para acero)
          _calculatedWeight = (volumenCm3 * steelDensity) / 1000; // convertir g a kg
          
        } else if (_selectedType == 'tubo') {
          // Tubo: diámetro exterior (pulg), espesor pared (pulg), largo (cm)
          final diametroExtPulg = double.tryParse(_diametroController.text) ?? 0;
          final espesorPulg = _parseFraction(_espesorController.text);
          final largoCm = double.tryParse(_largoController.text) ?? 0;
          
          // Convertir a cm
          final diametroExtCm = diametroExtPulg * 2.54;
          final espesorCm = espesorPulg * 2.54;
          final diametroIntCm = diametroExtCm - (2 * espesorCm);
          
          // Volumen del cilindro hueco
          final radioExtCm = diametroExtCm / 2;
          final radioIntCm = diametroIntCm / 2;
          final volumenCm3 = math.pi * (radioExtCm * radioExtCm - radioIntCm * radioIntCm) * largoCm;
          
          _calculatedWeight = (volumenCm3 * steelDensity) / 1000;
          
        } else if (_selectedType == 'eje') {
          // Eje: diámetro (pulg), largo (cm)
          final diametroPulg = double.tryParse(_diametroController.text) ?? 0;
          final largoCm = double.tryParse(_largoController.text) ?? 0;
          
          // Convertir a cm
          final diametroCm = diametroPulg * 2.54;
          final radioCm = diametroCm / 2;
          
          // Volumen del cilindro sólido
          final volumenCm3 = math.pi * radioCm * radioCm * largoCm;
          
          _calculatedWeight = (volumenCm3 * steelDensity) / 1000;
        }
      } catch (e) {
        _calculatedWeight = 0.0;
      }
    });
  }

  /// Convierte fracciones como "1/2", "3/4" a decimal
  double _parseFraction(String input) {
    input = input.trim();
    if (input.isEmpty) return 0;
    
    // Si contiene /
    if (input.contains('/')) {
      final parts = input.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0].trim()) ?? 0;
        final den = double.tryParse(parts[1].trim()) ?? 1;
        return den != 0 ? num / den : 0;
      }
    }
    
    // Si es decimal normal
    return double.tryParse(input) ?? 0;
  }

  void _addComponent() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un nombre para el componente')),
      );
      return;
    }

    final component = RecipeComponent(
      materialId: null, // No viene del inventario
      name: _nameController.text.trim(),
      description: _getComponentDescription(),
      category: _selectedType,
      weight: _calculatedWeight,
      pricePerKg: double.tryParse(_precioKgController.text) ?? 0,
    );

    widget.onAddComponent(component);
    
    // Limpiar nombre
    _nameController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Componente agregado')),
    );
  }

  String _getComponentDescription() {
    switch (_selectedType) {
      case 'lamina':
        return '${_largoController.text}×${_anchoController.text}cm × ${_espesorController.text}"';
      case 'tubo':
        return 'Ø${_diametroController.text}" × ${_espesorController.text}" × ${_largoController.text}cm';
      case 'eje':
        return 'Ø${_diametroController.text}" × ${_largoController.text}cm';
      default:
        return '';
    }
  }
}

// ==================== SELECTOR DE MATERIALES ====================

class _MaterialSelectorDialog extends StatefulWidget {
  final List<mat.Material> materials;
  final Function(mat.Material, double) onSelect;

  const _MaterialSelectorDialog({
    required this.materials,
    required this.onSelect,
  });

  @override
  State<_MaterialSelectorDialog> createState() => _MaterialSelectorDialogState();
}

class _MaterialSelectorDialogState extends State<_MaterialSelectorDialog> {
  String _searchQuery = '';
  String? _selectedCategory;
  mat.Material? _selectedMaterial;
  final _quantityController = TextEditingController(text: '1');

  List<mat.Material> get _filteredMaterials {
    return widget.materials.where((m) {
      final matchesSearch = m.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || m.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleccionar Material del Inventario',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar material...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredMaterials.length,
                itemBuilder: (context, index) {
                  final material = _filteredMaterials[index];
                  final isSelected = _selectedMaterial?.id == material.id;
                  return ListTile(
                    selected: isSelected,
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? AppTheme.primaryColor : Colors.grey,
                      child: const Icon(Icons.inventory_2, color: Colors.white),
                    ),
                    title: Text(material.name),
                    subtitle: Text(
                      '${helpers.Helpers.formatCurrency(material.pricePerKg)}/kg • Stock: ${material.stock.toStringAsFixed(2)} ${material.unit}',
                    ),
                    onTap: () {
                      setState(() {
                        _selectedMaterial = material;
                      });
                    },
                  );
                },
              ),
            ),
            if (_selectedMaterial != null) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Cantidad (${_selectedMaterial!.unit})',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      final quantity = double.tryParse(_quantityController.text) ?? 1;
                      widget.onSelect(_selectedMaterial!, quantity);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
