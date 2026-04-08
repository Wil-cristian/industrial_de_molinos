import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/helpers.dart';
import '../../domain/entities/composite_product.dart';
import '../../domain/entities/inventory_material.dart';
import '../../domain/entities/material.dart' as mat;
import '../../data/providers/composite_products_provider.dart';
import '../../data/providers/inventory_provider.dart';
import '../../data/providers/settings_provider.dart';
import '../../domain/entities/company_settings.dart';
import '../widgets/material_form_dialog.dart';

class CompositeProductsPage extends ConsumerStatefulWidget {
  const CompositeProductsPage({super.key});

  @override
  ConsumerState<CompositeProductsPage> createState() =>
      _CompositeProductsPageState();
}

class _CompositeProductsPageState extends ConsumerState<CompositeProductsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(compositeProductsProvider.notifier).loadProducts();
      ref.read(settingsProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(compositeProductsProvider);
    final filteredProducts = state.filteredProducts;

    // Sync dynamic categories from settings
    final settingsState = ref.watch(settingsProvider);
    if (settingsState.categories.isNotEmpty) {
      ProductCategories.setCategories(
        settingsState.categories.map((c) => c.name).toList(),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.white,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 980;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () => context.go('/'),
                            tooltip: 'Volver al menú',
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Productos',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${state.products.length} productos registrados',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildQuickStat(
                            'Compuestos',
                            '${state.products.where((p) => p.components.isNotEmpty).length}',
                            const Color(0xFF1565C0),
                            Icons.settings,
                          ),
                          _buildQuickStat(
                            'Simples',
                            '${state.products.where((p) => p.components.isEmpty).length}',
                            const Color(0xFF2E7D32),
                            Icons.category,
                          ),
                          FilledButton.icon(
                            onPressed: () => _showCreateProductDialog(),
                            icon: const Icon(Icons.add),
                            label: Text(isNarrow ? 'Nuevo' : 'Nuevo Producto'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 16,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: isNarrow
                                ? constraints.maxWidth
                                : constraints.maxWidth * 0.62,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Buscar por nombre o código...',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (value) => ref
                                  .read(compositeProductsProvider.notifier)
                                  .setSearchQuery(value),
                            ),
                          ),
                          SizedBox(
                            width: isNarrow
                                ? constraints.maxWidth
                                : constraints.maxWidth * 0.34,
                            child: DropdownButtonFormField<String>(
                              value: state.selectedCategory,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Categoría',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'todos',
                                  child: Text('Todas'),
                                ),
                                ...ProductCategories.all.map(
                                  (cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(
                                      ProductCategories.getDisplayName(cat),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) => ref
                                  .read(compositeProductsProvider.notifier)
                                  .setSelectedCategory(value ?? 'todos'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Contenido ──
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                  ? _buildErrorState(state.error!)
                  : filteredProducts.isEmpty
                  ? _buildEmptyState()
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1400
                              ? 4
                              : constraints.maxWidth >= 1000
                              ? 3
                              : constraints.maxWidth >= 600
                              ? 2
                              : 1;
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  childAspectRatio: columns == 1
                                      ? 1.8
                                      : columns == 2
                                      ? 2.0
                                      : 1.6,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: filteredProducts.length,
                            itemBuilder: (context, index) {
                              return _buildProductCard(filteredProducts[index]);
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  WIDGETS AUXILIARES
  // ═══════════════════════════════════════════════════

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: const Color(0xFFE57373)),
          const SizedBox(height: 16),
          Text('Error: $error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () =>
                ref.read(compositeProductsProvider.notifier).loadProducts(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.layers_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay productos',
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primer producto o escanea una factura de venta',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showCreateProductDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Crear Primer Producto'),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
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

  Widget _buildProductCard(CompositeProduct product) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _showProductDetail(product),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(
                        product.category ?? '',
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(product.category ?? ''),
                      color: _getCategoryColor(product.category ?? ''),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          product.code,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (value) => _handleProductAction(value, product),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 18),
                            SizedBox(width: 8),
                            Text('Duplicar'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete,
                              size: 18,
                              color: Color(0xFFC62828),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: Color(0xFFC62828)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Descripción + componentes (se adapta al espacio disponible)
              Expanded(
                child: ClipRect(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Descripción
                      if (product.description != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            product.description!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                      // Lista de componentes dentro de la tarjeta
                      if (product.components.isNotEmpty)
                        ...product.components
                            .take(3)
                            .map(
                              (comp) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${comp.quantity}×',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        comp.label != null &&
                                                comp.label!.isNotEmpty
                                            ? '${comp.label} (${comp.materialName ?? 'Componente'})'
                                            : comp.materialName ?? 'Componente',
                                        style: const TextStyle(fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${Helpers.formatNumber(comp.totalWeight)} kg',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      if (product.components.length > 3)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '+${product.components.length - 3} más...',
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Stats
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      'Compra',
                      '\$ ${Helpers.formatNumber(product.materialsCostPrice)}',
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: const Color(0xFFE0E0E0),
                    ),
                    _buildStatColumn(
                      'Venta',
                      '\$ ${Helpers.formatNumber(product.customPrice ?? product.materialsCost)}',
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: const Color(0xFFE0E0E0),
                    ),
                    _buildStatColumn(
                      'Margen',
                      '${product.realProfitMargin.toStringAsFixed(1)}%',
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

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  HELPERS VISUALES
  // ═══════════════════════════════════════════════════

  Color _getCategoryColor(String category) {
    final cats = ProductCategories.all;
    final idx = cats.indexWhere(
      (c) => c.toLowerCase() == category.toLowerCase(),
    );
    const palette = [
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFFF9A825),
      Color(0xFF7B1FA2),
      Color(0xFF009688),
      Color(0xFF9E9E9E),
      Color(0xFFE65100),
      Color(0xFF283593),
      Color(0xFFC62828),
      Color(0xFF00695C),
    ];
    if (idx >= 0) return palette[idx % palette.length];
    return const Color(0xFF9E9E9E);
  }

  IconData _getCategoryIcon(String category) {
    final cats = ProductCategories.all;
    final idx = cats.indexWhere(
      (c) => c.toLowerCase() == category.toLowerCase(),
    );
    const icons = [
      Icons.settings,
      Icons.conveyor_belt,
      Icons.local_drink,
      Icons.foundation,
      Icons.precision_manufacturing,
      Icons.category,
      Icons.build,
      Icons.architecture,
      Icons.engineering,
      Icons.construction,
    ];
    if (idx >= 0) return icons[idx % icons.length];
    return Icons.category;
  }

  // ═══════════════════════════════════════════════════
  //  ACCIONES
  // ═══════════════════════════════════════════════════

  void _handleProductAction(String action, CompositeProduct product) {
    switch (action) {
      case 'edit':
        _showCreateProductDialog(product: product);
        break;
      case 'duplicate':
        _duplicateProduct(product);
        break;
      case 'delete':
        _confirmDelete(product);
        break;
    }
  }

  Future<void> _duplicateProduct(CompositeProduct product) async {
    final success = await ref
        .read(compositeProductsProvider.notifier)
        .duplicateProduct(product.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Producto duplicado exitosamente' : 'Error al duplicar',
          ),
          backgroundColor: success
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════
  //  DIALOGO DE DETALLE
  // ═══════════════════════════════════════════════════

  void _showProductDetail(CompositeProduct product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 750,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    _getCategoryIcon(product.category ?? ''),
                    color: _getCategoryColor(product.category ?? ''),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Código: ${product.code}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Venta: \$ ${Helpers.formatNumber(product.materialsCost)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Compra: \$ ${Helpers.formatNumber(product.materialsCostPrice)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${Helpers.formatNumber(product.totalWeight)} kg',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (product.description != null) ...[
                Text(
                  product.description!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Componentes
              Row(
                children: [
                  const Icon(Icons.list_alt, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Componentes (${product.componentCount})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: product.components.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final comp = product.components[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            // Número de orden
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 4),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1),
                              child: Text(
                                '${comp.quantity}×',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (comp.label != null &&
                                      comp.label!.isNotEmpty)
                                    Text(
                                      comp.label!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  Text(
                                    comp.materialName ?? 'Componente',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    comp.dimensionsDescription,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'V: \$ ${Helpers.formatNumber(comp.totalPrice)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'C: \$ ${Helpers.formatNumber(comp.totalCostPrice)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  '${Helpers.formatNumber(comp.totalWeight)} kg',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Resumen de costos
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildCostRow(
                      'Precio Compra',
                      '\$ ${Helpers.formatNumber(product.materialsCostPrice)}',
                    ),
                    _buildCostRow(
                      'Venta Materiales',
                      '\$ ${Helpers.formatNumber(product.materialsCost)}',
                    ),
                    if (product.customPrice != null)
                      _buildCostRow(
                        'Precio Final',
                        '\$ ${Helpers.formatNumber(product.customPrice!)}',
                        isBold: true,
                        valueColor: Theme.of(context).colorScheme.primary,
                      ),
                    _buildCostRow(
                      'Peso total',
                      '${Helpers.formatNumber(product.totalWeight)} kg',
                    ),
                    const Divider(),
                    _buildCostRow(
                      'Ganancia',
                      '\$ ${Helpers.formatNumber((product.customPrice ?? product.materialsCost) - product.materialsCostPrice)}',
                      isBold: true,
                      valueColor:
                          (product.customPrice ?? product.materialsCost) -
                                  product.materialsCostPrice >
                              0
                          ? const Color(0xFF388E3C)
                          : const Color(0xFFD32F2F),
                    ),
                    _buildCostRow(
                      'Margen',
                      '${product.realProfitMargin.toStringAsFixed(1)}%',
                      valueColor: product.realProfitMargin > 0
                          ? const Color(0xFF388E3C)
                          : const Color(0xFFD32F2F),
                    ),
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

  Widget _buildCostRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color:
                  valueColor ??
                  (isBold ? Theme.of(context).colorScheme.primary : null),
              fontSize: isBold ? 16 : null,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ELIMINAR
  // ═══════════════════════════════════════════════════

  void _confirmDelete(CompositeProduct product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Color(0xFFC62828)),
            SizedBox(width: 12),
            Text('Confirmar eliminación'),
          ],
        ),
        content: Text(
          '¿Está seguro de eliminar el producto "${product.name}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(compositeProductsProvider.notifier)
                  .deleteProduct(product.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Producto eliminado' : 'Error al eliminar',
                    ),
                    backgroundColor: success
                        ? const Color(0xFFC62828)
                        : const Color(0xFFF9A825),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  CREAR / EDITAR DIALOG
  // ═══════════════════════════════════════════════════

  void _showCreateProductDialog({CompositeProduct? product}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CompositeProductFormDialog(
        product: product,
        onSave: (savedProduct) async {
          final notifier = ref.read(compositeProductsProvider.notifier);
          bool success;
          if (product != null) {
            success = await notifier.updateProduct(
              savedProduct.copyWith(id: product.id),
            );
          } else {
            success = await notifier.createProduct(savedProduct);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? (product != null
                            ? 'Producto actualizado'
                            : 'Producto creado exitosamente')
                      : 'Error al guardar',
                ),
                backgroundColor: success
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
              ),
            );
          }
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  DIALOG DE FORMULARIO PARA CREAR/EDITAR PRODUCTO
// ═══════════════════════════════════════════════════════

class _CompositeProductFormDialog extends ConsumerStatefulWidget {
  final CompositeProduct? product;
  final Future<void> Function(CompositeProduct product) onSave;

  const _CompositeProductFormDialog({this.product, required this.onSave});

  @override
  ConsumerState<_CompositeProductFormDialog> createState() =>
      _CompositeProductFormDialogState();
}

class _CompositeProductFormDialogState
    extends ConsumerState<_CompositeProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Split ratio for calculator vs component list (0.0 to 1.0)
  double _topPanelRatio = 0.55;

  // Campos del producto
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;
  late TextEditingController _laborHoursController;
  late TextEditingController _laborRateController;
  late TextEditingController _indirectCostsController;
  late TextEditingController _profitMarginController;
  late TextEditingController _customPriceController;

  // Lista de componentes agregados
  late List<_ComponentFormData> _components;

  // ── Estado del panel de agregar componente ──
  String _addMode = 'calculado'; // 'calculado' | 'directo'
  String?
  _selectedCalculationType; // 'lamina' | 'tubo' | 'eje' | 'eje_cuadrado'
  mat.Material? _selectedMaterial;
  mat.Material? _selectedDirectMaterial;
  double _calculatedWeight = 0;
  double _wastePercentage = 5;
  String _searchQuery = '';

  // Controllers para calculadora
  final _largoController = TextEditingController();
  final _anchoController = TextEditingController();
  final _espesorController = TextEditingController(text: '1/4');
  final _diametroExtController = TextEditingController(text: '1');
  final _espesorParedController = TextEditingController(text: '1/4');
  final _diametroController = TextEditingController(text: '1');
  final _ladoController = TextEditingController(
    text: '1',
  ); // Lado de eje cuadrado
  final _labelController = TextEditingController(); // Título de la pieza
  final _cantidadController = TextEditingController(text: '1');
  final _directQuantityController = TextEditingController(text: '1');
  final _wasteController = TextEditingController(text: '5');

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _codeController = TextEditingController(text: p?.code ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _selectedCategory = p?.category ?? ProductCategories.all.first;
    // Ensure selected category exists in list (case-insensitive)
    final matchIdx = ProductCategories.all.indexWhere(
      (c) => c.toLowerCase() == _selectedCategory.toLowerCase(),
    );
    if (matchIdx >= 0) {
      _selectedCategory = ProductCategories.all[matchIdx];
    } else if (ProductCategories.all.isNotEmpty) {
      _selectedCategory = ProductCategories.all.first;
    }
    _laborHoursController = TextEditingController(
      text: (p?.laborHours ?? 0).toString(),
    );
    _laborRateController = TextEditingController(
      text: (p?.laborRate ?? 25).toString(),
    );
    _indirectCostsController = TextEditingController(
      text: (p?.indirectCosts ?? 0).toString(),
    );
    _profitMarginController = TextEditingController(
      text: (p?.profitMargin ?? 20).toString(),
    );
    _customPriceController = TextEditingController(
      text: p?.customPrice != null ? p!.customPrice!.toStringAsFixed(0) : '',
    );

    _components =
        p?.components
            .map((c) => _ComponentFormData.fromComponent(c))
            .toList() ??
        [];

    // Cargar inventario
    Future.microtask(() {
      ref.read(inventoryProvider.notifier).loadMaterials();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _laborHoursController.dispose();
    _laborRateController.dispose();
    _indirectCostsController.dispose();
    _profitMarginController.dispose();
    _customPriceController.dispose();
    _largoController.dispose();
    _anchoController.dispose();
    _espesorController.dispose();
    _diametroExtController.dispose();
    _espesorParedController.dispose();
    _diametroController.dispose();
    _ladoController.dispose();
    _labelController.dispose();
    _cantidadController.dispose();
    _directQuantityController.dispose();
    _wasteController.dispose();
    super.dispose();
  }

  CompositeProduct _buildProduct() {
    return CompositeProduct(
      id: widget.product?.id ?? '',
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      category: _selectedCategory,
      components: _components.map((c) => c.toComponent()).toList(),
      laborHours: double.tryParse(_laborHoursController.text) ?? 0,
      laborRate: double.tryParse(_laborRateController.text) ?? 25,
      indirectCosts: double.tryParse(_indirectCostsController.text) ?? 0,
      profitMargin: double.tryParse(_profitMarginController.text) ?? 20,
      customPrice: _customPriceController.text.trim().isNotEmpty
          ? double.tryParse(_customPriceController.text.trim())
          : null,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Validate _selectedCategory against current list to prevent dropdown crash
    if (!ProductCategories.all.contains(_selectedCategory)) {
      _selectedCategory = ProductCategories.all.first;
    }
    final preview = _buildProduct();
    final inventoryState = ref.read(inventoryProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1150,
        height: 700,
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──
              Row(
                children: [
                  Icon(
                    _isEditing ? Icons.edit : Icons.add_box,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isEditing
                        ? 'Editar Producto Compuesto'
                        : 'Nuevo Producto Compuesto',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const Divider(height: 8),

              // ── Form body ──
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Info
                    SizedBox(
                      width: 280,
                      child: SingleChildScrollView(
                        child: _buildLeftPanel(preview),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, color: const Color(0xFFE0E0E0)),
                    const SizedBox(width: 12),

                    // Right: Agregar componentes + Lista
                    Expanded(flex: 1, child: _buildRightPanel(inventoryState)),
                  ],
                ),
              ),

              const Divider(height: 12),

              // ── Botones ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isEditing ? 'Guardar Cambios' : 'Crear Producto',
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

  // ═══════════════════════════════════════════════════
  //  PANEL IZQUIERDO: Info General + Costos + Resumen
  // ═══════════════════════════════════════════════════

  Widget _buildLeftPanel(CompositeProduct preview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Información General'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: 'Código *',
            hintText: 'MOL-44M',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          style: const TextStyle(fontSize: 12),
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre *',
            hintText: 'Molino 44m',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          style: const TextStyle(fontSize: 12),
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 12, color: Color(0xDD000000)),
                items: ProductCategories.all
                    .map(
                      (cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(
                          ProductCategories.getDisplayName(cat),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => _showManageCategoriesDialog(context),
              icon: const Icon(Icons.settings, size: 20),
              tooltip: 'Administrar categorías',
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Descripción',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          style: const TextStyle(fontSize: 12),
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Resumen de precios en vivo
        _sectionTitle('Resumen'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _previewRow(
                'Costo',
                '\$ ${Helpers.formatNumber(preview.materialsCostPrice)}',
              ),
              _previewRow(
                'Venta Materiales',
                '\$ ${Helpers.formatNumber(preview.materialsCost)}',
              ),
              const SizedBox(height: 4),
              // Campo editable de precio final
              TextFormField(
                controller: _customPriceController,
                decoration: InputDecoration(
                  labelText: 'Precio de venta final',
                  hintText: 'Ej: 10000000',
                  prefixText: '\$ ',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFFF8E1),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 4),
              _previewRow(
                'Margen',
                '${preview.realProfitMargin.toStringAsFixed(1)}%',
                bold: true,
                color: preview.realProfitMargin > 0
                    ? const Color(0xFF388E3C)
                    : const Color(0xFFD32F2F),
              ),
              _previewRow(
                'Peso',
                '${Helpers.formatNumber(preview.totalWeight)} kg',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  PANEL DERECHO: Agregar Componentes + Lista
  // ═══════════════════════════════════════════════════

  Widget _buildRightPanel(InventoryState inventoryState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final topHeight = (totalHeight * _topPanelRatio).clamp(
          100.0,
          totalHeight - 100.0,
        );
        final bottomHeight = totalHeight - topHeight - 14; // 14 = divider area

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Panel de agregar componente ──
            SizedBox(
              height: topHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  children: [
                    // Tabs: Calculado | Directo
                    _buildModeTabs(),
                    const Divider(height: 1),
                    // Contenido según modo
                    Expanded(
                      child: _addMode == 'calculado'
                          ? _buildCalculadoPanel(inventoryState)
                          : _buildDirectoPanel(inventoryState),
                    ),
                  ],
                ),
              ),
            ),

            // ── Divisor arrastrable ──
            GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  _topPanelRatio =
                      ((_topPanelRatio + details.delta.dy / totalHeight).clamp(
                        0.2,
                        0.8,
                      ));
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeRow,
                child: Container(
                  height: 14,
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

            // ── Lista de componentes agregados ──
            SizedBox(
              height: bottomHeight.clamp(0.0, double.infinity),
              child: _buildComponentsList(),
            ),
          ],
        );
      },
    );
  }

  // ── Tabs: Calculado / Directo ──
  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          _modeTab('Con Cálculo', 'calculado', Icons.calculate),
          const SizedBox(width: 6),
          _modeTab('Directo', 'directo', Icons.inventory_2),
        ],
      ),
    );
  }

  Widget _modeTab(String label, String mode, IconData icon) {
    final isActive = _addMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _addMode = mode),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFF757575),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFF757575),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  MODO CALCULADO: Tipo → Material → Dimensiones → Peso
  // ═══════════════════════════════════════════════════

  Widget _buildCalculadoPanel(InventoryState inventoryState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Paso 1 + 2 en fila: Tipo | Material
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tipo (chips compactos horizontales)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. Tipo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _typeChip(
                        'Lám',
                        'lamina',
                        Icons.crop_square,
                        const Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 4),
                      _typeChip(
                        'Tubo',
                        'tubo',
                        Icons.circle_outlined,
                        const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 4),
                      _typeChip(
                        'Eje',
                        'eje',
                        Icons.horizontal_rule,
                        const Color(0xFFF9A825),
                      ),
                      const SizedBox(width: 4),
                      _typeChip(
                        'Cuad',
                        'eje_cuadrado',
                        Icons.square_outlined,
                        const Color(0xFF8E24AA),
                      ),
                    ],
                  ),
                ],
              ),
              if (_selectedCalculationType != null) ...[
                const SizedBox(width: 10),
                // Material dropdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '2. Material',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildMaterialDropdown(inventoryState),
                    ],
                  ),
                ),
              ],
            ],
          ),

          if (_selectedMaterial != null) ...[
            const SizedBox(height: 6),

            // Paso 3: Dimensiones + Cantidad + Resultado en layout compacto
            Row(
              children: [
                Text(
                  '3. ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '${_selectedMaterial!.name} • ${Helpers.formatCurrency(_selectedMaterial!.effectiveCostPrice)}/kg',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildDimensionFields(),
            const SizedBox(height: 6),

            // Cantidad + Pérdida + Resultado en una fila
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _cantidadController,
                    decoration: const InputDecoration(
                      labelText: 'Cant.',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                    ),
                    style: const TextStyle(fontSize: 11),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateWeight(),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.content_cut,
                  size: 12,
                  color: const Color(0xFFF57C00),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 40,
                  child: TextField(
                    controller: _wasteController,
                    decoration: InputDecoration(
                      suffixText: '%',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9A825).withOpacity(0.1),
                    ),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFEF6C00),
                    ),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final val = double.tryParse(v) ?? 0;
                      setState(() => _wastePercentage = val.clamp(0, 50));
                      _calculateWeight();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Resultado inline
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _calculatedWeight > 0
                          ? const Color(0xFF2E7D32).withOpacity(0.1)
                          : const Color(0xFF9E9E9E).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _calculatedWeight > 0
                            ? const Color(0xFF2E7D32).withOpacity(0.3)
                            : const Color(0xFF9E9E9E).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          '${_calculatedWeight.toStringAsFixed(2)} kg',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _calculatedWeight > 0
                                ? const Color(0xFF388E3C)
                                : const Color(0xFF9E9E9E),
                          ),
                        ),
                        Text(
                          Helpers.formatCurrency(
                            _calculatedWeight *
                                (_selectedMaterial?.effectiveCostPrice ?? 0) *
                                (1 + _wastePercentage / 100),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _calculatedWeight > 0
                                ? const Color(0xFF388E3C)
                                : const Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Título de la pieza (opcional)
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: 'Nombre de la pieza (opcional)',
                hintText: 'Ej: tapa lateral, fondo, cuerpo...',
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                prefixIcon: const Icon(Icons.label_outline, size: 16),
              ),
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 6),

            // Botón agregar
            SizedBox(
              width: double.infinity,
              height: 32,
              child: FilledButton.icon(
                onPressed: _calculatedWeight > 0 ? _addCalculatedItem : null,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _typeChip(String label, String type, IconData icon, Color color) {
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : const Color(0xFF9E9E9E),
              size: 14,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : const Color(0xFF616161),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialDropdown(InventoryState inventoryState) {
    // Filtrar materiales por categoría según tipo seleccionado
    final materials = inventoryState.materials.where((m) {
      final cat = m.category.toLowerCase();
      switch (_selectedCalculationType) {
        case 'lamina':
          return cat.contains('lamina') ||
              cat.contains('lámina') ||
              cat.contains('placa');
        case 'tubo':
          return cat.contains('tubo') || cat.contains('tuberia');
        case 'eje':
        case 'eje_cuadrado':
          return cat.contains('eje') || cat.contains('barra');
        default:
          return true;
      }
    }).toList();

    if (inventoryState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (materials.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9A825).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, size: 18, color: const Color(0xFFF57C00)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No hay materiales de tipo "$_selectedCalculationType" en inventario.\nPuedes agregar componentes en modo "Directo".',
                style: TextStyle(fontSize: 11, color: const Color(0xFFEF6C00)),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<mat.Material>(
      value: _selectedMaterial,
      decoration: InputDecoration(
        labelText: 'Material',
        hintText: '${materials.length} disponibles',
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      isExpanded: true,
      items: materials.map((m) {
        return DropdownMenuItem(
          value: m,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  m.name,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${Helpers.formatCurrency(m.effectiveCostPrice)}/kg',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) {
        setState(() {
          _selectedMaterial = v;
          _calculatedWeight = 0;
          _clearDimensionFields();
        });
      },
    );
  }

  Widget _buildDimensionFields() {
    switch (_selectedCalculationType) {
      case 'lamina':
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _largoController,
                decoration: const InputDecoration(
                  labelText: 'Largo cm',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateWeight(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _anchoController,
                decoration: const InputDecoration(
                  labelText: 'Ancho cm',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateWeight(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildThicknessSelector(_espesorController, 'Esp.'),
            ),
          ],
        );
      case 'tubo':
        return Row(
          children: [
            Expanded(
              child: _buildThicknessSelector(_diametroExtController, 'Ø Ext'),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildThicknessSelector(_espesorParedController, 'Pared'),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _largoController,
                decoration: const InputDecoration(
                  labelText: 'Largo cm',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateWeight(),
              ),
            ),
          ],
        );
      case 'eje':
        return Row(
          children: [
            Expanded(
              child: _buildThicknessSelector(_diametroController, 'Diám.'),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _largoController,
                decoration: const InputDecoration(
                  labelText: 'Largo cm',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateWeight(),
              ),
            ),
          ],
        );
      case 'eje_cuadrado':
        return Row(
          children: [
            Expanded(child: _buildThicknessSelector(_ladoController, 'Lado')),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _largoController,
                decoration: const InputDecoration(
                  labelText: 'Largo cm',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateWeight(),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Selector de pulgadas con rueda tipo iOS
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
      '4',
      '5',
      '6',
    ];

    int initialIndex = commonSizes.indexOf(controller.text);
    if (initialIndex < 0) initialIndex = 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            // Wheel picker
            Expanded(
              child: SizedBox(
                height: 64,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Container(
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      ListWheelScrollView.useDelegate(
                        itemExtent: 26,
                        diameterRatio: 1.8,
                        perspective: 0.001,
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
                            final isSel = controller.text == size;
                            return Center(
                              child: Text(
                                '$size"',
                                style: TextStyle(
                                  fontSize: isSel ? 13 : 10,
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSel
                                      ? Theme.of(context).colorScheme.primary
                                      : const Color(0xFF9E9E9E),
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
            ),
            const SizedBox(width: 6),
            // Input manual
            SizedBox(
              width: 56,
              height: 64,
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '?',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                onChanged: (_) => _calculateWeight(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  MODO DIRECTO: Seleccionar del inventario
  // ═══════════════════════════════════════════════════

  Widget _buildDirectoPanel(InventoryState inventoryState) {
    final materials = inventoryState.materials.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final totalDirecto = _selectedDirectMaterial != null
        ? (double.tryParse(_directQuantityController.text) ?? 1) *
              _selectedDirectMaterial!.effectiveCostPrice
        : 0.0;

    return Column(
      children: [
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Text(
                'Inventario (${materials.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 160,
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
                    fillColor: const Color(0xFFF5F5F5),
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
                    'No hay materiales',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : const Color(0xFFEEEEEE),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: _getMaterialCategoryColor(
                                m.category,
                              ),
                              child: Icon(
                                _getMaterialCategoryIcon(m.category),
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
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
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : const Color(0xFF424242),
                                    ),
                                  ),
                                  Text(
                                    '${m.category} • Stock: ${m.stock.toStringAsFixed(1)} ${m.unit}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Helpers.formatCurrency(m.effectiveCostPrice),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : const Color(0xFF616161),
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Column(
              children: [
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
                      '${Helpers.formatCurrency(_selectedDirectMaterial!.effectiveCostPrice)}/${_selectedDirectMaterial!.unit}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('Cantidad:', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        final c =
                            double.tryParse(_directQuantityController.text) ??
                            1;
                        if (c > 1) {
                          setState(
                            () => _directQuantityController.text = (c - 1)
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
                      width: 70,
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
                        final c =
                            double.tryParse(_directQuantityController.text) ??
                            0;
                        setState(
                          () => _directQuantityController.text = (c + 1)
                              .toString(),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Text(
                      ' ${_selectedDirectMaterial!.unit}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Total: ${Helpers.formatCurrency(totalDirecto)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: FilledButton.icon(
                    onPressed: _addDirectItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text(
                      'Agregar',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  LISTA DE COMPONENTES AGREGADOS
  // ═══════════════════════════════════════════════════

  Widget _buildComponentsList() {
    final totalWeight = _components.fold<double>(
      0,
      (sum, c) => sum + c.totalWeight,
    );
    final totalCost = _components.fold<double>(
      0,
      (sum, c) => sum + c.totalPrice,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt, size: 16, color: const Color(0xFF616161)),
                const SizedBox(width: 6),
                Text(
                  'Lista de componentes (${_components.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (_components.isNotEmpty) ...[
                  Text(
                    '${totalWeight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF616161),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Helpers.formatCurrency(totalCost),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Lista
          Expanded(
            child: _components.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 24,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Agrega componentes arriba',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    itemCount: _components.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final comp = _components[index];
                      final hasAssociation = comp.materialId.isNotEmpty;
                      return InkWell(
                        onTap: () => _showEditComponentDialog(index),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: hasAssociation
                                ? Colors.white
                                : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: hasAssociation
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : const Color(0xFFFFB74D),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: hasAssociation
                                    ? _getMaterialCategoryColor(comp.category)
                                    : const Color(0xFFFF9800),
                                child: Icon(
                                  hasAssociation
                                      ? _getMaterialCategoryIcon(comp.category)
                                      : Icons.link_off,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (comp.label.isNotEmpty)
                                      Text(
                                        comp.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    Text(
                                      '${comp.quantity}× ${comp.name}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      hasAssociation
                                          ? comp.description
                                          : 'Toca para asociar material',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: hasAssociation
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant
                                            : const Color(0xFFE65100),
                                        fontStyle: hasAssociation
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${comp.totalWeight.toStringAsFixed(2)} kg',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    Helpers.formatCurrency(comp.totalPrice),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () =>
                                    setState(() => _components.removeAt(index)),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: const Color(0xFFEF5350),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  LÓGICA DE CÁLCULO DE PESO
  // ═══════════════════════════════════════════════════

  void _calculateWeight() {
    if (_selectedMaterial == null) return;

    final cantidad = int.tryParse(_cantidadController.text) ?? 1;
    double pesoUnitario = 0;
    const double steelDensity = 7.85; // g/cm³

    if (_selectedCalculationType == 'lamina') {
      final largo = double.tryParse(_largoController.text) ?? 0;
      final ancho = double.tryParse(_anchoController.text) ?? 0;
      final espesorPulg = _parseFraction(_espesorController.text);
      final espesorCm = espesorPulg * 2.54;
      if (largo > 0 && ancho > 0 && espesorCm > 0) {
        final volumenCm3 = largo * ancho * espesorCm;
        pesoUnitario = (volumenCm3 * steelDensity) / 1000;
      }
    } else if (_selectedCalculationType == 'tubo') {
      final dExtPulg = _parseFraction(_diametroExtController.text);
      final espesorParedPulg = _parseFraction(_espesorParedController.text);
      final largo = double.tryParse(_largoController.text) ?? 0;
      final dExtCm = dExtPulg * 2.54;
      final espesorParedCm = espesorParedPulg * 2.54;
      final dIntCm = dExtCm - (2 * espesorParedCm);
      if (dExtCm > 0 && dIntCm > 0 && largo > 0) {
        final rExt = dExtCm / 2;
        final rInt = dIntCm / 2;
        final volumenCm3 = math.pi * (rExt * rExt - rInt * rInt) * largo;
        pesoUnitario = (volumenCm3 * steelDensity) / 1000;
      }
    } else if (_selectedCalculationType == 'eje') {
      final dPulg = _parseFraction(_diametroController.text);
      final largo = double.tryParse(_largoController.text) ?? 0;
      final dCm = dPulg * 2.54;
      if (dCm > 0 && largo > 0) {
        final r = dCm / 2;
        final volumenCm3 = math.pi * r * r * largo;
        pesoUnitario = (volumenCm3 * steelDensity) / 1000;
      }
    } else if (_selectedCalculationType == 'eje_cuadrado') {
      final ladoPulg = _parseFraction(_ladoController.text);
      final largo = double.tryParse(_largoController.text) ?? 0;
      final ladoCm = ladoPulg * 2.54;
      if (ladoCm > 0 && largo > 0) {
        final volumenCm3 = ladoCm * ladoCm * largo;
        pesoUnitario = (volumenCm3 * steelDensity) / 1000;
      }
    }

    setState(() {
      _calculatedWeight = pesoUnitario * cantidad;
    });
  }

  double _parseFraction(String value) {
    if (value.isEmpty) return 0;
    value = value.trim();

    if (double.tryParse(value) != null) return double.parse(value);

    if (value.contains(' ')) {
      final parts = value.split(' ');
      if (parts.length == 2) {
        final whole = double.tryParse(parts[0]) ?? 0;
        final fraction = _parseFraction(parts[1]);
        return whole + fraction;
      }
    }

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

  void _clearDimensionFields() {
    _largoController.clear();
    _anchoController.clear();
    _espesorController.text = '1/4';
    _diametroExtController.text = '1';
    _espesorParedController.text = '1/4';
    _diametroController.text = '1';
    _ladoController.text = '1';
    _cantidadController.text = '1';
    _calculatedWeight = 0;
    _wastePercentage = 5;
    _wasteController.text = '5';
  }

  // ═══════════════════════════════════════════════════
  //  ACCIONES: AGREGAR COMPONENTES
  // ═══════════════════════════════════════════════════

  void _addCalculatedItem() {
    if (_selectedMaterial == null || _calculatedWeight <= 0) return;

    String description = '';
    MaterialShape shape = MaterialShape.custom;
    double? outerDiameter;
    double? thickness;
    double? length;
    double? width;

    final cantidad = int.tryParse(_cantidadController.text) ?? 1;

    if (_selectedCalculationType == 'lamina') {
      description =
          '${_largoController.text}×${_anchoController.text}cm, ${_espesorController.text}"';
      shape = MaterialShape.rectangularPlate;
      length = (double.tryParse(_largoController.text) ?? 0) * 10; // cm → mm
      width = (double.tryParse(_anchoController.text) ?? 0) * 10;
      thickness = _parseFraction(_espesorController.text) * 25.4; // pulg → mm
    } else if (_selectedCalculationType == 'tubo') {
      description =
          'Ø${_diametroExtController.text}" × ${_espesorParedController.text}" × ${_largoController.text}cm';
      shape = MaterialShape.cylinder;
      outerDiameter = _parseFraction(_diametroExtController.text) * 25.4;
      thickness = _parseFraction(_espesorParedController.text) * 25.4;
      length = (double.tryParse(_largoController.text) ?? 0) * 10;
    } else if (_selectedCalculationType == 'eje') {
      description =
          'Ø${_diametroController.text}" × ${_largoController.text}cm';
      shape = MaterialShape.solidCylinder;
      outerDiameter = _parseFraction(_diametroController.text) * 25.4;
      length = (double.tryParse(_largoController.text) ?? 0) * 10;
    } else if (_selectedCalculationType == 'eje_cuadrado') {
      description = '◻${_ladoController.text}" × ${_largoController.text}cm';
      shape = MaterialShape.solidSquare;
      width = _parseFraction(_ladoController.text) * 25.4; // lado en mm
      length = (double.tryParse(_largoController.text) ?? 0) * 10;
    }

    if (cantidad > 1) {
      description = '$cantidad pzs - $description';
    }
    if (_wastePercentage > 0) {
      description += ' (+${_wastePercentage.toStringAsFixed(0)}% pérdida)';
    }

    final pesoConPerdidas = _calculatedWeight * (1 + _wastePercentage / 100);
    final costoPorUnidad =
        (pesoConPerdidas / cantidad) * _selectedMaterial!.effectiveCostPrice;
    final ventaPorUnidad =
        (pesoConPerdidas / cantidad) * _selectedMaterial!.effectivePrice;

    setState(() {
      _components.add(
        _ComponentFormData(
          materialId: _selectedMaterial!.id,
          name: _selectedMaterial!.name,
          category: _selectedMaterial!.category,
          description: description,
          label: _labelController.text.trim(),
          shape: shape,
          outerDiameter: outerDiameter,
          thickness: thickness,
          length: length,
          width: width,
          quantity: cantidad,
          weightPerUnit: pesoConPerdidas / cantidad,
          pricePerUnit: ventaPorUnidad,
          costPricePerUnit: costoPorUnidad,
        ),
      );

      // Reset para siguiente componente
      _selectedMaterial = null;
      _calculatedWeight = 0;
      _labelController.clear();
      _clearDimensionFields();
    });
  }

  void _addDirectItem() {
    if (_selectedDirectMaterial == null) return;

    final cantidad = double.tryParse(_directQuantityController.text) ?? 1;
    final material = _selectedDirectMaterial!;
    final qtyInt = cantidad.ceil() > 0 ? cantidad.ceil() : 1;
    final weightPU = cantidad / qtyInt;

    setState(() {
      _components.add(
        _ComponentFormData(
          materialId: material.id,
          name: material.name,
          category: material.category,
          description:
              '${cantidad.toStringAsFixed(cantidad == cantidad.roundToDouble() ? 0 : 1)} ${material.unit}',
          shape: MaterialShape.custom,
          quantity: qtyInt,
          weightPerUnit: weightPU,
          pricePerUnit: material.effectivePrice * weightPU,
          costPricePerUnit: material.effectiveCostPrice * weightPU,
        ),
      );

      _selectedDirectMaterial = null;
      _directQuantityController.text = '1';
    });
  }

  // ═══════════════════════════════════════════════════
  //  EDITAR COMPONENTE (CLICK)
  // ═══════════════════════════════════════════════════

  void _showEditComponentDialog(int index) {
    final comp = _components[index];
    final inventoryState = ref.read(inventoryProvider);

    showDialog(
      context: context,
      builder: (ctx) => _EditComponentDialog(
        component: comp,
        materials: inventoryState.materials,
        onSave: (updated) {
          setState(() => _components[index] = updated);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _previewRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: bold
                ? const TextStyle(fontWeight: FontWeight.bold)
                : TextStyle(fontSize: 13, color: const Color(0xFF616161)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color:
                  color ??
                  (bold ? Theme.of(context).colorScheme.primary : null),
              fontSize: bold ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMaterialCategoryIcon(String category) {
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

  Color _getMaterialCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'lamina':
      case 'lámina':
        return const Color(0xFF1565C0);
      case 'tubo':
        return const Color(0xFF2E7D32);
      case 'eje':
        return const Color(0xFFF9A825);
      case 'rodamiento':
        return const Color(0xFF7B1FA2);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nameController.text.trim().isEmpty ||
        _codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre y código son requeridos'),
          backgroundColor: Color(0xFFF9A825),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final product = _buildProduct();
      await widget.onSave(product);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ═══════════════════════════════════════════════════════
  //  ADMINISTRAR CATEGORÍAS DE PRODUCTOS
  // ═══════════════════════════════════════════════════════

  void _showManageCategoriesDialog(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      builder: (context) => _ManageCategoriesDialog(ref: ref),
    ).then((_) {
      // Refresh categories after dialog closes
      final cats = ref.read(settingsProvider).categories;
      if (cats.isNotEmpty) {
        ProductCategories.setCategories(cats.map((c) => c.name).toList());
      }
      setState(() {
        // Ensure selected category still exists
        if (!ProductCategories.all.contains(_selectedCategory)) {
          _selectedCategory = ProductCategories.all.first;
        }
      });
    });
  }
}

// ═══════════════════════════════════════════════════════
//  DIÁLOGO ADMINISTRAR CATEGORÍAS
// ═══════════════════════════════════════════════════════

class _ManageCategoriesDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _ManageCategoriesDialog({required this.ref});

  @override
  ConsumerState<_ManageCategoriesDialog> createState() =>
      _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState
    extends ConsumerState<_ManageCategoriesDialog> {
  @override
  Widget build(BuildContext context) {
    final settingsState = ref.read(settingsProvider);
    final categories = settingsState.categories;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.category, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('Administrar Categorías')),
          IconButton(
            onPressed: () => _showAddCategoryDialog(context),
            icon: const Icon(Icons.add_circle),
            tooltip: 'Nueva categoría',
            color: theme.colorScheme.primary,
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        height: 400,
        child: categories.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 48,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay categorías',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _showAddCategoryDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Agregar categoría'),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: categories.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        cat.name.isNotEmpty ? cat.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      cat.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle:
                        cat.description != null && cat.description!.isNotEmpty
                        ? Text(
                            cat.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: () =>
                              _showEditCategoryDialog(context, cat),
                          tooltip: 'Editar',
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Color(0xFFC62828),
                          ),
                          onPressed: () => _confirmDeleteCategory(context, cat),
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
  }

  Future<void> _showAddCategoryDialog(BuildContext parentContext) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Categoría'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  hintText: 'Ej: Bombas, Válvulas...',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El nombre es requerido'),
                    backgroundColor: Color(0xFFE65100),
                  ),
                );
                return;
              }
              final newCat = ProductCategory(
                id: '',
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim().isNotEmpty
                    ? descCtrl.text.trim()
                    : null,
              );
              final ok = await ref
                  .read(settingsProvider.notifier)
                  .addCategory(newCat);
              if (ok && context.mounted) {
                Navigator.pop(context, true);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al crear categoría'),
                    backgroundColor: Color(0xFFC62828),
                  ),
                );
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result == true && mounted) setState(() {});
  }

  Future<void> _showEditCategoryDialog(
    BuildContext parentContext,
    ProductCategory cat,
  ) async {
    final nameCtrl = TextEditingController(text: cat.name);
    final descCtrl = TextEditingController(text: cat.description ?? '');

    final result = await showDialog<bool>(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('Editar Categoría'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El nombre es requerido'),
                    backgroundColor: Color(0xFFE65100),
                  ),
                );
                return;
              }
              final updated = ProductCategory(
                id: cat.id,
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim().isNotEmpty
                    ? descCtrl.text.trim()
                    : null,
                parentId: cat.parentId,
                isActive: cat.isActive,
                createdAt: cat.createdAt,
              );
              final ok = await ref
                  .read(settingsProvider.notifier)
                  .updateCategory(updated);
              if (ok && context.mounted) {
                Navigator.pop(context, true);
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al actualizar categoría'),
                    backgroundColor: Color(0xFFC62828),
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == true && mounted) setState(() {});
  }

  Future<void> _confirmDeleteCategory(
    BuildContext parentContext,
    ProductCategory cat,
  ) async {
    final confirm = await showDialog<bool>(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text(
          '¿Estás seguro de eliminar la categoría "${cat.name}"?\n\n'
          'Los productos que la usen quedarán sin categoría asignada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ref
          .read(settingsProvider.notifier)
          .deleteCategory(cat.id);
      if (ok && mounted) {
        setState(() {});
        if (parentContext.mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            SnackBar(
              content: Text('Categoría "${cat.name}" eliminada'),
              backgroundColor: const Color(0xFF2E7D32),
            ),
          );
        }
      }
    }
  }
}

// ═══════════════════════════════════════════════════════
//  DIÁLOGO EDITAR COMPONENTE (ASOCIAR MATERIAL + CÁLCULO)
// ═══════════════════════════════════════════════════════

class _EditComponentDialog extends StatefulWidget {
  final _ComponentFormData component;
  final List<mat.Material> materials;
  final void Function(_ComponentFormData updated) onSave;

  const _EditComponentDialog({
    required this.component,
    required this.materials,
    required this.onSave,
  });

  @override
  State<_EditComponentDialog> createState() => _EditComponentDialogState();
}

class _EditComponentDialogState extends State<_EditComponentDialog> {
  late List<mat.Material> _materials;
  late TextEditingController _labelController;
  late TextEditingController _quantityController;
  late TextEditingController _searchController;
  late TextEditingController _largoController;
  late TextEditingController _anchoController;
  late TextEditingController _espesorController;
  late TextEditingController _diametroExtController;
  late TextEditingController _espesorParedController;
  late TextEditingController _diametroController;
  late TextEditingController _ladoController;
  late TextEditingController _wasteController;
  late TextEditingController _unitPriceController;

  mat.Material? _selectedMaterial;
  String? _calcType; // null = directo, 'lamina', 'tubo', 'eje', 'eje_cuadrado'
  double _calculatedWeight = 0;
  double _wastePercentage = 5;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _materials = List.from(widget.materials);
    final c = widget.component;
    _labelController = TextEditingController(text: c.label);
    _quantityController = TextEditingController(text: c.quantity.toString());
    _searchController = TextEditingController();
    _largoController = TextEditingController();
    _anchoController = TextEditingController();
    _espesorController = TextEditingController(text: '1/4');
    _diametroExtController = TextEditingController(text: '1');
    _espesorParedController = TextEditingController(text: '1/4');
    _diametroController = TextEditingController(text: '1');
    _ladoController = TextEditingController(text: '1');
    _wasteController = TextEditingController(text: '5');
    _unitPriceController = TextEditingController(
      text: c.pricePerUnit > 0 ? c.pricePerUnit.toStringAsFixed(0) : '',
    );

    // Pre-select material if already associated
    if (c.materialId.isNotEmpty) {
      final idx = _materials.indexWhere((m) => m.id == c.materialId);
      if (idx >= 0) {
        _selectedMaterial = _materials[idx];
        // Update price field with current material venta price
        _unitPriceController.text = _selectedMaterial!.effectivePrice
            .toStringAsFixed(0);
      }
    }

    // Pre-load dimensions if they exist
    if (c.length != null && c.length! > 0) {
      _largoController.text = (c.length! / 10).toStringAsFixed(1); // mm→cm
    }
    if (c.width != null && c.width! > 0) {
      _anchoController.text = (c.width! / 10).toStringAsFixed(1);
    }
    if (c.weightPerUnit > 0) {
      _calculatedWeight = c.weightPerUnit * c.quantity;
    }

    // Detect calc type from shape
    switch (c.shape) {
      case MaterialShape.rectangularPlate:
        _calcType = 'lamina';
        break;
      case MaterialShape.cylinder:
        _calcType = 'tubo';
        break;
      case MaterialShape.solidCylinder:
        _calcType = 'eje';
        break;
      case MaterialShape.solidSquare:
        _calcType = 'eje_cuadrado';
        break;
      default:
        _calcType = null;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _quantityController.dispose();
    _searchController.dispose();
    _largoController.dispose();
    _anchoController.dispose();
    _espesorController.dispose();
    _diametroExtController.dispose();
    _espesorParedController.dispose();
    _diametroController.dispose();
    _ladoController.dispose();
    _wasteController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editar: ${widget.component.label.isNotEmpty ? widget.component.label : widget.component.name}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const Divider(height: 12),

            // Body: two columns
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Material search
                  Expanded(flex: 1, child: _buildMaterialSearch()),
                  const SizedBox(width: 12),
                  Container(width: 1, color: const Color(0xFFE0E0E0)),
                  const SizedBox(width: 12),
                  // Right: Config + calc
                  Expanded(flex: 1, child: _buildConfigPanel()),
                ],
              ),
            ),

            const Divider(height: 12),

            // Footer: preview + buttons
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Material Search Panel ──
  Widget _buildMaterialSearch() {
    final filtered = _materials.where((m) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return m.name.toLowerCase().contains(q) ||
          m.code.toLowerCase().contains(q) ||
          m.category.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Asociar Material del Inventario',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar en todo el inventario...',
            prefixIcon: const Icon(Icons.search, size: 16),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
          ),
          style: const TextStyle(fontSize: 11),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 6),
        Text(
          '${filtered.length} materiales',
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _createNewMaterial,
            icon: const Icon(Icons.add, size: 14),
            label: const Text(
              'Crear nuevo material',
              style: TextStyle(fontSize: 11),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final m = filtered[index];
              final isSelected = _selectedMaterial?.id == m.id;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedMaterial = m;
                    // Auto-fill price in Directo mode (show venta price)
                    if (_calcType == null) {
                      _unitPriceController.text = m.effectivePrice
                          .toStringAsFixed(0);
                    }
                    _recalculate();
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFEEEEEE),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
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
                                fontSize: 11,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : const Color(0xFF424242),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${m.category} • ${m.unit} • Stock: ${m.stock.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${Helpers.formatCurrency(m.effectivePrice)} V\n${Helpers.formatCurrency(m.effectiveCostPrice)} C',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : const Color(0xFF616161),
                        ),
                        textAlign: TextAlign.right,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Config Panel (right side) ──
  Widget _buildConfigPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label field
          Text(
            'Nombre de la pieza',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              hintText: 'Ej: Lamina Base, Tapa Superior...',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),

          // Calc type selector
          Text(
            'Tipo de cálculo',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _editCalcChip('Directo', null, Icons.straighten),
              const SizedBox(width: 4),
              _editCalcChip('Lám', 'lamina', Icons.crop_square),
              const SizedBox(width: 4),
              _editCalcChip('Tubo', 'tubo', Icons.circle_outlined),
              const SizedBox(width: 4),
              _editCalcChip('Eje', 'eje', Icons.horizontal_rule),
              const SizedBox(width: 4),
              _editCalcChip('Cuad', 'eje_cuadrado', Icons.square_outlined),
            ],
          ),
          const SizedBox(height: 12),

          // Dimension fields based on type
          if (_calcType != null) ...[
            Text(
              'Dimensiones',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            _buildEditDimensionFields(),
            const SizedBox(height: 8),
          ],

          // Quantity + waste
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalculate(),
                ),
              ),
              if (_calcType != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _wasteController,
                    decoration: InputDecoration(
                      labelText: '% Pérd.',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9A825).withOpacity(0.1),
                    ),
                    style: const TextStyle(fontSize: 11),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      _wastePercentage = (double.tryParse(v) ?? 0).clamp(0, 50);
                      _recalculate();
                    },
                  ),
                ),
              ],
            ],
          ),

          // Direct price (when no calc type)
          if (_calcType == null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _unitPriceController,
              readOnly: _selectedMaterial != null,
              decoration: InputDecoration(
                labelText:
                    _selectedMaterial != null && _selectedMaterial!.unit == 'KG'
                    ? 'Precio VENTA por kg (\$)'
                    : 'Precio VENTA unitario (\$)',
                hintText: _selectedMaterial != null
                    ? Helpers.formatCurrency(_selectedMaterial!.effectivePrice)
                    : 'Precio por unidad',
                isDense: true,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                suffixText: _selectedMaterial != null
                    ? '/${_selectedMaterial!.unit == 'KG' ? 'kg' : 'und'}'
                    : null,
              ),
              style: const TextStyle(fontSize: 12),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ],

          const SizedBox(height: 12),

          // Result preview - always show
          if (_selectedMaterial != null ||
              _calcType != null ||
              _unitPriceController.text.isNotEmpty) ...[
            _buildResultPreview(),
          ],
        ],
      ),
    );
  }

  Widget _editCalcChip(String label, String? type, IconData icon) {
    final isActive = _calcType == type;
    final color = type == null
        ? const Color(0xFF616161)
        : type == 'lamina'
        ? const Color(0xFF1565C0)
        : type == 'tubo'
        ? const Color(0xFF2E7D32)
        : type == 'eje'
        ? const Color(0xFFF9A825)
        : const Color(0xFF8E24AA);

    return InkWell(
      onTap: () {
        setState(() {
          _calcType = type;
          _calculatedWeight = 0;
        });
        _recalculate();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? color : const Color(0xFFE0E0E0),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? color : const Color(0xFF9E9E9E),
              size: 12,
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? color : const Color(0xFF616161),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditDimensionFields() {
    switch (_calcType) {
      case 'lamina':
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _largoController,
                decoration: const InputDecoration(
                  labelText: 'Largo cm',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalculate(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _anchoController,
                decoration: const InputDecoration(
                  labelText: 'Ancho cm',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalculate(),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _espesorController,
                decoration: const InputDecoration(
                  labelText: 'Esp. "',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                onChanged: (_) => _recalculate(),
              ),
            ),
          ],
        );
      case 'tubo':
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _diametroExtController,
                decoration: const InputDecoration(
                  labelText: 'Ø Ext "',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                onChanged: (_) => _recalculate(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _espesorParedController,
                decoration: const InputDecoration(
                  labelText: 'Pared "',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                onChanged: (_) => _recalculate(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _largoController,
                decoration: const InputDecoration(
                  labelText: 'Largo cm',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalculate(),
              ),
            ),
          ],
        );
      case 'eje':
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _diametroController,
                decoration: const InputDecoration(
                  labelText: 'Diámetro "',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                onChanged: (_) => _recalculate(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _largoController,
                decoration: const InputDecoration(
                  labelText: 'Largo cm',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalculate(),
              ),
            ),
          ],
        );
      case 'eje_cuadrado':
        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ladoController,
                decoration: const InputDecoration(
                  labelText: 'Lado "',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                onChanged: (_) => _recalculate(),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _largoController,
                decoration: const InputDecoration(
                  labelText: 'Largo cm',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                ),
                style: const TextStyle(fontSize: 11),
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalculate(),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildResultPreview() {
    final cantidad = int.tryParse(_quantityController.text) ?? 1;
    double pesoTotal = 0;
    double costoCompra = 0;
    double costoVenta = 0;
    String unitLabel = 'und';

    if (_calcType != null &&
        _calculatedWeight > 0 &&
        _selectedMaterial != null) {
      final pesoConPerdidas = _calculatedWeight * (1 + _wastePercentage / 100);
      pesoTotal = pesoConPerdidas;
      costoCompra = pesoConPerdidas * _selectedMaterial!.effectiveCostPrice;
      costoVenta = pesoConPerdidas * _selectedMaterial!.effectivePrice;
      unitLabel = 'kg';
    } else if (_calcType == null) {
      // Directo - use material prices when available, fallback to manual
      final manualPrice = double.tryParse(_unitPriceController.text) ?? 0;
      if (_selectedMaterial != null) {
        unitLabel = _selectedMaterial!.unit == 'KG' ? 'kg' : 'und';
        costoCompra = _selectedMaterial!.effectiveCostPrice * cantidad;
        costoVenta = _selectedMaterial!.effectivePrice * cantidad;
        pesoTotal = _selectedMaterial!.unit == 'KG' ? cantidad.toDouble() : 0;
      } else {
        costoCompra = manualPrice * cantidad;
        costoVenta = manualPrice * cantidad;
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (pesoTotal > 0 || costoCompra > 0)
            ? const Color(0xFF2E7D32).withOpacity(0.08)
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (pesoTotal > 0 || costoCompra > 0)
              ? const Color(0xFF2E7D32).withOpacity(0.3)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text(
                pesoTotal > 0 ? 'Peso' : 'Cantidad',
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                pesoTotal > 0
                    ? '${pesoTotal.toStringAsFixed(2)} kg'
                    : '$cantidad $unitLabel',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF388E3C),
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                'Compra',
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                Helpers.formatCurrency(costoCompra),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          Column(
            children: [
              Text(
                'Venta',
                style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                Helpers.formatCurrency(costoVenta),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF388E3C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer: save/cancel ──
  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Material info chip
        if (_selectedMaterial != null) ...[
          Icon(Icons.check_circle, size: 14, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${_selectedMaterial!.name} • V:${Helpers.formatCurrency(_selectedMaterial!.effectivePrice)} C:${Helpers.formatCurrency(_selectedMaterial!.effectiveCostPrice)}/${_selectedMaterial!.unit == 'KG' ? 'kg' : 'und'}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2E7D32),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
        ] else ...[
          const Spacer(),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _saveChanges,
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Guardar', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  // ── Calculation logic ──
  double _parseFraction(String value) {
    if (value.isEmpty) return 0;
    value = value.trim();
    if (double.tryParse(value) != null) return double.parse(value);
    if (value.contains(' ')) {
      final parts = value.split(' ');
      if (parts.length == 2) {
        return (double.tryParse(parts[0]) ?? 0) + _parseFraction(parts[1]);
      }
    }
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

  void _recalculate() {
    if (_calcType == null) {
      setState(() {});
      return;
    }

    final cantidad = int.tryParse(_quantityController.text) ?? 1;
    double pesoUnitario = 0;
    const double steelDensity = 7.85; // g/cm³

    if (_calcType == 'lamina') {
      final largo = double.tryParse(_largoController.text) ?? 0;
      final ancho = double.tryParse(_anchoController.text) ?? 0;
      final espesorPulg = _parseFraction(_espesorController.text);
      final espesorCm = espesorPulg * 2.54;
      if (largo > 0 && ancho > 0 && espesorCm > 0) {
        final volumenCm3 = largo * ancho * espesorCm;
        pesoUnitario = (volumenCm3 * steelDensity) / 1000;
      }
    } else if (_calcType == 'tubo') {
      final dExtPulg = _parseFraction(_diametroExtController.text);
      final espesorParedPulg = _parseFraction(_espesorParedController.text);
      final largo = double.tryParse(_largoController.text) ?? 0;
      final dExtCm = dExtPulg * 2.54;
      final espesorParedCm = espesorParedPulg * 2.54;
      final dIntCm = dExtCm - (2 * espesorParedCm);
      if (dExtCm > 0 && dIntCm > 0 && largo > 0) {
        final rExt = dExtCm / 2;
        final rInt = dIntCm / 2;
        final volumenCm3 = math.pi * (rExt * rExt - rInt * rInt) * largo;
        pesoUnitario = (volumenCm3 * steelDensity) / 1000;
      }
    } else if (_calcType == 'eje') {
      final dPulg = _parseFraction(_diametroController.text);
      final largo = double.tryParse(_largoController.text) ?? 0;
      final dCm = dPulg * 2.54;
      if (dCm > 0 && largo > 0) {
        final r = dCm / 2;
        final volumenCm3 = math.pi * r * r * largo;
        pesoUnitario = (volumenCm3 * steelDensity) / 1000;
      }
    } else if (_calcType == 'eje_cuadrado') {
      final ladoPulg = _parseFraction(_ladoController.text);
      final largo = double.tryParse(_largoController.text) ?? 0;
      final ladoCm = ladoPulg * 2.54;
      if (ladoCm > 0 && largo > 0) {
        final volumenCm3 = ladoCm * ladoCm * largo;
        pesoUnitario = (volumenCm3 * steelDensity) / 1000;
      }
    }

    setState(() {
      _calculatedWeight = pesoUnitario * cantidad;
    });
  }

  void _saveChanges() {
    final cantidad = int.tryParse(_quantityController.text) ?? 1;
    String description = '';
    MaterialShape shape = MaterialShape.custom;
    double? outerDiameter;
    double? thickness;
    double? length;
    double? width;
    double weightPerUnit = 0;
    double pricePerUnit = 0;
    double costPricePerUnit = 0;
    String materialId = _selectedMaterial?.id ?? '';
    String materialName = _selectedMaterial?.name ?? widget.component.name;
    String category = _selectedMaterial?.category ?? widget.component.category;

    if (_calcType != null &&
        _calculatedWeight > 0 &&
        _selectedMaterial != null) {
      // Calculated mode
      final pesoConPerdidas = _calculatedWeight * (1 + _wastePercentage / 100);
      weightPerUnit = pesoConPerdidas / cantidad;
      pricePerUnit = weightPerUnit * _selectedMaterial!.effectivePrice;
      costPricePerUnit = weightPerUnit * _selectedMaterial!.effectiveCostPrice;

      if (_calcType == 'lamina') {
        shape = MaterialShape.rectangularPlate;
        description =
            '${_largoController.text}×${_anchoController.text}cm, ${_espesorController.text}"';
        length = (double.tryParse(_largoController.text) ?? 0) * 10;
        width = (double.tryParse(_anchoController.text) ?? 0) * 10;
        thickness = _parseFraction(_espesorController.text) * 25.4;
      } else if (_calcType == 'tubo') {
        shape = MaterialShape.cylinder;
        description =
            'Ø${_diametroExtController.text}" × ${_espesorParedController.text}" × ${_largoController.text}cm';
        outerDiameter = _parseFraction(_diametroExtController.text) * 25.4;
        thickness = _parseFraction(_espesorParedController.text) * 25.4;
        length = (double.tryParse(_largoController.text) ?? 0) * 10;
      } else if (_calcType == 'eje') {
        shape = MaterialShape.solidCylinder;
        description =
            'Ø${_diametroController.text}" × ${_largoController.text}cm';
        outerDiameter = _parseFraction(_diametroController.text) * 25.4;
        length = (double.tryParse(_largoController.text) ?? 0) * 10;
      } else if (_calcType == 'eje_cuadrado') {
        shape = MaterialShape.solidSquare;
        description = '◻${_ladoController.text}" × ${_largoController.text}cm';
        width = _parseFraction(_ladoController.text) * 25.4;
        length = (double.tryParse(_largoController.text) ?? 0) * 10;
      }

      if (_wastePercentage > 0) {
        description += ' (+${_wastePercentage.toStringAsFixed(0)}% pérdida)';
      }
    } else {
      // Direct mode
      if (_selectedMaterial != null) {
        final m = _selectedMaterial!;
        if (m.unit == 'KG') {
          pricePerUnit = m.effectivePrice;
          costPricePerUnit = m.effectiveCostPrice;
          weightPerUnit = 1;
          description = '$cantidad KG';
        } else {
          pricePerUnit = m.effectivePrice;
          costPricePerUnit = m.effectiveCostPrice;
          weightPerUnit = 1;
          description = '$cantidad UND';
        }
      } else {
        final manualPrice = double.tryParse(_unitPriceController.text) ?? 0;
        pricePerUnit = manualPrice > 0
            ? manualPrice
            : widget.component.pricePerUnit;
        costPricePerUnit = widget.component.costPricePerUnit;
        weightPerUnit = 0;
        description = '$cantidad UND';
      }
    }

    final updated = _ComponentFormData(
      materialId: materialId,
      name: materialName,
      category: category,
      description: description,
      label: _labelController.text.trim().isNotEmpty
          ? _labelController.text.trim()
          : widget.component.label,
      shape: shape,
      outerDiameter: outerDiameter,
      thickness: thickness,
      length: length,
      width: width,
      quantity: cantidad,
      weightPerUnit: weightPerUnit,
      pricePerUnit: pricePerUnit,
      costPricePerUnit: costPricePerUnit,
    );

    widget.onSave(updated);
    Navigator.pop(context);
  }

  Future<void> _createNewMaterial() async {
    final created = await MaterialFormDialog.show(
      context,
      suggestedName: widget.component.name,
    );
    if (created != null && mounted) {
      setState(() {
        _materials.insert(0, created);
        _selectedMaterial = created;
        if (_calcType == null) {
          _unitPriceController.text = created.effectiveCostPrice
              .toStringAsFixed(0);
        }
      });
    }
  }
}

// ═══════════════════════════════════════════════════════
//  MODELO DE DATOS PARA COMPONENTES
// ═══════════════════════════════════════════════════════

class _ComponentFormData {
  final String materialId;
  final String name;
  final String category;
  final String description;
  final String label; // Título de la pieza (ej: "tapa lateral")
  final MaterialShape shape;
  final double? outerDiameter;
  final double? thickness;
  final double? length;
  final double? width;
  final int quantity;
  final double weightPerUnit;
  final double pricePerUnit;
  final double costPricePerUnit;

  _ComponentFormData({
    this.materialId = '',
    this.name = '',
    this.category = '',
    this.description = '',
    this.label = '',
    this.shape = MaterialShape.custom,
    this.outerDiameter,
    this.thickness,
    this.length,
    this.width,
    this.quantity = 1,
    this.weightPerUnit = 0,
    this.pricePerUnit = 0,
    this.costPricePerUnit = 0,
  });

  double get totalWeight => weightPerUnit * quantity;
  double get totalPrice => pricePerUnit * quantity;
  double get totalCostPrice => costPricePerUnit * quantity;

  factory _ComponentFormData.fromComponent(ProductComponent c) {
    return _ComponentFormData(
      materialId: c.materialId,
      name: c.materialName ?? '',
      category: '',
      description: c.dimensionsDescription,
      label: c.label ?? '',
      shape: c.shape ?? MaterialShape.custom,
      outerDiameter: c.outerDiameter,
      thickness: c.thickness,
      length: c.length,
      width: c.width,
      quantity: c.quantity,
      weightPerUnit: c.weightPerUnit,
      pricePerUnit: c.pricePerUnit,
      costPricePerUnit: c.costPricePerUnit,
    );
  }

  ProductComponent toComponent() {
    return ProductComponent(
      id: '',
      materialId: materialId,
      materialName: name,
      label: label.isNotEmpty ? label : null,
      shape: shape,
      outerDiameter: outerDiameter,
      thickness: thickness,
      length: length,
      width: width,
      quantity: quantity,
      weightPerUnit: weightPerUnit,
      pricePerUnit: pricePerUnit,
      costPricePerUnit: costPricePerUnit,
    );
  }
}
