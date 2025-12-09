import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/customers_provider.dart';
import '../../domain/entities/customer.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  String _selectedFilter = 'Todos';
  
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customersProvider.notifier).loadCustomers();
    });
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
        return customers.where((c) => c.type == CustomerType.individual).toList();
      default:
        return customers;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(customersProvider);
    final filteredCustomers = _getFilteredCustomers(state.filteredCustomers);
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clientes',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${state.customers.length} clientes registrados',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Stats rápidas
                    _buildQuickStat(
                      'Total Deuda',
                      Formatters.currency(state.customers.fold(0.0, (sum, c) => sum + c.currentBalance)),
                      Colors.orange,
                      Icons.account_balance_wallet,
                    ),
                    const SizedBox(width: 16),
                    _buildQuickStat(
                      'Clientes Activos',
                      state.customers.where((c) => c.isActive).length.toString(),
                      Colors.green,
                      Icons.people,
                    ),
                    const SizedBox(width: 24),
                    FilledButton.icon(
                      onPressed: () => _showAddCustomerDialog(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Nuevo Cliente'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Barra de búsqueda y filtros
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        onChanged: (value) => ref.read(customersProvider.notifier).search(value),
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
                          items: ['Todos', 'Activos', 'Con Deuda', 'Empresas', 'Personas']
                              .map((filter) => DropdownMenuItem(
                                    value: filter,
                                    child: Text(filter),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => _selectedFilter = value!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Botón refrescar
                    OutlinedButton.icon(
                      onPressed: () => ref.read(customersProvider.notifier).loadCustomers(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              padding: const EdgeInsets.all(24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
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
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: Colors.grey[200],
                                  ),
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
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
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
    Color typeColor = customer.type == CustomerType.business ? Colors.blue : Colors.purple;

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
          const SizedBox(width: 8),
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
                '${customer.documentType.name.toUpperCase()}: ${customer.documentNumber}',
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
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[300],
          ),
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
            style: TextStyle(
              color: Colors.grey[400],
            ),
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
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red[300],
          ),
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
            style: TextStyle(
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => ref.read(customersProvider.notifier).loadCustomers(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final documentController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    CustomerType selectedType = CustomerType.business;
    DocumentType selectedDocType = DocumentType.ruc;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo Cliente'),
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
                            value: selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Cliente',
                              border: OutlineInputBorder(),
                            ),
                            items: CustomerType.values.map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type == CustomerType.business ? 'Empresa' : 'Persona'),
                            )).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedType = value!;
                                selectedDocType = value == CustomerType.business 
                                    ? DocumentType.ruc 
                                    : DocumentType.dni;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<DocumentType>(
                            value: selectedDocType,
                            decoration: const InputDecoration(
                              labelText: 'Tipo Documento',
                              border: OutlineInputBorder(),
                            ),
                            items: DocumentType.values.map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.name.toUpperCase()),
                            )).toList(),
                            onChanged: (value) => setDialogState(() => selectedDocType = value!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: documentController,
                      decoration: const InputDecoration(
                        labelText: 'Número de Documento',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre / Razón Social',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Campo requerido' : null,
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
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final customer = Customer(
                    id: const Uuid().v4(),
                    type: selectedType,
                    documentType: selectedDocType,
                    documentNumber: documentController.text,
                    name: nameController.text,
                    phone: phoneController.text.isNotEmpty ? phoneController.text : null,
                    email: emailController.text.isNotEmpty ? emailController.text : null,
                    address: addressController.text.isNotEmpty ? addressController.text : null,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  
                  final result = await ref.read(customersProvider.notifier).createCustomer(customer);
                  if (result != null && context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cliente creado exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCustomerDialog(Customer customer) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Editando cliente: ${customer.name}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showCustomerDetails(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(customer.displayName),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Documento', '${customer.documentType.name.toUpperCase()}: ${customer.documentNumber}'),
              if (customer.phone != null) _buildDetailRow('Teléfono', customer.phone!),
              if (customer.email != null) _buildDetailRow('Email', customer.email!),
              if (customer.address != null) _buildDetailRow('Dirección', customer.address!),
              const Divider(),
              _buildDetailRow('Límite de Crédito', Formatters.currency(customer.creditLimit)),
              _buildDetailRow('Balance Actual', Formatters.currency(customer.currentBalance)),
              _buildDetailRow('Crédito Disponible', Formatters.currency(customer.availableCredit)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

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
        content: Text('¿Está seguro de eliminar al cliente "${customer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(customersProvider.notifier).deleteCustomer(customer.id);
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
