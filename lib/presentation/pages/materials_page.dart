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
                        value: _selectedCategory,
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
    final isEditing = material != null;
    final codeController = TextEditingController(text: material?.code ?? '');
    final nameController = TextEditingController(text: material?.name ?? '');
    final descController = TextEditingController(text: material?.description ?? '');
    final priceController = TextEditingController(text: material?.pricePerKg.toString() ?? '0');
    final densityController = TextEditingController(text: material?.density.toString() ?? '7850');
    final stockController = TextEditingController(text: material?.stockKg.toString() ?? '0');
    final minStockController = TextEditingController(text: material?.minStockKg.toString() ?? '0');
    
    String selectedCategory = material?.category ?? MaterialCategories.tubo;
    MaterialShape selectedShape = material?.shape ?? MaterialShape.cylinder;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(isEditing ? Icons.edit : Icons.add_box, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              Text(isEditing ? 'Editar Material' : 'Nuevo Material'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeController,
                          decoration: const InputDecoration(
                            labelText: 'Código',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(),
                          ),
                          items: MaterialCategories.all.map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(MaterialCategories.getDisplayName(cat)),
                          )).toList(),
                          onChanged: (value) => setDialogState(() => selectedCategory = value!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<MaterialShape>(
                          value: selectedShape,
                          decoration: const InputDecoration(
                            labelText: 'Forma',
                            border: OutlineInputBorder(),
                          ),
                          items: MaterialShape.values.map((shape) => DropdownMenuItem(
                            value: shape,
                            child: Text(_getShapeShortName(shape)),
                          )).toList(),
                          onChanged: (value) => setDialogState(() => selectedShape = value!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Precio por kg',
                            prefixText: 'S/ ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: densityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Densidad',
                            suffixText: 'kg/m³',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock Actual',
                            suffixText: 'kg',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: minStockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stock Mínimo',
                            suffixText: 'kg',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                // TODO: Guardar material
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEditing ? 'Material actualizado' : 'Material creado'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
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
              // TODO: Eliminar material
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
