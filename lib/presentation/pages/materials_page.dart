import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/providers.dart';
import '../../domain/entities/material.dart' as mat;

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
      final matchesSearch = m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.code.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'todos' || 
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
                      icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor, size: 20),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (value) => setState(() => _searchQuery = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(value: 'todos', child: Text('Todas')),
                          ...state.categories.map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(_getCategoryName(cat)),
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
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Text('Error: ${state.error}'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref.read(inventoryProvider.notifier).loadMaterials(),
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
                                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay materiales',
                                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
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

  Widget _buildQuickStat(String label, String value, Color color, IconData icon) {
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
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
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
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
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

  Widget _tableHeader(String text, [double? width, int flex = 0, TextAlign align = TextAlign.left]) {
    final child = Text(
      text,
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[700]),
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
    final margin = costPrice > 0 ? ((salePrice - costPrice) / costPrice * 100) : 0.0;
    final marginColor = margin > 30 ? Colors.green : margin > 15 ? Colors.orange : Colors.red;

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
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(material.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11)),
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
              child: Text(material.unit, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
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
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
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
                      margin > 30 ? Icons.trending_up : margin > 15 ? Icons.trending_flat : Icons.trending_down,
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
              child: Text(
                '${material.stock.toStringAsFixed(material.stock % 1 == 0 ? 0 : 1)} ${material.unit}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                  color: isLowStock ? Colors.orange[700] : null,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: 70,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: isLowStock ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
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
                  const PopupMenuItem(value: 'stock', child: Text('Ajustar Stock')),
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
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Código', material.code),
              _detailRow('Categoría', material.categoryDisplay),
              _detailRow('Unidad', material.unit),
              if (material.unit == 'KG')
                _detailRow('Precio/kg', '\$${material.pricePerKg.toStringAsFixed(2)}')
              else
                _detailRow('Precio/unidad', '\$${material.unitPrice.toStringAsFixed(2)}'),
              _detailRow('Stock Actual', '${material.stock} ${material.unit}'),
              _detailRow('Stock Mínimo', '${material.minStock} ${material.unit}'),
              if (material.supplier != null) _detailRow('Proveedor', material.supplier!),
              if (material.location != null) _detailRow('Ubicación', material.location!),
              if (material.description != null) ...[
                const SizedBox(height: 8),
                Text('Descripción:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                Text(material.description!, style: TextStyle(color: Colors.grey[600])),
              ],
            ],
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
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
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
    final costPriceCtrl = TextEditingController(text: material?.costPrice.toString() ?? '0');
    final priceKgCtrl = TextEditingController(text: material?.pricePerKg.toString() ?? '0');
    final priceUnitCtrl = TextEditingController(text: material?.unitPrice.toString() ?? '0');
    final stockCtrl = TextEditingController(text: material?.stock.toString() ?? '0');
    final minStockCtrl = TextEditingController(text: material?.minStock.toString() ?? '0');
    final supplierCtrl = TextEditingController(text: material?.supplier ?? '');
    final locationCtrl = TextEditingController(text: material?.location ?? '');
    
    String category = material?.category ?? 'general';
    String unit = material?.unit ?? 'KG';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Material' : 'Nuevo Material'),
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
                          controller: codeCtrl,
                          decoration: const InputDecoration(labelText: 'Código *'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(labelText: 'Categoría'),
                          items: const [
                            DropdownMenuItem(value: 'general', child: Text('General')),
                            DropdownMenuItem(value: 'tubo', child: Text('Tubos')),
                            DropdownMenuItem(value: 'lamina', child: Text('Láminas')),
                            DropdownMenuItem(value: 'eje', child: Text('Ejes')),
                            DropdownMenuItem(value: 'rodamiento', child: Text('Rodamientos')),
                            DropdownMenuItem(value: 'tornilleria', child: Text('Tornillería')),
                            DropdownMenuItem(value: 'consumible', child: Text('Consumibles')),
                            DropdownMenuItem(value: 'pintura', child: Text('Pintura')),
                          ],
                          onChanged: (v) => setDialogState(() => category = v!),
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
                  // Unidad
                  DropdownButtonFormField<String>(
                    initialValue: unit,
                    decoration: const InputDecoration(labelText: 'Unidad de Medida'),
                    items: const [
                      DropdownMenuItem(value: 'KG', child: Text('Kilogramos (KG)')),
                      DropdownMenuItem(value: 'UND', child: Text('Unidades (UND)')),
                      DropdownMenuItem(value: 'M', child: Text('Metros (M)')),
                      DropdownMenuItem(value: 'L', child: Text('Litros (L)')),
                    ],
                    onChanged: (v) => setDialogState(() => unit = v!),
                  ),
                  const SizedBox(height: 16),
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
                            Icon(Icons.attach_money, size: 18, color: Colors.blue[700]),
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
                                  helperStyle: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  prefixText: '\$ ',
                                  prefixIcon: Icon(Icons.shopping_cart, color: Colors.orange[700], size: 20),
                                  filled: true,
                                  fillColor: Colors.orange.withOpacity(0.05),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: unit == 'KG' ? priceKgCtrl : priceUnitCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Precio de VENTA',
                                  helperText: 'Lo que cobras al cliente',
                                  helperStyle: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                  prefixText: '\$ ',
                                  prefixIcon: Icon(Icons.sell, color: Colors.green[700], size: 20),
                                  filled: true,
                                  fillColor: Colors.green.withOpacity(0.05),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                          ],
                        ),
                        // Indicador de margen calculado EN TIEMPO REAL
                        Builder(
                          builder: (context) {
                            final costPrice = double.tryParse(costPriceCtrl.text) ?? 0;
                            final salePrice = double.tryParse(unit == 'KG' ? priceKgCtrl.text : priceUnitCtrl.text) ?? 0;
                            final margin = costPrice > 0 ? ((salePrice - costPrice) / costPrice * 100) : 0.0;
                            final profit = salePrice - costPrice;
                            
                            if (costPrice > 0 && salePrice > 0) {
                              final marginColor = margin > 30 ? Colors.green : margin > 15 ? Colors.orange : Colors.red;
                              return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: marginColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: marginColor.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            margin > 30 ? Icons.trending_up : margin > 15 ? Icons.trending_flat : Icons.trending_down,
                                            size: 20,
                                            color: marginColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'MARGEN',
                                                style: TextStyle(fontSize: 9, color: marginColor.withOpacity(0.8)),
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
                                      Container(width: 1, height: 30, color: marginColor.withOpacity(0.3)),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'GANANCIA POR ${unit.toUpperCase()}',
                                            style: TextStyle(fontSize: 9, color: marginColor.withOpacity(0.8)),
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
                                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Ingresa ambos precios para ver el margen de ganancia',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                          decoration: InputDecoration(labelText: 'Stock Actual ($unit)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: minStockCtrl,
                          decoration: InputDecoration(labelText: 'Stock Mínimo ($unit)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: supplierCtrl,
                          decoration: const InputDecoration(labelText: 'Proveedor'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: locationCtrl,
                          decoration: const InputDecoration(labelText: 'Ubicación'),
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
                    const SnackBar(content: Text('Código y nombre son requeridos')),
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
                  supplier: supplierCtrl.text.isEmpty ? null : supplierCtrl.text,
                  location: locationCtrl.text.isEmpty ? null : locationCtrl.text,
                  createdAt: material?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                Navigator.pop(context);

                if (isEditing) {
                  await ref.read(inventoryProvider.notifier).updateMaterial(newMaterial);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Material actualizado')),
                    );
                  }
                } else {
                  await ref.read(inventoryProvider.notifier).createMaterial(newMaterial);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Material creado')),
                    );
                  }
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
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Stock actual: ${material.stock} ${material.unit}'),
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
                    labelText: 'Cantidad (${material.unit})',
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

                final adjustment = operation == 'add' ? qty : -qty;
                Navigator.pop(context);

                await ref.read(inventoryProvider.notifier).adjustStock(material.id, adjustment);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        operation == 'add'
                            ? 'Stock aumentado en $qty ${material.unit}'
                            : 'Stock reducido en $qty ${material.unit}',
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
              Navigator.pop(context);
              await ref.read(inventoryProvider.notifier).deleteMaterial(material.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
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
    switch (category) {
      case 'tubo': return 'Tubos';
      case 'lamina': return 'Láminas';
      case 'eje': return 'Ejes';
      case 'rodamiento': return 'Rodamientos';
      case 'tornilleria': return 'Tornillería';
      case 'consumible': return 'Consumibles';
      case 'pintura': return 'Pintura';
      case 'general': return 'General';
      default: return category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'tubo': return Colors.blue;
      case 'lamina': return Colors.green;
      case 'eje': return Colors.purple;
      case 'rodamiento': return Colors.orange;
      case 'tornilleria': return Colors.teal;
      case 'consumible': return Colors.brown;
      case 'pintura': return Colors.pink;
      default: return Colors.grey;
    }
  }
}
