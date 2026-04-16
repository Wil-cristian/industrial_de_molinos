import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/helpers.dart';
import '../../core/utils/logger.dart';
import '../../data/datasources/invoices_datasource.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/material.dart' as domain;

/// Página de detalle de materiales para una entrega pendiente.
/// Muestra qué materiales hay en stock y cuáles faltan por comprar.
class DeliveryMaterialDetailPage extends ConsumerStatefulWidget {
  final Invoice invoice;

  const DeliveryMaterialDetailPage({super.key, required this.invoice});

  @override
  ConsumerState<DeliveryMaterialDetailPage> createState() =>
      _DeliveryMaterialDetailPageState();
}

class _DeliveryMaterialDetailPageState
    extends ConsumerState<DeliveryMaterialDetailPage> {
  bool _isLoading = true;
  // Lista consolidada de materiales necesarios
  List<_MaterialRequirement> _requirements = [];

  double get _costInStock =>
      _requirements.fold(0.0, (s, r) => s + r.costFromStock);
  double get _costToBuy => _requirements.fold(0.0, (s, r) => s + r.costToBuy);
  double get _totalMaterialCost => _costInStock + _costToBuy;

  @override
  void initState() {
    super.initState();
    _analyzeRequirements();
  }

  Future<void> _analyzeRequirements() async {
    setState(() => _isLoading = true);
    try {
      final invoice = widget.invoice;
      // Mapa acumulador: materialId → _MaterialAccum
      final accum = <String, _MaterialAccum>{};

      for (final item in invoice.items) {
        if (item.productId != null && item.productId!.isNotEmpty) {
          // Verificar si es receta
          final product = await InventoryDataSource.client
              .from('products')
              .select('id, name, is_recipe')
              .eq('id', item.productId!)
              .maybeSingle();

          if (product != null && product['is_recipe'] == true) {
            // Cargar componentes de la receta
            final components = await InventoryDataSource.getProductComponents(
              item.productId!,
            );
            for (final comp in components) {
              final matId = comp.materialId;
              if (matId == null || matId.isEmpty) continue;
              if (!accum.containsKey(matId)) {
                accum[matId] = _MaterialAccum(
                  materialId: matId,
                  materialName: comp.name,
                  materialCode: '',
                );
              }
              // calculatedWeight es el peso del componente por unidad de receta
              // quantity del componente × item.quantity de la factura
              final neededQty = comp.calculatedWeight > 0
                  ? comp.calculatedWeight * item.quantity
                  : comp.quantity * item.quantity;
              final costPerUnit = comp.unitCost > 0 ? comp.unitCost : 0.0;
              accum[matId]!.requiredQty += neededQty;
              if (costPerUnit > 0) {
                accum[matId]!.costPerUnit = costPerUnit;
              }
              accum[matId]!.sources.add(
                '${product['name']} ×${item.quantity.toStringAsFixed(0)}',
              );
            }
          }
          // Productos simples (no receta) no descomponen en materiales
        } else if (item.materialId != null && item.materialId!.isNotEmpty) {
          // Material directo
          final matId = item.materialId!;
          if (!accum.containsKey(matId)) {
            accum[matId] = _MaterialAccum(
              materialId: matId,
              materialName: item.productName,
              materialCode: item.productCode ?? '',
            );
          }
          accum[matId]!.requiredQty += item.quantity;
          accum[matId]!.sources.add('Material directo');
        }
      }

      // Ahora consultar stock actual de cada material
      final allMaterials = await InventoryDataSource.getAllMaterials();
      final materialMap = <String, domain.Material>{};
      for (final m in allMaterials) {
        materialMap[m.id] = m;
      }

      final requirements = <_MaterialRequirement>[];
      for (final entry in accum.entries) {
        final mat = materialMap[entry.key];
        final a = entry.value;
        final available = mat?.stock ?? 0;
        final costPrice = mat?.effectiveCostPrice ?? a.costPerUnit;
        final fromStock = min(a.requiredQty, max(0.0, available));
        final toBuy = max(0.0, a.requiredQty - available);

        requirements.add(
          _MaterialRequirement(
            materialId: a.materialId,
            materialName: a.materialName.isNotEmpty
                ? a.materialName
                : (mat?.name ?? 'Material'),
            materialCode: a.materialCode.isNotEmpty
                ? a.materialCode
                : (mat?.code ?? ''),
            unit: mat?.unit ?? 'KG',
            requiredQty: a.requiredQty,
            availableStock: available,
            fromStock: fromStock,
            toBuy: toBuy,
            costPerUnit: costPrice,
            sources: a.sources.toSet().toList(),
          ),
        );
      }

      // Ordenar: primero los que faltan (toBuy > 0), luego los que hay
      requirements.sort((a, b) {
        if (a.toBuy > 0 && b.toBuy <= 0) return -1;
        if (a.toBuy <= 0 && b.toBuy > 0) return 1;
        return a.materialName.compareTo(b.materialName);
      });

      setState(() {
        _requirements = requirements;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Error analizando materiales: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAndGoBack() async {
    try {
      await InvoicesDataSource.updateMaterialCosts(
        widget.invoice.id,
        materialCostTotal: _totalMaterialCost,
        materialCostPending: _costToBuy,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Costos calculados para ${widget.invoice.fullNumber}: '
              'Total ${Helpers.formatCurrency(_totalMaterialCost)}, '
              'Por comprar ${Helpers.formatCurrency(_costToBuy)}',
            ),
            backgroundColor: const Color(0xFF43A047),
          ),
        );
        Navigator.of(context).pop(true); // true = refresh parent
      }
    } catch (e) {
      AppLogger.error('Error guardando costos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortage = _requirements.where((r) => r.toBuy > 0).toList();
    final inStock = _requirements.where((r) => r.toBuy <= 0).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Materiales - ${widget.invoice.fullNumber}',
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _analyzeRequirements,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recalcular',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requirements.isEmpty
          ? _buildEmpty()
          : Column(
              children: [
                _buildSummaryBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    children: [
                      // Sección: Material por comprar
                      if (shortage.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Material por Comprar',
                          '${shortage.length} materiales',
                          const Color(0xFFC62828),
                          Icons.shopping_bag,
                        ),
                        const SizedBox(height: 8),
                        ...shortage.map(_buildShortageCard),
                        const SizedBox(height: 20),
                      ],
                      // Sección: Material en inventario
                      if (inStock.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Material en Inventario',
                          '${inStock.length} materiales disponibles',
                          const Color(0xFF43A047),
                          Icons.inventory_2,
                        ),
                        const SizedBox(height: 8),
                        ...inStock.map(_buildInStockCard),
                      ],
                    ],
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No se encontraron materiales',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Los items de esta factura no tienen recetas\no materiales asociados',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final shortage = _requirements.where((r) => r.toBuy > 0).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        children: [
          _buildMiniStat(
            'Material Total',
            Helpers.formatCurrency(_totalMaterialCost),
            const Color(0xFF6A1B9A),
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          _buildMiniStat(
            'En Inventario',
            Helpers.formatCurrency(_costInStock),
            const Color(0xFF43A047),
          ),
          Container(
            width: 1,
            height: 36,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          _buildMiniStat(
            'Por Comprar',
            Helpers.formatCurrency(_costToBuy),
            const Color(0xFFC62828),
          ),
          if (shortage > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$shortage faltan',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFC62828),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildShortageCard(_MaterialRequirement req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF9A9A)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC62828).withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  req.materialCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC62828),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  req.materialName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Comprar: ${_fmtQty(req.toBuy)} ${req.unit}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC62828),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip(
                'Necesario',
                '${_fmtQty(req.requiredQty)} ${req.unit}',
                const Color(0xFF1565C0),
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                'Disponible',
                '${_fmtQty(req.availableStock)} ${req.unit}',
                req.availableStock > 0
                    ? const Color(0xFFF57C00)
                    : const Color(0xFFC62828),
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                'Costo compra',
                Helpers.formatCurrency(req.costToBuy),
                const Color(0xFFC62828),
              ),
            ],
          ),
          if (req.sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Usado en: ${req.sources.join(', ')}',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInStockCard(_MaterialRequirement req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF43A047), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${req.materialCode} — ${req.materialName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_fmtQty(req.requiredQty)} ${req.unit} necesarios • ${_fmtQty(req.availableStock)} ${req.unit} disponibles',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            Helpers.formatCurrency(req.costFromStock),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6A1B9A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: color)),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2,
                      size: 16,
                      color: Color(0xFF6A1B9A),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Material Total: ${Helpers.formatCurrency(_totalMaterialCost)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.shopping_bag,
                      size: 16,
                      color: Color(0xFFC62828),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Por Comprar: ${Helpers.formatCurrency(_costToBuy)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC62828),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _saveAndGoBack,
            icon: const Icon(Icons.save),
            label: const Text('Guardar Costos'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

// ═══════════════════ Modelos internos ═══════════════════

class _MaterialAccum {
  final String materialId;
  String materialName;
  String materialCode;
  double requiredQty = 0;
  double costPerUnit = 0;
  final List<String> sources = [];

  _MaterialAccum({
    required this.materialId,
    required this.materialName,
    required this.materialCode,
  });
}

class _MaterialRequirement {
  final String materialId;
  final String materialName;
  final String materialCode;
  final String unit;
  final double requiredQty;
  final double availableStock;
  final double fromStock;
  final double toBuy;
  final double costPerUnit;
  final List<String> sources;

  _MaterialRequirement({
    required this.materialId,
    required this.materialName,
    required this.materialCode,
    required this.unit,
    required this.requiredQty,
    required this.availableStock,
    required this.fromStock,
    required this.toBuy,
    required this.costPerUnit,
    required this.sources,
  });

  double get costFromStock => fromStock * costPerUnit;
  double get costToBuy => toBuy * costPerUnit;
}
