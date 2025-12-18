import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../domain/entities/inventory_material.dart';

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key});

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  String _searchQuery = '';
  String _selectedCategory = 'todos';

  // Datos de ejemplo de materiales
  final List<InventoryMaterial> _materials = [
    InventoryMaterial(
      id: '1',
      code: 'TUB-A36-001',
      name: 'Tubo Acero A36',
      description: 'Tubo de acero estructural para construcción de molinos',
      shape: MaterialShape.cylinder,
      category: MaterialCategories.tubo,
      density: 7850,
      pricePerKg: 5.00,
      stockKg: 1500,
      minStockKg: 200,
      defaultThickness: 12,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    InventoryMaterial(
      id: '2',
      code: 'TUB-INOX-304',
      name: 'Tubo Acero Inoxidable 304',
      description: 'Tubo de acero inoxidable para tanques y equipos sanitarios',
      shape: MaterialShape.cylinder,
      category: MaterialCategories.tubo,
      density: 8000,
      pricePerKg: 12.00,
      stockKg: 800,
      minStockKg: 100,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    InventoryMaterial(
      id: '3',
      code: 'LAM-A36-3MM',
      name: 'Lámina Acero A36 3mm',
      description: 'Lámina de acero para tapas y bases',
      shape: MaterialShape.rectangularPlate,
      category: MaterialCategories.lamina,
      density: 7850,
      pricePerKg: 4.50,
      stockKg: 2500,
      minStockKg: 500,
      defaultThickness: 3,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    InventoryMaterial(
      id: '4',
      code: 'LAM-A36-6MM',
      name: 'Lámina Acero A36 6mm',
      description: 'Lámina de acero para tapas y estructuras',
      shape: MaterialShape.rectangularPlate,
      category: MaterialCategories.lamina,
      density: 7850,
      pricePerKg: 4.50,
      stockKg: 1800,
      minStockKg: 400,
      defaultThickness: 6,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    InventoryMaterial(
      id: '5',
      code: 'LAM-INOX-304-2MM',
      name: 'Lámina Inoxidable 304 2mm',
      description: 'Lámina de acero inoxidable para tanques',
      shape: MaterialShape.rectangularPlate,
      category: MaterialCategories.lamina,
      density: 8000,
      pricePerKg: 12.00,
      stockKg: 600,
      minStockKg: 100,
      defaultThickness: 2,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    InventoryMaterial(
      id: '6',
      code: 'EJE-SAE1045',
      name: 'Eje SAE 1045',
      description: 'Eje de acero para transmisión',
      shape: MaterialShape.solidCylinder,
      category: MaterialCategories.eje,
      density: 7850,
      pricePerKg: 6.50,
      stockKg: 450,
      minStockKg: 100,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    InventoryMaterial(
      id: '7',
      code: 'EJE-SAE4140',
      name: 'Eje SAE 4140',
      description: 'Eje de acero aleado de alta resistencia',
      shape: MaterialShape.solidCylinder,
      category: MaterialCategories.eje,
      density: 7850,
      pricePerKg: 8.00,
      stockKg: 280,
      minStockKg: 50,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    InventoryMaterial(
      id: '8',
      code: 'ROD-6310',
      name: 'Rodamiento SKF 6310',
      description: 'Rodamiento de bolas para ejes de molino',
      shape: MaterialShape.bearing,
      category: MaterialCategories.rodamiento,
      density: 7800,
      pricePerKg: 0,
      fixedWeight: 1.2,
      fixedPrice: 85.00,
      stockKg: 24, // 20 unidades × 1.2 kg
      minStockKg: 6,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    InventoryMaterial(
      id: '9',
      code: 'ROD-6312',
      name: 'Rodamiento SKF 6312',
      description: 'Rodamiento de bolas grande',
      shape: MaterialShape.bearing,
      category: MaterialCategories.rodamiento,
      density: 7800,
      pricePerKg: 0,
      fixedWeight: 1.8,
      fixedPrice: 120.00,
      stockKg: 18, // 10 unidades × 1.8 kg
      minStockKg: 5,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    InventoryMaterial(
      id: '10',
      code: 'TAP-A36',
      name: 'Disco/Tapa Acero A36',
      description: 'Material para tapas circulares',
      shape: MaterialShape.circularPlate,
      category: MaterialCategories.tapa,
      density: 7850,
      pricePerKg: 4.50,
      stockKg: 800,
      minStockKg: 150,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  List<InventoryMaterial> get _filteredMaterials {
    return _materials.where((m) {
      final matchesSearch = m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.code.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'todos' || m.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                      onPressed: () => context.go('/'),
                      tooltip: 'Volver al menú',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Materiales de Inventario',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_materials.length} materiales registrados',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    _buildQuickStat('Stock Total', '${Helpers.formatNumber(_materials.fold(0.0, (sum, m) => sum + m.stockKg))} kg', Colors.blue, Icons.inventory),
                    const SizedBox(width: 12),
                    _buildQuickStat('Stock Bajo', '${_materials.where((m) => m.isLowStock).length}', Colors.orange, Icons.warning),
                    const SizedBox(width: 24),
                    FilledButton.icon(
                      onPressed: () => _showAddMaterialDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo Material'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Filtros
                Row(
                  children: [
                    // Búsqueda
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o código...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Filtro por categoría
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'todos', child: Text('Todas')),
                          ...MaterialCategories.all.map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(MaterialCategories.getDisplayName(cat)),
                          )),
                        ],
                        onChanged: (value) => setState(() => _selectedCategory = value!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de materiales
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Encabezados de tabla
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 60, child: Text('Código', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                          SizedBox(width: 100, child: Text('Categoría', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                          SizedBox(width: 80, child: Text('Forma', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]))),
                          SizedBox(width: 100, child: Text('Precio/kg', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.right)),
                          SizedBox(width: 100, child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]), textAlign: TextAlign.right)),
                          const SizedBox(width: 60),
                        ],
                      ),
                    ),
                    // Filas de materiales
                    Expanded(
                      child: ListView.separated(
                        itemCount: _filteredMaterials.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                        itemBuilder: (context, index) {
                          final material = _filteredMaterials[index];
                          return _buildMaterialRow(material);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialRow(InventoryMaterial material) {
    final isLowStock = material.isLowStock;
    
    return InkWell(
      onTap: () => _showMaterialDetail(material),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isLowStock ? Colors.orange.withOpacity(0.05) : null,
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                material.code,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(material.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  if (material.description != null)
                    Text(
                      material.description!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCategoryColor(material.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  MaterialCategories.getDisplayName(material.category),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getCategoryColor(material.category),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                _getShapeShortName(material.shape),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                material.fixedPrice != null
                    ? 'S/ ${Helpers.formatNumber(material.fixedPrice!)} c/u'
                    : 'S/ ${Helpers.formatNumber(material.pricePerKg)}/kg',
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isLowStock)
                    const Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${Helpers.formatNumber(material.stockKg)} kg',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isLowStock ? Colors.orange : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 60,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                onSelected: (value) => _handleMaterialAction(value, material),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
                  const PopupMenuItem(value: 'stock', child: Row(children: [Icon(Icons.inventory, size: 18), SizedBox(width: 8), Text('Ajustar Stock')])),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case MaterialCategories.tubo: return Colors.blue;
      case MaterialCategories.lamina: return Colors.green;
      case MaterialCategories.tapa: return Colors.orange;
      case MaterialCategories.eje: return Colors.purple;
      case MaterialCategories.rodamiento: return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getShapeShortName(MaterialShape shape) {
    switch (shape) {
      case MaterialShape.cylinder: return 'Tubo';
      case MaterialShape.solidCylinder: return 'Eje';
      case MaterialShape.circularPlate: return 'Circular';
      case MaterialShape.rectangularPlate: return 'Rectangular';
      case MaterialShape.ring: return 'Anillo';
      case MaterialShape.bearing: return 'Rodamiento';
      case MaterialShape.custom: return 'Manual';
    }
  }

  void _handleMaterialAction(String action, InventoryMaterial material) {
    switch (action) {
      case 'edit':
        _showAddMaterialDialog(material: material);
        break;
      case 'stock':
        _showStockAdjustmentDialog(material);
        break;
      case 'delete':
        _confirmDelete(material);
        break;
    }
  }

  void _showMaterialDetail(InventoryMaterial material) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_getCategoryIcon(material.category), color: _getCategoryColor(material.category)),
            const SizedBox(width: 12),
            Text(material.name),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Código', material.code),
              _buildDetailRow('Categoría', MaterialCategories.getDisplayName(material.category)),
              _buildDetailRow('Forma', material.shapeDisplayName),
              _buildDetailRow('Densidad', '${material.density} kg/m³'),
              if (material.fixedPrice != null)
                _buildDetailRow('Precio Fijo', 'S/ ${Helpers.formatNumber(material.fixedPrice!)}')
              else
                _buildDetailRow('Precio por kg', 'S/ ${Helpers.formatNumber(material.pricePerKg)}'),
              if (material.fixedWeight != null)
                _buildDetailRow('Peso Fijo', '${material.fixedWeight} kg'),
              const Divider(),
              _buildDetailRow('Stock Actual', '${Helpers.formatNumber(material.stockKg)} kg'),
              _buildDetailRow('Stock Mínimo', '${Helpers.formatNumber(material.minStockKg)} kg'),
              if (material.isLowStock)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Stock bajo - Requiere reabastecimiento', style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showAddMaterialDialog(material: material);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case MaterialCategories.tubo: return Icons.view_in_ar;
      case MaterialCategories.lamina: return Icons.rectangle;
      case MaterialCategories.tapa: return Icons.lens;
      case MaterialCategories.eje: return Icons.horizontal_rule;
      case MaterialCategories.rodamiento: return Icons.settings;
      default: return Icons.category;
    }
  }

  void _showAddMaterialDialog({InventoryMaterial? material}) {
    showDialog(
      context: context,
      builder: (context) => _AddMaterialDialog(
        material: material,
        onSave: (newMaterial) {
          setState(() {
            if (material != null) {
              final index = _materials.indexWhere((m) => m.id == material.id);
              if (index != -1) {
                _materials[index] = newMaterial;
              }
            } else {
              _materials.add(newMaterial);
            }
          });
        },
      ),
    );
  }

  void _showStockAdjustmentDialog(InventoryMaterial material) {
    final adjustmentController = TextEditingController();
    String adjustmentType = 'add';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.inventory, color: AppTheme.primaryColor),
              SizedBox(width: 12),
              Text('Ajustar Stock'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Material: ${material.name}'),
              Text('Stock actual: ${Helpers.formatNumber(material.stockKg)} kg'),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'add', label: Text('Agregar'), icon: Icon(Icons.add)),
                  ButtonSegment(value: 'remove', label: Text('Retirar'), icon: Icon(Icons.remove)),
                ],
                selected: {adjustmentType},
                onSelectionChanged: (value) => setDialogState(() => adjustmentType = value.first),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: adjustmentController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: adjustmentType == 'add' ? 'Cantidad a agregar' : 'Cantidad a retirar',
                  suffixText: 'kg',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                // TODO: Ajustar stock
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stock ajustado'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(InventoryMaterial material) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('Confirmar eliminación'),
          ],
        ),
        content: Text('¿Está seguro de eliminar el material "${material.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _materials.removeWhere((m) => m.id == material.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Material eliminado'), backgroundColor: Colors.red),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ============================================
// DIÁLOGO DE AGREGAR/EDITAR MATERIAL
// ============================================
class _AddMaterialDialog extends StatefulWidget {
  final InventoryMaterial? material;
  final Function(InventoryMaterial) onSave;

  const _AddMaterialDialog({this.material, required this.onSave});

  @override
  State<_AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends State<_AddMaterialDialog> {
  bool get isEditing => widget.material != null;
  
  // Controladores
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _pricePerKgController = TextEditingController();
  final _pricePerUnitController = TextEditingController();
  final _stockKgController = TextEditingController();
  final _stockUnitsController = TextEditingController();
  final _minStockKgController = TextEditingController();
  final _minStockUnitsController = TextEditingController();
  
  // Para dimensiones en mm
  final _outerDiameterController = TextEditingController();
  final _wallThicknessController = TextEditingController();
  final _thicknessController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  
  // Para dimensiones en pulgadas
  int _diameterInches = 0;
  String? _diameterFraction;
  int _thicknessInches = 0;
  String? _thicknessFraction;
  int _wallThicknessInches = 0;
  String? _wallThicknessFraction;
  final int _lengthInches = 0;
  String? _lengthFraction;
  int _widthInches = 0;
  String? _widthFraction;
  
  // Selecciones
  InventoryMaterialType _selectedType = InventoryMaterialType.tubo;
  MeasurementUnit _selectedUnit = MeasurementUnit.milimetros;
  
  // Cálculos
  double _calculatedWeight = 0;
  double _totalValue = 0;
  
  // Densidad fija del acero
  static const double _steelDensity = 7850.0; // kg/m³
  
  @override
  void initState() {
    super.initState();
    if (widget.material != null) {
      final m = widget.material!;
      _codeController.text = m.code;
      _nameController.text = m.name;
      _descController.text = m.description ?? '';
      _pricePerKgController.text = m.pricePerKg.toString();
      _pricePerUnitController.text = m.fixedPrice?.toString() ?? '0';
      _stockKgController.text = m.stockKg.toString();
      _stockUnitsController.text = m.stockUnits.toString();
      _minStockKgController.text = m.minStockKg.toString();
      _minStockUnitsController.text = m.minStockUnits.toString();
      _outerDiameterController.text = m.outerDiameter?.toString() ?? '';
      _wallThicknessController.text = m.wallThickness?.toString() ?? '';
      _thicknessController.text = m.thickness?.toString() ?? '';
      _lengthController.text = m.length?.toString() ?? '';
      _widthController.text = m.width?.toString() ?? '';
      _selectedType = m.type;
      _selectedUnit = m.measurementUnit;
      _calculatedWeight = m.calculatedWeight;
      _totalValue = m.totalValue;
    }
  }
  
  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _pricePerKgController.dispose();
    _pricePerUnitController.dispose();
    _stockKgController.dispose();
    _stockUnitsController.dispose();
    _minStockKgController.dispose();
    _minStockUnitsController.dispose();
    _outerDiameterController.dispose();
    _wallThicknessController.dispose();
    _thicknessController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    super.dispose();
  }
  
  void _calculateWeight() {
    double weight = 0;
    const pi = 3.14159265359;
    
    // Obtener dimensiones en mm
    // Nota: Largo siempre está en cm (centímetros), convertir a mm (* 10)
    double outerDiamMm = _getDimensionInMm(_outerDiameterController.text, _diameterInches, _diameterFraction);
    double wallThickMm = _getDimensionInMm(_wallThicknessController.text, _wallThicknessInches, _wallThicknessFraction);
    double thickMm = _getDimensionInMm(_thicknessController.text, _thicknessInches, _thicknessFraction);
    double lengthCm = double.tryParse(_lengthController.text) ?? 0;
    double lengthMm = lengthCm * 10; // Convertir cm a mm
    double widthMm = _getDimensionInMm(_widthController.text, _widthInches, _widthFraction);
    
    // Convertir a metros
    double d1 = outerDiamMm / 1000;
    double t = wallThickMm / 1000;
    double e = thickMm / 1000;
    double l = lengthMm / 1000;
    double w = widthMm / 1000;
    
    switch (_selectedType) {
      case InventoryMaterialType.tubo:
        // Tubo: π × ((De/2)² - (Di/2)²) × L × ρ
        // Di = De - 2×espesor
        double innerD = d1 - (2 * t);
        if (innerD < 0) innerD = 0;
        double outerR = d1 / 2;
        double innerR = innerD / 2;
        double volume = pi * (outerR * outerR - innerR * innerR) * l;
        weight = volume * _steelDensity;
        break;
        
      case InventoryMaterialType.lamina:
        // Lámina: largo × ancho × espesor × ρ
        double volume = l * w * e;
        weight = volume * _steelDensity;
        break;
        
      case InventoryMaterialType.tapa:
        // Tapa circular: π × r² × espesor × ρ
        double radius = d1 / 2;
        double volume = pi * radius * radius * e;
        weight = volume * _steelDensity;
        break;
        
      case InventoryMaterialType.eje:
        // Eje: π × r² × largo × ρ
        double radius = d1 / 2;
        double volume = pi * radius * radius * l;
        weight = volume * _steelDensity;
        break;
        
      case InventoryMaterialType.porKilo:
        weight = double.tryParse(_stockKgController.text) ?? 0;
        break;
        
      case InventoryMaterialType.porUnidad:
        // No aplica peso
        weight = 0;
        break;
    }
    
    // Calcular valor total
    double value = 0;
    if (_selectedType == InventoryMaterialType.porUnidad) {
      int units = int.tryParse(_stockUnitsController.text) ?? 0;
      double pricePerUnit = double.tryParse(_pricePerUnitController.text) ?? 0;
      value = units * pricePerUnit;
    } else {
      double pricePerKg = double.tryParse(_pricePerKgController.text) ?? 0;
      value = weight * pricePerKg;
    }
    
    setState(() {
      _calculatedWeight = weight;
      _totalValue = value;
    });
  }
  
  double _getDimensionInMm(String mmText, int inches, String? fraction) {
    if (_selectedUnit == MeasurementUnit.milimetros) {
      return double.tryParse(mmText) ?? 0;
    } else {
      return InchFractions.inchesToMm(inches, fraction);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.add_box, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Editar Material' : 'Nuevo Material',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Contenido
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // PASO 1: Tipo de material
                    _buildSectionHeader('1. Tipo de Material', Icons.category),
                    const SizedBox(height: 12),
                    _buildMaterialTypeSelector(),
                    const SizedBox(height: 24),
                    
                    // PASO 2: Información básica
                    _buildSectionHeader('2. Información Básica', Icons.info_outline),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            decoration: const InputDecoration(
                              labelText: 'Código',
                              border: OutlineInputBorder(),
                              hintText: 'TUB-001',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              border: OutlineInputBorder(),
                              hintText: 'Tubo Acero A36',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    
                    // PASO 3: Dimensiones (solo si aplica)
                    if (_selectedType != InventoryMaterialType.porKilo && _selectedType != InventoryMaterialType.porUnidad) ...[
                      _buildSectionHeader('3. Dimensiones', Icons.straighten),
                      const SizedBox(height: 12),
                      _buildUnitSelector(),
                      const SizedBox(height: 16),
                      _buildDimensionFields(),
                      const SizedBox(height: 24),
                    ],
                    
                    // PASO 4: Precio
                    _buildSectionHeader(
                      _selectedType == InventoryMaterialType.porUnidad ? '3. Precio por Unidad' : '4. Precio por Kilogramo',
                      Icons.attach_money,
                    ),
                    const SizedBox(height: 12),
                    _buildPriceField(),
                    const SizedBox(height: 24),
                    
                    // PASO 5: Stock
                    _buildSectionHeader(
                      _selectedType == InventoryMaterialType.porUnidad ? '4. Stock' : '5. Stock',
                      Icons.inventory_2,
                    ),
                    const SizedBox(height: 12),
                    _buildStockFields(),
                    const SizedBox(height: 24),
                    
                    // Vista previa del cálculo
                    _buildCalculationPreview(),
                  ],
                ),
              ),
            ),
            
            // Footer con botones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saveMaterial,
                    icon: const Icon(Icons.save),
                    label: Text(isEditing ? 'Guardar Cambios' : 'Crear Material'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
  
  Widget _buildMaterialTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: InventoryMaterialType.values.map((type) {
        final isSelected = _selectedType == type;
        return InkWell(
          onTap: () {
            setState(() => _selectedType = type);
            _calculateWeight();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getMaterialTypeIcon(type),
                  color: isSelected ? Colors.white : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _getMaterialTypeName(type),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  
  IconData _getMaterialTypeIcon(InventoryMaterialType type) {
    switch (type) {
      case InventoryMaterialType.tubo: return Icons.view_in_ar;
      case InventoryMaterialType.lamina: return Icons.rectangle_outlined;
      case InventoryMaterialType.tapa: return Icons.lens_outlined;
      case InventoryMaterialType.eje: return Icons.horizontal_rule;
      case InventoryMaterialType.porKilo: return Icons.scale;
      case InventoryMaterialType.porUnidad: return Icons.numbers;
    }
  }
  
  String _getMaterialTypeName(InventoryMaterialType type) {
    switch (type) {
      case InventoryMaterialType.tubo: return 'Tubo';
      case InventoryMaterialType.lamina: return 'Lámina';
      case InventoryMaterialType.tapa: return 'Tapa Circular';
      case InventoryMaterialType.eje: return 'Eje';
      case InventoryMaterialType.porKilo: return 'Por Kilo';
      case InventoryMaterialType.porUnidad: return 'Por Unidad';
    }
  }
  
  Widget _buildUnitSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.straighten, color: Colors.blue[700]),
          const SizedBox(width: 12),
          const Text('Unidad de medida:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          SegmentedButton<MeasurementUnit>(
            segments: const [
              ButtonSegment(
                value: MeasurementUnit.milimetros,
                label: Text('Milímetros'),
                icon: Icon(Icons.linear_scale),
              ),
              ButtonSegment(
                value: MeasurementUnit.pulgadas,
                label: Text('Pulgadas'),
                icon: Icon(Icons.architecture),
              ),
            ],
            selected: {_selectedUnit},
            onSelectionChanged: (value) {
              setState(() => _selectedUnit = value.first);
              _calculateWeight();
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildDimensionFields() {
    if (_selectedUnit == MeasurementUnit.milimetros) {
      return _buildMmDimensionFields();
    } else {
      return _buildInchesDimensionFields();
    }
  }
  
  Widget _buildMmDimensionFields() {
    switch (_selectedType) {
      case InventoryMaterialType.tubo:
        return Row(
          children: [
            Expanded(child: _buildMmField(_outerDiameterController, 'Diámetro Exterior', 'mm')),
            const SizedBox(width: 12),
            Expanded(child: _buildMmField(_wallThicknessController, 'Espesor Pared', 'mm')),
            const SizedBox(width: 12),
            Expanded(child: _buildCmField(_lengthController, 'Largo')),
          ],
        );
      case InventoryMaterialType.lamina:
        return Row(
          children: [
            Expanded(child: _buildCmField(_lengthController, 'Largo')),
            const SizedBox(width: 12),
            Expanded(child: _buildMmField(_widthController, 'Ancho', 'mm')),
            const SizedBox(width: 12),
            Expanded(child: _buildMmField(_thicknessController, 'Espesor', 'mm')),
          ],
        );
      case InventoryMaterialType.tapa:
        return Row(
          children: [
            Expanded(child: _buildMmField(_outerDiameterController, 'Diámetro', 'mm')),
            const SizedBox(width: 12),
            Expanded(child: _buildMmField(_thicknessController, 'Espesor', 'mm')),
            const Expanded(child: SizedBox()),
          ],
        );
      case InventoryMaterialType.eje:
        return Row(
          children: [
            Expanded(child: _buildMmField(_outerDiameterController, 'Diámetro (Calibre)', 'mm')),
            const SizedBox(width: 12),
            Expanded(child: _buildCmField(_lengthController, 'Largo')),
            const Expanded(child: SizedBox()),
          ],
        );
      default:
        return const SizedBox();
    }
  }
  
  Widget _buildMmField(TextEditingController controller, String label, String suffix) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => _calculateWeight(),
    );
  }

  Widget _buildCmField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'cm',
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => _calculateWeight(),
    );
  }
  
  Widget _buildInchesDimensionFields() {
    switch (_selectedType) {
      case InventoryMaterialType.tubo:
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildInchesField('Diámetro Exterior', _diameterInches, _diameterFraction, (i, f) {
                  setState(() { _diameterInches = i; _diameterFraction = f; });
                  _calculateWeight();
                })),
                const SizedBox(width: 12),
                Expanded(child: _buildInchesField('Espesor Pared', _wallThicknessInches, _wallThicknessFraction, (i, f) {
                  setState(() { _wallThicknessInches = i; _wallThicknessFraction = f; });
                  _calculateWeight();
                })),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildCmField(_lengthController, 'Largo')),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        );
      case InventoryMaterialType.lamina:
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildCmField(_lengthController, 'Largo')),
                const SizedBox(width: 12),
                Expanded(child: _buildInchesField('Ancho', _widthInches, _widthFraction, (i, f) {
                  setState(() { _widthInches = i; _widthFraction = f; });
                  _calculateWeight();
                })),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildInchesField('Espesor', _thicknessInches, _thicknessFraction, (i, f) {
                  setState(() { _thicknessInches = i; _thicknessFraction = f; });
                  _calculateWeight();
                })),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        );
      case InventoryMaterialType.tapa:
        return Row(
          children: [
            Expanded(child: _buildInchesField('Diámetro', _diameterInches, _diameterFraction, (i, f) {
              setState(() { _diameterInches = i; _diameterFraction = f; });
              _calculateWeight();
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildInchesField('Espesor', _thicknessInches, _thicknessFraction, (i, f) {
              setState(() { _thicknessInches = i; _thicknessFraction = f; });
              _calculateWeight();
            })),
          ],
        );
      case InventoryMaterialType.eje:
        return Row(
          children: [
            Expanded(child: _buildInchesField('Diámetro (Calibre)', _diameterInches, _diameterFraction, (i, f) {
              setState(() { _diameterInches = i; _diameterFraction = f; });
              _calculateWeight();
            })),
            const SizedBox(width: 12),
            Expanded(child: _buildCmField(_lengthController, 'Largo')),
          ],
        );
      default:
        return const SizedBox();
    }
  }
  
  Widget _buildInchesField(String label, int inches, String? fraction, Function(int, String?) onChanged) {
    return GestureDetector(
      onTap: () => _showInchesWheelPicker(label, inches, fraction, onChanged),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(
                    _formatInchesDisplay(inches, fraction),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Text('"', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(Icons.tune, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  void _showInchesWheelPicker(String label, int inches, String? fraction, Function(int, String?) onChanged) {
    int tempInches = inches;
    String? tempFraction = fraction;
    
    final fractions = [null, '1/16', '1/8', '3/16', '1/4', '5/16', '3/8', '7/16', '1/2', '9/16', '5/8', '11/16', '3/4', '13/16', '7/8', '15/16'];
    int fractionIndex = fractions.indexOf(tempFraction);
    if (fractionIndex < 0) fractionIndex = 0;

    final inchesController = FixedExtentScrollController(initialItem: tempInches);
    final fractionController = FixedExtentScrollController(initialItem: fractionIndex);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: 350,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      onChanged(tempInches, tempFraction);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(),
              // Preview
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${_formatInchesDisplay(tempInches, tempFraction)}"',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
              ),
              // Wheel pickers
              Expanded(
                child: Row(
                  children: [
                    // Pulgadas enteras
                    Expanded(
                      child: Column(
                        children: [
                          Text('Pulgadas', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: inchesController,
                              itemExtent: 40,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                setModalState(() => tempInches = index);
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 49,
                                builder: (context, index) => Center(
                                  child: Text(
                                    '$index',
                                    style: TextStyle(
                                      fontSize: index == tempInches ? 24 : 18,
                                      fontWeight: index == tempInches ? FontWeight.bold : FontWeight.normal,
                                      color: index == tempInches ? const Color(0xFF2C3E50) : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Fracciones
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Text('Fracción', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: fractionController,
                              itemExtent: 40,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                setModalState(() => tempFraction = fractions[index]);
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: fractions.length,
                                builder: (context, index) {
                                  final f = fractions[index];
                                  final isSelected = index == fractionIndex || f == tempFraction;
                                  return Center(
                                    child: Text(
                                      f ?? '—',
                                      style: TextStyle(
                                        fontSize: isSelected ? 24 : 18,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? const Color(0xFF2C3E50) : Colors.grey,
                                      ),
                                    ),
                                  );
                                },
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
          ),
        ),
      ),
    );
  }

  String _formatInchesDisplay(int inches, String? fraction) {
    if (fraction != null && fraction != '-') {
      if (inches == 0) return fraction;
      return '$inches $fraction';
    }
    return '$inches';
  }
  
  Widget _buildPriceField() {
    if (_selectedType == InventoryMaterialType.porUnidad) {
      return TextField(
        controller: _pricePerUnitController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Precio por Unidad',
          prefixText: 'S/ ',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => _calculateWeight(),
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _pricePerKgController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio por Kilogramo',
                prefixText: 'S/ ',
                suffixText: '/kg',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _calculateWeight(),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                const SizedBox(width: 8),
                Text('Densidad: 7,850 kg/m³', style: TextStyle(color: Colors.orange[700], fontSize: 12)),
              ],
            ),
          ),
        ],
      );
    }
  }
  
  Widget _buildStockFields() {
    if (_selectedType == InventoryMaterialType.porUnidad) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _stockUnitsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock Actual',
                suffixText: 'unidades',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _calculateWeight(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _minStockUnitsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock Mínimo',
                suffixText: 'unidades',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      );
    } else if (_selectedType == InventoryMaterialType.porKilo) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _stockKgController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cantidad en Stock',
                suffixText: 'kg',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _calculateWeight(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _minStockKgController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Stock Mínimo',
                suffixText: 'kg',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      );
    } else {
      // Para tipos con dimensiones, el peso se calcula
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Peso calculado: ${Helpers.formatNumber(_calculatedWeight)} kg',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minStockKgController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Stock Mínimo',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
                    helperText: 'Alerta cuando el inventario baje de este valor',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      );
    }
  }
  
  Widget _buildCalculationPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withOpacity(0.1), AppTheme.primaryColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Vista Previa del Cálculo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(),
          if (_selectedType != InventoryMaterialType.porUnidad) ...[
            _buildPreviewRow('Peso Total:', '${Helpers.formatNumber(_calculatedWeight)} kg'),
            _buildPreviewRow('Precio/kg:', 'S/ ${Helpers.formatNumber(double.tryParse(_pricePerKgController.text) ?? 0)}'),
          ] else ...[
            _buildPreviewRow('Cantidad:', '${int.tryParse(_stockUnitsController.text) ?? 0} unidades'),
            _buildPreviewRow('Precio/unidad:', 'S/ ${Helpers.formatNumber(double.tryParse(_pricePerUnitController.text) ?? 0)}'),
          ],
          const Divider(thickness: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('VALOR TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(
                'S/ ${Helpers.formatNumber(_totalValue)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.primaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
  
  void _saveMaterial() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es requerido'), backgroundColor: Colors.red),
      );
      return;
    }
    
    // Obtener dimensiones finales en mm
    double? outerDiam = _getDimensionInMm(_outerDiameterController.text, _diameterInches, _diameterFraction);
    double? wallThick = _getDimensionInMm(_wallThicknessController.text, _wallThicknessInches, _wallThicknessFraction);
    double? thick = _getDimensionInMm(_thicknessController.text, _thicknessInches, _thicknessFraction);
    double? length = _getDimensionInMm(_lengthController.text, _lengthInches, _lengthFraction);
    double? width = _getDimensionInMm(_widthController.text, _widthInches, _widthFraction);
    
    // Determinar shape según type
    MaterialShape shape;
    String category;
    switch (_selectedType) {
      case InventoryMaterialType.tubo:
        shape = MaterialShape.cylinder;
        category = MaterialCategories.tubo;
        break;
      case InventoryMaterialType.lamina:
        shape = MaterialShape.rectangularPlate;
        category = MaterialCategories.lamina;
        break;
      case InventoryMaterialType.tapa:
        shape = MaterialShape.circularPlate;
        category = MaterialCategories.tapa;
        break;
      case InventoryMaterialType.eje:
        shape = MaterialShape.solidCylinder;
        category = MaterialCategories.eje;
        break;
      case InventoryMaterialType.porKilo:
        shape = MaterialShape.custom;
        category = MaterialCategories.otros;
        break;
      case InventoryMaterialType.porUnidad:
        shape = MaterialShape.custom;
        category = MaterialCategories.otros;
        break;
    }
    
    final newMaterial = InventoryMaterial(
      id: widget.material?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      code: _codeController.text.isNotEmpty ? _codeController.text : 'MAT-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text,
      description: _descController.text.isNotEmpty ? _descController.text : null,
      shape: shape,
      type: _selectedType,
      category: category,
      density: _steelDensity,
      pricePerKg: double.tryParse(_pricePerKgController.text) ?? 0,
      fixedPrice: _selectedType == InventoryMaterialType.porUnidad ? double.tryParse(_pricePerUnitController.text) : null,
      outerDiameter: outerDiam > 0 ? outerDiam : null,
      wallThickness: wallThick > 0 ? wallThick : null,
      thickness: thick > 0 ? thick : null,
      length: length > 0 ? length : null,
      width: width > 0 ? width : null,
      calculatedWeight: _calculatedWeight,
      totalValue: _totalValue,
      stockKg: _selectedType == InventoryMaterialType.porKilo 
          ? (double.tryParse(_stockKgController.text) ?? 0)
          : _calculatedWeight,
      minStockKg: double.tryParse(_minStockKgController.text) ?? 0,
      stockUnits: int.tryParse(_stockUnitsController.text) ?? 0,
      minStockUnits: int.tryParse(_minStockUnitsController.text) ?? 0,
      measurementUnit: _selectedUnit,
      createdAt: widget.material?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    widget.onSave(newMaterial);
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? 'Material actualizado correctamente' : 'Material creado correctamente'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
