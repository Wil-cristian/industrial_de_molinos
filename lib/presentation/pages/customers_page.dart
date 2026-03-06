import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/datasources/customers_datasource.dart';
import '../../data/datasources/invoices_datasource.dart';
import '../../domain/entities/account.dart';
import '../../data/providers/customers_provider.dart';
import '../../data/providers/invoices_provider.dart';
import '../../data/providers/quotations_provider.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/invoice.dart';
import 'suppliers_page.dart';
import 'purchase_orders_page.dart';

class CustomersPage extends ConsumerStatefulWidget {
  final bool openNewDialog;

  const CustomersPage({super.key, this.openNewDialog = false});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'Todos';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(customersProvider.notifier).loadCustomers();
      // Abrir diálogo si viene de la ruta /customers/new
      if (widget.openNewDialog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showAddCustomerDialog(context);
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Customer> _getFilteredCustomers(List<Customer> customers) {
    switch (_selectedFilter) {
      case 'Activos':
        return customers.where((c) => c.isActive).toList();
      case 'Con Deuda':
        return customers.where((c) => c.hasDebt).toList();
      case 'Empresas':
        return customers.where((c) => c.type == CustomerType.business).toList();
      case 'Personas':
        return customers
            .where((c) => c.type == CustomerType.individual)
            .toList();
      default:
        return customers;
    }
  }

  // Helper para normalizar el tipo de documento (convierte legacy a colombiano)
  DocumentType _ensureValidDocumentType(DocumentType docType) {
    // Usar el método normalized para convertir valores legacy
    return docType.normalized;
  }

  // Lista de tipos de documento válidos para Colombia (sin legacy)
  static const _colombianDocTypes = [
    DocumentType.cc,
    DocumentType.nit,
    DocumentType.ce,
    DocumentType.pasaporte,
    DocumentType.ti,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(customersProvider);
    final filteredCustomers = _getFilteredCustomers(state.filteredCustomers);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header con tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 20, right: 20, top: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  onPressed: () => context.go('/'),
                  tooltip: 'Volver al menú',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                // Tabs
                SizedBox(
                  width: 450,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.primaryColor,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.people, size: 18),
                        text: 'Clientes',
                        height: 44,
                      ),
                      Tab(
                        icon: Icon(Icons.local_shipping, size: 18),
                        text: 'Proveedores',
                        height: 44,
                      ),
                      Tab(
                        icon: Icon(Icons.shopping_cart, size: 18),
                        text: 'Órdenes de Compra',
                        height: 44,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          // Contenido de tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCustomersContent(theme, state, filteredCustomers),
                const SuppliersPage(),
                const PurchaseOrdersPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersContent(
    ThemeData theme,
    CustomersState state,
    List<Customer> filteredCustomers,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${state.customers.length} clientes registrados',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  // Stats rápidas
                  _buildQuickStat(
                    'Total Deuda',
                    Formatters.currency(
                      state.customers.fold(
                        0.0,
                        (sum, c) => sum + c.currentBalance,
                      ),
                    ),
                    Colors.orange,
                    Icons.account_balance_wallet,
                  ),
                  const SizedBox(width: 12),
                  _buildQuickStat(
                    'Clientes Activos',
                    state.customers.where((c) => c.isActive).length.toString(),
                    Colors.green,
                    Icons.people,
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () => _showAddCustomerDialog(context),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Nuevo Cliente'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Barra de búsqueda y filtros
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) =>
                          ref.read(customersProvider.notifier).search(value),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, documento o email...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Filtro
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        items:
                            [
                                  'Todos',
                                  'Activos',
                                  'Con Deuda',
                                  'Empresas',
                                  'Personas',
                                ]
                                .map(
                                  (filter) => DropdownMenuItem(
                                    value: filter,
                                    child: Text(filter),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedFilter = value!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Botón refrescar
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(customersProvider.notifier).loadCustomers(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón recalcular balances
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Recalculando balances...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        await CustomersDataSource.recalculateAllBalances();
                        ref.read(customersProvider.notifier).loadCustomers();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Balances recalculados'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.calculate, color: Colors.orange),
                    label: const Text('Recalcular Deudas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Lista de clientes
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.error != null
                    ? _buildErrorState(state.error!)
                    : filteredCustomers.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(0),
                        itemCount: filteredCustomers.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1, color: Colors.grey[200]),
                        itemBuilder: (context, index) {
                          final customer = filteredCustomers[index];
                          return _buildCustomerTile(customer);
                        },
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
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
        ],
      ),
    );
  }

  Widget _buildCustomerTile(Customer customer) {
    final debt = customer.currentBalance;
    final creditLimit = customer.creditLimit;
    final debtPercentage = creditLimit > 0 ? (debt / creditLimit) : 0.0;

    Color statusColor = customer.isActive ? Colors.green : Colors.grey;
    Color typeColor = customer.type == CustomerType.business
        ? Colors.blue
        : Colors.purple;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: Text(
          customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              customer.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              customer.type == CustomerType.business ? 'Empresa' : 'Persona',
              style: TextStyle(
                fontSize: 11,
                color: typeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: creditLimit > 0
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  creditLimit > 0 ? Icons.credit_card : Icons.payments,
                  size: 12,
                  color: creditLimit > 0 ? Colors.blue : Colors.green[700],
                ),
                const SizedBox(width: 4),
                Text(
                  creditLimit > 0 ? 'Crédito' : 'Contado',
                  style: TextStyle(
                    fontSize: 11,
                    color: creditLimit > 0 ? Colors.blue : Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.badge, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                '${customer.documentType.displayName}: ${customer.documentNumber}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(width: 16),
              if (customer.phone != null) ...[
                Icon(Icons.phone, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  customer.phone!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ],
          ),
          if (debt > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: debtPercentage.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                        debtPercentage > 0.8 ? Colors.red : Colors.orange,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Deuda: ${Formatters.currency(debt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: debtPercentage > 0.8 ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'edit':
              _showEditCustomerDialog(customer);
              break;
            case 'delete':
              _confirmDelete(customer);
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text('Editar'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Eliminar', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
      onTap: () => _showCustomerDetails(customer),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No hay clientes registrados',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega tu primer cliente para comenzar',
            style: TextStyle(color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showAddCustomerDialog(context),
            icon: const Icon(Icons.person_add),
            label: const Text('Agregar Cliente'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error al cargar clientes',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () =>
                ref.read(customersProvider.notifier).loadCustomers(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, {Customer? customer}) {
    final isEditMode = customer != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(
      text: isEditMode ? customer.name : '',
    );
    final documentController = TextEditingController(
      text: isEditMode ? customer.documentNumber : '',
    );
    final phoneController = TextEditingController(
      text: isEditMode ? customer.phone ?? '' : '',
    );
    final emailController = TextEditingController(
      text: isEditMode ? customer.email ?? '' : '',
    );
    final addressController = TextEditingController(
      text: isEditMode ? customer.address ?? '' : '',
    );
    final creditLimitController = TextEditingController(
      text: isEditMode ? customer.creditLimit.toString() : '0',
    );
    final currentBalanceController = TextEditingController(
      text: isEditMode ? customer.currentBalance.toString() : '0',
    );
    CustomerType selectedType = isEditMode
        ? customer.type
        : CustomerType.business;
    // Asegurar que el tipo de documento sea válido para el dropdown
    DocumentType selectedDocType = isEditMode
        ? _ensureValidDocumentType(customer.documentType)
        : DocumentType.nit;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditMode ? 'Editar Cliente' : 'Nuevo Cliente'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<CustomerType>(
                            initialValue: selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Cliente',
                              border: OutlineInputBorder(),
                            ),
                            items: CustomerType.values
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(
                                      type == CustomerType.business
                                          ? 'Empresa'
                                          : 'Persona',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedType = value!;
                                selectedDocType = value == CustomerType.business
                                    ? DocumentType.nit
                                    : DocumentType.cc;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<DocumentType>(
                            initialValue: selectedDocType,
                            decoration: const InputDecoration(
                              labelText: 'Tipo Documento',
                              border: OutlineInputBorder(),
                            ),
                            items: _colombianDocTypes
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type.displayName),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setDialogState(() => selectedDocType = value!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: documentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Número de Documento',
                        border: OutlineInputBorder(),
                        helperText: 'Ingresa un número de documento válido',
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Campo requerido';
                        }
                        if (value == '0') {
                          return 'Ingresa un número de documento válido (no puede ser 0)';
                        }
                        if (int.tryParse(value!) == null) {
                          return 'Debe ser un número válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre / Razón Social',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Límite de Crédito y Deuda',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: creditLimitController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Límite de Crédito',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Campo requerido';
                              }
                              if (double.tryParse(value!) == null) {
                                return 'Valor inválido';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: currentBalanceController,
                            keyboardType: TextInputType.number,
                            readOnly:
                                true, // No editable - se calcula automáticamente
                            decoration: InputDecoration(
                              labelText: 'Deuda Actual',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.money_off),
                              helperText: 'Calculado desde facturas',
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final creditLimit =
                      double.tryParse(creditLimitController.text) ?? 0;
                  final currentBalance =
                      double.tryParse(currentBalanceController.text) ?? 0;

                  if (isEditMode) {
                    // Modo edición
                    final updatedCustomer = Customer(
                      id: customer.id,
                      type: selectedType,
                      documentType: selectedDocType,
                      documentNumber: documentController.text,
                      name: nameController.text,
                      phone: phoneController.text.isNotEmpty
                          ? phoneController.text
                          : null,
                      email: emailController.text.isNotEmpty
                          ? emailController.text
                          : null,
                      address: addressController.text.isNotEmpty
                          ? addressController.text
                          : null,
                      creditLimit: creditLimit,
                      currentBalance: currentBalance,
                      createdAt: customer.createdAt,
                      updatedAt: DateTime.now(),
                    );

                    final result = await ref
                        .read(customersProvider.notifier)
                        .updateCustomer(updatedCustomer);
                    if (result && mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Cliente actualizado exitosamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    // Modo creación
                    final newCustomer = Customer(
                      id: const Uuid().v4(),
                      type: selectedType,
                      documentType: selectedDocType,
                      documentNumber: documentController.text,
                      name: nameController.text,
                      phone: phoneController.text.isNotEmpty
                          ? phoneController.text
                          : null,
                      email: emailController.text.isNotEmpty
                          ? emailController.text
                          : null,
                      address: addressController.text.isNotEmpty
                          ? addressController.text
                          : null,
                      creditLimit: creditLimit,
                      currentBalance: currentBalance,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    final result = await ref
                        .read(customersProvider.notifier)
                        .createCustomer(newCustomer);
                    if (result != null && mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Cliente creado exitosamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else if (mounted) {
                      // Mostrar error si falló
                      final error = ref.read(customersProvider).error;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Error al crear cliente: ${error ?? "Error desconocido"}',
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(isEditMode ? 'Actualizar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCustomerDialog(Customer customer) {
    _showAddCustomerDialog(context, customer: customer);
  }

  void _showCustomerDetails(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => _CustomerHistoryDialog(customer: customer),
    );
  }

  // ignore: unused_element - Reserved for future use
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _confirmDelete(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Está seguro de eliminar al cliente "${customer.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(customersProvider.notifier)
                  .deleteCustomer(customer.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cliente "${customer.name}" eliminado'),
                    backgroundColor: Colors.red,
                  ),
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
}

// ===================== DIALOGO DE HISTORIAL DEL CLIENTE =====================

class _CustomerHistoryDialog extends ConsumerStatefulWidget {
  final Customer customer;

  const _CustomerHistoryDialog({required this.customer});

  @override
  ConsumerState<_CustomerHistoryDialog> createState() =>
      _CustomerHistoryDialogState();
}

class _CustomerHistoryDialogState extends ConsumerState<_CustomerHistoryDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _customerPayments = [];
  bool _loadingPayments = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Cargar datos
    Future.microtask(() {
      ref.read(invoicesProvider.notifier).refresh();
      ref.read(quotationsProvider.notifier).loadQuotations();
    });
    _loadCustomerPayments();
  }

  Future<void> _loadCustomerPayments() async {
    try {
      final payments = await InvoicesDataSource.getPaymentsByCustomerId(
        widget.customer.id,
      );
      if (mounted) {
        setState(() {
          _customerPayments = payments;
          _loadingPayments = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPayments = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final invoicesState = ref.watch(invoicesProvider);
    final quotationsState = ref.watch(quotationsProvider);

    // Filtrar facturas y cotizaciones de este cliente
    final customerInvoices =
        invoicesState.invoices
            .where((inv) => inv.customerId == customer.id)
            .toList()
          ..sort((a, b) => b.issueDate.compareTo(a.issueDate));

    final customerQuotations =
        quotationsState.quotations
            .where((q) => q.customerId == customer.id)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        height: 550,
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            // Header con info del cliente
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      customer.name.isNotEmpty
                          ? customer.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${customer.documentType.displayName}: ${customer.documentNumber}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Stats rápidas
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Deuda Total',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          Formatters.currency(customer.currentBalance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              color: Colors.grey[100],
              child: TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: AppTheme.primaryColor,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline, size: 18),
                        const SizedBox(width: 6),
                        const Text('Datos'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long, size: 18),
                        const SizedBox(width: 6),
                        Text('Recibos (${customerInvoices.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payments_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text('Pagos (${_customerPayments.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.request_quote, size: 18),
                        const SizedBox(width: 6),
                        Text('Cotizaciones (${customerQuotations.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Contenido de tabs
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Datos del cliente
                  _buildDatosTab(customer),
                  // Tab 2: Facturas
                  _buildFacturasTab(customerInvoices),
                  // Tab 3: Pagos
                  _buildPagosTab(),
                  // Tab 4: Cotizaciones
                  _buildCotizacionesTab(customerQuotations),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatosTab(Customer customer) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection('Información de Contacto', [
            if (customer.phone != null)
              _buildInfoRow(Icons.phone, 'Teléfono', customer.phone!),
            if (customer.email != null)
              _buildInfoRow(Icons.email, 'Email', customer.email!),
            if (customer.address != null)
              _buildInfoRow(Icons.location_on, 'Dirección', customer.address!),
          ]),
          const SizedBox(height: 20),
          _buildSection('Información Financiera', [
            _buildInfoRow(
              Icons.credit_card,
              'Límite de Crédito',
              Formatters.currency(customer.creditLimit),
            ),
            _buildInfoRow(
              Icons.account_balance,
              'Balance Actual',
              Formatters.currency(customer.currentBalance),
              valueColor: customer.currentBalance > 0
                  ? Colors.red
                  : Colors.green,
            ),
            _buildInfoRow(
              Icons.savings,
              'Crédito Disponible',
              Formatters.currency(customer.availableCredit),
              valueColor: Colors.green,
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection('Forma de Pago', [
            _buildInfoRow(
              Icons.payment,
              'Método',
              customer.creditLimit > 0 ? 'Crédito' : 'Contado',
              valueColor: customer.creditLimit > 0 ? Colors.blue : Colors.green,
            ),
            if (customer.creditLimit > 0) ...[
              _buildInfoRow(Icons.calendar_today, 'Plazo', 'Crédito a 30 días'),
              _buildInfoRow(
                Icons.account_balance_wallet,
                'Cupo Disponible',
                Formatters.currency(customer.availableCredit),
                valueColor: customer.availableCredit > 0
                    ? Colors.green
                    : Colors.red,
              ),
            ],
          ]),
          const SizedBox(height: 20),
          _buildSection('Estado', [
            _buildInfoRow(
              Icons.circle,
              'Estado',
              customer.isActive ? 'Activo' : 'Inactivo',
              valueColor: customer.isActive ? Colors.green : Colors.grey,
            ),
            _buildInfoRow(
              Icons.business,
              'Tipo',
              customer.type == CustomerType.business
                  ? 'Empresa'
                  : 'Persona Natural',
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacturasTab(List invoices) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Sin recibos registrados',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final inv = invoices[index];
        // Usar comparación directa con enum para evitar problemas con hot reload
        final isPaid = inv.status == InvoiceStatus.paid;
        final isOverdue =
            !isPaid &&
            inv.dueDate != null &&
            inv.dueDate!.isBefore(DateTime.now());

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: isPaid
                ? Colors.green[50]
                : (isOverdue ? Colors.red[50] : Colors.orange[50]),
            child: Icon(
              isPaid
                  ? Icons.check_circle
                  : (isOverdue ? Icons.warning : Icons.schedule),
              color: isPaid
                  ? Colors.green
                  : (isOverdue ? Colors.red : Colors.orange),
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Text(
                inv.number,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                Formatters.currency(inv.total),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPaid
                      ? Colors.green
                      : (isOverdue ? Colors.red : Colors.orange),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    Formatters.date(inv.issueDate),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? Colors.green[100]
                          : (isOverdue ? Colors.red[100] : Colors.orange[100]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isPaid ? 'Pagada' : (isOverdue ? 'Vencida' : 'Pendiente'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isPaid
                            ? Colors.green[700]
                            : (isOverdue
                                  ? Colors.red[700]
                                  : Colors.orange[700]),
                      ),
                    ),
                  ),
                  if (inv.paymentMethod != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getPaymentMethodIcon(
                              inv.paymentMethod?.toString().split('.').last,
                            ),
                            size: 12,
                            color: Colors.indigo[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getPaymentMethodLabel(
                              inv.paymentMethod?.toString().split('.').last,
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isPaid && inv.dueDate != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Vence: ${Formatters.date(inv.dueDate!)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
              if (!isPaid) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Pendiente: ${Formatters.currency(inv.pendingAmount)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 28,
                      child: FilledButton.icon(
                        onPressed: () => _showPaymentDialog(inv),
                        icon: const Icon(Icons.payment, size: 14),
                        label: const Text(
                          'Pagar',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showPaymentDialog(Invoice inv) async {
    // Cargar cuentas disponibles
    List<Account> accounts = [];
    try {
      accounts = await AccountsDataSource.getAllAccounts();
    } catch (_) {}

    if (!mounted) return;

    final amountController = TextEditingController(
      text: inv.pendingAmount.toStringAsFixed(0),
    );
    final referenceController = TextEditingController();
    final notesController = TextEditingController();
    String selectedMethod = 'cash';
    Account? selectedAccount = accounts.isNotEmpty ? accounts.first : null;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.payment, color: Colors.green[700]),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Registrar Pago',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        'Recibo: ${inv.series}-${inv.number}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info de la factura
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total factura',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                Formatters.currency(inv.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pagado',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                Formatters.currency(inv.paidAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Pendiente',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                Formatters.currency(inv.pendingAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Monto
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Monto a pagar',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.attach_money),
                        helperText:
                            'Máximo: ${Formatters.currency(inv.pendingAmount)}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Cuenta destino
                    if (accounts.isNotEmpty) ...[
                      DropdownButtonFormField<Account>(
                        value: selectedAccount,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Cuenta destino',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_balance),
                        ),
                        items: accounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a,
                                child: Text(
                                  '${a.name} (${Formatters.currency(a.balance)})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => selectedAccount = v),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Referencia
                    TextFormField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Referencia (opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                        hintText: 'Ej: Nro. transferencia',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Notas
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas (opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: isSaving
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Ingresa un monto válido mayor a 0',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (amount > inv.pendingAmount + 0.01) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'El monto excede el pendiente (${Formatters.currency(inv.pendingAmount)})',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          await InvoicesDataSource.registerPayment(
                            invoiceId: inv.id,
                            amount: amount,
                            method: selectedMethod,
                            accountId: selectedAccount?.id,
                            reference: referenceController.text.isNotEmpty
                                ? referenceController.text
                                : null,
                            notes: notesController.text.isNotEmpty
                                ? notesController.text
                                : null,
                          );
                          if (mounted) {
                            Navigator.pop(dialogContext);
                            // Recargar datos
                            ref.read(invoicesProvider.notifier).refresh();
                            ref
                                .read(customersProvider.notifier)
                                .loadCustomers();
                            _loadCustomerPayments();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Pago de ${Formatters.currency(amount)} registrado en ${inv.series}-${inv.number}',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(isSaving ? 'Guardando...' : 'Registrar Pago'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getPaymentMethodLabel(String? method) {
    switch (method) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return 'Tarjeta';
      case 'transfer':
        return 'Transferencia';
      case 'credit':
        return 'Crédito';
      case 'check':
        return 'Cheque';
      case 'yape':
        return 'Yape';
      case 'plin':
        return 'Plin';
      default:
        return method ?? 'N/A';
    }
  }

  IconData _getPaymentMethodIcon(String? method) {
    switch (method) {
      case 'cash':
        return Icons.payments;
      case 'card':
        return Icons.credit_card;
      case 'transfer':
        return Icons.swap_horiz;
      case 'credit':
        return Icons.account_balance_wallet;
      case 'check':
        return Icons.description;
      case 'yape':
      case 'plin':
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }

  Color _getPaymentMethodColor(String? method) {
    switch (method) {
      case 'cash':
        return Colors.green;
      case 'card':
        return Colors.blue;
      case 'transfer':
        return Colors.indigo;
      case 'credit':
        return Colors.orange;
      case 'check':
        return Colors.brown;
      case 'yape':
        return Colors.purple;
      case 'plin':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPagosTab() {
    if (_loadingPayments) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_customerPayments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Sin pagos registrados',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Los pagos aparecerán aquí cuando se registren',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Calcular total pagado
    final totalPagado = _customerPayments.fold<double>(
      0,
      (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0),
    );

    return Column(
      children: [
        // Resumen de pagos
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700], size: 20),
              const SizedBox(width: 10),
              Text(
                'Total Pagado:',
                style: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                Formatters.currency(totalPagado),
                style: TextStyle(
                  color: Colors.green[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        // Lista de pagos
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _customerPayments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final payment = _customerPayments[index];
              final amount =
                  double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
              final method = payment['method'] as String?;
              final reference = payment['reference'] as String?;
              final notes = payment['notes'] as String?;
              final invoiceNumber =
                  payment['invoice_number'] as String? ?? 'N/A';
              final paymentDate = payment['payment_date'] != null
                  ? DateTime.tryParse(payment['payment_date'].toString())
                  : null;

              final methodColor = _getPaymentMethodColor(method);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila principal: método, factura, monto
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: methodColor.withOpacity(0.1),
                            child: Icon(
                              _getPaymentMethodIcon(method),
                              color: methodColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: methodColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _getPaymentMethodLabel(method),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: methodColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.receipt,
                                      size: 13,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      invoiceNumber,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                if (paymentDate != null)
                                  Text(
                                    Formatters.date(paymentDate),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.currency(amount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      // Referencia y notas
                      if (reference != null && reference.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.tag, size: 14, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ref: $reference',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.notes,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                notes,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildCotizacionesTab(List quotations) {
    if (quotations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.request_quote, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Sin cotizaciones registradas',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: quotations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final q = quotations[index];
        final status = q.status;
        final isApproved = status == 'Aprobada';
        final isRejected = status == 'Rechazada';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: isApproved
                ? Colors.green[50]
                : (isRejected ? Colors.red[50] : Colors.blue[50]),
            child: Icon(
              isApproved
                  ? Icons.check_circle
                  : (isRejected ? Icons.cancel : Icons.description),
              color: isApproved
                  ? Colors.green
                  : (isRejected ? Colors.red : Colors.blue),
              size: 20,
            ),
          ),
          title: Row(
            children: [
              Text(
                q.number,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                Formatters.currency(q.total),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isApproved
                      ? Colors.green
                      : (isRejected ? Colors.red : Colors.blue),
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              Text(
                Formatters.date(q.date),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isApproved
                      ? Colors.green[100]
                      : (isRejected ? Colors.red[100] : Colors.blue[100]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isApproved
                        ? Colors.green[700]
                        : (isRejected ? Colors.red[700] : Colors.blue[700]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
