import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/providers.dart';
import '../../data/datasources/invoices_datasource.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/material.dart' as domain;
import '../../domain/entities/invoice.dart';

class NewInvoicePage extends ConsumerStatefulWidget {
  const NewInvoicePage({super.key});

  @override
  ConsumerState<NewInvoicePage> createState() => _NewInvoicePageState();
}

class _NewInvoicePageState extends ConsumerState<NewInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  
  // Tipo de comprobante
  InvoiceType _invoiceType = InvoiceType.invoice;
  String _series = 'F001';
  
  // Cliente seleccionado
  Customer? _selectedCustomer;
  
  // Fechas
  DateTime _issueDate = DateTime.now();
  DateTime? _dueDate;
  
  // Items de la factura
  final List<_InvoiceItemData> _items = [];
  
  // Notas
  final _notesController = TextEditingController();
  
  // Tipo de pago
  String _paymentType = 'credit'; // 'credit' o 'cash'
  
  // Estado
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now().add(const Duration(days: 30));
    
    // Cargar datos
    Future.microtask(() {
      ref.read(customersProvider.notifier).loadCustomers();
      ref.read(productsProvider.notifier).loadProducts();
      ref.read(inventoryProvider.notifier).loadMaterials();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Calcular totales
  double get _subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _taxAmount => _subtotal * 0.18;
  double get _total => _subtotal + _taxAmount;

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customersProvider);
    final productsState = ref.watch(productsProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/invoices'),
        ),
        title: const Text('Nueva Venta', style: TextStyle(color: Colors.white)),
        actions: [
          // Botón Guardar como Borrador
          OutlinedButton.icon(
            onPressed: _isSaving ? null : () => _saveInvoice(asDraft: true),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar Borrador'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 12),
          // Botón Emitir
          FilledButton.icon(
            onPressed: _isSaving || _items.isEmpty || _selectedCustomer == null 
                ? null 
                : () => _saveInvoice(asDraft: false),
            icon: _isSaving 
                ? const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                  )
                : const Icon(Icons.send),
            label: const Text('Emitir Comprobante'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              disabledBackgroundColor: Colors.white54,
              disabledForegroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Panel izquierdo - Formulario
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo de comprobante y serie
                    _buildSection(
                      title: 'Tipo de Comprobante',
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTypeSelector(),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              initialValue: _series,
                              decoration: const InputDecoration(
                                labelText: 'Serie',
                                border: OutlineInputBorder(),
                              ),
                              items: ['F001', 'F002', 'B001', 'B002']
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (v) => setState(() => _series = v ?? 'F001'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Cliente
                    _buildSection(
                      title: 'Cliente',
                      child: _buildCustomerSelector(customersState.customers),
                    ),
                    const SizedBox(height: 24),

                    // Fechas
                    _buildSection(
                      title: 'Fechas',
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              label: 'Fecha de Emisión',
                              value: _issueDate,
                              onChanged: (d) => setState(() => _issueDate = d),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDateField(
                              label: 'Fecha de Vencimiento',
                              value: _dueDate,
                              onChanged: (d) => setState(() => _dueDate = d),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Productos
                    _buildSection(
                      title: 'Productos / Servicios',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showAddMaterialDialog(ref.read(inventoryProvider).materials),
                            icon: const Icon(Icons.inventory_2_outlined, size: 18),
                            label: const Text('Agregar Material'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _showAddProductDialog(productsState.products),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Agregar Producto'),
                          ),
                        ],
                      ),
                      child: _buildItemsTable(),
                    ),
                    const SizedBox(height: 24),

                    // Notas
                    _buildSection(
                      title: 'Notas',
                      child: TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Notas adicionales para el recibo...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Panel derecho - Resumen
            Container(
              width: 350,
              margin: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      Text(
                        'Resumen',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Cliente info o advertencia
                      if (_selectedCustomer != null) ...[
                        _buildSummaryRow('Cliente', _selectedCustomer!.name),
                        _buildSummaryRow('RUC/DNI', _selectedCustomer!.documentNumber),
                        const Divider(height: 32),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Selecciona un cliente para emitir',
                                  style: TextStyle(color: Colors.orange, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 32),
                      ],

                      // Items count
                      _buildSummaryRow('Items', '${_items.length} productos'),
                      const SizedBox(height: 16),

                      // Totales
                      _buildSummaryRow('Subtotal', Formatters.currency(_subtotal)),
                      _buildSummaryRow('IGV (18%)', Formatters.currency(_taxAmount)),
                      const Divider(height: 24),
                      _buildSummaryRow(
                        'TOTAL',
                        Formatters.currency(_total),
                        isTotal: true,
                      ),

                      const SizedBox(height: 24),

                      // Tipo de pago
                      DropdownButtonFormField<String>(
                        initialValue: _paymentType,
                        decoration: const InputDecoration(
                          labelText: 'Condición de Pago',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.payment),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'credit',
                            child: Text('Crédito (30 días)'),
                          ),
                          DropdownMenuItem(
                            value: 'cash',
                            child: Text('Contado'),
                          ),
                          DropdownMenuItem(
                            value: 'installments',
                            child: Text('Cuotas'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _paymentType = value!;
                          });
                        },
                      ),

                      const SizedBox(height: 24),

                      // Botones de acción
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving || _items.isEmpty || _selectedCustomer == null 
                              ? null 
                              : () => _saveInvoice(asDraft: false),
                          icon: const Icon(Icons.send),
                          label: const Text('Emitir Comprobante'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return SegmentedButton<InvoiceType>(
      segments: const [
        ButtonSegment(
          value: InvoiceType.invoice,
          label: Text('Recibo de Caja Menor'),
          icon: Icon(Icons.receipt_long),
        ),
        ButtonSegment(
          value: InvoiceType.receipt,
          label: Text('Boleta'),
          icon: Icon(Icons.receipt),
        ),
      ],
      selected: {_invoiceType},
      onSelectionChanged: (selection) {
        setState(() {
          _invoiceType = selection.first;
          _series = _invoiceType == InvoiceType.invoice ? 'F001' : 'B001';
        });
      },
    );
  }

  Widget _buildCustomerSelector(List<Customer> customers) {
    return Column(
      children: [
        Autocomplete<Customer>(
          displayStringForOption: (c) => '${c.documentNumber} - ${c.name}',
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return customers.take(10);
            }
            final query = textEditingValue.text.toLowerCase();
            return customers.where((c) =>
              c.name.toLowerCase().contains(query) ||
              c.documentNumber.contains(query)
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Buscar cliente por RUC o nombre',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _selectedCustomer != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          setState(() => _selectedCustomer = null);
                        },
                      )
                    : null,
              ),
            );
          },
          onSelected: (customer) {
            setState(() => _selectedCustomer = customer);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300, maxWidth: 500),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final customer = options.elementAt(index);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          child: Icon(
                            customer.type == CustomerType.business
                                ? Icons.business
                                : Icons.person,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(customer.name),
                        subtitle: Text(customer.documentNumber),
                        onTap: () => onSelected(customer),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        if (_selectedCustomer != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.successColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedCustomer!.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_selectedCustomer!.documentType.name.toUpperCase()}: ${_selectedCustomer!.documentNumber}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (_selectedCustomer!.address != null)
                        Text(
                          _selectedCustomer!.address!,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required Function(DateTime) onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (date != null) onChanged(date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          value != null ? Formatters.date(value) : 'Seleccionar fecha',
        ),
      ),
    );
  }

  Widget _buildItemsTable() {
    if (_items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No hay productos agregados',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Haz clic en "Agregar" para añadir productos',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FixedColumnWidth(80),
        2: FixedColumnWidth(100),
        3: FixedColumnWidth(100),
        4: FixedColumnWidth(50),
      },
      border: TableBorder.all(color: Colors.grey[300]!),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[100]),
          children: const [
            Padding(
              padding: EdgeInsets.all(12),
              child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text('Cant.', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text('P. Unit.', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text('Subtotal', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text('', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        ..._items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(item.productCode, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextFormField(
                  initialValue: item.quantity.toString(),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final qty = double.tryParse(v) ?? 1;
                    setState(() => _items[index].quantity = qty);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(Formatters.currency(item.unitPrice)),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  Formatters.currency(item.subtotal),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? AppTheme.primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(List<Product> products) {
    showDialog(
      context: context,
      builder: (context) => _AddProductDialog(
        products: products,
        onAdd: (item) {
          setState(() => _items.add(item));
        },
      ),
    );
  }

  void _showAddMaterialDialog(List<domain.Material> materials) {
    showDialog(
      context: context,
      builder: (context) => _AddMaterialDialog(
        materials: materials,
        onAdd: (item) {
          setState(() => _items.add(item));
        },
      ),
    );
  }

  Future<void> _saveInvoice({required bool asDraft}) async {
    if (!asDraft && (_selectedCustomer == null || _items.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un cliente y agrega al menos un producto'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Crear recibo de caja menor
      final invoice = await InvoicesDataSource.createWithItems(
        type: _invoiceType == InvoiceType.invoice ? 'invoice' : 'receipt',
        series: _series,
        customer: _selectedCustomer!,
        issueDate: _issueDate,
        dueDate: _dueDate,
        items: _items.map((i) => InvoiceItem(
          id: '',
          invoiceId: '',
          productId: i.productId,
          materialId: i.materialId,
          productCode: i.productCode,
          productName: i.productName,
          description: i.productName,
          quantity: i.quantity,
          unit: i.unit,
          unitPrice: i.unitPrice,
          discount: 0,
          taxRate: 18,
          subtotal: i.subtotal,
          taxAmount: i.subtotal * 0.18,
          total: i.subtotal * 1.18,
        )).toList(),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      // Actualizar estado si no es borrador
      if (!asDraft) {
        await InvoicesDataSource.updateStatus(invoice.id, 'issued');
      }

      // Refrescar listas (recibos y productos para actualizar stock)
      ref.read(invoicesProvider.notifier).refresh();
      ref.read(productsProvider.notifier).loadProducts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(asDraft 
                ? 'Borrador guardado: ${invoice.fullNumber}'
                : 'Comprobante emitido: ${invoice.fullNumber}'
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

// Clase para manejar items del recibo de caja menor
class _InvoiceItemData {
  final String? productId;
  final String? materialId;
  final String productCode;
  final String productName;
  final String unit;
  final double unitPrice;
  double quantity;

  _InvoiceItemData({
    this.productId,
    this.materialId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.unitPrice,
    this.quantity = 1,
  });

  double get subtotal => unitPrice * quantity;
}

// Diálogo para agregar producto
class _AddProductDialog extends StatefulWidget {
  final List<Product> products;
  final Function(_InvoiceItemData) onAdd;

  const _AddProductDialog({
    required this.products,
    required this.onAdd,
  });

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _searchController = TextEditingController();
  Product? _selectedProduct;
  double _quantity = 1;

  List<Product> get _filteredProducts {
    if (_searchController.text.isEmpty) return widget.products;
    final query = _searchController.text.toLowerCase();
    return widget.products.where((p) =>
      p.name.toLowerCase().contains(query) ||
      p.code.toLowerCase().contains(query)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar Producto'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar producto',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  final isSelected = _selectedProduct?.id == product.id;
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        product.code.substring(0, 2),
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(product.name),
                    subtitle: Text('${product.code} • Receta'),
                    trailing: Text(
                      Formatters.currency(product.unitPrice),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => setState(() => _selectedProduct = product),
                  );
                },
              ),
            ),
            if (_selectedProduct != null) ...[
              const Divider(),
              // Mostrar info del producto (es receta)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.precision_manufacturing,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Producto fabricado bajo pedido',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text('Cantidad:', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _quantity > 1 
                        ? () => setState(() => _quantity--) 
                        : null,
                  ),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: _quantity.toStringAsFixed(0)),
                      onChanged: (v) {
                        final qty = double.tryParse(v);
                        if (qty != null && qty > 0) {
                          // Limitar al stock disponible
                          final maxQty = _selectedProduct!.stock;
                          setState(() => _quantity = qty > maxQty ? maxQty : qty);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    // Deshabilitar si se alcanza el stock máximo
                    onPressed: _quantity >= _selectedProduct!.stock
                        ? null
                        : () => setState(() => _quantity++),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${Formatters.currency(_selectedProduct!.unitPrice * _quantity)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selectedProduct == null
              ? null
              : () {
                  widget.onAdd(_InvoiceItemData(
                    productId: _selectedProduct!.id,
                    productCode: _selectedProduct!.code,
                    productName: _selectedProduct!.name,
                    unit: _selectedProduct!.unit,
                    unitPrice: _selectedProduct!.unitPrice,
                    quantity: _quantity,
                  ));
                  Navigator.pop(context);
                },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

// Diálogo para agregar material del inventario
class _AddMaterialDialog extends StatefulWidget {
  final List<domain.Material> materials;
  final Function(_InvoiceItemData) onAdd;

  const _AddMaterialDialog({
    required this.materials,
    required this.onAdd,
  });

  @override
  State<_AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends State<_AddMaterialDialog> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  domain.Material? _selectedMaterial;
  double _quantity = 1;

  List<String> get _categories {
    final cats = widget.materials.map((m) => m.category).toSet().toList();
    cats.sort();
    return cats;
  }

  List<domain.Material> get _filteredMaterials {
    var filtered = widget.materials;
    
    // Filtrar por categoría
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered.where((m) => m.category == _selectedCategory).toList();
    }
    
    // Filtrar por búsqueda
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((m) =>
        m.name.toLowerCase().contains(query) ||
        m.code.toLowerCase().contains(query)
      ).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar Material del Inventario'),
      content: SizedBox(
        width: 550,
        height: 450,
        child: Column(
          children: [
            // Barra de búsqueda y filtro de categoría
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar material',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (value) => setState(() => _selectedCategory = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredMaterials.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('No hay materiales', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : ListView.builder(
                itemCount: _filteredMaterials.length,
                itemBuilder: (context, index) {
                  final material = _filteredMaterials[index];
                  final isSelected = _selectedMaterial?.id == material.id;
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.orange.withValues(alpha: 0.1),
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      child: const Icon(Icons.inventory_2, color: Colors.orange, size: 20),
                    ),
                    title: Text(material.name),
                    subtitle: Text('${material.code} • Stock: ${material.stock} ${material.unit}'),
                    trailing: Text(
                      Formatters.currency(material.pricePerKg > 0 ? material.pricePerKg : material.unitPrice),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () => setState(() => _selectedMaterial = material),
                  );
                },
              ),
            ),
            if (_selectedMaterial != null) ...[
              const Divider(),
              Row(
                children: [
                  Text('Cantidad (${_selectedMaterial!.unit}):', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _quantity > 1 
                        ? () => setState(() => _quantity--) 
                        : null,
                  ),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: _quantity.toStringAsFixed(0)),
                      onChanged: (v) {
                        final qty = double.tryParse(v);
                        if (qty != null && qty > 0) {
                          setState(() => _quantity = qty);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _quantity++),
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${Formatters.currency((_selectedMaterial!.pricePerKg > 0 ? _selectedMaterial!.pricePerKg : _selectedMaterial!.unitPrice) * _quantity)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _selectedMaterial == null
              ? null
              : () {
                  final price = _selectedMaterial!.pricePerKg > 0 
                      ? _selectedMaterial!.pricePerKg 
                      : _selectedMaterial!.unitPrice;
                  widget.onAdd(_InvoiceItemData(
                    materialId: _selectedMaterial!.id,
                    productCode: _selectedMaterial!.code,
                    productName: _selectedMaterial!.name,
                    unit: _selectedMaterial!.unit,
                    unitPrice: price,
                    quantity: _quantity,
                  ));
                  Navigator.pop(context);
                },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
