import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../domain/entities/inventory_material.dart';
import '../../domain/entities/composite_product.dart';

class CompositeProductsPage extends StatefulWidget {
  const CompositeProductsPage({super.key});

  @override
  State<CompositeProductsPage> createState() => _CompositeProductsPageState();
}

class _CompositeProductsPageState extends State<CompositeProductsPage> {
  String _searchQuery = '';
  String _selectedCategory = 'todos';

  // Datos de ejemplo de productos compuestos
  final List<CompositeProduct> _products = [
    CompositeProduct(
      id: 'PROD-001',
      code: 'MOL-44M',
      name: 'Molino 44m',
      description: 'Molino de bolas de 44 metros para procesamiento de minerales',
      category: ProductCategories.molino,
      components: [
        ProductComponent(
          id: '1', materialId: 'TUB-A36-001', materialName: 'Cilindro principal',
          shape: MaterialShape.cylinder, outerDiameter: 508, thickness: 12, length: 1000,
          quantity: 1, weightPerUnit: 150.2, pricePerUnit: 675.90,
        ),
        ProductComponent(
          id: '2', materialId: 'TAP-A36', materialName: 'Tapa frontal',
          shape: MaterialShape.circularPlate, outerDiameter: 508, thickness: 12,
          quantity: 2, weightPerUnit: 18.5, pricePerUnit: 83.25,
        ),
        ProductComponent(
          id: '3', materialId: 'EJE-SAE4140', materialName: 'Eje de transmisión',
          shape: MaterialShape.solidCylinder, outerDiameter: 100, length: 1200,
          quantity: 1, weightPerUnit: 74.0, pricePerUnit: 592.00,
        ),
        ProductComponent(
          id: '4', materialId: 'LAM-A36-10MM', materialName: 'Base metálica',
          shape: MaterialShape.rectangularPlate, width: 1500, height: 800, thickness: 10,
          quantity: 1, weightPerUnit: 94.2, pricePerUnit: 423.90,
        ),
        ProductComponent(
          id: '5', materialId: 'ROD-6310', materialName: 'Rodamiento principal SKF 6310',
          shape: MaterialShape.bearing,
          quantity: 2, weightPerUnit: 1.2, pricePerUnit: 85.00,
        ),
      ],
      laborHours: 40,
      laborRate: 25,
      indirectCosts: 150,
      profitMargin: 20,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CompositeProduct(
      id: 'PROD-002',
      code: 'MOL-36M',
      name: 'Molino 36m',
      description: 'Molino de bolas de 36 metros',
      category: ProductCategories.molino,
      components: [
        ProductComponent(
          id: '1', materialId: 'TUB-A36-001', materialName: 'Cilindro principal',
          shape: MaterialShape.cylinder, outerDiameter: 406, thickness: 10, length: 800,
          quantity: 1, weightPerUnit: 95.5, pricePerUnit: 429.75,
        ),
        ProductComponent(
          id: '2', materialId: 'TAP-A36', materialName: 'Tapa frontal',
          shape: MaterialShape.circularPlate, outerDiameter: 406, thickness: 10,
          quantity: 2, weightPerUnit: 10.2, pricePerUnit: 45.90,
        ),
        ProductComponent(
          id: '3', materialId: 'EJE-SAE4140', materialName: 'Eje de transmisión',
          shape: MaterialShape.solidCylinder, outerDiameter: 80, length: 1000,
          quantity: 1, weightPerUnit: 39.4, pricePerUnit: 315.20,
        ),
      ],
      laborHours: 30,
      laborRate: 25,
      indirectCosts: 100,
      profitMargin: 20,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CompositeProduct(
      id: 'PROD-003',
      code: 'TRANS-001',
      name: 'Transportador de banda 5m',
      description: 'Transportador de banda de 5 metros para carga',
      category: ProductCategories.transportador,
      components: [
        ProductComponent(
          id: '1', materialId: 'LAM-A36-6MM', materialName: 'Estructura lateral',
          shape: MaterialShape.rectangularPlate, width: 5000, height: 150, thickness: 6,
          quantity: 2, weightPerUnit: 35.3, pricePerUnit: 158.85,
        ),
        ProductComponent(
          id: '2', materialId: 'TUB-A36-001', materialName: 'Rodillo tensor',
          shape: MaterialShape.cylinder, outerDiameter: 89, thickness: 5, length: 500,
          quantity: 3, weightPerUnit: 15.2, pricePerUnit: 76.00,
        ),
        ProductComponent(
          id: '3', materialId: 'TUB-A36-001', materialName: 'Tambor motriz',
          shape: MaterialShape.cylinder, outerDiameter: 200, thickness: 8, length: 500,
          quantity: 1, weightPerUnit: 45.0, pricePerUnit: 202.50,
        ),
      ],
      laborHours: 20,
      laborRate: 25,
      indirectCosts: 80,
      profitMargin: 18,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CompositeProduct(
      id: 'PROD-004',
      code: 'TAN-500L',
      name: 'Tanque 500 litros',
      description: 'Tanque de acero inoxidable de 500 litros',
      category: ProductCategories.tanque,
      components: [
        ProductComponent(
          id: '1', materialId: 'TUB-INOX-304', materialName: 'Cuerpo cilíndrico',
          shape: MaterialShape.cylinder, outerDiameter: 800, thickness: 3, length: 1000,
          quantity: 1, weightPerUnit: 60.5, pricePerUnit: 726.00,
        ),
        ProductComponent(
          id: '2', materialId: 'LAM-INOX-304-2MM', materialName: 'Tapa superior',
          shape: MaterialShape.circularPlate, outerDiameter: 800, thickness: 3,
          quantity: 1, weightPerUnit: 12.0, pricePerUnit: 144.00,
        ),
        ProductComponent(
          id: '3', materialId: 'LAM-INOX-304-2MM', materialName: 'Fondo cónico',
          shape: MaterialShape.circularPlate, outerDiameter: 800, thickness: 3,
          quantity: 1, weightPerUnit: 15.0, pricePerUnit: 180.00,
        ),
      ],
      laborHours: 15,
      laborRate: 25,
      indirectCosts: 50,
      profitMargin: 25,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  List<CompositeProduct> get _filteredProducts {
    return _products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.code.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'todos' || p.category == _selectedCategory;
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
                            'Productos Compuestos',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_products.length} productos registrados (Molinos, Transportadores, etc.)',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    _buildQuickStat('Molinos', '${_products.where((p) => p.category == ProductCategories.molino).length}', Colors.blue, Icons.settings),
                    const SizedBox(width: 12),
                    _buildQuickStat('Otros', '${_products.where((p) => p.category != ProductCategories.molino).length}', Colors.green, Icons.category),
                    const SizedBox(width: 24),
                    FilledButton.icon(
                      onPressed: () => _showCreateProductDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo Producto'),
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
                          ...ProductCategories.all.map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(ProductCategories.getDisplayName(cat)),
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

          // Lista de productos
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  return _buildProductCard(_filteredProducts[index]);
                },
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

  Widget _buildProductCard(CompositeProduct product) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showProductDetail(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(product.category ?? '').withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(product.category ?? ''),
                      color: _getCategoryColor(product.category ?? ''),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          product.code,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                    onSelected: (value) => _handleProductAction(value, product),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')])),
                      const PopupMenuItem(value: 'duplicate', child: Row(children: [Icon(Icons.copy, size: 18), SizedBox(width: 8), Text('Duplicar')])),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Descripción
              if (product.description != null)
                Text(
                  product.description!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const Spacer(),
              
              // Stats
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('Componentes', '${product.componentCount}'),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    _buildStatColumn('Peso', '${Helpers.formatNumber(product.totalWeight)} kg'),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    _buildStatColumn('Precio', 'S/ ${Helpers.formatNumber(product.totalPrice)}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case ProductCategories.molino: return Colors.blue;
      case ProductCategories.transportador: return Colors.green;
      case ProductCategories.tanque: return Colors.orange;
      case ProductCategories.estructura: return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case ProductCategories.molino: return Icons.settings;
      case ProductCategories.transportador: return Icons.conveyor_belt;
      case ProductCategories.tanque: return Icons.local_drink;
      case ProductCategories.estructura: return Icons.foundation;
      default: return Icons.category;
    }
  }

  void _handleProductAction(String action, CompositeProduct product) {
    switch (action) {
      case 'edit':
        _showCreateProductDialog(product: product);
        break;
      case 'duplicate':
        // TODO: Duplicar producto
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto duplicado')),
        );
        break;
      case 'delete':
        _confirmDelete(product);
        break;
    }
  }

  void _showProductDetail(CompositeProduct product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 700,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(_getCategoryIcon(product.category ?? ''), color: _getCategoryColor(product.category ?? ''), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Código: ${product.code}', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'S/ ${Helpers.formatNumber(product.totalPrice)}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                      Text('${Helpers.formatNumber(product.totalWeight)} kg', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              
              if (product.description != null) ...[
                Text(product.description!, style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
              ],
              
              // Componentes
              Row(
                children: [
                  const Icon(Icons.list_alt, size: 20),
                  const SizedBox(width: 8),
                  Text('Componentes (${product.componentCount})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Para recibo empresa',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: product.components.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                  itemBuilder: (context, index) {
                    final comp = product.components[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        child: Text('${comp.quantity}×', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      title: Text(comp.materialName ?? 'Componente'),
                      subtitle: Text(comp.dimensionsDescription),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('S/ ${Helpers.formatNumber(comp.totalPrice)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${Helpers.formatNumber(comp.totalWeight)} kg', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Resumen de costos
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildCostRow('Materiales', 'S/ ${Helpers.formatNumber(product.materialsCost)}'),
                    _buildCostRow('Mano de obra (${product.laborHours}h × S/${product.laborRate})', 'S/ ${Helpers.formatNumber(product.laborCost)}'),
                    _buildCostRow('Costos indirectos', 'S/ ${Helpers.formatNumber(product.indirectCosts)}'),
                    const Divider(),
                    _buildCostRow('Subtotal', 'S/ ${Helpers.formatNumber(product.subtotal)}'),
                    _buildCostRow('Margen (${product.profitMargin.toStringAsFixed(0)}%)', 'S/ ${Helpers.formatNumber(product.profitAmount)}'),
                    const Divider(),
                    _buildCostRow('TOTAL', 'S/ ${Helpers.formatNumber(product.totalPrice)}', isBold: true),
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
                    child: const Text('Cerrar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showCreateProductDialog(product: product);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? AppTheme.primaryColor : null,
              fontSize: isBold ? 16 : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateProductDialog({CompositeProduct? product}) {
    final isEditing = product != null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(isEditing ? Icons.edit : Icons.add_box, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Text(isEditing ? 'Editar Producto' : 'Nuevo Producto Compuesto'),
          ],
        ),
        content: const SizedBox(
          width: 500,
          child: Text(
            'Esta funcionalidad permite crear productos compuestos (como Molinos) '
            'que contienen múltiples materiales del inventario.\n\n'
            'Próximamente: Formulario completo para crear/editar productos con sus componentes.',
          ),
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

  void _confirmDelete(CompositeProduct product) {
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
        content: Text('¿Está seguro de eliminar el producto "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: Eliminar producto
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Producto eliminado'), backgroundColor: Colors.red),
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
