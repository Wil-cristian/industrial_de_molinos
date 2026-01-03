import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../domain/entities/material.dart' as mat;
import '../../data/providers/providers.dart';
import 'weight_calculator_dialog.dart';

/// Dialog moderno para crear recetas con calculadora de peso integrada
/// El flujo es: Seleccionar Material → Calcular Dimensiones → Agregar a Receta
class RecipeDialog extends ConsumerStatefulWidget {
  final String? productId; // Si viene, estamos editando

  const RecipeDialog({super.key, this.productId});

  static Future<bool?> show(BuildContext context, {String? productId}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecipeDialog(productId: productId),
    );
  }

  @override
  ConsumerState<RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends ConsumerState<RecipeDialog> {
  // Controladores principales
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _laborCostController = TextEditingController(text: '0');

  // Lista de componentes
  final List<_RecipeItem> _items = [];

  // Pérdidas de material
  double _wastePercentage = 3.0;

  // Modo de agregar: 'calculado' o 'directo'
  String _addMode = 'calculado';

  // Tipo de cálculo seleccionado: lamina, tubo, eje
  String? _selectedCalculationType;

  // Material seleccionado para calcular
  mat.Material? _selectedMaterial;

  // Controladores de dimensiones (para modo calculado)
  final _largoController = TextEditingController();
  final _anchoController = TextEditingController();
  final _espesorController = TextEditingController();
  final _diametroExtController = TextEditingController();
  final _espesorParedController = TextEditingController();
  final _diametroController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');

  // Controladores para modo directo
  final _directNameController = TextEditingController();
  final _directQuantityController = TextEditingController(text: '1');
  final _directUnitPriceController = TextEditingController(text: '0');

  // Peso calculado
  double _calculatedWeight = 0.0;

  // Filtro de búsqueda
  String _searchQuery = '';

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Cargar materiales del inventario
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final notifier = ref.read(inventoryProvider.notifier);
        notifier
            .loadMaterials()
            .then((_) {
              final state = ref.read(inventoryProvider);
              debugPrint('✅ Materiales cargados: ${state.materials.length}');
              for (var m in state.materials) {
                debugPrint('   - ${m.name} [${m.category}]');
              }
            })
            .catchError((e) {
              debugPrint('❌ Error cargando materiales: $e');
            });
      } catch (e) {
        debugPrint('❌ Error en initState: $e');
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _laborCostController.dispose();
    _largoController.dispose();
    _anchoController.dispose();
    _espesorController.dispose();
    _diametroExtController.dispose();
    _espesorParedController.dispose();
    _diametroController.dispose();
    _cantidadController.dispose();
    _directNameController.dispose();
    _directQuantityController.dispose();
    _directUnitPriceController.dispose();
    super.dispose();
  }

  // Getters para totales
  // ignore: unused_element - Reserved for weight display
  double get _totalWeight =>
      _items.fold(0.0, (sum, item) => sum + item.totalWeight);
  double get _totalMaterialCost =>
      _items.fold(0.0, (sum, item) => sum + item.totalCost);
  double get _totalSalePrice =>
      _items.fold(0.0, (sum, item) => sum + (item.totalWeight * item.salePricePerKg));
  double get _laborCost => double.tryParse(_laborCostController.text) ?? 0;
  // El total ya incluye las pérdidas porque se añaden a cada item calculado
  double get _grandTotal => _totalMaterialCost + _laborCost;

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header compacto
            _buildHeader(),

            // Contenido principal
            Expanded(
              child: Row(
                children: [
                  // Panel izquierdo: Agregar componentes
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(
                          right: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Selector compacto de tipo + botón directo
                          _buildCompactTypeSelector(inventoryState),
                          // Calculadora o agregar directo
                          Expanded(child: _buildInputArea(inventoryState)),
                        ],
                      ),
                    ),
                  ),

                  // Panel derecho: Receta (componentes + costos)
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        // Info de receta compacto
                        _buildCompactRecipeInfo(),
                        // Lista de componentes (prioridad)
                        Expanded(flex: 3, child: _buildComponentsList()),
                        // Resumen de costos compacto
                        _buildCompactCostSummary(),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer con acciones
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Nueva Receta',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }

  /// Selector compacto: Modo (Calculado/Directo) + Tipo de material
  Widget _buildCompactTypeSelector(InventoryState inventoryState) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tabs: Calculado vs Directo
          Row(
            children: [
              Expanded(
                child: _buildModeTab(
                  'calculado',
                  'Con Cálculo',
                  Icons.calculate,
                  'Láminas, Tubos, Ejes',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeTab(
                  'directo',
                  'Directo',
                  Icons.add_shopping_cart,
                  'Tornillos, Rodamientos...',
                ),
              ),
            ],
          ),
          // Si es modo calculado, mostrar tipos
          if (_addMode == 'calculado') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _buildCompactTypeChip(
                  'lamina',
                  'Lámina',
                  Icons.crop_square,
                  Colors.blue,
                ),
                const SizedBox(width: 6),
                _buildCompactTypeChip(
                  'tubo',
                  'Tubo',
                  Icons.circle_outlined,
                  Colors.green,
                ),
                const SizedBox(width: 6),
                _buildCompactTypeChip(
                  'eje',
                  'Eje',
                  Icons.horizontal_rule,
                  Colors.orange,
                ),
              ],
            ),
            // Dropdown de materiales en fila separada
            if (_selectedCalculationType != null) ...[
              const SizedBox(height: 8),
              _buildMaterialDropdown(inventoryState),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildModeTab(
    String mode,
    String label,
    IconData icon,
    String subtitle,
  ) {
    final isSelected = _addMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _addMode = mode;
          _selectedCalculationType = null;
          _selectedMaterial = null;
          _calculatedWeight = 0;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isSelected ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      color: isSelected ? Colors.white70 : Colors.grey[500],
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

  Widget _buildCompactTypeChip(
    String type,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedCalculationType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCalculationType = type;
          _selectedMaterial = null;
          _calculatedWeight = 0;
          _clearDimensionFields();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialDropdown(InventoryState inventoryState) {
    final materials = inventoryState.materials.where((m) {
      final cat = m.category.toLowerCase();
      if (_selectedCalculationType == 'lamina') {
        return cat.contains('lamina') || cat.contains('lámina');
      } else if (_selectedCalculationType == 'tubo') {
        return cat.contains('tubo');
      } else if (_selectedCalculationType == 'eje') {
        return cat.contains('eje');
      }
      return false;
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<mat.Material>(
          value: _selectedMaterial,
          hint: Text(
            materials.isEmpty ? 'Sin materiales' : 'Seleccionar material...',
            style: const TextStyle(fontSize: 12),
          ),
          isExpanded: true,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          items: materials.map((m) {
            return DropdownMenuItem(
              value: m,
              child: Text(
                '${m.name} - ${Helpers.formatCurrency(m.pricePerKg)}/kg',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (m) {
            if (m != null) _selectMaterial(m);
          },
        ),
      ),
    );
  }

  /// Área de entrada: Calculadora o Agregar Directo
  Widget _buildInputArea(InventoryState inventoryState) {
    if (_addMode == 'directo') {
      return _buildDirectInput(inventoryState);
    } else {
      if (_selectedMaterial != null) {
        return _buildCalculator();
      } else {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                _selectedCalculationType == null
                    ? 'Selecciona un tipo de material'
                    : 'Selecciona un material del dropdown',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        );
      }
    }
  }

  // Material seleccionado en modo directo
  mat.Material? _selectedDirectMaterial;

  /// Vista de inventario para agregar materiales directamente
  Widget _buildDirectInput(InventoryState inventoryState) {
    final materials = inventoryState.materials;
    final cantidad = double.tryParse(_directQuantityController.text) ?? 0;
    final totalDirecto = _selectedDirectMaterial != null
        ? cantidad * _selectedDirectMaterial!.effectiveCostPrice
        : 0.0;

    return Column(
      children: [
        // Header con búsqueda
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                'Inventario (${materials.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              // Búsqueda
              SizedBox(
                width: 150,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  style: const TextStyle(fontSize: 11),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ],
          ),
        ),

        // Lista del inventario
        Expanded(
          child: inventoryState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : materials.isEmpty
              ? Center(
                  child: Text(
                    'No hay materiales en inventario',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  itemCount: materials.length,
                  itemBuilder: (context, index) {
                    final m = materials[index];
                    // Filtro de búsqueda
                    if (_searchQuery.isNotEmpty &&
                        !m.name.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        )) {
                      return const SizedBox.shrink();
                    }
                    final isSelected = _selectedDirectMaterial?.id == m.id;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDirectMaterial = m;
                          _directQuantityController.text = '1';
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey[200]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Icono categoría
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: _getCategoryColor(m.category),
                              child: Icon(
                                _getCategoryIcon(m.category),
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 12,
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : Colors.grey[800],
                                    ),
                                  ),
                                  Text(
                                    '${m.category} • Stock: ${m.stock.toStringAsFixed(1)} ${m.unit}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Precio
                            Text(
                              Helpers.formatCurrency(m.pricePerKg),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.grey[700],
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_circle,
                                color: AppTheme.primaryColor,
                                size: 18,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Panel inferior: cantidad y agregar
        if (_selectedDirectMaterial != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                // Material seleccionado
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDirectMaterial!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${Helpers.formatCurrency(_selectedDirectMaterial!.pricePerKg)}/${_selectedDirectMaterial!.unit}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Cantidad
                Row(
                  children: [
                    const Text('Cantidad:', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        final current =
                            double.tryParse(_directQuantityController.text) ??
                            1;
                        if (current > 1) {
                          setState(
                            () => _directQuantityController.text = (current - 1)
                                .toString(),
                          );
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _directQuantityController,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () {
                        final current =
                            double.tryParse(_directQuantityController.text) ??
                            0;
                        setState(
                          () => _directQuantityController.text = (current + 1)
                              .toString(),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Text(
                      ' ${_selectedDirectMaterial!.unit}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    // Total
                    Text(
                      'Total: ${Helpers.formatCurrency(totalDirecto)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Botón agregar
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _addDirectItemFromInventory,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar a la Receta'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _addDirectItemFromInventory() {
    if (_selectedDirectMaterial == null) return;

    final cantidad = double.tryParse(_directQuantityController.text) ?? 1;
    final material = _selectedDirectMaterial!;

    setState(() {
      _items.add(
        _RecipeItem(
          materialId: material.id,
          name: material.name,
          category: material.category,
          description:
              '${cantidad.toStringAsFixed(cantidad == cantidad.roundToDouble() ? 0 : 1)} ${material.unit}',
          pricePerKg: material.effectiveCostPrice,
          salePricePerKg: material.effectivePrice, // Precio de venta real
          totalWeight: cantidad,
          totalCost: cantidad * material.effectiveCostPrice,
        ),
      );
      // Reset
      _selectedDirectMaterial = null;
      _directQuantityController.text = '1';
    });
  }

  void _clearDimensionFields() {
    _largoController.clear();
    _anchoController.clear();
    _espesorController.clear();
    _diametroExtController.clear();
    _espesorParedController.clear();
    _diametroController.clear();
    _cantidadController.text = '1';
  }

  Widget _buildCalculator() {
    if (_selectedMaterial == null) return const SizedBox.shrink();

    final category =
        _selectedCalculationType ?? _selectedMaterial!.category.toLowerCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paso 3: Título
          Row(
            children: [
              const Text(
                '3. Ingresa las dimensiones',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedMaterial!.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${Helpers.formatCurrency(_selectedMaterial!.pricePerKg)}/kg',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),

          const SizedBox(height: 12),

          // Campos según tipo de material
          if (category == 'lamina' || category == 'lámina')
            _buildLaminaFields()
          else if (category == 'tubo')
            _buildTuboFields()
          else if (category == 'eje')
            _buildEjeFields()
          else
            _buildGenericFields(),

          const SizedBox(height: 12),

          // Cantidad
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cantidadController,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de piezas',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _calculateWeight(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Resultado del cálculo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Peso calculado:',
                          style: TextStyle(fontSize: 11),
                        ),
                        Text(
                          '${_calculatedWeight.toStringAsFixed(3)} kg',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Costo material:',
                          style: TextStyle(fontSize: 11),
                        ),
                        Text(
                          Helpers.formatCurrency(
                            _calculatedWeight * _selectedMaterial!.effectiveCostPrice,
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 12),
                // Pérdidas por corte - campo simple
                Row(
                  children: [
                    Icon(
                      Icons.content_cut,
                      size: 14,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pérdida:',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 6),
                    // Campo de porcentaje
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: TextEditingController(
                          text: _wastePercentage.toStringAsFixed(0),
                        ),
                        decoration: InputDecoration(
                          suffixText: '%',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          filled: true,
                          fillColor: Colors.orange.withOpacity(0.1),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final val = double.tryParse(v) ?? 3;
                          setState(() => _wastePercentage = val.clamp(0, 50));
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Resultado con pérdida
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Con pérdida:',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange[800],
                              ),
                            ),
                            Text(
                              '${(_calculatedWeight * (1 + _wastePercentage / 100)).toStringAsFixed(2)} kg → ${Helpers.formatCurrency(_calculatedWeight * _selectedMaterial!.effectiveCostPrice * (1 + _wastePercentage / 100))}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                      ),
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
            child: FilledButton.icon(
              onPressed: _calculatedWeight > 0 ? _addItemToRecipe : null,
              icon: const Icon(Icons.add),
              label: const Text('Agregar a la Receta'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaminaFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dimensiones de la Lámina',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _largoController,
                decoration: const InputDecoration(
                  labelText: 'Largo (cm)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateWeight(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _anchoController,
                decoration: const InputDecoration(
                  labelText: 'Ancho (cm)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateWeight(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Selector de espesor tipo iOS
        _buildThicknessSelector(_espesorController, 'Espesor'),
      ],
    );
  }

  /// Selector de pulgadas estilo rueda/barril (wheel picker) - compacto
  Widget _buildThicknessSelector(
    TextEditingController controller,
    String label,
  ) {
    final commonSizes = [
      '1/16',
      '1/8',
      '3/16',
      '1/4',
      '5/16',
      '3/8',
      '1/2',
      '5/8',
      '3/4',
      '7/8',
      '1',
      '1 1/4',
      '1 1/2',
      '2',
      '2 1/2',
      '3',
    ];

    int initialIndex = commonSizes.indexOf(controller.text);
    if (initialIndex < 0) initialIndex = 6;

    return Row(
      children: [
        // Label compacto
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ),
        // Wheel picker cuadrado
        SizedBox(
          width: 70,
          height: 55,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                ListWheelScrollView.useDelegate(
                  itemExtent: 22,
                  diameterRatio: 1.2,
                  perspective: 0.002,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(
                    initialItem: initialIndex,
                  ),
                  onSelectedItemChanged: (index) {
                    setState(() => controller.text = commonSizes[index]);
                    _calculateWeight();
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: commonSizes.length,
                    builder: (context, index) {
                      final size = commonSizes[index];
                      final isSelected = controller.text == size;
                      return Center(
                        child: Text(
                          '$size"',
                          style: TextStyle(
                            fontSize: isSelected ? 13 : 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.grey[500],
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
        const SizedBox(width: 6),
        // Input manual
        SizedBox(
          width: 45,
          height: 55,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '?',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            onChanged: (_) => _calculateWeight(),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildTuboFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dimensiones del Tubo',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        // Diámetro exterior
        _buildThicknessSelector(_diametroExtController, 'Diámetro Exterior'),
        const SizedBox(height: 12),
        // Espesor de pared
        _buildThicknessSelector(_espesorParedController, 'Espesor de Pared'),
        const SizedBox(height: 12),
        TextField(
          controller: _largoController,
          decoration: const InputDecoration(
            labelText: 'Largo (cm)',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => _calculateWeight(),
        ),
      ],
    );
  }

  Widget _buildEjeFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dimensiones del Eje',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        // Diámetro del eje
        _buildThicknessSelector(_diametroController, 'Diámetro'),
        const SizedBox(height: 12),
        TextField(
          controller: _largoController,
          decoration: const InputDecoration(
            labelText: 'Largo (cm)',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => _calculateWeight(),
        ),
      ],
    );
  }

  Widget _buildGenericFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Este material no tiene calculadora automática',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _largoController,
          decoration: const InputDecoration(
            labelText: 'Peso directo (kg)',
            isDense: true,
            border: OutlineInputBorder(),
            helperText: 'Ingresa el peso manualmente',
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            setState(() {
              final cantidad = int.tryParse(_cantidadController.text) ?? 1;
              _calculatedWeight = (double.tryParse(v) ?? 0) * cantidad;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCompactRecipeInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Receta *',
                hintText: 'Ej: Molino 44"',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentsList() {
    if (_items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 40,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sin componentes',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecciona materiales del panel izquierdo',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _getCategoryColor(item.category),
                child: Icon(
                  _getCategoryIcon(item.category),
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      item.description,
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.totalWeight.toStringAsFixed(2)} kg',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    Helpers.formatCurrency(item.totalCost),
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _items.removeAt(index)),
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.red[400],
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactCostSummary() {
    // Calcular margen real
    final margin = _grandTotal > 0 ? ((_totalSalePrice - _grandTotal) / _grandTotal * 100) : 0.0;
    final marginColor = margin > 30 ? Colors.green : margin > 15 ? Colors.orange : Colors.red;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          // Mano de obra
          Row(
            children: [
              Icon(Icons.engineering, size: 16, color: Colors.orange[700]),
              const SizedBox(width: 6),
              const Text('Mano de Obra:', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _laborCostController,
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 11),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const Spacer(),
              // Total materiales
              Text(
                'Materiales: ${Helpers.formatCurrency(_totalMaterialCost)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
          const Divider(height: 12),
          // Resumen con Costo y Venta
          Row(
            children: [
              // Costo de fabricación
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_cart, size: 14, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Costo:',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    Text(
                      Helpers.formatCurrency(_grandTotal),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
              // Precio de venta real
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sell, size: 14, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Venta:',
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    Text(
                      Helpers.formatCurrency(_totalSalePrice),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
              // Indicador de margen
              if (_grandTotal > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: marginColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: marginColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        margin > 30 ? Icons.trending_up : margin > 15 ? Icons.trending_flat : Icons.trending_down,
                        size: 16,
                        color: marginColor,
                      ),
                      Text(
                        '${margin.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: marginColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // Info del peso
          if (_totalWeight > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Peso total: ${_totalWeight.toStringAsFixed(1)} KG',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceSuggestion(String label, double price, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
        Text(
          Helpers.formatCurrency(price),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed:
                _items.isEmpty || _titleController.text.isEmpty || _isLoading
                ? null
                : _saveRecipe,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_isLoading ? 'Guardando...' : 'Crear Receta'),
          ),
        ],
      ),
    );
  }

  // ===================== FUNCIONES AUXILIARES =====================

  void _selectMaterial(mat.Material material) async {
    // Abrir el diálogo de calculador de peso moderno
    final result = await WeightCalculatorDialog.show(
      context,
      material: material,
      category: _selectedCalculationType ?? 'tubo',
    );

    if (result != null && mounted) {
      // Agregar el componente con los datos calculados
      setState(() {
        _items.add(_RecipeItem(
          materialId: material.id,
          name: material.name,
          category: _selectedCalculationType ?? 'tubo',
          description: result.dimensionDescription,
          pricePerKg: material.effectiveCostPrice,
          salePricePerKg: material.effectivePrice, // Precio de venta real
          totalWeight: result.weight,
          totalCost: result.cost,
        ));
        
        // Limpiar selección
        _selectedMaterial = null;
        _selectedCalculationType = null;
      });
    }
  }

  void _selectMaterialOld(mat.Material material) {
    setState(() {
      _selectedMaterial = material;
      // Limpiar campos
      _largoController.clear();
      _anchoController.clear();
      _espesorController.clear();
      _diametroExtController.clear();
      _espesorParedController.clear();
      _diametroController.clear();
      _cantidadController.text = '1';
      _calculatedWeight = 0;
    });
  }

  void _calculateWeight() {
    if (_selectedMaterial == null) return;

    // ignore: unused_local_variable - Reserved for extended calculations
    final category =
        _selectedCalculationType ?? _selectedMaterial!.category.toLowerCase();
    final cantidad = int.tryParse(_cantidadController.text) ?? 1;
    double pesoUnitario = 0;

    const double steelDensity = 7.85; // g/cm³

    // Normalizar categoría para el cálculo
    final normalizedCategory = _selectedCalculationType ?? 'otro';

    if (normalizedCategory == 'lamina') {
      // Lámina: Largo × Ancho × Espesor × Densidad
      final largo = double.tryParse(_largoController.text) ?? 0; // cm
      final ancho = double.tryParse(_anchoController.text) ?? 0; // cm
      final espesorPulg = _parseFraction(_espesorController.text); // pulgadas
      final espesorCm = espesorPulg * 2.54; // convertir a cm

      if (largo > 0 && ancho > 0 && espesorCm > 0) {
        final volumenCm3 = largo * ancho * espesorCm;
        pesoUnitario = (volumenCm3 * steelDensity) / 1000; // kg
      }
    } else if (normalizedCategory == 'tubo') {
      // Tubo: π × (R_ext² - R_int²) × Largo × Densidad
      final dExtPulg = _parseFraction(_diametroExtController.text); // pulgadas
      final espesorParedPulg = _parseFraction(_espesorParedController.text);
      final largo = double.tryParse(_largoController.text) ?? 0; // cm

      final dExtCm = dExtPulg * 2.54;
      final espesorParedCm = espesorParedPulg * 2.54;
      final dIntCm = dExtCm - (2 * espesorParedCm);

      if (dExtCm > 0 && dIntCm > 0 && largo > 0) {
        final rExt = dExtCm / 2;
        final rInt = dIntCm / 2;
        final volumenCm3 = math.pi * (rExt * rExt - rInt * rInt) * largo;
        pesoUnitario = (volumenCm3 * steelDensity) / 1000; // kg
      }
    } else if (normalizedCategory == 'eje') {
      // Eje sólido: π × R² × Largo × Densidad
      final dPulg = _parseFraction(_diametroController.text); // pulgadas
      final largo = double.tryParse(_largoController.text) ?? 0; // cm
      final dCm = dPulg * 2.54;

      if (dCm > 0 && largo > 0) {
        final r = dCm / 2;
        final volumenCm3 = math.pi * r * r * largo;
        pesoUnitario = (volumenCm3 * steelDensity) / 1000; // kg
      }
    }

    setState(() {
      _calculatedWeight = pesoUnitario * cantidad;
    });
  }

  double _parseFraction(String value) {
    if (value.isEmpty) return 0;

    // Limpiar espacios
    value = value.trim();

    // Si ya es decimal
    if (double.tryParse(value) != null) {
      return double.parse(value);
    }

    // Manejar fracciones mixtas: "1 1/2" → 1.5
    if (value.contains(' ')) {
      final parts = value.split(' ');
      if (parts.length == 2) {
        final whole = double.tryParse(parts[0]) ?? 0;
        final fraction = _parseFraction(parts[1]);
        return whole + fraction;
      }
    }

    // Manejar fracciones simples: "1/2" → 0.5
    if (value.contains('/')) {
      final parts = value.split('/');
      if (parts.length == 2) {
        final num = double.tryParse(parts[0]) ?? 0;
        final den = double.tryParse(parts[1]) ?? 1;
        return den != 0 ? num / den : 0;
      }
    }

    return 0;
  }

  void _addItemToRecipe() {
    if (_selectedMaterial == null || _calculatedWeight <= 0) return;

    final category = _selectedMaterial!.category.toLowerCase();
    String description = '';

    // Crear descripción según el tipo
    if (category == 'lamina' || category == 'lámina') {
      description =
          '${_largoController.text}×${_anchoController.text}cm, ${_espesorController.text}"';
    } else if (category == 'tubo') {
      description =
          'Ø${_diametroExtController.text}" × ${_espesorParedController.text}" × ${_largoController.text}cm';
    } else if (category == 'eje') {
      description =
          'Ø${_diametroController.text}" × ${_largoController.text}cm';
    }

    final cantidad = int.tryParse(_cantidadController.text) ?? 1;
    if (cantidad > 1) {
      description = '$cantidad piezas - $description';
    }

    // Incluir pérdidas por corte
    if (_wastePercentage > 0) {
      description += ' (+${_wastePercentage.toStringAsFixed(0)}% pérdida)';
    }

    // Peso total incluyendo pérdidas
    final pesoConPerdidas = _calculatedWeight * (1 + _wastePercentage / 100);
    final costoConPerdidas = pesoConPerdidas * _selectedMaterial!.effectiveCostPrice;

    setState(() {
      _items.add(
        _RecipeItem(
          materialId: _selectedMaterial!.id,
          name: _selectedMaterial!.name,
          category: _selectedMaterial!.category,
          description: description,
          pricePerKg: _selectedMaterial!.effectiveCostPrice,
          salePricePerKg: _selectedMaterial!.effectivePrice, // Precio de venta real
          totalWeight: pesoConPerdidas,
          totalCost: costoConPerdidas,
        ),
      );

      // Limpiar para siguiente
      _selectedMaterial = null;
      _calculatedWeight = 0;
      _wastePercentage = 3; // Reset a valor por defecto
    });
  }

  Future<void> _saveRecipe() async {
    if (_titleController.text.isEmpty || _items.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Convertir items a RecipeComponent
      final components = _items
          .map(
            (item) => RecipeComponent(
              materialId: item.materialId,
              name: item.name,
              description: item.description,
              category: item.category,
              weight: item.totalWeight,
              pricePerKg: item.pricePerKg,
              salePricePerKg: item.salePricePerKg,
            ),
          )
          .toList();

      final success = await ref
          .read(recipesProvider.notifier)
          .saveRecipe(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            components: components,
          );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Receta creada exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        final errorMsg = ref.read(recipesProvider).error ?? "Error desconocido";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar: $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Excepción: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ignore: unused_element - Reserved for category display
  String _capitalizeCategory(String category) {
    if (category.isEmpty) return category;
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'lamina':
      case 'lámina':
        return Icons.crop_square;
      case 'tubo':
        return Icons.circle_outlined;
      case 'eje':
        return Icons.horizontal_rule;
      case 'rodamiento':
        return Icons.settings;
      case 'tornilleria':
        return Icons.hardware;
      default:
        return Icons.inventory_2;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'lamina':
      case 'lámina':
        return Colors.blue;
      case 'tubo':
        return Colors.green;
      case 'eje':
        return Colors.orange;
      case 'rodamiento':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

/// Modelo interno para items de la receta
class _RecipeItem {
  final String materialId;
  final String name;
  final String category;
  final String description;
  final double pricePerKg; // Precio de costo
  final double salePricePerKg; // Precio de venta
  final double totalWeight;
  final double totalCost;

  _RecipeItem({
    required this.materialId,
    required this.name,
    required this.category,
    required this.description,
    required this.pricePerKg,
    required this.salePricePerKg,
    required this.totalWeight,
    required this.totalCost,
  });
}
