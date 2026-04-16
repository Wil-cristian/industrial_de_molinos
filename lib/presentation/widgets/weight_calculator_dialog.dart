import 'package:flutter/material.dart';
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

  /// Muestra el bottom sheet y retorna el resultado del cálculo
  static Future<WeightCalculatorResult?> show(
    BuildContext context, {
    required mat.Material material,
    required String category,
  }) {
    return showModalBottomSheet<WeightCalculatorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          WeightCalculatorDialog(material: material, initialCategory: category),
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
        final anchoCm = double.tryParse(_widthCtrl.text) ?? 0;
        final thickness = _inchFractionToMm(_thicknessCtrl.text);
        if (largoCm > 0 && anchoCm > 0 && thickness > 0) {
          weight = WeightCalculator.calculateRectangularPlateWeight(
            width: largoCm * 10, // cm a mm (largo)
            height: anchoCm * 10, // cm a mm (ancho)
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

  /// Fracciones de pulgada comunes
  static const List<String> _commonFractions = [
    '1/8', '3/16', '1/4', '5/16', '3/8', '1/2', '5/8', '3/4', '7/8',
    '1', '1 1/4', '1 1/2', '2', '2 1/2', '3', '4', '5', '6',
  ];

  /// Campo de texto para dimensiones en pulgadas - diseño mobile-first
  Widget _buildInchField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label con icono
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              // Valor actual como badge
              if (controller.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${controller.text}"',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Campo de texto
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Ej: 1 1/2',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
              suffixText: '"',
              suffixStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
              filled: true,
              fillColor: colorScheme.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            keyboardType: TextInputType.text,
            onChanged: (_) => _recalculate(),
          ),
          const SizedBox(height: 10),
          // Chips de fracciones - scrollable horizontalmente
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _commonFractions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final f = _commonFractions[index];
                final isSelected = controller.text.trim() == f;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      controller.text = f;
                      _recalculate();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                        border: isSelected
                            ? null
                            : Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                      ),
                      child: Center(
                        child: Text(
                          '$f"',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Campo para dimensiones en cm (largo, ancho) - mobile-first
  Widget _buildCmField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.tertiary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.4)),
              suffixText: 'cm',
              suffixStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.tertiary,
              ),
              filled: true,
              fillColor: colorScheme.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: colorScheme.tertiary, width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _recalculate(),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionFields() {
    switch (_selectedType) {
      case 'cylinder': // Tubo
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInchField(
              label: 'Ø Exterior',
              controller: _outerDiameterCtrl,
              icon: Icons.circle_outlined,
            ),
            const SizedBox(height: 10),
            _buildInchField(
              label: 'Espesor Pared',
              controller: _thicknessCtrl,
              icon: Icons.layers_outlined,
            ),
            const SizedBox(height: 10),
            _buildCmField(
              label: 'Largo',
              controller: _lengthCmCtrl,
              icon: Icons.straighten,
            ),
          ],
        );

      case 'rectangular_plate': // Lámina
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCmField(
              label: 'Largo',
              controller: _lengthCmCtrl,
              icon: Icons.straighten,
            ),
            const SizedBox(height: 10),
            _buildCmField(
              label: 'Ancho',
              controller: _widthCtrl,
              icon: Icons.swap_horiz,
            ),
            const SizedBox(height: 10),
            _buildInchField(
              label: 'Espesor',
              controller: _thicknessCtrl,
              icon: Icons.layers_outlined,
            ),
          ],
        );

      case 'shaft': // Eje
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInchField(
              label: 'Diámetro',
              controller: _outerDiameterCtrl,
              icon: Icons.circle_outlined,
            ),
            const SizedBox(height: 10),
            _buildCmField(
              label: 'Largo',
              controller: _lengthCmCtrl,
              icon: Icons.straighten,
            ),
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
      width: _selectedType == 'rectangular_plate'
          ? (double.tryParse(_widthCtrl.text) ?? 0) * 10
          : null,
      height: null,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final typeLabel = _selectedType == 'cylinder'
        ? 'Tubo'
        : _selectedType == 'rectangular_plate'
        ? 'Lámina'
        : 'Eje';
    final typeIcon = _selectedType == 'cylinder'
        ? Icons.panorama_horizontal_select
        : _selectedType == 'rectangular_plate'
        ? Icons.rectangle_outlined
        : Icons.remove;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Tipo badge con icono
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calcular Peso',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        widget.material.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(color: colorScheme.outlineVariant.withOpacity(0.5), height: 1),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dimension fields
                  _buildDimensionFields(),
                  const SizedBox(height: 12),

                  // Cantidad y costo en row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        // Cantidad
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.tag, size: 16, color: colorScheme.secondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cantidad',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _quantityCtrl,
                                  decoration: InputDecoration(
                                    hintText: '1',
                                    filled: true,
                                    fillColor: colorScheme.surface,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: colorScheme.secondary, width: 1.5),
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _recalculate(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Costo/kg
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Precio/KG',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '\$ ${widget.material.effectiveCostPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resultado - tarjeta destacada
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: _calculatedWeight > 0
                          ? LinearGradient(
                              colors: [
                                const Color(0xFF2E7D32).withOpacity(0.08),
                                const Color(0xFF1B5E20).withOpacity(0.04),
                              ],
                            )
                          : null,
                      color: _calculatedWeight > 0
                          ? null
                          : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _calculatedWeight > 0
                            ? const Color(0xFF4CAF50).withOpacity(0.4)
                            : colorScheme.outlineVariant.withOpacity(0.3),
                        width: _calculatedWeight > 0 ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Peso
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.scale,
                                    size: 14,
                                    color: _calculatedWeight > 0
                                        ? const Color(0xFF388E3C)
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Peso Total',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_calculatedWeight.toStringAsFixed(3)} kg',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _calculatedWeight > 0
                                      ? const Color(0xFF2E7D32)
                                      : colorScheme.onSurfaceVariant.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Separador
                        Container(
                          width: 1,
                          height: 40,
                          color: _calculatedWeight > 0
                              ? const Color(0xFF4CAF50).withOpacity(0.3)
                              : colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                        const SizedBox(width: 16),
                        // Costo
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    size: 14,
                                    color: _calculatedWeight > 0
                                        ? const Color(0xFF388E3C)
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Costo Total',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$ ${_totalCost.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _calculatedWeight > 0
                                      ? const Color(0xFF2E7D32)
                                      : colorScheme.onSurfaceVariant.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botones de acción - full width en móvil
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: colorScheme.outlineVariant),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _calculatedWeight > 0 ? _onAdd : null,
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          label: const Text(
                            'Agregar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
