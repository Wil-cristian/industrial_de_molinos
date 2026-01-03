import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/providers.dart';
import '../../data/datasources/invoices_datasource.dart';
import '../../data/datasources/inventory_datasource.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/material.dart' as domain;
import '../../domain/entities/invoice.dart';
import '../../domain/entities/account.dart';

class NewInvoicePage extends ConsumerStatefulWidget {
  const NewInvoicePage({super.key});

  @override
  ConsumerState<NewInvoicePage> createState() => _NewInvoicePageState();
}

class _NewInvoicePageState extends ConsumerState<NewInvoicePage> {
  final _formKey = GlobalKey<FormState>();

  // Serie para Recibo de Caja Menor
  final String _series = 'F001';

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

  // Cuenta para pago en efectivo/contado
  Account? _selectedAccount;
  List<Account> _accounts = [];

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
    
    // Cargar cuentas
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AccountsDataSource.getAllAccounts(activeOnly: true);
    if (mounted) {
      setState(() {
        _accounts = accounts;
        // Seleccionar "Caja" por defecto si existe
        _selectedAccount = accounts.firstWhere(
          (a) => a.name.toLowerCase().contains('caja'),
          orElse: () => accounts.isNotEmpty ? accounts.first : Account(id: '', name: '', type: AccountType.cash, balance: 0),
        );
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Calcular totales
  double get _subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get _total => _subtotal;

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
                : _showPreviewDialog,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : const Icon(Icons.send),
            label: const Text('Emitir Comprobante'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryColor,
              disabledBackgroundColor: Colors.white54,
              disabledForegroundColor: AppTheme.primaryColor.withValues(
                alpha: 0.5,
              ),
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
                            onPressed: () => _showAddMaterialDialog(
                              ref.read(inventoryProvider).materials,
                            ),
                            icon: const Icon(
                              Icons.inventory_2_outlined,
                              size: 18,
                            ),
                            label: const Text('Agregar Material'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () =>
                                _showAddProductDialog(productsState.products),
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

            // Panel derecho - Resumen Compacto
            Container(
              width: 320,
              margin: const EdgeInsets.all(12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ===== HEADER COMPACTO =====
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1e293b),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.receipt_long, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Resumen', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            _items.isEmpty ? 'Sin items' : '${_items.length} items',
                                            style: TextStyle(color: Colors.green[300], fontSize: 10, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                Formatters.currency(_total),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // ===== CONTENIDO COMPACTO =====
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cliente
                            if (_selectedCustomer != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('CLIENTE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1)),
                                    const SizedBox(height: 6),
                                    Text(_selectedCustomer!.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111418))),
                                    Text(_selectedCustomer!.documentNumber, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.person_add, color: Colors.orange[700], size: 16),
                                    const SizedBox(width: 8),
                                    const Expanded(child: Text('Selecciona un cliente', style: TextStyle(color: Colors.orange, fontSize: 12))),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            
                            // Tipo de pago
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _paymentType,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  prefixIcon: Icon(Icons.credit_card, color: Color(0xFF1e293b), size: 18),
                                  isDense: true,
                                ),
                                style: const TextStyle(color: Color(0xFF111418), fontSize: 13),
                                items: const [
                                  DropdownMenuItem(value: 'credit', child: Text('Crédito (30 días)')),
                                  DropdownMenuItem(value: 'cash', child: Text('Contado')),
                                  DropdownMenuItem(value: 'installments', child: Text('Cuotas')),
                                ],
                                onChanged: (value) => setState(() => _paymentType = value!),
                              ),
                            ),
                            
                            // Selector de cuenta (solo para Contado)
                            if (_paymentType == 'cash') ...[
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                                  color: Colors.green.withOpacity(0.05),
                                ),
                                child: DropdownButtonFormField<Account>(
                                  value: _selectedAccount,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    prefixIcon: Icon(Icons.account_balance_wallet, color: Colors.green[700], size: 18),
                                    isDense: true,
                                    labelText: 'Destino del pago',
                                    labelStyle: TextStyle(color: Colors.green[700], fontSize: 11),
                                  ),
                                  style: const TextStyle(color: Color(0xFF111418), fontSize: 13),
                                  items: _accounts.map((account) => DropdownMenuItem(
                                    value: account,
                                    child: Row(
                                      children: [
                                        Icon(
                                          account.type == AccountType.cash ? Icons.point_of_sale : Icons.account_balance,
                                          size: 16,
                                          color: Colors.green[700],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(account.name),
                                      ],
                                    ),
                                  )).toList(),
                                  onChanged: (value) => setState(() => _selectedAccount = value),
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            
                            // Items resumidos
                            if (_items.isNotEmpty) ...[
                              Text('PRODUCTOS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1)),
                              const SizedBox(height: 8),
                              ..._items.take(3).map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(item.productName, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    Text(Formatters.currency(item.unitPrice * item.quantity), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              )),
                              if (_items.length > 3)
                                Text('+ ${_items.length - 3} más...', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                              const SizedBox(height: 12),
                            ],
                            
                            // Total
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1e293b).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('TOTAL', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text(Formatters.currency(_total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF137fec))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // ===== BOTÓN =====
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving || _items.isEmpty || _selectedCustomer == null ? null : _showPreviewDialog,
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Emitir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF137fec),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
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
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
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
            return customers.where(
              (c) =>
                  c.name.toLowerCase().contains(query) ||
                  c.documentNumber.contains(query),
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
                  constraints: const BoxConstraints(
                    maxHeight: 300,
                    maxWidth: 500,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final customer = options.elementAt(index);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primaryColor.withValues(
                            alpha: 0.1,
                          ),
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
              border: Border.all(
                color: AppTheme.successColor.withValues(alpha: 0.3),
              ),
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
                        '${_selectedCustomer!.documentType.displayName}: ${_selectedCustomer!.documentNumber}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (_selectedCustomer!.address != null)
                        Text(
                          _selectedCustomer!.address!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
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
              Icon(
                Icons.shopping_cart_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
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
              child: Text(
                'Producto',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Cant.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'P. Unit.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Subtotal',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
                    Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      item.productCode,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
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
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ignore: unused_element - Reserved for future use
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

  // ignore: unused_element - Reserved for future use
  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, style: BorderStyle.solid)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Color(0xFF111418), fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ignore: unused_element - Reserved for date formatting
  String _getMonthName(int month) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 
                    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[month - 1];
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

  void _showPreviewDialog() async {
    if (_selectedCustomer == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un cliente y agrega al menos un producto'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Obtener componentes de las recetas
    final productsWithComponents = <Map<String, dynamic>>[];
    for (final item in _items) {
      final productData = <String, dynamic>{
        'name': item.productName,
        'quantity': item.quantity,
        'unitPrice': item.unitPrice,
        'costPrice': item.costPrice, // Precio de costo para cálculo de margen
        'total': item.subtotal,
        'isRecipe': item.isRecipe,
        'productId': item.productId,
        'components': <Map<String, dynamic>>[],
      };
      
      // Si es receta y tiene productId, obtener componentes
      if (item.isRecipe && item.productId != null) {
        try {
          final components = await InventoryDataSource.checkRecipeStock(
            item.productId!,
            quantity: item.quantity.toInt(),
          );
          productData['components'] = components;
        } catch (e) {
          // Si falla, dejar vacío
          debugPrint('Error obteniendo componentes: $e');
        }
      }
      
      productsWithComponents.add(productData);
    }
    
    // Construir datos para preview
    final invoiceData = {
      'number': 'RCM-${DateTime.now().year}-PREVIEW',
      'customer': _selectedCustomer!.name,
      'customerRuc': _selectedCustomer!.documentNumber,
      'date': _issueDate,
      'dueDate': _dueDate,
      'status': 'Pendiente',
      'subtotal': _subtotal,
      'tax': 0.0,
      'total': _total,
      'paid': 0.0,
      'items': _items.length,
      'products': productsWithComponents,
    };
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => _NewInvoicePreviewDialog(
        invoice: invoiceData,
        onConfirm: () {
          Navigator.pop(context);
          _saveInvoice(asDraft: false);
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
        type: 'invoice', // Solo Recibo de Caja Menor
        series: _series,
        customer: _selectedCustomer!,
        issueDate: _issueDate,
        dueDate: _dueDate,
        taxRate: 0, // Sin IVA
        items: _items
            .map(
              (i) => InvoiceItem(
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
                taxRate: 0,
                subtotal: i.subtotal,
                taxAmount: 0,
                total: i.subtotal,
              ),
            )
            .toList(),
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      // Actualizar estado si no es borrador
      if (!asDraft) {
        await InvoicesDataSource.updateStatus(invoice.id, 'issued');
        
        // Si es pago de contado, registrar el pago automáticamente
        if (_paymentType == 'cash' && _selectedAccount != null) {
          await InvoicesDataSource.registerPayment(
            invoiceId: invoice.id,
            amount: invoice.total,
            method: 'cash',
            accountId: _selectedAccount!.id,
            reference: 'Pago de contado - ${invoice.fullNumber}',
          );
        }
      }

      // Refrescar listas (recibos y productos para actualizar stock)
      ref.read(invoicesProvider.notifier).refresh();
      ref.read(productsProvider.notifier).loadProducts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              asDraft
                  ? 'Borrador guardado: ${invoice.fullNumber}'
                  : 'Comprobante emitido: ${invoice.fullNumber}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Navegar a la página de ventas
        context.go('/invoices');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
  final double costPrice; // Precio de costo
  final bool isRecipe;
  double quantity;

  _InvoiceItemData({
    this.productId,
    this.materialId,
    required this.productCode,
    required this.productName,
    required this.unit,
    required this.unitPrice,
    this.costPrice = 0,
    this.isRecipe = false,
    this.quantity = 1,
  });

  double get subtotal => unitPrice * quantity;
  double get totalCost => costPrice * quantity;
}

// Diálogo para agregar producto
class _AddProductDialog extends StatefulWidget {
  final List<Product> products;
  final Function(_InvoiceItemData) onAdd;

  const _AddProductDialog({required this.products, required this.onAdd});

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  Product? _selectedProduct;
  double _quantity = 1;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(double newQty) {
    setState(() {
      _quantity = newQty;
      _quantityController.text = newQty.toStringAsFixed(0);
    });
  }

  List<Product> get _filteredProducts {
    if (_searchController.text.isEmpty) return widget.products;
    final query = _searchController.text.toLowerCase();
    return widget.products
        .where(
          (p) =>
              p.name.toLowerCase().contains(query) ||
              p.code.toLowerCase().contains(query),
        )
        .toList();
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
                    selectedTileColor: AppTheme.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
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
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    'Cantidad:',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _quantity > 1
                        ? () => _updateQuantity(_quantity - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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
                    onPressed: () => _updateQuantity(_quantity + 1),
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
                  widget.onAdd(
                    _InvoiceItemData(
                      productId: _selectedProduct!.id,
                      productCode: _selectedProduct!.code,
                      productName: _selectedProduct!.name,
                      unit: _selectedProduct!.unit,
                      unitPrice: _selectedProduct!.unitPrice,
                      costPrice: _selectedProduct!.costPrice > 0 
                          ? _selectedProduct!.costPrice 
                          : _selectedProduct!.totalCost, // Usar costPrice o totalCost
                      isRecipe: _selectedProduct!.isRecipe,
                      quantity: _quantity,
                    ),
                  );
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

  const _AddMaterialDialog({required this.materials, required this.onAdd});

  @override
  State<_AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends State<_AddMaterialDialog> {
  final _searchController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  String? _selectedCategory;
  domain.Material? _selectedMaterial;
  double _quantity = 1;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity(double newQty) {
    if (newQty > 0) {
      setState(() => _quantity = newQty);
      _quantityController.text = newQty == newQty.truncate() 
          ? newQty.toStringAsFixed(0) 
          : newQty.toStringAsFixed(2);
    }
  }

  List<String> get _categories {
    final cats = widget.materials.map((m) => m.category).toSet().toList();
    cats.sort();
    return cats;
  }

  List<domain.Material> get _filteredMaterials {
    var filtered = widget.materials;

    // Filtrar por categoría
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((m) => m.category == _selectedCategory)
          .toList();
    }

    // Filtrar por búsqueda
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where(
            (m) =>
                m.name.toLowerCase().contains(query) ||
                m.code.toLowerCase().contains(query),
          )
          .toList();
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
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ..._categories.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
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
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No hay materiales',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
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
                          selectedTileColor: Colors.orange.withValues(
                            alpha: 0.1,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(
                              Icons.inventory_2,
                              color: Colors.orange,
                              size: 20,
                            ),
                          ),
                          title: Text(material.name),
                          subtitle: Text(
                            '${material.code} • Stock: ${material.stock} ${material.unit}',
                          ),
                          trailing: Text(
                            Formatters.currency(
                              material.pricePerKg > 0
                                  ? material.pricePerKg
                                  : material.unitPrice,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () =>
                              setState(() => _selectedMaterial = material),
                        );
                      },
                    ),
            ),
            if (_selectedMaterial != null) ...[
              const Divider(),
              Row(
                children: [
                  Text(
                    'Cantidad (${_selectedMaterial!.unit}):',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _quantity > 1
                        ? () => _updateQuantity(_quantity - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
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
                    onPressed: () => _updateQuantity(_quantity + 1),
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
                  // Precio de venta
                  final salePrice = _selectedMaterial!.effectivePrice;
                  // Precio de costo
                  final costPrice = _selectedMaterial!.effectiveCostPrice;
                  widget.onAdd(
                    _InvoiceItemData(
                      materialId: _selectedMaterial!.id,
                      productCode: _selectedMaterial!.code,
                      productName: _selectedMaterial!.name,
                      unit: _selectedMaterial!.unit,
                      unitPrice: salePrice,
                      costPrice: costPrice,
                      quantity: _quantity,
                    ),
                  );
                  Navigator.pop(context);
                },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

// ============================================
// DIÁLOGO DE PREVISUALIZACIÓN NUEVA VENTA
// ============================================
class _NewInvoicePreviewDialog extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onConfirm;

  const _NewInvoicePreviewDialog({required this.invoice, required this.onConfirm});

  @override
  State<_NewInvoicePreviewDialog> createState() => _NewInvoicePreviewDialogState();
}

class _NewInvoicePreviewDialogState extends State<_NewInvoicePreviewDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final screenHeight = MediaQuery.of(context).size.height;
    const headerColor = Color(0xFF1e293b);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 1100,
        height: screenHeight * 0.9,
        child: Column(
          children: [
            // Header compacto con fondo oscuro
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: headerColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vista Previa del Recibo', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(inv['number'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Formatters.currency(inv['total']), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('${(inv['products'] as List).length} items', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            // Tabs
            Container(
              color: headerColor,
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  _buildTab('Recibo Cliente', Icons.person, 0),
                  const SizedBox(width: 8),
                  _buildTab('Recibo Empresa', Icons.business, 1),
                ],
              ),
            ),
            // Contenido de tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildClientView(inv),
                  _buildEnterpriseView(inv),
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Cliente: ${inv['customer']}  •  Fecha: ${_formatDate(inv['date'])}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: widget.onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Confirmar y Emitir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildTab(String label, IconData icon, int index) {
    final isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.animateTo(index)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white60, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // VISTA CLIENTE - Diseño compacto moderno
  // ==========================================
  Widget _buildClientView(Map<String, dynamic> inv) {
    final products = inv['products'] as List<dynamic>? ?? [];
    const headerColor = Color(0xFF1e293b);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Barra de acento superior
              Container(
                width: double.infinity,
                height: 4,
                decoration: const BoxDecoration(
                  color: headerColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
              // Contenido con scroll
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Título + Logo
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.verified, color: headerColor, size: 28),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'RECIBO DE CAJA',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF111418),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  inv['number'],
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          // Logo empresa
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'lib/photo/logo_empresa.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [headerColor, headerColor.withOpacity(0.8)]),
                                      ),
                                      child: const Icon(Icons.precision_manufacturing, color: Colors.white, size: 24),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text('Industrial de Molinos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              const Text('NIT: 901946675-1', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Sección Cliente
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CLIENTE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1)),
                                  const SizedBox(height: 4),
                                  Text(inv['customer'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111418))),
                                  Text('NIT/CC: ${inv['customerRuc'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildDateRow('Fecha:', _formatDate(inv['date'])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tabla de productos
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            // Header de tabla
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(flex: 3, child: Text('Descripción', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey))),
                                  SizedBox(width: 50, child: Text('Cant.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]), textAlign: TextAlign.center)),
                                  SizedBox(width: 90, child: Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]), textAlign: TextAlign.right)),
                                ],
                              ),
                            ),
                            // Filas de productos
                            ...products.map((prod) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[100]!))),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  ),
                                  SizedBox(
                                    width: 50,
                                    child: Text('${prod['quantity']}', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700], fontSize: 12), textAlign: TextAlign.center),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(Formatters.currency(prod['total']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Totales
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 220,
                            child: Column(
                              children: [
                                _buildTotalRow('Subtotal', inv['subtotal']),
                                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(thickness: 1)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    Text(Formatters.currency(inv['total']), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: headerColor)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Nota de agradecimiento
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.email, size: 14, color: Colors.blue[700]),
                            const SizedBox(width: 8),
                            Text('industriasdemolinosasfact@gmail.com', style: TextStyle(fontSize: 10, color: Colors.blue[700])),
                            const Spacer(),
                            Text('¡GRACIAS POR SU COMPRA!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700], fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Widget _buildTotalRow(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(Formatters.currency(value), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  // ==========================================
  // VISTA EMPRESA - ERP Style Compacto
  // ==========================================
  Widget _buildEnterpriseView(Map<String, dynamic> inv) {
    final products = inv['products'] as List<dynamic>? ?? [];
    const headerColor = Color(0xFF1e293b);
    
    // Calcular totales y márgenes
    double totalCost = 0;
    double totalSale = inv['total'] ?? 0;
    for (var prod in products) {
      final qty = (prod['quantity'] ?? 1).toDouble();
      final costPrice = (prod['costPrice'] ?? prod['unitPrice'] ?? 0).toDouble();
      totalCost += costPrice * qty;
    }
    final profit = totalSale - totalCost;
    final marginPercent = totalSale > 0 ? (profit / totalSale * 100) : 0.0;
    final marginColor = marginPercent >= 30 ? Colors.green : marginPercent >= 15 ? Colors.orange : Colors.red;

    return Container(
      color: const Color(0xFFF1F4F8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header documento interno compacto
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'lib/photo/logo_empresa.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [headerColor, headerColor.withOpacity(0.8)]),
                          ),
                          child: const Icon(Icons.business, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DOCUMENTO INTERNO', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF111418))),
                        Text('${inv['number']} • ${inv['customer']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 12, color: Colors.orange[800]),
                        const SizedBox(width: 4),
                        Text('USO INTERNO', style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Tabla de productos con componentes
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.list_alt, color: headerColor, size: 18),
                        const SizedBox(width: 8),
                        const Text('Detalle de Productos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${products.length} item(s)', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                      ],
                    ),
                  ),
                  // Items con componentes
                  ...products.map((prod) {
                    final components = prod['components'] as List<dynamic>? ?? [];
                    final isRecipe = prod['isRecipe'] == true;
                    final costPrice = (prod['costPrice'] ?? prod['unitPrice'] ?? 0).toDouble();
                    final salePrice = (prod['unitPrice'] ?? 0).toDouble();
                    final qty = (prod['quantity'] ?? 1).toDouble();
                    final itemMargin = salePrice > 0 ? ((salePrice - costPrice) / salePrice * 100) : 0.0;
                    final itemProfit = (salePrice - costPrice) * qty;
                    
                    return Column(
                      children: [
                        // Producto principal
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isRecipe ? Colors.blue[50] : Colors.white,
                            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isRecipe ? Colors.blue[100] : headerColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: isRecipe
                                      ? Icon(Icons.precision_manufacturing, color: Colors.blue[700], size: 18)
                                      : Text('${prod['quantity']}×', style: TextStyle(fontWeight: FontWeight.bold, color: headerColor, fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(child: Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                        const SizedBox(width: 6),
                                        // Indicador de margen por item
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (itemMargin >= 30 ? Colors.green : itemMargin >= 15 ? Colors.orange : Colors.red).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${itemMargin.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: itemMargin >= 30 ? Colors.green[700] : itemMargin >= 15 ? Colors.orange[700] : Colors.red[700],
                                            ),
                                          ),
                                        ),
                                        if (isRecipe) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text('RECETA', style: TextStyle(color: Colors.blue[700], fontSize: 8, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '${prod['quantity']} × ${Formatters.currency(prod['unitPrice'])} • Costo: ${Formatters.currency(costPrice)}',
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(Formatters.currency(prod['total']), style: TextStyle(fontWeight: FontWeight.bold, color: headerColor, fontSize: 14)),
                                  Text('Gan: ${Formatters.currency(itemProfit)}', style: TextStyle(fontSize: 9, color: itemProfit >= 0 ? Colors.green[700] : Colors.red[700])),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Componentes de la receta (compacto)
                        if (isRecipe && components.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: const Color(0xFFFAFAFA),
                            child: Row(
                              children: [
                                const SizedBox(width: 46),
                                Icon(Icons.subdirectory_arrow_right, color: Colors.grey[400], size: 14),
                                const SizedBox(width: 4),
                                Text('COMPONENTES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5)),
                              ],
                            ),
                          ),
                          ...components.map((comp) {
                            final compName = comp['component_name'] ?? comp['name'] ?? 'Material';
                            final requiredQty = comp['required_qty'] ?? comp['quantity'] ?? 0;
                            final unit = comp['unit'] ?? 'UND';
                            final currentStock = comp['current_stock'] ?? 0;
                            final hasStock = comp['has_stock'] ?? true;
                            
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 46),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: hasStock ? Colors.green[400] : Colors.red[400],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$compName ($requiredQty $unit)',
                                      style: const TextStyle(fontSize: 10),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: hasStock ? Colors.green[50] : Colors.red[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      hasStock ? 'OK' : 'FALTA',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: hasStock ? Colors.green[700] : Colors.red[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Resumen financiero CON MARGEN DE GANANCIA
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.analytics_outlined, size: 18, color: headerColor),
                      const SizedBox(width: 8),
                      const Text('Resumen Financiero', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Grid de métricas
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard('Costo Total', Formatters.currency(totalCost), Colors.grey[700]!, Icons.shopping_cart),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard('Venta Total', Formatters.currency(totalSale), headerColor, Icons.point_of_sale),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMetricCard('Ganancia', Formatters.currency(profit), profit >= 0 ? Colors.green[700]! : Colors.red[700]!, Icons.trending_up),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: marginColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: marginColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                marginPercent >= 30 ? Icons.trending_up : marginPercent >= 15 ? Icons.trending_flat : Icons.trending_down,
                                color: marginColor,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text('MARGEN', style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                              Text(
                                '${marginPercent.toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: marginColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 8, color: Colors.grey[600])),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
