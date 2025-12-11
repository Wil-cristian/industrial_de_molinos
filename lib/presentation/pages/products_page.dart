import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/providers.dart';
import '../../domain/entities/product.dart';

class ProductsPage extends ConsumerStatefulWidget {
  final bool openNewDialog;

  const ProductsPage({super.key, this.openNewDialog = false});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Todos';

  @override
  void initState() {
    super.initState();
    // Cargar productos desde Supabase
    Future.microtask(() {
      ref.read(productsProvider.notifier).loadProducts();
      // Abrir diálogo si viene de la ruta /products/new
      if (widget.openNewDialog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showProductDialog();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);

    // Filtrar productos
    List<Product> filtered = state.products;

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where(
            (p) =>
                p.code.toLowerCase().contains(query) ||
                p.name.toLowerCase().contains(query),
          )
          .toList();
    }

    if (_selectedCategory != 'Todos') {
      // Filtrar por categoría - aquí usaremos la descripción como categoría temporal
      filtered = filtered.where((p) {
        // Mapear según el precio (implementación temporal)
        if (_selectedCategory == 'Harinas') {
          return p.unitPrice >= 80 && p.unitPrice <= 120;
        }
        if (_selectedCategory == 'Subproductos') return p.unitPrice < 80;
        return true;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Productos'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
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
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Categoría'),
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
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppTheme.errorColor,
                          ),
                          const SizedBox(height: 16),
                          Text('Error: ${state.error}'),
                        ],
                      ),
                    )
                  : Card(
                      child: Column(
                        children: [
                          // Encabezado de tabla
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
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
                            child: filtered.isEmpty
                                ? Center(
                                    child: Text(
                                      'No hay productos',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, index) {
                                      final product = filtered[index];
                                      final isLowStock =
                                          product.stock <= product.minStock;

                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        color: isLowStock
                                            ? AppTheme.errorColor.withOpacity(
                                                0.05,
                                              )
                                            : null,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                product.code,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(product.name),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryColor
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  product.description ??
                                                      'General',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                '${product.stock.toInt()}',
                                                style: TextStyle(
                                                  color: isLowStock
                                                      ? AppTheme.errorColor
                                                      : null,
                                                  fontWeight: isLowStock
                                                      ? FontWeight.bold
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                Formatters.currency(
                                                  product.unitPrice,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isLowStock
                                                      ? AppTheme.errorColor
                                                            .withOpacity(0.1)
                                                      : AppTheme.successColor
                                                            .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  isLowStock
                                                      ? 'Stock Bajo'
                                                      : 'Normal',
                                                  style: TextStyle(
                                                    color: isLowStock
                                                        ? AppTheme.errorColor
                                                        : AppTheme.successColor,
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
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.edit,
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _showProductDialog(
                                                          product: product,
                                                        ),
                                                    tooltip: 'Editar',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                      Icons.delete,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      ref
                                                          .read(
                                                            productsProvider
                                                                .notifier,
                                                          )
                                                          .deleteProduct(
                                                            product.id,
                                                          );
                                                    },
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

  void _showProductDialog({Product? product}) {
    final isEditMode = product != null;
    final nameController = TextEditingController(
      text: isEditMode ? product.name : '',
    );
    final codeController = TextEditingController(
      text: isEditMode ? product.code : '',
    );
    final priceController = TextEditingController(
      text: isEditMode ? product.unitPrice.toString() : '',
    );
    final stockController = TextEditingController(
      text: isEditMode ? product.stock.toString() : '',
    );
    String selectedCategory = isEditMode
        ? (product.description ?? 'Harinas')
        : 'Harinas';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEditMode ? 'Editar Producto' : 'Nuevo Producto'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'Código *',
                  hintText: 'Ej: P006',
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Producto *',
                  hintText: 'Ej: Harina Especial 50kg',
                  prefixIcon: Icon(Icons.inventory_2),
                ),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setDialogState) =>
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoría *',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: ['Harinas', 'Subproductos', 'Otros']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategory = value ?? 'Harinas';
                        });
                      },
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Precio *',
                        hintText: '0.00',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isEditMode
                            ? 'Stock Actual'
                            : 'Stock Inicial',
                        hintText: '0',
                        prefixIcon: const Icon(Icons.inventory),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty ||
                  codeController.text.isEmpty ||
                  priceController.text.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Por favor complete todos los campos obligatorios',
                    ),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }

              if (isEditMode) {
                // Modo edición
                final updatedProduct = Product(
                  id: product.id,
                  code: codeController.text,
                  name: nameController.text,
                  description: selectedCategory,
                  categoryId: product.categoryId,
                  unitPrice: double.tryParse(priceController.text) ?? 0,
                  costPrice: product.costPrice,
                  stock: double.tryParse(stockController.text) ?? product.stock,
                  minStock: product.minStock,
                  unit: product.unit,
                  isActive: product.isActive,
                  createdAt: product.createdAt,
                  updatedAt: DateTime.now(),
                );

                await ref
                    .read(productsProvider.notifier)
                    .updateProduct(updatedProduct);

                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Producto "${nameController.text}" actualizado correctamente',
                      ),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              } else {
                // Modo creación
                final newProduct = Product(
                  id: DateTime.now().toString(),
                  code: codeController.text,
                  name: nameController.text,
                  description: selectedCategory,
                  categoryId: null,
                  unitPrice: double.tryParse(priceController.text) ?? 0,
                  costPrice: (double.tryParse(priceController.text) ?? 0) * 0.6,
                  stock: (double.tryParse(stockController.text) ?? 0),
                  minStock: 20,
                  unit: 'UND',
                  isActive: true,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await ref
                    .read(productsProvider.notifier)
                    .createProduct(newProduct);

                if (mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Producto "${nameController.text}" agregado correctamente',
                      ),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              }
            },
            child: Text(isEditMode ? 'Actualizar' : 'Guardar'),
          ),
        ],
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
