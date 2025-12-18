import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/providers.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/material.dart' as mat;

/// Página de Productos/Recetas
/// Muestra productos que son plantillas (recetas) compuestas de materiales del inventario
class ProductsPage extends ConsumerStatefulWidget {
  final bool openNewDialog;

  const ProductsPage({super.key, this.openNewDialog = false});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final _searchController = TextEditingController();
  final bool _showOnlyRecipes = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productsProvider.notifier).loadProducts();
      ref.read(inventoryProvider.notifier).loadMaterials();
      if (widget.openNewDialog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showRecipeDialog();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> get _filteredProducts {
    final state = ref.watch(productsProvider);
    var products = state.products;

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      products = products
          .where((p) =>
              p.code.toLowerCase().contains(query) ||
              p.name.toLowerCase().contains(query))
          .toList();
    }

    // Aquí podríamos filtrar solo recetas cuando tengamos el campo is_recipe
    return products;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
                      onPressed: () => context.go('/'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Productos / Recetas',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Text(
                            '${state.products.length} productos registrados',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _buildQuickStat(
                      'Recetas',
                      '${state.products.length}',
                      Colors.blue,
                      Icons.receipt_long,
                    ),
                    const SizedBox(width: 20),
                    FilledButton.icon(
                      onPressed: _showRecipeDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nueva Receta'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Búsqueda
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por código o nombre...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de productos
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
                              onPressed: () => ref.read(productsProvider.notifier).loadProducts(),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : _filteredProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay recetas',
                                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Crea una receta para poder usarla en cotizaciones',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: _showRecipeDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Crear Primera Receta'),
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildProductsGrid(),
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

  Widget _buildProductsGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showRecipeDetail(product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long, color: AppTheme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.code,
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'view', child: Text('Ver Componentes')),
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                      const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                    onSelected: (value) => _handleMenuAction(value, product),
                  ),
                ],
              ),
              const Spacer(),
              if (product.description != null)
                Text(
                  product.description!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const Spacer(),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Precio: \$${Helpers.formatNumber(product.unitPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Receta',
                      style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action, Product product) {
    switch (action) {
      case 'view':
        _showRecipeDetail(product);
        break;
      case 'edit':
        _showRecipeDialog(product: product);
        break;
      case 'duplicate':
        _duplicateRecipe(product);
        break;
      case 'delete':
        _confirmDelete(product);
        break;
    }
  }

  void _showRecipeDetail(Product product) async {
    // Cargar componentes
    await ref.read(componentsProvider.notifier).loadComponents(product.id);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final compState = ref.watch(componentsProvider);
          
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontSize: 18)),
                      Text(product.code, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 600,
              height: 400,
              child: compState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : compState.components.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('Sin componentes', style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showRecipeDialog(product: product);
                                },
                                child: const Text('Agregar componentes'),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Tabla de componentes
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Expanded(flex: 3, child: Text('#', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                          const Expanded(flex: 10, child: Text('Componente', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                                          const Expanded(flex: 4, child: Text('Cantidad', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11), textAlign: TextAlign.right)),
                                          const Expanded(flex: 4, child: Text('Peso', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11), textAlign: TextAlign.right)),
                                          const Expanded(flex: 4, child: Text('Costo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11), textAlign: TextAlign.right)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.separated(
                                        itemCount: compState.components.length,
                                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                                        itemBuilder: (context, index) {
                                          final comp = compState.components[index];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            child: Row(
                                              children: [
                                                Expanded(flex: 3, child: Text('${index + 1}', style: TextStyle(fontSize: 11, color: Colors.grey[600]))),
                                                Expanded(
                                                  flex: 10,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(comp.name, style: const TextStyle(fontSize: 12)),
                                                      if (comp.description != null)
                                                        Text(comp.description!, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(flex: 4, child: Text('${comp.quantity} ${comp.unit}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                                                Expanded(flex: 4, child: Text('${comp.calculatedWeight.toStringAsFixed(2)} kg', style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                                                Expanded(flex: 4, child: Text('\$${comp.totalCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
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
                            const SizedBox(height: 16),
                            // Totales
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${compState.components.length} componentes'),
                                  Row(
                                    children: [
                                      Text('Peso: ${compState.totalWeight.toStringAsFixed(2)} kg'),
                                      const SizedBox(width: 24),
                                      Text(
                                        'Costo: \$${compState.totalCost.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
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
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showRecipeDialog(product: product);
                },
                child: const Text('Editar Receta'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRecipeDialog({Product? product}) async {
    final isEditing = product != null;
    final codeCtrl = TextEditingController(text: product?.code ?? '');
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final descCtrl = TextEditingController(text: product?.description ?? '');
    final laborCtrl = TextEditingController(text: '0');
    double lossPercentage = 5.0; // 5% pérdidas de material
    
    // Lista temporal de componentes
    List<_TempComponent> tempComponents = [];
    
    // Si estamos editando, cargar componentes existentes
    if (isEditing) {
      await ref.read(componentsProvider.notifier).loadComponents(product.id);
      final existingComponents = ref.read(componentsProvider).components;
      tempComponents = existingComponents.map((c) => _TempComponent(
        materialId: c.materialId,
        name: c.name,
        description: c.description,
        unit: c.unit,
        unitCost: c.unitCost,
        quantity: c.quantity,
        calculatedWeight: c.calculatedWeight,
      )).toList();
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final inventoryState = ref.watch(inventoryProvider);
          
          return AlertDialog(
            title: Text(isEditing ? 'Editar Receta' : 'Nueva Receta'),
            content: SizedBox(
              width: 700,
              height: 500,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Panel izquierdo: Datos del producto
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Datos del Producto', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                          const SizedBox(height: 12),
                          TextField(
                            controller: codeCtrl,
                            decoration: const InputDecoration(labelText: 'Código *', isDense: true),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(labelText: 'Nombre *', isDense: true),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descCtrl,
                            decoration: const InputDecoration(labelText: 'Descripción', isDense: true),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),
                          // Sección de costos adicionales
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.engineering, size: 16, color: Colors.orange[700]),
                                    const SizedBox(width: 6),
                                    Text('Mano de Obra', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange[700], fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: laborCtrl,
                                  decoration: const InputDecoration(
                                    prefixText: 'S/ ',
                                    isDense: true,
                                    hintText: '0.00',
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Porcentaje de pérdidas
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber, size: 16, color: Colors.red[700]),
                                    const SizedBox(width: 6),
                                    Text('Pérdidas Material', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red[700], fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        value: lossPercentage,
                                        min: 0,
                                        max: 20,
                                        divisions: 20,
                                        activeColor: Colors.red[400],
                                        onChanged: (v) => setDialogState(() => lossPercentage = v),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('${lossPercentage.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700], fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Agregar material
                          Text('Agregar Material', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          ...inventoryState.categories.map((cat) {
                            final materialsInCat = inventoryState.materials.where((m) => m.category == cat).toList();
                            if (materialsInCat.isEmpty) return const SizedBox.shrink();
                            
                            return ExpansionTile(
                              title: Text(_getCategoryName(cat), style: const TextStyle(fontSize: 13)),
                              dense: true,
                              tilePadding: EdgeInsets.zero,
                              children: materialsInCat.map((material) => ListTile(
                                dense: true,
                                title: Text(material.name, style: const TextStyle(fontSize: 12)),
                                subtitle: Text('${material.stock} ${material.unit} disponible', style: const TextStyle(fontSize: 10)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 20),
                                  onPressed: () {
                                    setDialogState(() {
                                      // Calcular peso inicial (1 unidad del material)
                                      double initialWeight = 0;
                                      if (material.unit == 'KG') {
                                        initialWeight = 1;
                                      } else if (material.fixedWeight != null) {
                                        initialWeight = material.fixedWeight!;
                                      }
                                      
                                      tempComponents.add(_TempComponent(
                                        materialId: material.id,
                                        name: material.name,
                                        description: material.description,
                                        unit: material.unit,
                                        unitCost: material.effectivePrice,
                                        quantity: 1,
                                        calculatedWeight: initialWeight,
                                      ));
                                    });
                                  },
                                ),
                              )).toList(),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(),
                  // Panel derecho: Componentes agregados
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Componentes (${tempComponents.length})', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                            if (tempComponents.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => setDialogState(() => tempComponents.clear()),
                                icon: const Icon(Icons.clear_all, size: 16),
                                label: const Text('Limpiar', style: TextStyle(fontSize: 11)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: tempComponents.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inbox_outlined, size: 40, color: Colors.grey[400]),
                                      const SizedBox(height: 8),
                                      Text('Agrega materiales del panel izquierdo', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: tempComponents.length,
                                  itemBuilder: (context, index) {
                                    final comp = tempComponents[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(comp.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                                                  Text('\$${comp.unitCost.toStringAsFixed(2)} / ${comp.unit}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                                ],
                                              ),
                                            ),
                                            SizedBox(
                                              width: 80,
                                              child: TextField(
                                                controller: TextEditingController(text: comp.quantity.toString()),
                                                decoration: InputDecoration(
                                                  labelText: comp.unit,
                                                  isDense: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                ),
                                                keyboardType: TextInputType.number,
                                                onChanged: (v) {
                                                  final newQty = double.tryParse(v) ?? 0;
                                                  comp.quantity = newQty;
                                                  // Actualizar peso si es por KG
                                                  if (comp.unit == 'KG') {
                                                    comp.calculatedWeight = newQty;
                                                  }
                                                  setDialogState(() {});
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '\$${(comp.quantity * comp.unitCost).toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                              onPressed: () => setDialogState(() => tempComponents.removeAt(index)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        // Resumen de costos
                        const Divider(),
                        Builder(
                          builder: (context) {
                            final materialCost = tempComponents.fold(0.0, (sum, c) => sum + (c.quantity * c.unitCost));
                            final lossCost = materialCost * (lossPercentage / 100);
                            final laborCost = double.tryParse(laborCtrl.text) ?? 0;
                            final totalPrice = materialCost + lossCost + laborCost;
                            
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                children: [
                                  // Materiales
                                  _buildCostRow(
                                    'Materiales (${tempComponents.length} items)',
                                    materialCost,
                                    Icons.inventory_2,
                                    Colors.blue,
                                  ),
                                  const SizedBox(height: 6),
                                  // Pérdidas
                                  _buildCostRow(
                                    'Pérdidas (${lossPercentage.toStringAsFixed(0)}%)',
                                    lossCost,
                                    Icons.warning_amber,
                                    Colors.red,
                                  ),
                                  const SizedBox(height: 6),
                                  // Mano de obra
                                  _buildCostRow(
                                    'Mano de Obra',
                                    laborCost,
                                    Icons.engineering,
                                    Colors.orange,
                                  ),
                                  const Divider(height: 16),
                                  // Total
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.monetization_on, size: 18, color: Colors.green[700]),
                                          const SizedBox(width: 6),
                                          Text('PRECIO DE VENTA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700], fontSize: 12)),
                                        ],
                                      ),
                                      Text(
                                        'S/ ${totalPrice.toStringAsFixed(2)}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[700]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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
                  if (codeCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código y nombre son requeridos')),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  // Calcular totales
                  final materialCost = tempComponents.fold(0.0, (sum, c) => sum + (c.quantity * c.unitCost));
                  final lossCost = materialCost * (lossPercentage / 100);
                  final laborCost = double.tryParse(laborCtrl.text) ?? 0;
                  final totalPrice = materialCost + lossCost + laborCost;
                  final totalWeight = tempComponents.fold(0.0, (sum, c) => sum + c.calculatedWeight);
                  
                  final newProduct = Product(
                    id: product?.id ?? '',
                    code: codeCtrl.text,
                    name: nameCtrl.text,
                    description: descCtrl.text.isEmpty ? null : descCtrl.text,
                    unitPrice: totalPrice, // Precio calculado automáticamente
                    costPrice: materialCost + lossCost, // Costo de materiales + pérdidas
                    stock: 0,
                    minStock: 0,
                    unit: 'UND',
                    isRecipe: true,
                    recipeDescription: descCtrl.text.isEmpty ? null : descCtrl.text,
                    totalWeight: totalWeight,
                    totalCost: materialCost,
                    createdAt: product?.createdAt ?? DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  String productId;
                  
                  if (isEditing) {
                    await ref.read(productsProvider.notifier).updateProduct(newProduct);
                    productId = product.id;
                  } else {
                    final created = await ref.read(productsProvider.notifier).createProduct(newProduct);
                    productId = created?.id ?? '';
                  }
                  
                  // Guardar componentes solo si tenemos un productId válido
                  if (productId.isNotEmpty && tempComponents.isNotEmpty) {
                    // Eliminar componentes anteriores si estamos editando
                    if (isEditing) {
                      await InventoryDataSource.deleteAllComponents(productId);
                    }
                    
                    // Crear nuevos componentes
                    for (int i = 0; i < tempComponents.length; i++) {
                      final comp = tempComponents[i];
                      final component = mat.ProductComponent(
                        id: '',
                        productId: productId,
                        materialId: comp.materialId,
                        name: comp.name,
                        description: comp.description,
                        quantity: comp.quantity,
                        unit: comp.unit,
                        calculatedWeight: comp.calculatedWeight,
                        unitCost: comp.unitCost,
                        totalCost: comp.quantity * comp.unitCost,
                        sortOrder: i + 1,
                      );
                      await InventoryDataSource.createComponent(component);
                    }
                    
                    // Actualizar totales del producto
                    await InventoryDataSource.updateProductTotals(productId);
                  }

                  if (mounted) {
                    // Recargar productos para ver los cambios
                    await ref.read(productsProvider.notifier).loadProducts();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEditing ? 'Receta actualizada' : 'Receta creada exitosamente')),
                    );
                  }
                },
                child: Text(isEditing ? 'Guardar' : 'Crear Receta'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _duplicateRecipe(Product product) async {
    final newProduct = Product(
      id: '',
      code: '${product.code}-COPY',
      name: '${product.name} (Copia)',
      description: product.description,
      unitPrice: product.unitPrice,
      costPrice: product.costPrice,
      stock: 0,
      minStock: 0,
      unit: product.unit,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.read(productsProvider.notifier).createProduct(newProduct);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receta duplicada')),
      );
    }
  }

  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Receta'),
        content: Text('¿Estás seguro de eliminar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(productsProvider.notifier).deleteProduct(product.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Receta eliminada')),
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
      default: return category;
    }
  }

  Widget _buildCostRow(String label, double amount, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          ],
        ),
        Text(
          'S/ ${amount.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: color),
        ),
      ],
    );
  }
}

/// Clase temporal para componentes en el diálogo
class _TempComponent {
  String? materialId;
  String name;
  String? description;
  String unit;
  double unitCost;
  double quantity;
  double calculatedWeight;

  _TempComponent({
    this.materialId,
    required this.name,
    this.description,
    required this.unit,
    required this.unitCost,
    required this.quantity,
    this.calculatedWeight = 0,
  });
}
