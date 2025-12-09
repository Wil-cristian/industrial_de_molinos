import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Todos';

  // Datos de ejemplo
  final List<Map<String, dynamic>> _products = [
    {'code': 'P001', 'name': 'Harina de Trigo 50kg', 'stock': 150, 'minStock': 50, 'price': 120.00, 'category': 'Harinas'},
    {'code': 'P002', 'name': 'Harina Integral 25kg', 'stock': 45, 'minStock': 30, 'price': 85.00, 'category': 'Harinas'},
    {'code': 'P003', 'name': 'Salvado de Trigo 40kg', 'stock': 20, 'minStock': 25, 'price': 45.00, 'category': 'Subproductos'},
    {'code': 'P004', 'name': 'Sémola 25kg', 'stock': 80, 'minStock': 40, 'price': 95.00, 'category': 'Harinas'},
    {'code': 'P005', 'name': 'Afrecho 50kg', 'stock': 10, 'minStock': 20, 'price': 35.00, 'category': 'Subproductos'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Barra de búsqueda y filtros
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar producto por código o nombre...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                    ),
                    items: ['Todos', 'Harinas', 'Subproductos', 'Otros']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value ?? 'Todos';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => context.go('/products/new'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo Producto'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tabla de productos
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    // Encabezado de tabla
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          _buildHeaderCell('Código', flex: 1),
                          _buildHeaderCell('Producto', flex: 3),
                          _buildHeaderCell('Categoría', flex: 2),
                          _buildHeaderCell('Stock', flex: 1),
                          _buildHeaderCell('Precio', flex: 1),
                          _buildHeaderCell('Estado', flex: 1),
                          _buildHeaderCell('Acciones', flex: 1),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    
                    // Filas de productos
                    Expanded(
                      child: ListView.separated(
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          final isLowStock = product['stock'] <= product['minStock'];
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            color: isLowStock ? AppTheme.errorColor.withOpacity(0.05) : null,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    product['code'],
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(product['name']),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      product['category'],
                                      style: const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    '${product['stock']}',
                                    style: TextStyle(
                                      color: isLowStock ? AppTheme.errorColor : null,
                                      fontWeight: isLowStock ? FontWeight.bold : null,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(Formatters.currency(product['price'])),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isLowStock
                                          ? AppTheme.errorColor.withOpacity(0.1)
                                          : AppTheme.successColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isLowStock ? 'Stock Bajo' : 'Normal',
                                      style: TextStyle(
                                        color: isLowStock ? AppTheme.errorColor : AppTheme.successColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () {},
                                        tooltip: 'Editar',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20),
                                        onPressed: () {},
                                        tooltip: 'Eliminar',
                                        color: AppTheme.errorColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
