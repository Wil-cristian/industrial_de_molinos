import 'package:flutter/material.dart';
import '../../data/datasources/products_datasource.dart';
import '../../domain/entities/product.dart';

/// Diálogo reutilizable para crear un Producto rápidamente.
/// Acepta valores sugeridos para pre-llenar campos.
/// Retorna el Product creado, o null si se canceló.
class QuickProductDialog extends StatefulWidget {
  final String? suggestedCode;
  final String? suggestedName;
  final String? suggestedDescription;
  final double? suggestedUnitPrice;
  final double? suggestedCostPrice;
  final String? suggestedUnit;
  final bool showScanBanner;

  const QuickProductDialog({
    super.key,
    this.suggestedCode,
    this.suggestedName,
    this.suggestedDescription,
    this.suggestedUnitPrice,
    this.suggestedCostPrice,
    this.suggestedUnit,
    this.showScanBanner = false,
  });

  static Future<Product?> show(
    BuildContext context, {
    String? suggestedCode,
    String? suggestedName,
    String? suggestedDescription,
    double? suggestedUnitPrice,
    double? suggestedCostPrice,
    String? suggestedUnit,
    bool showScanBanner = false,
  }) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final widget = QuickProductDialog(
      suggestedCode: suggestedCode,
      suggestedName: suggestedName,
      suggestedDescription: suggestedDescription,
      suggestedUnitPrice: suggestedUnitPrice,
      suggestedCostPrice: suggestedCostPrice,
      suggestedUnit: suggestedUnit,
      showScanBanner: showScanBanner,
    );
    if (isMobile) {
      return Navigator.of(context, rootNavigator: true).push<Product?>(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => widget),
      );
    }
    return showDialog<Product?>(context: context, builder: (_) => widget);
  }

  @override
  State<QuickProductDialog> createState() => _QuickProductDialogState();
}

class _QuickProductDialogState extends State<QuickProductDialog> {
  late final TextEditingController codeCtrl;
  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController unitPriceCtrl;
  late final TextEditingController costPriceCtrl;
  late final TextEditingController unitCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    codeCtrl = TextEditingController(
      text:
          widget.suggestedCode ??
          'PROD-${DateTime.now().millisecondsSinceEpoch % 100000}',
    );
    nameCtrl = TextEditingController(text: widget.suggestedName ?? '');
    descCtrl = TextEditingController(
      text: widget.suggestedDescription ?? widget.suggestedName ?? '',
    );
    unitPriceCtrl = TextEditingController(
      text: (widget.suggestedUnitPrice ?? 0).toStringAsFixed(2),
    );
    costPriceCtrl = TextEditingController(
      text: (widget.suggestedCostPrice ?? 0).toStringAsFixed(2),
    );
    unitCtrl = TextEditingController(text: widget.suggestedUnit ?? 'UND');
  }

  @override
  void dispose() {
    codeCtrl.dispose();
    nameCtrl.dispose();
    descCtrl.dispose();
    unitPriceCtrl.dispose();
    costPriceCtrl.dispose();
    unitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final formContent = SingleChildScrollView(
      padding: isMobile ? const EdgeInsets.all(16) : EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showScanBanner)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Color(0xFF1565C0)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Datos pre-llenados desde el escaneo. Revisa y ajusta.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1565C0)),
                    ),
                  ),
                ],
              ),
            ),
          TextField(
            controller: codeCtrl,
            decoration: const InputDecoration(
              labelText: 'Código',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre *',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          if (isMobile) ...[
            TextField(
              controller: unitPriceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio venta',
                isDense: true,
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costPriceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio costo',
                isDense: true,
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: unitPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio venta',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: costPriceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio costo',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            controller: unitCtrl,
            decoration: const InputDecoration(
              labelText: 'Unidad',
              isDense: true,
              border: OutlineInputBorder(),
              hintText: 'UND, KG, M, etc.',
            ),
          ),
          if (isMobile) const SizedBox(height: 24),
        ],
      ),
    );

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Crear Producto',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saving ? null : () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _saving ? null : _onSave,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 16),
                label: const Text('Crear'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(child: formContent),
      );
    }

    return AlertDialog(
      title: const Text(
        'Crear Producto',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(width: 400, child: formContent),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _onSave,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check, size: 16),
          label: const Text('Crear Producto'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1565C0),
          ),
        ),
      ],
    );
  }

  Future<void> _onSave() async {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre del producto es requerido'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final defaultPrice = double.tryParse(unitPriceCtrl.text) ?? 0;
      final newProduct = await ProductsDataSource.create(
        Product(
          id: '',
          code: codeCtrl.text.trim(),
          name: name,
          description: descCtrl.text.trim(),
          unitPrice: double.tryParse(unitPriceCtrl.text) ?? defaultPrice,
          costPrice: double.tryParse(costPriceCtrl.text) ?? defaultPrice,
          stock: 0,
          minStock: 0,
          unit: unitCtrl.text.trim().isNotEmpty ? unitCtrl.text.trim() : 'UND',
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (mounted) {
        Navigator.pop(context, newProduct);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Producto "$name" creado'),
            backgroundColor: const Color(0xFF1565C0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creando producto: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }
}
