import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/weight_calculator.dart';
import '../../data/providers/providers.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/material.dart' as mat;
import '../widgets/app_sidebar.dart';
import '../widgets/quick_actions_button.dart';
import '../widgets/recipe_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productsProvider.notifier).loadProducts();
      ref.read(inventoryProvider.notifier).loadMaterials();
      if (widget.openNewDialog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNewRecipeDialog();
        });
      }
    });
  }

  /// Muestra el dialog para crear una nueva receta
  Future<void> _showNewRecipeDialog() async {
    final result = await RecipeDialog.show(context);
    if (result == true && mounted) {
      // Recargar productos si se guardó exitosamente
      ref.read(productsProvider.notifier).loadProducts();
    }
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
      body: Stack(
        children: [
          Row(
            children: [
              const AppSidebar(currentRoute: '/products'),
              Expanded(
                child: Column(
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
                      onPressed: () => _showNewRecipeDialog(),
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
                                  onPressed: () => _showNewRecipeDialog(),
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
              ),
            ],
          ),
          const QuickActionsButton(),
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
                            
                            final normalizedCat = _normalizeCategory(cat.toLowerCase());
                            final isCalculable = ['tubo', 'lamina', 'eje'].contains(normalizedCat);
                            
                            return ExpansionTile(
                              title: Row(
                                children: [
                                  Text(_getCategoryName(cat), style: const TextStyle(fontSize: 13)),
                                  if (isCalculable) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_getShapeIcon(normalizedCat), size: 12, color: Colors.blue.shade700),
                                          const SizedBox(width: 4),
                                          Text('Calculable', style: TextStyle(fontSize: 9, color: Colors.blue.shade700)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              dense: true,
                              tilePadding: EdgeInsets.zero,
                              children: materialsInCat.map((material) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: isCalculable 
                                      ? Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _getShapeColor(normalizedCat).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            _getShapeIcon(normalizedCat), 
                                            size: 20, 
                                            color: _getShapeColor(normalizedCat),
                                          ),
                                        )
                                      : null,
                                    title: Text(material.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${material.stock.toStringAsFixed(1)} ${material.unit} disponible', 
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                        Text('S/ ${material.effectivePrice.toStringAsFixed(2)} / ${material.unit}', 
                                          style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                    trailing: FilledButton.icon(
                                      onPressed: () {
                                        if (isCalculable) {
                                          _showDimensionsDialog(
                                            context, 
                                            material, 
                                            normalizedCat,
                                            (component) {
                                              setDialogState(() {
                                                tempComponents.add(component);
                                              });
                                            },
                                          );
                                        } else {
                                          setDialogState(() {
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
                                              category: cat,
                                            ));
                                          });
                                        }
                                      },
                                      icon: Icon(isCalculable ? Icons.calculate : Icons.add, size: 14),
                                      label: Text(isCalculable ? 'Calcular' : 'Agregar', style: const TextStyle(fontSize: 11)),
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        backgroundColor: isCalculable ? Colors.blue : AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
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

  /// Fracciones de pulgada comunes para cálculos
  static const List<String> _inchFractions = [
    '', '1/16', '1/8', '3/16', '1/4', '5/16', '3/8', '7/16', '1/2',
    '9/16', '5/8', '11/16', '3/4', '13/16', '7/8', '15/16',
  ];
  
  /// Convertir fracción de pulgada a milímetros
  double _fractionToMm(String fraction) {
    if (fraction.isEmpty) return 0;
    final parts = fraction.split('/');
    if (parts.length == 2) {
      final num = double.tryParse(parts[0]) ?? 0;
      final den = double.tryParse(parts[1]) ?? 1;
      return (num / den) * 25.4;
    }
    return 0;
  }
  
  /// Convertir pulgadas enteras + fracción a milímetros
  double _inchesToMm(int inches, String fraction) {
    return (inches * 25.4) + _fractionToMm(fraction);
  }

  /// Diálogo para ingresar dimensiones y calcular peso de materiales
  void _showDimensionsDialog(
    BuildContext context,
    mat.Material material,
    String category,
    Function(_TempComponent) onAdd,
  ) {
    // Controllers para mm
    final outerDiameterCtrl = TextEditingController();
    final thicknessCtrl = TextEditingController();
    final lengthCtrl = TextEditingController();
    final widthCtrl = TextEditingController();
    final heightCtrl = TextEditingController();
    final quantityCtrl = TextEditingController(text: '1');
    
    // Controllers para pulgadas (enteros)
    final outerDiameterInchCtrl = TextEditingController();
    final thicknessInchCtrl = TextEditingController();
    final lengthInchCtrl = TextEditingController();
    final widthInchCtrl = TextEditingController();
    final heightInchCtrl = TextEditingController();
    
    // Fracciones seleccionadas
    String outerDiameterFrac = '';
    String thicknessFrac = '';
    String lengthFrac = '';
    String widthFrac = '';
    String heightFrac = '';
    
    double calculatedWeight = 0;
    double totalCost = 0;
    const double density = 7.85; // Acero al carbono
    String selectedType = category == 'tubo' ? 'cylinder' : category == 'lamina' ? 'rectangular_plate' : 'shaft';
    bool useInches = false; // Toggle para mm/pulgadas

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          
          /// Obtener dimensión en mm (ya sea directa o convertida de pulgadas)
          double getDimensionMm(TextEditingController mmCtrl, TextEditingController inchCtrl, String fraction) {
            if (useInches) {
              final inches = int.tryParse(inchCtrl.text) ?? 0;
              return _inchesToMm(inches, fraction);
            } else {
              return double.tryParse(mmCtrl.text) ?? 0;
            }
          }
          
          void recalculate() {
            double weight = 0;
            final quantity = double.tryParse(quantityCtrl.text) ?? 1;
            
            switch (selectedType) {
              case 'cylinder':
                final outerD = getDimensionMm(outerDiameterCtrl, outerDiameterInchCtrl, outerDiameterFrac);
                final thickness = getDimensionMm(thicknessCtrl, thicknessInchCtrl, thicknessFrac);
                final length = getDimensionMm(lengthCtrl, lengthInchCtrl, lengthFrac);
                if (outerD > 0 && thickness > 0 && length > 0) {
                  weight = WeightCalculator.calculateCylinderWeight(outerDiameter: outerD, thickness: thickness, length: length, density: density);
                }
                break;
              case 'rectangular_plate':
                final width = getDimensionMm(widthCtrl, widthInchCtrl, widthFrac);
                final height = getDimensionMm(heightCtrl, heightInchCtrl, heightFrac);
                final thickness = getDimensionMm(thicknessCtrl, thicknessInchCtrl, thicknessFrac);
                if (width > 0 && height > 0 && thickness > 0) {
                  weight = WeightCalculator.calculateRectangularPlateWeight(width: width, height: height, thickness: thickness, density: density);
                }
                break;
              case 'shaft':
                final diameter = getDimensionMm(outerDiameterCtrl, outerDiameterInchCtrl, outerDiameterFrac);
                final length = getDimensionMm(lengthCtrl, lengthInchCtrl, lengthFrac);
                if (diameter > 0 && length > 0) {
                  weight = WeightCalculator.calculateShaftWeight(diameter: diameter, length: length, density: density);
                }
                break;
            }
            
            setDialogState(() {
              calculatedWeight = weight * quantity;
              totalCost = calculatedWeight * material.effectivePrice;
            });
          }

          /// Widget para input con fracciones de pulgada
          Widget buildInchInput(String label, TextEditingController inchCtrl, String currentFrac, Function(String) onFracChanged) {
            return Row(
              children: [
                // Pulgadas enteras
                SizedBox(
                  width: 45,
                  child: TextField(
                    controller: inchCtrl,
                    decoration: const InputDecoration(
                      hintText: '0',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => recalculate(),
                  ),
                ),
                const SizedBox(width: 4),
                // Dropdown de fracciones
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentFrac,
                      isDense: true,
                      items: _inchFractions.map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.isEmpty ? '0' : f, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (v) {
                        onFracChanged(v ?? '');
                        recalculate();
                      },
                    ),
                  ),
                ),
                const Text('"', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            );
          }

          Widget buildDimensionFields() {
            if (useInches) {
              // Modo pulgadas con fracciones
              switch (selectedType) {
                case 'cylinder':
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const SizedBox(width: 70, child: Text('Ø Ext:', style: TextStyle(fontSize: 12))),
                        Expanded(child: buildInchInput('Ø Ext', outerDiameterInchCtrl, outerDiameterFrac, (v) => setDialogState(() => outerDiameterFrac = v))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const SizedBox(width: 70, child: Text('Espesor:', style: TextStyle(fontSize: 12))),
                        Expanded(child: buildInchInput('Espesor', thicknessInchCtrl, thicknessFrac, (v) => setDialogState(() => thicknessFrac = v))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const SizedBox(width: 70, child: Text('Largo:', style: TextStyle(fontSize: 12))),
                        Expanded(child: buildInchInput('Largo', lengthInchCtrl, lengthFrac, (v) => setDialogState(() => lengthFrac = v))),
                      ]),
                    ],
                  );
                case 'rectangular_plate':
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const SizedBox(width: 70, child: Text('Ancho:', style: TextStyle(fontSize: 12))),
                        Expanded(child: buildInchInput('Ancho', widthInchCtrl, widthFrac, (v) => setDialogState(() => widthFrac = v))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const SizedBox(width: 70, child: Text('Alto:', style: TextStyle(fontSize: 12))),
                        Expanded(child: buildInchInput('Alto', heightInchCtrl, heightFrac, (v) => setDialogState(() => heightFrac = v))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const SizedBox(width: 70, child: Text('Espesor:', style: TextStyle(fontSize: 12))),
                        Expanded(child: buildInchInput('Espesor', thicknessInchCtrl, thicknessFrac, (v) => setDialogState(() => thicknessFrac = v))),
                      ]),
                    ],
                  );
                case 'shaft':
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const SizedBox(width: 70, child: Text('Diámetro:', style: TextStyle(fontSize: 12))),
                        Expanded(child: buildInchInput('Diámetro', outerDiameterInchCtrl, outerDiameterFrac, (v) => setDialogState(() => outerDiameterFrac = v))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const SizedBox(width: 70, child: Text('Largo:', style: TextStyle(fontSize: 12))),
                        Expanded(child: buildInchInput('Largo', lengthInchCtrl, lengthFrac, (v) => setDialogState(() => lengthFrac = v))),
                      ]),
                    ],
                  );
                default:
                  return const SizedBox.shrink();
              }
            } else {
              // Modo milímetros (original)
              switch (selectedType) {
                case 'cylinder':
                  return Row(children: [
                    Expanded(child: TextField(controller: outerDiameterCtrl, decoration: const InputDecoration(labelText: 'Ø Ext', suffixText: 'mm', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => recalculate())),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: thicknessCtrl, decoration: const InputDecoration(labelText: 'Espesor', suffixText: 'mm', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => recalculate())),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: lengthCtrl, decoration: const InputDecoration(labelText: 'Largo', suffixText: 'mm', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => recalculate())),
                  ]);
                case 'rectangular_plate':
                  return Row(children: [
                    Expanded(child: TextField(controller: widthCtrl, decoration: const InputDecoration(labelText: 'Ancho', suffixText: 'mm', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => recalculate())),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: heightCtrl, decoration: const InputDecoration(labelText: 'Alto', suffixText: 'mm', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => recalculate())),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: thicknessCtrl, decoration: const InputDecoration(labelText: 'Espesor', suffixText: 'mm', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => recalculate())),
                  ]);
                case 'shaft':
                  return Row(children: [
                    Expanded(child: TextField(controller: outerDiameterCtrl, decoration: const InputDecoration(labelText: 'Diámetro', suffixText: 'mm', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => recalculate())),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: lengthCtrl, decoration: const InputDecoration(labelText: 'Largo', suffixText: 'mm', isDense: true), keyboardType: TextInputType.number, onChanged: (_) => recalculate())),
                  ]);
                default:
                  return const SizedBox.shrink();
              }
            }
          }
          
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Row(
                    children: [
                      Icon(Icons.calculate, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Calcular Peso - ${material.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Selector de tipo con SegmentedButton
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'cylinder', label: Text('Tubo'), icon: Icon(Icons.circle_outlined)),
                      ButtonSegment(value: 'rectangular_plate', label: Text('Lámina'), icon: Icon(Icons.rectangle_outlined)),
                      ButtonSegment(value: 'shaft', label: Text('Eje'), icon: Icon(Icons.horizontal_rule)),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (selection) {
                      setDialogState(() {
                        selectedType = selection.first;
                        // Limpiar valores
                        outerDiameterCtrl.clear(); thicknessCtrl.clear(); lengthCtrl.clear();
                        widthCtrl.clear(); heightCtrl.clear();
                        outerDiameterInchCtrl.clear(); thicknessInchCtrl.clear(); lengthInchCtrl.clear();
                        widthInchCtrl.clear(); heightInchCtrl.clear();
                        outerDiameterFrac = ''; thicknessFrac = ''; lengthFrac = '';
                        widthFrac = ''; heightFrac = '';
                        calculatedWeight = 0; totalCost = 0;
                      });
                    },
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                  const SizedBox(height: 12),
                  
                  // Toggle mm / pulgadas
                  Row(
                    children: [
                      const Text('Unidad: ', style: TextStyle(fontSize: 13)),
                      ChoiceChip(
                        label: const Text('mm'),
                        selected: !useInches,
                        onSelected: (_) => setDialogState(() {
                          useInches = false;
                          calculatedWeight = 0; totalCost = 0;
                        }),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Pulgadas'),
                        selected: useInches,
                        onSelected: (_) => setDialogState(() {
                          useInches = true;
                          calculatedWeight = 0; totalCost = 0;
                        }),
                        avatar: useInches ? null : const Icon(Icons.straighten, size: 16),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (useInches) ...[
                        const SizedBox(width: 8),
                        Text('(fracciones)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Campos de dimensiones
                  buildDimensionFields(),
                  const SizedBox(height: 12),
                  
                  // Cantidad
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: quantityCtrl,
                          decoration: const InputDecoration(labelText: 'Cantidad', isDense: true),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => recalculate(),
                        ),
                      ),
                      const Spacer(),
                      Text('Precio: S/ ${material.effectivePrice.toStringAsFixed(2)}/KG', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Resultado
                  if (calculatedWeight > 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Peso: ${calculatedWeight.toStringAsFixed(3)} KG', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ]),
                          Text('S/ ${totalCost.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // Botones
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: calculatedWeight > 0 ? () {
                          Navigator.pop(context);
                          // Calcular dimensiones en mm para guardar
                          final outerD = getDimensionMm(outerDiameterCtrl, outerDiameterInchCtrl, outerDiameterFrac);
                          final thick = getDimensionMm(thicknessCtrl, thicknessInchCtrl, thicknessFrac);
                          final len = getDimensionMm(lengthCtrl, lengthInchCtrl, lengthFrac);
                          final wid = getDimensionMm(widthCtrl, widthInchCtrl, widthFrac);
                          final hei = getDimensionMm(heightCtrl, heightInchCtrl, heightFrac);
                          
                          String dimDesc = '';
                          String cat = selectedType == 'cylinder' ? 'tubo' : selectedType == 'rectangular_plate' ? 'lamina' : 'eje';
                          
                          // Descripción según el modo usado
                          if (useInches) {
                            // Formato en pulgadas
                            String fmtInch(TextEditingController ctrl, String frac) {
                              final i = ctrl.text.isEmpty ? '0' : ctrl.text;
                              return frac.isEmpty ? '$i"' : '$i $frac"';
                            }
                            if (selectedType == 'cylinder') {
                              dimDesc = 'Ø${fmtInch(outerDiameterInchCtrl, outerDiameterFrac)}×${fmtInch(thicknessInchCtrl, thicknessFrac)}×${fmtInch(lengthInchCtrl, lengthFrac)}';
                            } else if (selectedType == 'rectangular_plate') {
                              dimDesc = '${fmtInch(widthInchCtrl, widthFrac)}×${fmtInch(heightInchCtrl, heightFrac)}×${fmtInch(thicknessInchCtrl, thicknessFrac)}';
                            } else {
                              dimDesc = 'Ø${fmtInch(outerDiameterInchCtrl, outerDiameterFrac)}×${fmtInch(lengthInchCtrl, lengthFrac)}';
                            }
                          } else {
                            // Formato en mm
                            if (selectedType == 'cylinder') {
                              dimDesc = 'Ø${outerDiameterCtrl.text}×${thicknessCtrl.text}×${lengthCtrl.text}mm';
                            } else if (selectedType == 'rectangular_plate') {
                              dimDesc = '${widthCtrl.text}×${heightCtrl.text}×${thicknessCtrl.text}mm';
                            } else {
                              dimDesc = 'Ø${outerDiameterCtrl.text}×${lengthCtrl.text}mm';
                            }
                          }
                          
                          onAdd(_TempComponent(
                            materialId: material.id,
                            name: '${material.name} ($dimDesc)',
                            description: dimDesc,
                            unit: 'KG',
                            unitCost: material.effectivePrice,
                            quantity: calculatedWeight,
                            calculatedWeight: calculatedWeight,
                            category: cat,
                            outerDiameter: outerD > 0 ? outerD : null,
                            thickness: thick > 0 ? thick : null,
                            length: len > 0 ? len : null,
                            width: wid > 0 ? wid : null,
                            height: hei > 0 ? hei : null,
                            density: density,
                          ));
                        } : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Normaliza la categoría a formato estándar (singular, sin acentos, minúsculas)
  String _normalizeCategory(String category) {
    final cat = category.toLowerCase().trim();
    // Tubos
    if (cat.contains('tubo')) return 'tubo';
    // Láminas (con o sin acento)
    if (cat.contains('lamina') || cat.contains('lámina')) return 'lamina';
    // Ejes
    if (cat.contains('eje')) return 'eje';
    // Rodamientos
    if (cat.contains('rodamiento')) return 'rodamiento';
    // Tornillería
    if (cat.contains('tornill')) return 'tornilleria';
    // Consumibles
    if (cat.contains('consumible')) return 'consumible';
    // Pintura
    if (cat.contains('pintura')) return 'pintura';
    return cat;
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

  /// Ícono de forma según categoría
  IconData _getShapeIcon(String category) {
    switch (category) {
      case 'tubo': return Icons.circle_outlined; // Tubo hueco (cilindro)
      case 'lamina': return Icons.crop_square; // Lámina (rectángulo)
      case 'eje': return Icons.horizontal_rule; // Eje sólido (barra)
      default: return Icons.category;
    }
  }

  /// Color de forma según categoría
  Color _getShapeColor(String category) {
    switch (category) {
      case 'tubo': return Colors.orange;
      case 'lamina': return Colors.blue;
      case 'eje': return Colors.purple;
      default: return Colors.grey;
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
  String? category; // tubo, lamina, eje, etc.
  
  // Dimensiones para cálculo de peso
  double? outerDiameter; // mm - tubos, ejes, tapas
  double? innerDiameter; // mm - tubos (diámetro interior)
  double? thickness;     // mm - espesor de pared (tubos) o grosor (láminas)
  double? length;        // mm - largo
  double? width;         // mm - ancho (láminas)
  double? height;        // mm - alto (láminas)
  double density;        // kg/dm³ - densidad del material

  _TempComponent({
    this.materialId,
    required this.name,
    this.description,
    required this.unit,
    required this.unitCost,
    required this.quantity,
    this.calculatedWeight = 0,
    this.category,
    this.outerDiameter,
    this.thickness,
    this.length,
    this.width,
    this.height,
    this.density = 7.85, // Acero por defecto
  });
}
