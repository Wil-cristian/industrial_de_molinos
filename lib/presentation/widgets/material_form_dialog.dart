import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers/providers.dart';
import '../../data/providers/suppliers_provider.dart';
import '../../data/providers/settings_provider.dart';
import '../../data/providers/purchase_orders_provider.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../domain/entities/material.dart' as mat;
import '../../domain/entities/material_category.dart';
import '../../core/utils/material_code_generator.dart';

/// Diálogo reutilizable para crear o editar un Material.
/// Se puede invocar desde cualquier parte de la app (materials_page, scan dialog, etc.)
/// Si se pasa [suggestedName], [suggestedUnitPrice], etc., se pre-llenan los campos.
/// Retorna el Material creado/editado, o null si se canceló.
class MaterialFormDialog extends ConsumerStatefulWidget {
  final mat.Material? initial;
  final String? suggestedName;
  final double? suggestedCostPrice;
  final double? suggestedUnitPrice;
  final String? suggestedUnit;
  final String? suggestedCategory;

  const MaterialFormDialog({
    super.key,
    this.initial,
    this.suggestedName,
    this.suggestedCostPrice,
    this.suggestedUnitPrice,
    this.suggestedUnit,
    this.suggestedCategory,
  });

  /// Muestra el diálogo y retorna el material creado/editado, o null.
  /// En móvil (<600dp) se abre como página fullscreen con AppBar.
  static Future<mat.Material?> show(
    BuildContext context, {
    mat.Material? initial,
    String? suggestedName,
    double? suggestedCostPrice,
    double? suggestedUnitPrice,
    String? suggestedUnit,
    String? suggestedCategory,
  }) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final widget = MaterialFormDialog(
      initial: initial,
      suggestedName: suggestedName,
      suggestedCostPrice: suggestedCostPrice,
      suggestedUnitPrice: suggestedUnitPrice,
      suggestedUnit: suggestedUnit,
      suggestedCategory: suggestedCategory,
    );
    if (isMobile) {
      return Navigator.of(context, rootNavigator: true).push<mat.Material?>(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => widget),
      );
    }
    return showDialog<mat.Material?>(context: context, builder: (_) => widget);
  }

  @override
  ConsumerState<MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends ConsumerState<MaterialFormDialog> {
  late final bool isEditing;
  late final TextEditingController codeCtrl;
  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController costPriceCtrl;
  late final TextEditingController priceKgCtrl;
  late final TextEditingController priceUnitCtrl;
  late final TextEditingController stockCtrl;
  late final TextEditingController minStockCtrl;
  late final TextEditingController supplierCtrl;
  late final TextEditingController locationCtrl;
  late final TextEditingController outerDiameterCtrl;
  late final TextEditingController wallThicknessCtrl;
  late final TextEditingController thicknessCtrl;
  late final TextEditingController totalLengthCtrl;
  late final TextEditingController widthCtrl;
  String? selectedSupplierId;
  late String category;
  late String unit;
  String? subcategoryId;

  // Auto-code generation
  bool _autoCodeEnabled = true;
  bool _isGeneratingCode = false;
  String _codePreview = '';

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    isEditing = m != null;

    codeCtrl = TextEditingController(text: m?.code ?? '');
    nameCtrl = TextEditingController(
      text: m?.name ?? widget.suggestedName ?? '',
    );
    descCtrl = TextEditingController(text: m?.description ?? '');
    costPriceCtrl = TextEditingController(
      text: (m?.costPrice ?? widget.suggestedCostPrice ?? 0).toString(),
    );
    priceKgCtrl = TextEditingController(text: (m?.pricePerKg ?? 0).toString());
    priceUnitCtrl = TextEditingController(
      text: (m?.unitPrice ?? widget.suggestedUnitPrice ?? 0).toString(),
    );
    stockCtrl = TextEditingController(text: (m?.stock ?? 0).toString());
    minStockCtrl = TextEditingController(text: (m?.minStock ?? 0).toString());
    supplierCtrl = TextEditingController(text: m?.supplier ?? '');
    locationCtrl = TextEditingController(text: m?.location ?? '');

    outerDiameterCtrl = TextEditingController(
      text: m != null && (m.outerDiameter ?? 0) > 0
          ? m.outerDiameter.toString()
          : '',
    );
    wallThicknessCtrl = TextEditingController(
      text: m != null && (m.wallThickness ?? 0) > 0
          ? m.wallThickness.toString()
          : '',
    );
    thicknessCtrl = TextEditingController(
      text: m != null && (m.thickness ?? 0) > 0 ? m.thickness.toString() : '',
    );
    totalLengthCtrl = TextEditingController(
      text: m != null && (m.totalLength ?? 0) > 0
          ? (m.totalLength! * 100).toStringAsFixed(
              m.totalLength! * 100 == (m.totalLength! * 100).roundToDouble()
                  ? 0
                  : 2,
            )
          : '',
    );
    widthCtrl = TextEditingController(
      text: m != null && (m.width ?? 0) > 0
          ? (m.width! * 100).toStringAsFixed(
              m.width! * 100 == (m.width! * 100).roundToDouble() ? 0 : 2,
            )
          : '',
    );

    // Categoría y unidad
    final catState = ref.read(materialCategoryProvider);
    category =
        m?.category ??
        widget.suggestedCategory ??
        (catState.categories.isNotEmpty ? catState.categories.first.slug : '');
    final initialCat = catState.categories.where((c) => c.slug == category);

    // Unidad sugerida o inferida de la categoría
    final sugUnit = widget.suggestedUnit?.toUpperCase();
    unit =
        m?.unit.toUpperCase() ??
        (sugUnit != null && MaterialCategory.availableUnits.containsKey(sugUnit)
            ? sugUnit
            : (initialCat.isNotEmpty ? initialCat.first.defaultUnit : 'KG'));
    if (!MaterialCategory.availableUnits.containsKey(unit)) {
      unit = 'KG';
    }
    subcategoryId = m?.subcategoryId;

    // Disable auto-code for editing existing materials
    _autoCodeEnabled = !isEditing && codeCtrl.text.isEmpty;

    // Listen to name changes for auto-code generation
    nameCtrl.addListener(_onNameChanged);

    // Ensure categories are loaded
    _ensureCategoriesLoaded();
  }

  Future<void> _ensureCategoriesLoaded() async {
    final catState = ref.read(materialCategoryProvider);
    if (catState.categories.isEmpty && !catState.isLoading) {
      await ref.read(materialCategoryProvider.notifier).loadCategories();
      // Update default category after load
      if (mounted) {
        final loaded = ref.read(materialCategoryProvider);
        if (loaded.categories.isNotEmpty && category.isEmpty) {
          setState(() => category = loaded.categories.first.slug);
        }
      }
    }
  }

  void _onNameChanged() {
    if (_autoCodeEnabled) _generateAutoCode();
  }

  /// Genera el código automático basado en nombre + categoría + subcategoría.
  Future<void> _generateAutoCode() async {
    if (!_autoCodeEnabled || !mounted) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _codePreview = '';
        codeCtrl.text = '';
      });
      return;
    }

    // Get category code prefix
    final catState = ref.read(materialCategoryProvider);
    final cats = catState.categories.where((c) => c.slug == category);
    final catPrefix = cats.isNotEmpty
        ? (cats.first.codePrefix ??
              cats.first.sortOrder.toString().padLeft(2, '0'))
        : '00';

    // Get subcategory slug
    String? subcatSlug;
    if (subcategoryId != null) {
      final subcats = catState.subcategories.where(
        (s) => s.id == subcategoryId,
      );
      if (subcats.isNotEmpty) subcatSlug = subcats.first.slug;
    }

    // Build prefix for preview
    final prefix = MaterialCodeGenerator.codePrefix(
      name: name,
      categoryCodePrefix: catPrefix,
      subcategorySlug: subcatSlug,
    );

    // Show preview immediately
    if (mounted) {
      setState(() {
        _codePreview = '$prefix-...';
        _isGeneratingCode = true;
      });
    }

    // Query next sequential
    try {
      final nextSeq = await InventoryDataSource.getNextSequential(prefix);
      if (!mounted || !_autoCodeEnabled) return;
      final code = MaterialCodeGenerator.generate(
        name: name,
        categoryCodePrefix: catPrefix,
        subcategorySlug: subcatSlug,
        nextSequential: nextSeq,
      );
      setState(() {
        codeCtrl.text = code;
        _codePreview = code;
        _isGeneratingCode = false;
      });
    } catch (_) {
      // Fallback: use timestamp-based sequential
      if (!mounted || !_autoCodeEnabled) return;
      final fallbackSeq = DateTime.now().millisecondsSinceEpoch % 10000;
      final code = '$prefix-${fallbackSeq.toString().padLeft(4, '0')}';
      setState(() {
        codeCtrl.text = code;
        _codePreview = code;
        _isGeneratingCode = false;
      });
    }
  }

  @override
  void dispose() {
    nameCtrl.removeListener(_onNameChanged);
    codeCtrl.dispose();
    nameCtrl.dispose();
    descCtrl.dispose();
    costPriceCtrl.dispose();
    priceKgCtrl.dispose();
    priceUnitCtrl.dispose();
    stockCtrl.dispose();
    minStockCtrl.dispose();
    supplierCtrl.dispose();
    locationCtrl.dispose();
    outerDiameterCtrl.dispose();
    wallThicknessCtrl.dispose();
    thicknessCtrl.dispose();
    totalLengthCtrl.dispose();
    widthCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Editar Material' : 'Nuevo Material'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _onSave,
                child: Text(isEditing ? 'Guardar' : 'Crear'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCodeCategoryRow(),
                _buildSubcategoryRow(),
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
                _buildUnitDropdown(),
                const SizedBox(height: 16),
                if (_hasDimensions) _buildDimensionsSection(),
                _buildPricingSection(),
                const SizedBox(height: 16),
                _buildStockRow(),
                const SizedBox(height: 16),
                _buildSupplierLocationRow(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }

    final dialogWidth = 600.0;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Material' : 'Nuevo Material'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Código + Categoría
              _buildCodeCategoryRow(),
              // Subcategoría
              _buildSubcategoryRow(),
              const SizedBox(height: 16),
              // Nombre
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              const SizedBox(height: 16),
              // Descripción
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // Unidad
              _buildUnitDropdown(),
              const SizedBox(height: 16),
              // Dimensiones
              if (_hasDimensions) _buildDimensionsSection(),
              // Precios
              _buildPricingSection(),
              const SizedBox(height: 16),
              // Stock
              _buildStockRow(),
              const SizedBox(height: 16),
              // Proveedor + Ubicación
              _buildSupplierLocationRow(),
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
          onPressed: _onSave,
          child: Text(isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  bool get _hasDimensions =>
      category == 'tubo' ||
      category == 'eje' ||
      category == 'perfil' ||
      category == 'lamina';

  // ─── Code + Category ───────────────────────────────────────────
  Widget _buildCodeCategoryRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: codeCtrl,
            readOnly: _autoCodeEnabled,
            decoration: InputDecoration(
              labelText: 'Código *',
              helperText: _autoCodeEnabled ? 'Auto-generado' : null,
              helperStyle: const TextStyle(
                fontSize: 10,
                color: Color(0xFF4CAF50),
              ),
              suffixIcon: !isEditing
                  ? IconButton(
                      icon: Icon(
                        _autoCodeEnabled ? Icons.lock : Icons.lock_open,
                        size: 18,
                        color: _autoCodeEnabled
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF9E9E9E),
                      ),
                      tooltip: _autoCodeEnabled
                          ? 'Código automático (clic para editar manual)'
                          : 'Código manual (clic para auto-generar)',
                      onPressed: () {
                        setState(() {
                          _autoCodeEnabled = !_autoCodeEnabled;
                          if (_autoCodeEnabled) {
                            _generateAutoCode();
                          }
                        });
                      },
                    )
                  : null,
              suffix: _isGeneratingCode
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Builder(
            builder: (context) {
              final catState = ref.watch(materialCategoryProvider);
              final cats = catState.categories;
              final fallback = cats.isNotEmpty ? cats.first.slug : '';
              final validCategory = cats.any((c) => c.slug == category)
                  ? category
                  : fallback;
              if (validCategory != category) {
                Future.microtask(
                  () => setState(() => category = validCategory),
                );
              }
              if (cats.isEmpty) {
                if (catState.isLoading) {
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (catState.error != null) {
                  return Text(
                    'Error: ${catState.error}',
                    style: const TextStyle(fontSize: 10, color: Colors.red),
                  );
                }
                return const Text(
                  'Sin categorías',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                );
              }
              return DropdownButtonFormField<String>(
                value: validCategory,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: cats
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.slug,
                        child: Row(
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
                            Expanded(
                              child: Text(
                                c.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  category = v!;
                  subcategoryId = null;
                  final selectedCat = cats.firstWhere((c) => c.slug == v);
                  unit = selectedCat.defaultUnit.toUpperCase();
                  if (_autoCodeEnabled) _generateAutoCode();
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Subcategory ───────────────────────────────────────────────
  Widget _buildSubcategoryRow() {
    return Builder(
      builder: (context) {
        final catState = ref.watch(materialCategoryProvider);
        final subcats = catState.subcategoriesForSlug(category);
        final validSubcatId = subcats.any((s) => s.id == subcategoryId)
            ? subcategoryId
            : null;
        if (validSubcatId != subcategoryId) {
          Future.microtask(() => setState(() => subcategoryId = validSubcatId));
        }
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              if (subcats.isNotEmpty)
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: validSubcatId,
                    decoration: const InputDecoration(
                      labelText: 'Subcategoría',
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Sin subcategoría',
                          style: TextStyle(color: Color(0xFF9E9E9E)),
                        ),
                      ),
                      ...subcats.map(
                        (s) => DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.name),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => subcategoryId = v);
                      if (_autoCodeEnabled) _generateAutoCode();
                    },
                  ),
                )
              else
                Expanded(
                  child: Text(
                    'Sin subcategorías',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── Unit dropdown ─────────────────────────────────────────────
  Widget _buildUnitDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey('unit_$unit'),
      value: unit,
      decoration: const InputDecoration(labelText: 'Unidad de Medida'),
      items: const [
        DropdownMenuItem(value: 'KG', child: Text('Kilogramos (KG)')),
        DropdownMenuItem(value: 'UND', child: Text('Unidades (UND)')),
        DropdownMenuItem(value: 'M', child: Text('Metros (M)')),
        DropdownMenuItem(value: 'L', child: Text('Litros (L)')),
        DropdownMenuItem(value: 'M2', child: Text('Metros² (M²)')),
        DropdownMenuItem(value: 'GAL', child: Text('Galones (GAL)')),
      ],
      onChanged: (v) => setState(() => unit = v!),
    );
  }

  // ─── Dimensions Section ────────────────────────────────────────
  Widget _buildDimensionsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF7B1FA2).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7B1FA2).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten, size: 18, color: Color(0xFF7B1FA2)),
              const SizedBox(width: 8),
              const Text(
                'Dimensiones del Material',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B1FA2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (category == 'tubo' ||
              category == 'eje' ||
              category == 'perfil') ...[
            _buildFractionInchField(
              controller: outerDiameterCtrl,
              label: 'Diámetro exterior',
              helperText: 'Ej: 42 o 1.5',
            ),
            const SizedBox(height: 18),
            _buildFractionInchField(
              controller: wallThicknessCtrl,
              label: category == 'eje'
                  ? 'N/A (eje sólido)'
                  : 'Espesor de pared',
              helperText: category == 'eje'
                  ? 'No aplica para ejes sólidos'
                  : 'Ej: 0.25 o 1/4"',
              enabled: category != 'eje',
            ),
            const SizedBox(height: 18),
          ],
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
                    keyboardType: const TextInputType.numberWithOptions(
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: totalLengthCtrl,
            decoration: const InputDecoration(
              labelText: 'Largo total (centímetros)',
              helperText: 'Ej: 44, 150, 600',
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _calculateWeight,
              icon: const Icon(Icons.calculate, size: 18),
              label: const Text('Calcular peso automáticamente'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Fraction inch field (inline version) ──────────────────────
  static const Map<String, double> _commonFractions = {
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

  Widget _buildFractionInchField({
    required TextEditingController controller,
    required String label,
    String? helperText,
    bool enabled = true,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              helperText: helperText,
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
            enabled: enabled,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<double>(
          onSelected: (value) {
            controller.text = value.toString();
            setState(() {});
          },
          enabled: enabled,
          tooltip: 'Seleccionar fracción',
          icon: Icon(
            Icons.format_list_numbered,
            size: 24,
            color: enabled
                ? AppColors.info
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          itemBuilder: (_) => _commonFractions.entries
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
                          color: AppColors.info.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '= ${e.value}"',
                        style: const TextStyle(fontSize: 11),
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

  // ─── Pricing Section ───────────────────────────────────────────
  Widget _buildPricingSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_money, size: 18, color: AppColors.info),
              const SizedBox(width: 8),
              const Text(
                'Precios y Margen de Ganancia',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.info,
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    prefixText: '\$ ',
                    prefixIcon: const Icon(
                      Icons.shopping_cart,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.warning.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (category != 'consumible') ...[
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: unit == 'KG' ? priceKgCtrl : priceUnitCtrl,
                    decoration: InputDecoration(
                      labelText: 'Precio de VENTA',
                      helperText: 'Lo que cobras al cliente',
                      helperStyle: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      prefixText: '\$ ',
                      prefixIcon: const Icon(
                        Icons.sell,
                        color: AppColors.success,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.success.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ],
          ),
          _buildMarginIndicator(),
        ],
      ),
    );
  }

  Widget _buildMarginIndicator() {
    if (category == 'consumible') {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Material de uso interno — sin precio de venta',
                  style: TextStyle(fontSize: 11, color: AppColors.warning),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final costPrice = double.tryParse(costPriceCtrl.text) ?? 0;
    final salePrice =
        double.tryParse(unit == 'KG' ? priceKgCtrl.text : priceUnitCtrl.text) ??
        0;

    if (costPrice > 0 && salePrice > 0) {
      final margin = (salePrice - costPrice) / costPrice * 100;
      final profit = salePrice - costPrice;
      final marginColor = margin > 30
          ? AppColors.success
          : margin > 15
          ? AppColors.warning
          : AppColors.danger;
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MARGEN',
                        style: TextStyle(
                          fontSize: 9,
                          color: marginColor.withOpacity(0.8),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GANANCIA POR ${unit.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 9,
                      color: marginColor.withOpacity(0.8),
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

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'Ingresa ambos precios para ver el margen de ganancia',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Stock Row ─────────────────────────────────────────────────
  Widget _buildStockRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: stockCtrl,
            decoration: InputDecoration(
              labelText: unit == 'KG' ? 'Stock Peso (kg)' : 'Stock ($unit)',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: minStockCtrl,
            decoration: InputDecoration(labelText: 'Stock Mín. ($unit)'),
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  // ─── Supplier + Location ───────────────────────────────────────
  Widget _buildSupplierLocationRow() {
    return Row(
      children: [
        Expanded(
          child: Builder(
            builder: (context) {
              final suppState = ref.read(suppliersProvider);
              final suppliers = suppState.suppliers;
              if (suppliers.isEmpty && !suppState.isLoading) {
                Future.microtask(
                  () => ref.read(suppliersProvider.notifier).loadSuppliers(),
                );
              }
              return DropdownButtonFormField<String>(
                value:
                    supplierCtrl.text.isNotEmpty &&
                        suppliers.any((s) => s.name == supplierCtrl.text)
                    ? supplierCtrl.text
                    : null,
                decoration: const InputDecoration(labelText: 'Proveedor'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text(
                      'Sin proveedor',
                      style: TextStyle(color: Color(0xFF9E9E9E)),
                    ),
                  ),
                  ...suppliers.map(
                    (s) => DropdownMenuItem(
                      value: s.name,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) {
                  supplierCtrl.text = v ?? '';
                  final sel = suppliers.where((s) => s.name == v);
                  selectedSupplierId = sel.isNotEmpty ? sel.first.id : null;
                },
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Builder(
            builder: (context) {
              final settingsState = ref.read(settingsProvider);
              final locations = settingsState.storageLocations;
              if (locations.isEmpty && !settingsState.isLoading) {
                Future.microtask(
                  () => ref.read(settingsProvider.notifier).loadAll(),
                );
              }
              return DropdownButtonFormField<String>(
                value:
                    locationCtrl.text.isNotEmpty &&
                        locations.any((l) => l.name == locationCtrl.text)
                    ? locationCtrl.text
                    : null,
                decoration: const InputDecoration(labelText: 'Ubicación'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text(
                      'Sin ubicación',
                      style: TextStyle(color: Color(0xFF9E9E9E)),
                    ),
                  ),
                  ...locations.map(
                    (l) => DropdownMenuItem(
                      value: l.name,
                      child: Text(l.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => locationCtrl.text = v ?? '',
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Calculate Weight ──────────────────────────────────────────
  void _calculateWeight() {
    double weight = 0;

    if (category == 'lamina') {
      final largoCm = double.tryParse(totalLengthCtrl.text) ?? 0;
      final anchoCm = double.tryParse(widthCtrl.text) ?? 0;
      final espesorPulg = double.tryParse(thicknessCtrl.text) ?? 0;
      if (largoCm <= 0 || anchoCm <= 0 || espesorPulg <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingresa largo, ancho y espesor'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      final largoMm = largoCm * 10;
      final anchoMm = anchoCm * 10;
      final espesorMm = espesorPulg * 25.4;
      weight = largoMm * anchoMm * espesorMm * 7.85e-6;
    } else {
      final diameter = double.tryParse(outerDiameterCtrl.text) ?? 0;
      final thickness = double.tryParse(wallThicknessCtrl.text) ?? 0;
      final lengthCm = double.tryParse(totalLengthCtrl.text) ?? 0;
      if (diameter <= 0 || lengthCm <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingresa diámetro y largo'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      final diameterMm = diameter * 25.4;
      final thicknessMm = (thickness > 0 ? thickness : 0) * 25.4;
      final diameterInnerMm = diameterMm - (2 * thicknessMm);
      final lengthMm = lengthCm * 10;
      if (category == 'eje') {
        weight = (3.14159 * diameterMm * diameterMm / 4) * lengthMm * 7.85e-6;
      } else {
        weight =
            (3.14159 *
                (diameterMm * diameterMm - diameterInnerMm * diameterInnerMm) /
                4) *
            lengthMm *
            7.85e-6;
      }
    }

    setState(() => stockCtrl.text = weight.toStringAsFixed(2));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Peso calculado: ${weight.toStringAsFixed(2)} kg'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  // ─── Save ──────────────────────────────────────────────────────
  Future<void> _onSave() async {
    if (codeCtrl.text.isEmpty && !isEditing) {
      // Generate auto-code on save if still empty
      await _generateAutoCode();
      if (codeCtrl.text.isEmpty) {
        codeCtrl.text = 'MAT-${DateTime.now().millisecondsSinceEpoch % 100000}';
      }
    }
    if (nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('El nombre es requerido')));
      return;
    }

    final newMaterial = mat.Material(
      id: widget.initial?.id ?? '',
      code: codeCtrl.text,
      name: nameCtrl.text,
      description: descCtrl.text.isEmpty ? null : descCtrl.text,
      category: category,
      subcategoryId: subcategoryId,
      unit: unit,
      costPrice: double.tryParse(costPriceCtrl.text) ?? 0,
      pricePerKg: double.tryParse(priceKgCtrl.text) ?? 0,
      unitPrice: double.tryParse(priceUnitCtrl.text) ?? 0,
      stock: double.tryParse(stockCtrl.text) ?? 0,
      minStock: double.tryParse(minStockCtrl.text) ?? 0,
      outerDiameter: double.tryParse(outerDiameterCtrl.text) ?? 0,
      wallThickness: double.tryParse(wallThicknessCtrl.text) ?? 0,
      thickness: double.tryParse(thicknessCtrl.text) ?? 0,
      totalLength: ((double.tryParse(totalLengthCtrl.text) ?? 0) / 100),
      width: ((double.tryParse(widthCtrl.text) ?? 0) / 100),
      supplier: supplierCtrl.text.isEmpty ? null : supplierCtrl.text,
      location: locationCtrl.text.isEmpty ? null : locationCtrl.text,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      mat.Material savedMaterial;
      if (isEditing) {
        await ref.read(inventoryProvider.notifier).updateMaterial(newMaterial);
        savedMaterial = newMaterial;
      } else {
        final created = await InventoryDataSource.createMaterial(newMaterial);
        savedMaterial = created;
      }

      // Guardar precio proveedor-material si hay proveedor seleccionado
      if (selectedSupplierId != null && savedMaterial.id.isNotEmpty) {
        await ref
            .read(supplierMaterialsProvider.notifier)
            .upsertPrice(
              supplierId: selectedSupplierId!,
              materialId: savedMaterial.id,
              unitPrice: savedMaterial.costPrice > 0
                  ? savedMaterial.costPrice
                  : savedMaterial.pricePerKg,
            );
      }

      if (mounted) Navigator.pop(context, savedMaterial);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }
}
