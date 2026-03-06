import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/providers.dart';
import '../../data/providers/suppliers_provider.dart';
import '../../data/providers/purchase_orders_provider.dart';
import '../../domain/entities/material.dart' as mat;
import '../../domain/entities/material_category.dart';

class MaterialsPage extends ConsumerStatefulWidget {
  final bool openNewDialog;

  const MaterialsPage({super.key, this.openNewDialog = false});

  @override
  ConsumerState<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends ConsumerState<MaterialsPage> {
  String _searchQuery = '';
  String _selectedCategory = 'todos';
  bool _dialogOpened = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(inventoryProvider.notifier).loadMaterials();
      ref.read(materialCategoryProvider.notifier).loadCategories();
      // Abrir diálogo si viene con el parámetro
      if (widget.openNewDialog && !_dialogOpened) {
        _dialogOpened = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _showAddMaterialDialog();
        });
      }
    });
  }

  List<mat.Material> get _filteredMaterials {
    final state = ref.watch(inventoryProvider);
    return state.materials.where((m) {
      final matchesSearch =
          m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.code.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'todos' ||
          m.category.toLowerCase() == _selectedCategory.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header compacto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      onPressed: () => context.go('/'),
                      tooltip: 'Volver al menú',
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      'Inventario de Materiales',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${state.materials.length} materiales',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const Spacer(),
                    _buildQuickStat(
                      'Valor Total',
                      '\$${Helpers.formatNumber(state.totalInventoryValue)}',
                      Colors.green,
                      Icons.attach_money,
                    ),
                    const SizedBox(width: 10),
                    _buildQuickStat(
                      'Stock Bajo',
                      '${state.lowStockMaterials.length}',
                      Colors.orange,
                      Icons.warning,
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _showAddMaterialDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nuevo Material'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Filtros
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o código...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'todos',
                            child: Text('Todas'),
                          ),
                          ...state.categories.map(
                            (cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(
                                _getCategoryName(cat),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedCategory = value!),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _showManageCategoriesDialog,
                      icon: const Icon(Icons.settings, size: 20),
                      tooltip: 'Administrar categorías',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de materiales
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text('Error: ${state.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref
                              .read(inventoryProvider.notifier)
                              .loadMaterials(),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : _filteredMaterials.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay materiales',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agrega materiales al inventario para comenzar',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(3),
                    child: _buildMaterialsTable(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                _tableHeader('Código', 70),
                _tableHeader('Nombre', null, 2),
                _tableHeader('Categoría', 80),
                _tableHeader('Unidad', 50),
                _tableHeader('P.Compra', 70, 0, TextAlign.right),
                _tableHeader('P.Venta', 70, 0, TextAlign.right),
                _tableHeader('Margen', 70, 0, TextAlign.center),
                _tableHeader('Stock', 70, 0, TextAlign.right),
                _tableHeader('Estado', 70),
                const SizedBox(width: 40),
              ],
            ),
          ),
          // Rows
          Expanded(
            child: ListView.separated(
              itemCount: _filteredMaterials.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey[200]),
              itemBuilder: (context, index) {
                final material = _filteredMaterials[index];
                return _buildMaterialRow(material);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(
    String text, [
    double? width,
    int flex = 0,
    TextAlign align = TextAlign.left,
  ]) {
    final child = Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
        color: Colors.grey[700],
      ),
      textAlign: align,
    );
    if (width != null) {
      return SizedBox(width: width, child: child);
    }
    return Expanded(flex: flex, child: child);
  }

  Widget _buildMaterialRow(mat.Material material) {
    final isLowStock = material.isLowStock;
    // Calcular margen de ganancia
    final costPrice = material.costPrice;
    final salePrice = material.effectivePrice;
    final margin = costPrice > 0
        ? ((salePrice - costPrice) / costPrice * 100)
        : 0.0;
    final marginColor = margin > 30
        ? Colors.green
        : margin > 15
        ? Colors.orange
        : Colors.red;

    return InkWell(
      onTap: () => _showMaterialDetail(material),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: isLowStock ? Colors.orange.withOpacity(0.05) : null,
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Text(
                material.code,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                  if (material.description != null)
                    Text(
                      material.description!,
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _getCategoryColor(material.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getCategoryName(material.category),
                  style: TextStyle(
                    fontSize: 9,
                    color: _getCategoryColor(material.category),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(
                material.unit,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),
            // Precio de compra (costo)
            SizedBox(
              width: 70,
              child: Text(
                '\$${costPrice.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.right,
              ),
            ),
            // Precio de venta
            SizedBox(
              width: 70,
              child: Text(
                '\$${salePrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            // Margen de ganancia
            SizedBox(
              width: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: marginColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      margin > 30
                          ? Icons.trending_up
                          : margin > 15
                          ? Icons.trending_flat
                          : Icons.trending_down,
                      size: 10,
                      color: marginColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${margin.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: marginColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${material.stock.toStringAsFixed(material.stock % 1 == 0 ? 0 : 1)} ${material.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                      color: isLowStock ? Colors.orange[700] : null,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isLowStock
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isLowStock ? 'Bajo' : 'OK',
                  style: TextStyle(
                    fontSize: 9,
                    color: isLowStock ? Colors.orange[700] : Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(
                    value: 'stock',
                    child: Text('Ajustar Stock'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
                onSelected: (value) => _handleMenuAction(value, material),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action, mat.Material material) {
    switch (action) {
      case 'edit':
        _showEditMaterialDialog(material);
        break;
      case 'stock':
        _showAdjustStockDialog(material);
        break;
      case 'delete':
        _confirmDelete(material);
        break;
    }
  }

  void _showMaterialDetail(mat.Material material) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(material.name),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('Código', material.code),
                _detailRow('Categoría', material.categoryDisplay),
                _detailRow('Unidad', material.unit),
                if (material.unit == 'KG')
                  _detailRow(
                    'Precio/kg',
                    '\$${material.pricePerKg.toStringAsFixed(2)}',
                  )
                else
                  _detailRow(
                    'Precio/unidad',
                    '\$${material.unitPrice.toStringAsFixed(2)}',
                  ),
                const Divider(),
                // Stock
                _detailRow(
                  'Stock Peso',
                  '${material.stock.toStringAsFixed(2)} ${material.unit}',
                ),
                _detailRow(
                  'Stock Mín.',
                  '${material.minStock} ${material.unit}',
                ),
                // Dimensiones
                if (material.dimensionText.isNotEmpty) ...[
                  const Divider(),
                  Text(
                    'Dimensiones:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    material.dimensionText,
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
                // Metadata
                if (material.supplier != null)
                  _detailRow('Proveedor', material.supplier!),
                if (material.location != null)
                  _detailRow('Ubicación', material.location!),
                if (material.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Descripción:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    material.description!,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditMaterialDialog(material);
            },
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMaterialDialog() {
    _showMaterialFormDialog(null);
  }

  void _showEditMaterialDialog(mat.Material material) {
    _showMaterialFormDialog(material);
  }

  void _showMaterialFormDialog(mat.Material? material) {
    final isEditing = material != null;
    final codeCtrl = TextEditingController(text: material?.code ?? '');
    final nameCtrl = TextEditingController(text: material?.name ?? '');
    final descCtrl = TextEditingController(text: material?.description ?? '');
    final costPriceCtrl = TextEditingController(
      text: material?.costPrice.toString() ?? '0',
    );
    final priceKgCtrl = TextEditingController(
      text: material?.pricePerKg.toString() ?? '0',
    );
    final priceUnitCtrl = TextEditingController(
      text: material?.unitPrice.toString() ?? '0',
    );
    final stockCtrl = TextEditingController(
      text: material?.stock.toString() ?? '0',
    );
    final minStockCtrl = TextEditingController(
      text: material?.minStock.toString() ?? '0',
    );
    final supplierCtrl = TextEditingController(text: material?.supplier ?? '');
    String? selectedSupplierId; // ID del proveedor seleccionado
    final locationCtrl = TextEditingController(text: material?.location ?? '');
    // Dimensional controllers
    final outerDiameterCtrl = TextEditingController(
      text: material != null && (material.outerDiameter ?? 0) > 0
          ? material.outerDiameter.toString()
          : '',
    );
    final wallThicknessCtrl = TextEditingController(
      text: material != null && (material.wallThickness ?? 0) > 0
          ? material.wallThickness.toString()
          : '',
    );
    final thicknessCtrl = TextEditingController(
      text: material != null && (material.thickness ?? 0) > 0
          ? material.thickness.toString()
          : '',
    );
    // DB almacena en metros, UI muestra en centímetros
    final totalLengthCtrl = TextEditingController(
      text: material != null && (material.totalLength ?? 0) > 0
          ? (material.totalLength! * 100).toStringAsFixed(
              material.totalLength! * 100 ==
                      (material.totalLength! * 100).roundToDouble()
                  ? 0
                  : 2,
            )
          : '',
    );
    final widthCtrl = TextEditingController(
      text: material != null && (material.width ?? 0) > 0
          ? (material.width! * 100).toStringAsFixed(
              material.width! * 100 == (material.width! * 100).roundToDouble()
                  ? 0
                  : 2,
            )
          : '',
    );

    // Pre-asignar la unidad desde la categoría seleccionada
    final catState = ref.read(materialCategoryProvider);

    String category =
        material?.category ??
        (_selectedCategory != 'todos'
            ? _selectedCategory
            : (catState.categories.isNotEmpty
                  ? catState.categories.first.slug
                  : ''));
    final initialCat = catState.categories.where((c) => c.slug == category);
    String unit =
        material?.unit ??
        (initialCat.isNotEmpty ? initialCat.first.defaultUnit : 'KG');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Material' : 'Nuevo Material'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Código *',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final catState = ref.watch(
                                    materialCategoryProvider,
                                  );
                                  final cats = catState.categories;
                                  // Asegurar que el valor seleccionado existe en la lista
                                  final fallback = cats.isNotEmpty
                                      ? cats.first.slug
                                      : '';
                                  final validCategory =
                                      cats.any((c) => c.slug == category)
                                      ? category
                                      : fallback;
                                  if (validCategory != category) {
                                    Future.microtask(
                                      () => setDialogState(
                                        () => category = validCategory,
                                      ),
                                    );
                                  }
                                  if (cats.isEmpty) return const SizedBox();
                                  return DropdownButtonFormField<String>(
                                    value: validCategory,
                                    decoration: const InputDecoration(
                                      labelText: 'Categoría',
                                    ),
                                    items: cats
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c.slug,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: c.displayColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(c.name),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setDialogState(() {
                                      category = v!;
                                      // Auto-asignar unidad por defecto de la categoría
                                      final selectedCat = cats.firstWhere(
                                        (c) => c.slug == v,
                                      );
                                      unit = selectedCat.defaultUnit;
                                    }),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () async {
                                final newCat = await _showNewCategoryDialog(
                                  context,
                                );
                                if (newCat != null) {
                                  setDialogState(() {
                                    category = newCat.slug;
                                    unit = newCat.defaultUnit;
                                  });
                                }
                              },
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 22,
                              ),
                              tooltip: 'Nueva categoría',
                              style: IconButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre *'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  // Unidad (pre-seleccionada por la categoría)
                  DropdownButtonFormField<String>(
                    key: ValueKey('unit_$unit'),
                    value: unit,
                    decoration: const InputDecoration(
                      labelText: 'Unidad de Medida',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'KG',
                        child: Text('Kilogramos (KG)'),
                      ),
                      DropdownMenuItem(
                        value: 'UND',
                        child: Text('Unidades (UND)'),
                      ),
                      DropdownMenuItem(value: 'M', child: Text('Metros (M)')),
                      DropdownMenuItem(value: 'L', child: Text('Litros (L)')),
                      DropdownMenuItem(
                        value: 'M2',
                        child: Text('Metros² (M²)'),
                      ),
                      DropdownMenuItem(
                        value: 'GAL',
                        child: Text('Galones (GAL)'),
                      ),
                    ],
                    onChanged: (v) => setDialogState(() => unit = v!),
                  ),
                  const SizedBox(height: 16),
                  // SECCIÓN DE DIMENSIONES (para materiales con forma geométrica)
                  if (category == 'tubo' ||
                      category == 'eje' ||
                      category == 'perfil' ||
                      category == 'lamina')
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.straighten,
                                size: 18,
                                color: Colors.purple[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Dimensiones del Material',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // For tubes/ejes/perfiles: diameter and wall thickness
                          if (category == 'tubo' ||
                              category == 'eje' ||
                              category == 'perfil') ...[
                            _FractionInchField(
                              controller: outerDiameterCtrl,
                              label: 'Diámetro exterior',
                              helperText: 'Ej: 42 o 1.5',
                              enabled: true,
                              onChanged: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: 18),
                            _FractionInchField(
                              controller: wallThicknessCtrl,
                              label: category == 'eje'
                                  ? 'N/A (eje sólido)'
                                  : 'Espesor de pared',
                              helperText: category == 'eje'
                                  ? 'No aplica para ejes sólidos'
                                  : 'Ej: 0.25 o 1/4"',
                              enabled: category != 'eje',
                              onChanged: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: 18),
                          ],
                          // For sheets: thickness and width
                          if (category == 'lamina') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: thicknessCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Espesor (pulg)',
                                      helperText: 'Ej: 0.25',
                                      isDense: true,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: widthCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Ancho (centímetros)',
                                      helperText: 'Ej: 122',
                                      isDense: true,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          // Total length (UI en cm, DB en metros)
                          TextField(
                            controller: totalLengthCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Largo total (centímetros)',
                              helperText: 'Ej: 44, 150, 600',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Botón calcular peso (para TODAS las categorías dimensionales)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                double weight = 0;

                                if (category == 'lamina') {
                                  // LÁMINA: largo × ancho × espesor × densidad
                                  final largoCm =
                                      double.tryParse(totalLengthCtrl.text) ??
                                      0;
                                  final anchoCm =
                                      double.tryParse(widthCtrl.text) ?? 0;
                                  final espesorPulg =
                                      double.tryParse(thicknessCtrl.text) ?? 0;

                                  if (largoCm <= 0 ||
                                      anchoCm <= 0 ||
                                      espesorPulg <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Ingresa largo, ancho y espesor',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  // Convertir todo a mm
                                  final largoMm = largoCm * 10;
                                  final anchoMm = anchoCm * 10;
                                  final espesorMm = espesorPulg * 25.4;

                                  // Peso = L × A × E × densidad
                                  weight =
                                      largoMm * anchoMm * espesorMm * 7.85e-6;
                                } else {
                                  // TUBO / EJE / PERFIL
                                  final diameter =
                                      double.tryParse(outerDiameterCtrl.text) ??
                                      0;
                                  final thickness =
                                      double.tryParse(wallThicknessCtrl.text) ??
                                      0;
                                  final lengthCm =
                                      double.tryParse(totalLengthCtrl.text) ??
                                      0;

                                  if (diameter <= 0 || lengthCm <= 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Ingresa diámetro y largo',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  // Diámetro en pulgadas → mm (×25.4)
                                  // Largo en centímetros → mm (×10)
                                  final diameterMm = diameter * 25.4;
                                  final thicknessMm =
                                      (thickness > 0 ? thickness : 0) * 25.4;
                                  final diameterInnerMm =
                                      diameterMm - (2 * thicknessMm);
                                  final lengthMm = lengthCm * 10;

                                  if (category == 'eje') {
                                    // Eje sólido: π × D² / 4 × L × ρ
                                    weight =
                                        (3.14159 *
                                            diameterMm *
                                            diameterMm /
                                            4) *
                                        lengthMm *
                                        7.85e-6;
                                  } else {
                                    // Tubo hueco: π × (D_ext² - D_int²) / 4 × L × ρ
                                    weight =
                                        (3.14159 *
                                            (diameterMm * diameterMm -
                                                diameterInnerMm *
                                                    diameterInnerMm) /
                                            4) *
                                        lengthMm *
                                        7.85e-6;
                                  }
                                }

                                setDialogState(() {
                                  stockCtrl.text = weight.toStringAsFixed(2);
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Peso calculado: ${weight.toStringAsFixed(2)} kg',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.calculate, size: 18),
                              label: const Text(
                                'Calcular peso automáticamente',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // SECCIÓN DE PRECIOS
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 18,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Precios y Margen de Ganancia',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: costPriceCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Precio de COMPRA (Costo)',
                                  helperText: 'Lo que pagaste al proveedor',
                                  helperStyle: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                  prefixText: '\$ ',
                                  prefixIcon: Icon(
                                    Icons.shopping_cart,
                                    color: Colors.orange[700],
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: Colors.orange.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: unit == 'KG'
                                    ? priceKgCtrl
                                    : priceUnitCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Precio de VENTA',
                                  helperText: 'Lo que cobras al cliente',
                                  helperStyle: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                  prefixText: '\$ ',
                                  prefixIcon: Icon(
                                    Icons.sell,
                                    color: Colors.green[700],
                                    size: 20,
                                  ),
                                  filled: true,
                                  fillColor: Colors.green.withOpacity(0.05),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                          ],
                        ),
                        // Indicador de margen calculado EN TIEMPO REAL
                        Builder(
                          builder: (context) {
                            final costPrice =
                                double.tryParse(costPriceCtrl.text) ?? 0;
                            final salePrice =
                                double.tryParse(
                                  unit == 'KG'
                                      ? priceKgCtrl.text
                                      : priceUnitCtrl.text,
                                ) ??
                                0;
                            final margin = costPrice > 0
                                ? ((salePrice - costPrice) / costPrice * 100)
                                : 0.0;
                            final profit = salePrice - costPrice;

                            if (costPrice > 0 && salePrice > 0) {
                              final marginColor = margin > 30
                                  ? Colors.green
                                  : margin > 15
                                  ? Colors.orange
                                  : Colors.red;
                              return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: marginColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: marginColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            margin > 30
                                                ? Icons.trending_up
                                                : margin > 15
                                                ? Icons.trending_flat
                                                : Icons.trending_down,
                                            size: 20,
                                            color: marginColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'MARGEN',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: marginColor
                                                      .withOpacity(0.8),
                                                ),
                                              ),
                                              Text(
                                                '${margin.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: marginColor,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Container(
                                        width: 1,
                                        height: 30,
                                        color: marginColor.withOpacity(0.3),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'GANANCIA POR ${unit.toUpperCase()}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: marginColor.withOpacity(
                                                0.8,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '\$${profit.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: marginColor,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            // Mensaje guía cuando no hay precios
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ingresa ambos precios para ver el margen de ganancia',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          decoration: InputDecoration(
                            labelText: 'Stock Peso (kg)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: minStockCtrl,
                          decoration: InputDecoration(
                            labelText: 'Stock Mín. ($unit)',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final suppState = ref.watch(suppliersProvider);
                            final suppliers = suppState.suppliers;
                            // Cargar proveedores si aún no se han cargado
                            if (suppliers.isEmpty && !suppState.isLoading) {
                              Future.microtask(
                                () => ref
                                    .read(suppliersProvider.notifier)
                                    .loadSuppliers(),
                              );
                            }
                            return DropdownButtonFormField<String>(
                              value:
                                  supplierCtrl.text.isNotEmpty &&
                                      suppliers.any(
                                        (s) => s.name == supplierCtrl.text,
                                      )
                                  ? supplierCtrl.text
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'Proveedor',
                                suffixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 20,
                                  ),
                                  tooltip: 'Ir a Proveedores',
                                  onPressed: () {
                                    Navigator.pop(context);
                                    context.go('/customers');
                                  },
                                ),
                              ),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    'Sin proveedor',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                ...suppliers.map(
                                  (s) => DropdownMenuItem(
                                    value: s.name,
                                    child: Text(
                                      s.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                supplierCtrl.text = v ?? '';
                                // Guardar el ID del proveedor seleccionado
                                final sel = suppliers.where((s) => s.name == v);
                                selectedSupplierId = sel.isNotEmpty
                                    ? sel.first.id
                                    : null;
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: locationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Ubicación',
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
              onPressed: () async {
                if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Código y nombre son requeridos'),
                    ),
                  );
                  return;
                }

                final newMaterial = mat.Material(
                  id: material?.id ?? '',
                  code: codeCtrl.text,
                  name: nameCtrl.text,
                  description: descCtrl.text.isEmpty ? null : descCtrl.text,
                  category: category,
                  unit: unit,
                  costPrice: double.tryParse(costPriceCtrl.text) ?? 0,
                  pricePerKg: double.tryParse(priceKgCtrl.text) ?? 0,
                  unitPrice: double.tryParse(priceUnitCtrl.text) ?? 0,
                  stock: double.tryParse(stockCtrl.text) ?? 0,
                  minStock: double.tryParse(minStockCtrl.text) ?? 0,
                  outerDiameter: double.tryParse(outerDiameterCtrl.text) ?? 0,
                  wallThickness: double.tryParse(wallThicknessCtrl.text) ?? 0,
                  thickness: double.tryParse(thicknessCtrl.text) ?? 0,
                  // UI es cm, DB es metros → dividir por 100
                  totalLength:
                      ((double.tryParse(totalLengthCtrl.text) ?? 0) / 100),
                  width: ((double.tryParse(widthCtrl.text) ?? 0) / 100),
                  supplier: supplierCtrl.text.isEmpty
                      ? null
                      : supplierCtrl.text,
                  location: locationCtrl.text.isEmpty
                      ? null
                      : locationCtrl.text,
                  createdAt: material?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);

                String? savedMaterialId;

                if (isEditing) {
                  await ref
                      .read(inventoryProvider.notifier)
                      .updateMaterial(newMaterial);
                  savedMaterialId = newMaterial.id;
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Material actualizado')),
                    );
                  }
                } else {
                  final created = await ref
                      .read(inventoryProvider.notifier)
                      .createMaterial(newMaterial);
                  savedMaterialId = created?.id;
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Material creado')),
                    );
                  }
                }

                // Guardar precio proveedor-material si hay proveedor seleccionado
                if (selectedSupplierId != null &&
                    savedMaterialId != null &&
                    savedMaterialId.isNotEmpty) {
                  await ref
                      .read(supplierMaterialsProvider.notifier)
                      .upsertPrice(
                        supplierId: selectedSupplierId!,
                        materialId: savedMaterialId,
                        unitPrice: newMaterial.costPrice > 0
                            ? newMaterial.costPrice
                            : newMaterial.pricePerKg,
                      );
                }
              },
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustStockDialog(mat.Material material) {
    final adjustCtrl = TextEditingController();
    String operation = 'add';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Ajustar Stock: ${material.name}'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current stock info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Stock:', style: TextStyle(fontSize: 13)),
                          Text(
                            '${material.stock.toStringAsFixed(2)} ${material.unit}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Agregar'),
                        value: 'add',
                        groupValue: operation,
                        onChanged: (v) => setDialogState(() => operation = v!),
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Quitar'),
                        value: 'remove',
                        groupValue: operation,
                        onChanged: (v) => setDialogState(() => operation = v!),
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: adjustCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cantidad Peso (kg)',
                    prefixText: operation == 'add' ? '+ ' : '- ',
                  ),
                  keyboardType: TextInputType.number,
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final qty = double.tryParse(adjustCtrl.text) ?? 0;
                if (qty <= 0) return;

                final sign = operation == 'add' ? 1.0 : -1.0;
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);

                await ref
                    .read(inventoryProvider.notifier)
                    .adjustStock(material.id, qty * sign);

                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        operation == 'add'
                            ? 'Stock aumentado: $qty ${material.unit}'
                            : 'Stock reducido: $qty ${material.unit}',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(mat.Material material) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Material'),
        content: Text('¿Estás seguro de eliminar "${material.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              await ref
                  .read(inventoryProvider.notifier)
                  .deleteMaterial(material.id);
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Material eliminado')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(String category) {
    final catState = ref.read(materialCategoryProvider);
    final match = catState.categories.where((c) => c.slug == category);
    if (match.isNotEmpty) return match.first.name;
    // Fallback hardcodeado por si no hay datos aún
    switch (category) {
      case 'tubo':
        return 'Tubos';
      case 'lamina':
        return 'Láminas';
      case 'eje':
        return 'Ejes';
      case 'rodamiento':
        return 'Rodamientos';
      case 'tornilleria':
        return 'Tornillería';
      case 'consumible':
        return 'Consumibles';
      case 'pintura':
        return 'Pintura';
      case 'perfil':
        return 'Perfiles';
      case 'general':
        return 'General';
      default:
        return category;
    }
  }

  Color _getCategoryColor(String category) {
    final catState = ref.read(materialCategoryProvider);
    final match = catState.categories.where((c) => c.slug == category);
    if (match.isNotEmpty) return match.first.displayColor;
    // Fallback
    switch (category) {
      case 'tubo':
        return Colors.blue;
      case 'lamina':
        return Colors.green;
      case 'eje':
        return Colors.purple;
      case 'rodamiento':
        return Colors.orange;
      case 'tornilleria':
        return Colors.teal;
      case 'consumible':
        return Colors.brown;
      case 'pintura':
        return Colors.pink;
      case 'perfil':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  // ==================== ADMINISTRAR CATEGORÍAS ====================

  void _showManageCategoriesDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final catState = ref.watch(materialCategoryProvider);
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.category, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('Categorías de Materiales'),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    final newCat = await _showNewCategoryDialog(context);
                    if (newCat != null) {
                      // Recargar materiales para actualizar filtros
                      ref.read(inventoryProvider.notifier).loadMaterials();
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: catState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : catState.categories.isEmpty
                  ? const Center(child: Text('No hay categorías'))
                  : ListView.separated(
                      itemCount: catState.categories.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final cat = catState.categories[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cat.displayColor.withOpacity(0.15),
                            child: Icon(
                              cat.displayIcon,
                              color: cat.displayColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            cat.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${cat.defaultUnit} · ${cat.description ?? "Sin descripción"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          trailing: cat.isSystem
                              ? Chip(
                                  label: const Text(
                                    'Sistema',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.grey[200],
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: Colors.blue[700],
                                      ),
                                      onPressed: () async {
                                        await _showEditCategoryDialog(
                                          context,
                                          cat,
                                        );
                                      },
                                      tooltip: 'Editar',
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red[700],
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              'Eliminar categoría',
                                            ),
                                            content: Text(
                                              '¿Eliminar "${cat.name}"? Los materiales que la usen quedarán sin categoría válida.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                child: const Text('Eliminar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          final ok = await ref
                                              .read(
                                                materialCategoryProvider
                                                    .notifier,
                                              )
                                              .deleteCategory(cat.id);
                                          if (!ok && context.mounted) {
                                            final error = ref
                                                .read(materialCategoryProvider)
                                                .error;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  error ??
                                                      'No se pudo eliminar',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      tooltip: 'Eliminar',
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Diálogo para crear nueva categoría
  Future<MaterialCategory?> _showNewCategoryDialog(
    BuildContext parentContext,
  ) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedUnit = 'KG';
    String selectedColor = '#607D8B';
    String selectedIcon = 'category';
    bool hasDimensions = false;
    String? dimensionType;

    return showDialog<MaterialCategory>(
      context: parentContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Nueva Categoría'),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre *',
                      hintText: 'Ej: Válvulas, Acoples, etc.',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Descripción opcional',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unidad por defecto',
                    ),
                    items: MaterialCategory.availableUnits.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedUnit = v!),
                  ),
                  const SizedBox(height: 16),
                  // Color selector
                  const Text(
                    'Color',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: MaterialCategory.availableColors.map((hex) {
                      final c = Color(
                        int.parse('FF${hex.replaceFirst("#", "")}', radix: 16),
                      );
                      final isSelected = hex == selectedColor;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = hex),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 2.5)
                                : Border.all(color: Colors.grey[300]!),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Icon selector
                  const Text(
                    'Ícono',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: MaterialCategory.availableIcons.map((entry) {
                      final isSelected = entry.key == selectedIcon;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedIcon = entry.key),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(
                                    int.parse(
                                      'FF${selectedColor.replaceFirst("#", "")}',
                                      radix: 16,
                                    ),
                                  ).withOpacity(0.2)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected
                                ? Border.all(
                                    color: Color(
                                      int.parse(
                                        'FF${selectedColor.replaceFirst("#", "")}',
                                        radix: 16,
                                      ),
                                    ),
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Icon(
                            entry.value,
                            size: 18,
                            color: isSelected
                                ? Color(
                                    int.parse(
                                      'FF${selectedColor.replaceFirst("#", "")}',
                                      radix: 16,
                                    ),
                                  )
                                : Colors.grey[600],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  // Has dimensions toggle
                  SwitchListTile(
                    title: const Text(
                      'Tiene dimensiones',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Permite calcular peso por geometría',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: hasDimensions,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (v) => setDialogState(() {
                      hasDimensions = v;
                      if (!v) dimensionType = null;
                    }),
                  ),
                  if (hasDimensions)
                    ..._buildDimensionTypeSelector(
                      dimensionType,
                      (v) => setDialogState(() => dimensionType = v),
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
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre es requerido'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                // Generar slug a partir del nombre
                final slug = nameCtrl.text
                    .trim()
                    .toLowerCase()
                    .replaceAll(RegExp(r'[áà]'), 'a')
                    .replaceAll(RegExp(r'[éè]'), 'e')
                    .replaceAll(RegExp(r'[íì]'), 'i')
                    .replaceAll(RegExp(r'[óò]'), 'o')
                    .replaceAll(RegExp(r'[úù]'), 'u')
                    .replaceAll(RegExp(r'ñ'), 'n')
                    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                    .replaceAll(RegExp(r'^_|_$'), '');

                final now = DateTime.now();
                final newCat = MaterialCategory(
                  id: '',
                  name: nameCtrl.text.trim(),
                  slug: slug,
                  description: descCtrl.text.trim().isNotEmpty
                      ? descCtrl.text.trim()
                      : null,
                  defaultUnit: selectedUnit,
                  color: selectedColor,
                  iconName: selectedIcon,
                  hasDimensions: hasDimensions,
                  dimensionType: dimensionType,
                  sortOrder: ref
                      .read(materialCategoryProvider)
                      .categories
                      .length,
                  createdAt: now,
                  updatedAt: now,
                );

                final created = await ref
                    .read(materialCategoryProvider.notifier)
                    .createCategory(newCat);
                if (created != null && context.mounted) {
                  Navigator.pop(context, created);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Categoría "${created.name}" creada'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (context.mounted) {
                  final error = ref.read(materialCategoryProvider).error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? 'Error al crear'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo para editar una categoría existente
  Future<void> _showEditCategoryDialog(
    BuildContext parentContext,
    MaterialCategory cat,
  ) async {
    final nameCtrl = TextEditingController(text: cat.name);
    final descCtrl = TextEditingController(text: cat.description ?? '');
    String selectedUnit = cat.defaultUnit;
    String selectedColor = cat.color;
    String selectedIcon = cat.iconName;
    bool hasDimensions = cat.hasDimensions;
    String? dimensionType = cat.dimensionType;

    await showDialog(
      context: parentContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text('Editar: ${cat.name}'),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre *'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unidad por defecto',
                    ),
                    items: MaterialCategory.availableUnits.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedUnit = v!),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Color',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: MaterialCategory.availableColors.map((hex) {
                      final c = Color(
                        int.parse('FF${hex.replaceFirst("#", "")}', radix: 16),
                      );
                      final isSelected = hex == selectedColor;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = hex),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 2.5)
                                : Border.all(color: Colors.grey[300]!),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ícono',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: MaterialCategory.availableIcons.map((entry) {
                      final isSelected = entry.key == selectedIcon;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedIcon = entry.key),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Color(
                                    int.parse(
                                      'FF${selectedColor.replaceFirst("#", "")}',
                                      radix: 16,
                                    ),
                                  ).withOpacity(0.2)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected
                                ? Border.all(
                                    color: Color(
                                      int.parse(
                                        'FF${selectedColor.replaceFirst("#", "")}',
                                        radix: 16,
                                      ),
                                    ),
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Icon(
                            entry.value,
                            size: 18,
                            color: isSelected
                                ? Color(
                                    int.parse(
                                      'FF${selectedColor.replaceFirst("#", "")}',
                                      radix: 16,
                                    ),
                                  )
                                : Colors.grey[600],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text(
                      'Tiene dimensiones',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Permite calcular peso por geometría',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: hasDimensions,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (v) => setDialogState(() {
                      hasDimensions = v;
                      if (!v) dimensionType = null;
                    }),
                  ),
                  if (hasDimensions)
                    ..._buildDimensionTypeSelector(
                      dimensionType,
                      (v) => setDialogState(() => dimensionType = v),
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
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre es requerido'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                final updated = cat.copyWith(
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim().isNotEmpty
                      ? descCtrl.text.trim()
                      : null,
                  defaultUnit: selectedUnit,
                  color: selectedColor,
                  iconName: selectedIcon,
                  hasDimensions: hasDimensions,
                  dimensionType: dimensionType,
                );
                final ok = await ref
                    .read(materialCategoryProvider.notifier)
                    .updateCategory(updated);
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Categoría "${updated.name}" actualizada'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDimensionTypeSelector(
    String? current,
    ValueChanged<String?> onChanged,
  ) {
    return [
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: current,
        decoration: const InputDecoration(labelText: 'Tipo de dimensión'),
        items: MaterialCategory.availableDimensionTypes.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
      ),
    ];
  }
}

/// Widget helper para campo de pulgadas con fracciones comunes
class _FractionInchField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helperText;
  final bool enabled;
  final void Function(String)? onChanged;

  const _FractionInchField({
    required this.controller,
    required this.label,
    this.helperText,
    this.enabled = true,
    this.onChanged,
  });

  @override
  State<_FractionInchField> createState() => _FractionInchFieldState();
}

class _FractionInchFieldState extends State<_FractionInchField> {
  // Fracciones comunes en pulgadas
  static const Map<String, double> commonFractions = {
    '1/8"': 0.125,
    '1/4"': 0.25,
    '3/8"': 0.375,
    '1/2"': 0.5,
    '5/8"': 0.625,
    '3/4"': 0.75,
    '7/8"': 0.875,
    '1"': 1.0,
    '1 1/4"': 1.25,
    '1 1/2"': 1.5,
    '1 3/4"': 1.75,
    '2"': 2.0,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Campo de entrada principal
        Expanded(
          child: TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: widget.helperText,
              isDense: false,
              suffixText: '"',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: widget.enabled,
            onChanged: widget.onChanged,
          ),
        ),
        const SizedBox(width: 8),
        // Botón popup con fracciones
        PopupMenuButton<double>(
          onSelected: (value) {
            widget.controller.text = value.toString();
            widget.onChanged?.call(value.toString());
          },
          enabled: widget.enabled,
          tooltip: 'Seleccionar fracción',
          icon: Icon(
            Icons.format_list_numbered,
            size: 24,
            color: widget.enabled ? Colors.blue[700] : Colors.grey[400],
          ),
          itemBuilder: (context) => commonFractions.entries
              .map(
                (e) => PopupMenuItem(
                  value: e.value,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '= ${e.value}"',
                        style: TextStyle(color: Colors.grey[700], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
