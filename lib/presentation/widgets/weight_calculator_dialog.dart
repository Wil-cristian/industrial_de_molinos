import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/weight_calculator.dart';
import '../../domain/entities/material.dart' as mat;

/// Resultado del cálculo de peso
class WeightCalculatorResult {
  final double weight;
  final double cost;
  final int quantity;
  final String type; // cylinder, rectangular_plate, shaft
  final String dimensionDescription;
  final double? outerDiameter;
  final double? thickness;
  final double? length;
  final double? width;
  final double? height;

  WeightCalculatorResult({
    required this.weight,
    required this.cost,
    required this.quantity,
    required this.type,
    required this.dimensionDescription,
    this.outerDiameter,
    this.thickness,
    this.length,
    this.width,
    this.height,
  });
}

/// Diálogo moderno para calcular peso de materiales
/// - Dimensiones en pulgadas con selector tipo rueda/barril
/// - Largo SIEMPRE en centímetros
class WeightCalculatorDialog extends StatefulWidget {
  final mat.Material material;
  final String initialCategory; // tubo, lamina, eje

  const WeightCalculatorDialog({
    super.key,
    required this.material,
    required this.initialCategory,
  });

  /// Muestra el diálogo y retorna el resultado del cálculo
  static Future<WeightCalculatorResult?> show(
    BuildContext context, {
    required mat.Material material,
    required String category,
  }) {
    return showDialog<WeightCalculatorResult>(
      context: context,
      builder: (context) => WeightCalculatorDialog(
        material: material,
        initialCategory: category,
      ),
    );
  }

  @override
  State<WeightCalculatorDialog> createState() => _WeightCalculatorDialogState();
}

class _WeightCalculatorDialogState extends State<WeightCalculatorDialog> {
  // Controllers para dimensiones en pulgadas (usando el selector)
  final _outerDiameterCtrl = TextEditingController(text: '1');
  final _thicknessCtrl = TextEditingController(text: '1/4');
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  
  // Controller para largo (siempre en cm)
  final _lengthCmCtrl = TextEditingController();
  
  // Controller para cantidad
  final _quantityCtrl = TextEditingController(text: '1');

  double _calculatedWeight = 0;
  double _totalCost = 0;
  static const double _density = 7.85; // Acero al carbono g/cm³

  late String _selectedType;

  // Fracciones comunes en pulgadas
  static const List<String> _commonSizes = [
    '1/16', '1/8', '3/16', '1/4', '5/16', '3/8', '1/2', '5/8',
    '3/4', '7/8', '1', '1 1/4', '1 1/2', '2', '2 1/2', '3', '4', '5', '6',
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialCategory == 'tubo'
        ? 'cylinder'
        : widget.initialCategory == 'lamina'
            ? 'rectangular_plate'
            : 'shaft';
  }

  @override
  void dispose() {
    _outerDiameterCtrl.dispose();
    _thicknessCtrl.dispose();
    _lengthCmCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  /// Convierte una fracción de pulgada a milímetros
  double _inchFractionToMm(String value) {
    if (value.isEmpty) return 0;
    
    double total = 0;
    
    // Manejar valores mixtos como "1 1/4"
    final parts = value.trim().split(' ');
    
    for (final part in parts) {
      if (part.contains('/')) {
        // Es una fracción
        final fracParts = part.split('/');
        if (fracParts.length == 2) {
          final num = double.tryParse(fracParts[0]) ?? 0;
          final den = double.tryParse(fracParts[1]) ?? 1;
          total += num / den;
        }
      } else {
        // Es un entero
        total += double.tryParse(part) ?? 0;
      }
    }
    
    return total * 25.4; // Convertir pulgadas a mm
  }

  void _recalculate() {
    double weight = 0;
    final quantity = double.tryParse(_quantityCtrl.text) ?? 1;
    final largoCm = double.tryParse(_lengthCmCtrl.text) ?? 0;
    final largoMm = largoCm * 10; // Convertir cm a mm

    switch (_selectedType) {
      case 'cylinder':
        final outerD = _inchFractionToMm(_outerDiameterCtrl.text);
        final thickness = _inchFractionToMm(_thicknessCtrl.text);
        if (outerD > 0 && thickness > 0 && largoMm > 0) {
          weight = WeightCalculator.calculateCylinderWeight(
            outerDiameter: outerD,
            thickness: thickness,
            length: largoMm,
            density: _density,
          );
        }
        break;
      case 'rectangular_plate':
        final width = double.tryParse(_widthCtrl.text) ?? 0; // cm
        final height = double.tryParse(_heightCtrl.text) ?? 0; // cm - este es el "ancho" de la lámina
        final thickness = _inchFractionToMm(_thicknessCtrl.text);
        if (largoCm > 0 && width > 0 && thickness > 0) {
          // Convertir todo a mm para el cálculo
          weight = WeightCalculator.calculateRectangularPlateWeight(
            width: largoCm * 10, // cm a mm (largo)
            height: width * 10, // cm a mm (ancho)
            thickness: thickness, // ya en mm
            density: _density,
          );
        }
        break;
      case 'shaft':
        final diameter = _inchFractionToMm(_outerDiameterCtrl.text);
        if (diameter > 0 && largoMm > 0) {
          weight = WeightCalculator.calculateShaftWeight(
            diameter: diameter,
            length: largoMm,
            density: _density,
          );
        }
        break;
    }

    setState(() {
      _calculatedWeight = weight * quantity;
      _totalCost = _calculatedWeight * widget.material.effectiveCostPrice;
    });
  }

  void _clearFields() {
    _outerDiameterCtrl.text = '1';
    _thicknessCtrl.text = '1/4';
    _lengthCmCtrl.clear();
    _widthCtrl.clear();
    _heightCtrl.clear();
    _calculatedWeight = 0;
    _totalCost = 0;
  }

  /// Selector tipo rueda/barril para fracciones de pulgada
  Widget _buildWheelSelector({
    required String label,
    required TextEditingController controller,
  }) {
    int initialIndex = _commonSizes.indexOf(controller.text);
    if (initialIndex < 0) initialIndex = 3; // Default a 1/4

    return Row(
      children: [
        // Label
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
        // Wheel picker
        SizedBox(
          width: 80,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Stack(
              children: [
                // Highlight de selección
                Center(
                  child: Container(
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                // Wheel
                ListWheelScrollView.useDelegate(
                  itemExtent: 24,
                  diameterRatio: 1.2,
                  perspective: 0.002,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(initialItem: initialIndex),
                  onSelectedItemChanged: (index) {
                    controller.text = _commonSizes[index];
                    _recalculate();
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: _commonSizes.length,
                    builder: (context, index) {
                      final size = _commonSizes[index];
                      final isSelected = controller.text == size;
                      return Center(
                        child: Text(
                          '$size"',
                          style: TextStyle(
                            fontSize: isSelected ? 14 : 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.primaryColor : Colors.grey[500],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Input manual
        SizedBox(
          width: 55,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '?',
              suffixText: '"',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            onChanged: (_) => _recalculate(),
          ),
        ),
      ],
    );
  }

  /// Campo para dimensiones en cm (largo, ancho)
  Widget _buildCmField({required String label, required TextEditingController controller}) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '0',
              suffixText: 'cm',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _recalculate(),
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionFields() {
    switch (_selectedType) {
      case 'cylinder': // Tubo
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dimensiones del Tubo',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildWheelSelector(label: 'Ø Exterior', controller: _outerDiameterCtrl),
            const SizedBox(height: 12),
            _buildWheelSelector(label: 'Espesor Pared', controller: _thicknessCtrl),
            const SizedBox(height: 12),
            _buildCmField(label: 'Largo', controller: _lengthCmCtrl),
          ],
        );

      case 'rectangular_plate': // Lámina
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dimensiones de la Lámina',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildCmField(label: 'Largo', controller: _lengthCmCtrl),
            const SizedBox(height: 12),
            _buildCmField(label: 'Ancho', controller: _widthCtrl),
            const SizedBox(height: 12),
            _buildWheelSelector(label: 'Espesor', controller: _thicknessCtrl),
          ],
        );

      case 'shaft': // Eje
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dimensiones del Eje',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildWheelSelector(label: 'Diámetro', controller: _outerDiameterCtrl),
            const SizedBox(height: 12),
            _buildCmField(label: 'Largo', controller: _lengthCmCtrl),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _buildDimensionDescription() {
    switch (_selectedType) {
      case 'cylinder':
        return 'Ø${_outerDiameterCtrl.text}"×${_thicknessCtrl.text}"×${_lengthCmCtrl.text}cm';
      case 'rectangular_plate':
        return '${_lengthCmCtrl.text}×${_widthCtrl.text}cm×${_thicknessCtrl.text}"';
      case 'shaft':
        return 'Ø${_outerDiameterCtrl.text}"×${_lengthCmCtrl.text}cm';
      default:
        return '';
    }
  }

  void _onAdd() {
    if (_calculatedWeight <= 0) return;

    final quantity = int.tryParse(_quantityCtrl.text) ?? 1;
    final largoCm = double.tryParse(_lengthCmCtrl.text) ?? 0;
    
    final result = WeightCalculatorResult(
      weight: _calculatedWeight,
      cost: _totalCost,
      quantity: quantity,
      type: _selectedType,
      dimensionDescription: _buildDimensionDescription(),
      outerDiameter: _inchFractionToMm(_outerDiameterCtrl.text),
      thickness: _inchFractionToMm(_thicknessCtrl.text),
      length: largoCm * 10, // cm a mm
      width: _selectedType == 'rectangular_plate' ? (double.tryParse(_widthCtrl.text) ?? 0) * 10 : null,
      height: null,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título con indicador de tipo
            Row(
              children: [
                Icon(Icons.calculate, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Calcular Peso - ${widget.material.name}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Chip indicando el tipo de material
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _selectedType == 'cylinder' ? 'Tubo' 
                        : _selectedType == 'rectangular_plate' ? 'Lámina' 
                        : 'Eje',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Campos de dimensiones
            _buildDimensionFields(),
            const SizedBox(height: 16),

            // Cantidad
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    'Cantidad',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _quantityCtrl,
                    decoration: InputDecoration(
                      hintText: '1',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recalculate(),
                  ),
                ),
                const Spacer(),
                // Costo por kg
                Text(
                  'Costo: \$ ${widget.material.effectiveCostPrice.toStringAsFixed(2)}/KG',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Resultado
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _calculatedWeight > 0 
                    ? Colors.green.withOpacity(0.1) 
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _calculatedWeight > 0 
                      ? Colors.green.withOpacity(0.3) 
                      : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Peso Total', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      Text(
                        '${_calculatedWeight.toStringAsFixed(3)} kg',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _calculatedWeight > 0 ? Colors.green[700] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Costo Total', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      Text(
                        '\$ ${_totalCost.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _calculatedWeight > 0 ? Colors.green[700] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _calculatedWeight > 0 ? _onAdd : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
