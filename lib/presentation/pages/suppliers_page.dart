import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../data/datasources/suppliers_datasource.dart';
import '../../data/providers/suppliers_provider.dart';
import '../../data/providers/purchase_orders_provider.dart';
import '../../data/providers/providers.dart';
import '../../domain/entities/supplier.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/cash_movement.dart';
import '../../domain/entities/account.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  final bool openNewDialog;

  const SuppliersPage({super.key, this.openNewDialog = false});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  String _selectedFilter = 'Todos';
  bool _dialogOpened = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(suppliersProvider.notifier).loadSuppliers();
      if (widget.openNewDialog && !_dialogOpened) {
        _dialogOpened = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _showAddSupplierDialog();
        });
      }
    });
  }

  List<Supplier> _getFilteredSuppliers(List<Supplier> suppliers) {
    switch (_selectedFilter) {
      case 'Activos':
        return suppliers.where((s) => s.isActive).toList();
      case 'Con Deuda':
        return suppliers.where((s) => s.hasDebt).toList();
      case 'Empresas':
        return suppliers.where((s) => s.type == SupplierType.business).toList();
      case 'Personas':
        return suppliers
            .where((s) => s.type == SupplierType.individual)
            .toList();
      default:
        return suppliers;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(suppliersProvider);
    final filteredSuppliers = _getFilteredSuppliers(state.filteredSuppliers);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${state.suppliers.length} proveedores registrados',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  _buildQuickStat(
                    'Total Deuda',
                    '\$${Helpers.formatNumber(state.suppliers.fold(0.0, (sum, s) => sum + s.currentDebt))}',
                    Colors.orange,
                    Icons.account_balance_wallet,
                  ),
                  const SizedBox(width: 12),
                  _buildQuickStat(
                    'Activos',
                    state.suppliers.where((s) => s.isActive).length.toString(),
                    Colors.green,
                    Icons.local_shipping,
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: _showAddSupplierDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo Proveedor'),
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
              // Búsqueda y filtros
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) => ref
                          .read(suppliersProvider.notifier)
                          .setSearchQuery(value),
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
                                  (f) => DropdownMenuItem(
                                    value: f,
                                    child: Text(f),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedFilter = value!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(suppliersProvider.notifier).loadSuppliers(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                    style: OutlinedButton.styleFrom(
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
        // Lista
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text('Error: ${state.error}'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref
                                  .read(suppliersProvider.notifier)
                                  .loadSuppliers(),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : filteredSuppliers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay proveedores',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Agrega proveedores para asociarlos a tus materiales',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: filteredSuppliers.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey[200]),
                        itemBuilder: (context, index) =>
                            _buildSupplierTile(filteredSuppliers[index]),
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
        color: color.withOpacity(0.1),
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

  Widget _buildSupplierTile(Supplier supplier) {
    final debt = supplier.currentDebt;
    Color statusColor = supplier.isActive ? Colors.green : Colors.grey;
    Color typeColor = supplier.type == SupplierType.business
        ? Colors.blue
        : Colors.purple;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      onTap: () => _showSupplierDetailDialog(supplier),
      leading: CircleAvatar(
        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
        child: Text(
          supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
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
              supplier.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              supplier.type == SupplierType.business ? 'Empresa' : 'Persona',
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
                '${supplier.documentType}: ${supplier.documentNumber}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (supplier.phone != null && supplier.phone!.isNotEmpty) ...[
                const SizedBox(width: 16),
                Icon(Icons.phone, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  supplier.phone!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
              if (supplier.email != null && supplier.email!.isNotEmpty) ...[
                const SizedBox(width: 16),
                Icon(Icons.email, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  supplier.email!,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ],
          ),
          if (debt > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Deuda: \$${Helpers.formatNumber(debt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
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
              _showEditSupplierDialog(supplier);
              break;
            case 'pay_debt':
              _showPayDebtDialog(supplier);
              break;
            case 'delete':
              _confirmDelete(supplier);
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
          if (supplier.hasDebt)
            const PopupMenuItem(
              value: 'pay_debt',
              child: Row(
                children: [
                  Icon(Icons.payments, size: 20, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Registrar Pago', style: TextStyle(color: Colors.green)),
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
    );
  }

  // ==================== DIÁLOGOS ====================

  // ============================
  // DIÁLOGO: Detalle de proveedor con materiales y órdenes
  // ============================
  void _showSupplierDetailDialog(Supplier supplier) {
    // Cargar materiales del proveedor
    ref.read(supplierMaterialsProvider.notifier).loadBySupplier(supplier.id);
    ref.read(purchaseOrdersProvider.notifier).loadBySupplier(supplier.id);

    showDialog(
      context: context,
      builder: (ctx) => _SupplierDetailDialog(supplier: supplier),
    );
  }

  void _showAddSupplierDialog() {
    _showSupplierFormDialog();
  }

  void _showEditSupplierDialog(Supplier supplier) {
    _showSupplierFormDialog(supplier: supplier);
  }

  void _showSupplierFormDialog({Supplier? supplier}) {
    final isEditing = supplier != null;
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final docNumberCtrl = TextEditingController(
      text: supplier?.documentNumber ?? '',
    );
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final emailCtrl = TextEditingController(text: supplier?.email ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final contactCtrl = TextEditingController(
      text: supplier?.contactPerson ?? '',
    );
    final bankNameCtrl = TextEditingController(text: supplier?.bankName ?? '');
    final bankAccountCtrl = TextEditingController(
      text: supplier?.bankAccount ?? '',
    );

    String docType = supplier?.documentType ?? 'NIT';
    SupplierType type = supplier?.type ?? SupplierType.business;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Proveedor' : 'Nuevo Proveedor'),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tipo
                  SegmentedButton<SupplierType>(
                    segments: const [
                      ButtonSegment(
                        value: SupplierType.business,
                        label: Text('Empresa'),
                        icon: Icon(Icons.business, size: 18),
                      ),
                      ButtonSegment(
                        value: SupplierType.individual,
                        label: Text('Persona'),
                        icon: Icon(Icons.person, size: 18),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (v) =>
                        setDialogState(() => type = v.first),
                  ),
                  const SizedBox(height: 16),
                  // Documento
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<String>(
                          value: docType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo doc.',
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'NIT', child: Text('NIT')),
                            DropdownMenuItem(value: 'CC', child: Text('CC')),
                            DropdownMenuItem(value: 'CE', child: Text('CE')),
                            DropdownMenuItem(value: 'RUC', child: Text('RUC')),
                            DropdownMenuItem(value: 'RUT', child: Text('RUT')),
                          ],
                          onChanged: (v) => setDialogState(() => docType = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: docNumberCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Número de documento *',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre *'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            prefixIcon: Icon(Icons.phone, size: 18),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email, size: 18),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      prefixIcon: Icon(Icons.location_on, size: 18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contactCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Persona de contacto',
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  // Datos bancarios
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance,
                              size: 18,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Datos Bancarios (opcional)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: bankNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Banco',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: bankAccountCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Número de cuenta',
                                  isDense: true,
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El nombre es requerido'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (docNumberCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El documento es requerido'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final now = DateTime.now();
                final supplierData = Supplier(
                  id: supplier?.id ?? '',
                  type: type,
                  documentType: docType,
                  documentNumber: docNumberCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  tradeName: null,
                  phone: phoneCtrl.text.trim().isNotEmpty
                      ? phoneCtrl.text.trim()
                      : null,
                  email: emailCtrl.text.trim().isNotEmpty
                      ? emailCtrl.text.trim()
                      : null,
                  address: addressCtrl.text.trim().isNotEmpty
                      ? addressCtrl.text.trim()
                      : null,
                  contactPerson: contactCtrl.text.trim().isNotEmpty
                      ? contactCtrl.text.trim()
                      : null,
                  bankName: bankNameCtrl.text.trim().isNotEmpty
                      ? bankNameCtrl.text.trim()
                      : null,
                  bankAccount: bankAccountCtrl.text.trim().isNotEmpty
                      ? bankAccountCtrl.text.trim()
                      : null,
                  currentDebt: supplier?.currentDebt ?? 0,
                  isActive: supplier?.isActive ?? true,
                  createdAt: supplier?.createdAt ?? now,
                  updatedAt: now,
                );

                if (isEditing) {
                  final ok = await ref
                      .read(suppliersProvider.notifier)
                      .updateSupplier(supplierData);
                  if (ok && context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Proveedor "${supplierData.name}" actualizado',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  final created = await ref
                      .read(suppliersProvider.notifier)
                      .createSupplier(supplierData);
                  if (created != null && context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Proveedor "${created.name}" creado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayDebtDialog(Supplier supplier) {
    final amountCtrl = TextEditingController(
      text: supplier.currentDebt.toStringAsFixed(0),
    );
    final descCtrl = TextEditingController(
      text: 'Pago a proveedor: ${supplier.displayName}',
    );
    String? selectedAccountId;
    bool isPartial = false;
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.payments, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Expanded(child: Text('Registrar Pago a Proveedor')),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info del proveedor
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.business, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supplier.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Deuda actual: \$${Helpers.formatNumber(supplier.currentDebt)}',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tipo de pago
                Row(
                  children: [
                    Expanded(
                      child: _buildPayOption(
                        ctx,
                        icon: Icons.check_circle,
                        label: 'Pago Total',
                        selected: !isPartial,
                        onTap: () {
                          setDialogState(() {
                            isPartial = false;
                            amountCtrl.text = supplier.currentDebt
                                .toStringAsFixed(0);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildPayOption(
                        ctx,
                        icon: Icons.pie_chart,
                        label: 'Abono Parcial',
                        selected: isPartial,
                        onTap: () {
                          setDialogState(() {
                            isPartial = true;
                            amountCtrl.clear();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Monto
                TextField(
                  controller: amountCtrl,
                  decoration: InputDecoration(
                    labelText: isPartial ? 'Monto del abono' : 'Monto total',
                    prefixText: '\$ ',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: !isPartial,
                ),
                const SizedBox(height: 12),

                // Descripción
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Cuenta de pago
                FutureBuilder<List<Account>>(
                  future: AccountsDataSource.getAllAccounts(),
                  builder: (context, snapshot) {
                    final accounts = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: selectedAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Cuenta de pago *',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(
                          Icons.account_balance_wallet,
                          size: 18,
                        ),
                      ),
                      items: accounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(
                                '${a.name} (\$${Formatters.currency(a.balance)})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedAccountId = v),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Se creará un movimiento de egreso en caja, '
                          'un asiento contable automático y se reducirá la deuda.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: isProcessing || selectedAccountId == null
                  ? null
                  : () async {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('El monto debe ser mayor a 0'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      if (amount > supplier.currentDebt) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'El monto no puede exceder la deuda (\$${Helpers.formatNumber(supplier.currentDebt)})',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isProcessing = true);

                      try {
                        // 1. Crear movimiento de egreso (dispara asiento contable automático)
                        final refNumber =
                            await AccountsDataSource.getNextReferenceNumber();
                        final movement = CashMovement(
                          id: '',
                          accountId: selectedAccountId!,
                          type: MovementType.expense,
                          category: MovementCategory.consumibles,
                          amount: amount,
                          description: descCtrl.text.trim(),
                          reference: refNumber.toString().padLeft(6, '0'),
                          personName: supplier.displayName,
                          date: DateTime.now(),
                        );
                        await AccountsDataSource.createMovementWithBalanceUpdate(
                          movement,
                        );

                        // 2. Reducir deuda del proveedor (monto negativo)
                        await SuppliersDataSource.updateDebt(
                          supplier.id,
                          -amount,
                        );

                        // 3. Recargar proveedores
                        if (mounted) {
                          ref.read(suppliersProvider.notifier).loadSuppliers();
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          final remaining = supplier.currentDebt - amount;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                remaining <= 0
                                    ? '✅ Pago total a ${supplier.displayName} registrado. Deuda saldada.'
                                    : '✅ Abono de \$${Helpers.formatNumber(amount)} registrado. '
                                          'Deuda restante: \$${Helpers.formatNumber(remaining)}',
                              ),
                              backgroundColor: Colors.green.shade700,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isProcessing = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              icon: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.payments, size: 18),
              label: Text(isProcessing ? 'Procesando...' : 'Registrar Pago'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.green.shade600 : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected ? Colors.green.shade50 : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.green.shade700 : Colors.grey.shade500,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.green.shade700 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Supplier supplier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar proveedor'),
        content: Text(
          '¿Estás seguro de eliminar a "${supplier.displayName}"?\n'
          'El proveedor será desactivado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref
                  .read(suppliersProvider.notifier)
                  .deleteSupplier(supplier.id);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Proveedor "${supplier.name}" eliminado'),
                    backgroundColor: Colors.green,
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

// ====================================
// WIDGET: Detalle de Proveedor (Dialog)
// ====================================
class _SupplierDetailDialog extends ConsumerWidget {
  final Supplier supplier;

  const _SupplierDetailDialog({required this.supplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smState = ref.watch(supplierMaterialsProvider);
    final poState = ref.watch(purchaseOrdersProvider);

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Text(
              supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.displayName,
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  '${supplier.documentType}: ${supplier.documentNumber}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (supplier.hasDebt)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Deuda: ${Formatters.currency(supplier.currentDebt)}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 700,
        height: 450,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                indicatorColor: AppTheme.primaryColor,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey[600],
                tabs: [
                  Tab(
                    icon: const Icon(Icons.inventory, size: 18),
                    text: 'Materiales (${smState.items.length})',
                    height: 44,
                  ),
                  Tab(
                    icon: const Icon(Icons.shopping_cart, size: 18),
                    text: 'Órdenes (${poState.orders.length})',
                    height: 44,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Materiales del proveedor
                    _buildMaterialsTab(context, ref, smState),
                    // Tab 2: Órdenes de compra
                    _buildOrdersTab(context, ref, poState),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (supplier.phone != null && supplier.phone!.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.phone, size: 14),
            label: Text(supplier.phone!, style: const TextStyle(fontSize: 11)),
          ),
        if (supplier.email != null && supplier.email!.isNotEmpty)
          Chip(
            avatar: const Icon(Icons.email, size: 14),
            label: Text(supplier.email!, style: const TextStyle(fontSize: 11)),
          ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildMaterialsTab(
    BuildContext context,
    WidgetRef ref,
    SupplierMaterialsState smState,
  ) {
    if (smState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (smState.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Sin materiales asociados',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Los materiales se asocian al crear un material\no al recibir una orden de compra',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showAssociateMaterialDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Asociar Material'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header con botón agregar
        Row(
          children: [
            Text(
              '${smState.items.length} materiales',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showAssociateMaterialDialog(context, ref),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Asociar Material',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: smState.items.length,
            itemBuilder: (ctx, i) {
              final sm = smState.items[i];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primaryColor.withValues(
                      alpha: 0.1,
                    ),
                    child: const Icon(
                      Icons.inventory,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: Text(
                    sm.materialName ?? 'Material',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        'Precio: ${Formatters.currency(sm.unitPrice)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (sm.lastPurchasePrice != null &&
                          sm.lastPurchasePrice != sm.unitPrice) ...[
                        const SizedBox(width: 8),
                        Text(
                          '→ Último: ${Formatters.currency(sm.lastPurchasePrice!)}',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (sm.lastPurchaseDate != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${Formatters.dateShort(sm.lastPurchaseDate!)})',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sm.isPreferred)
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          size: 16,
                          color: Colors.red[400],
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await ref
                              .read(supplierMaterialsProvider.notifier)
                              .deletePrice(sm.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Resumen
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                '${smState.items.length} materiales',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'Promedio: ${Formatters.currency(smState.items.isEmpty ? 0 : smState.items.fold(0.0, (s, i) => s + i.unitPrice) / smState.items.length)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersTab(
    BuildContext context,
    WidgetRef ref,
    PurchaseOrdersState poState,
  ) {
    if (poState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (poState.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Sin órdenes de compra',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Las órdenes se crean desde la pestaña "Órdenes de Compra"',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: poState.orders.length,
            itemBuilder: (ctx, i) {
              final order = poState.orders[i];
              final statusColor = _getStatusColor(order.status);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    child: Icon(
                      _getStatusIcon(order.status),
                      size: 18,
                      color: statusColor,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.status.display,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${order.itemCount} ítems • ${Formatters.dateShort(order.createdAt)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.currency(order.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (order.balance > 0)
                        Text(
                          'Debe: ${Formatters.currency(order.balance)}',
                          style: TextStyle(
                            color: Colors.red[400],
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Resumen
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                'Total compras: ${Formatters.currency(poState.orders.fold(0.0, (s, o) => s + o.total))}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                'Pendiente: ${Formatters.currency(poState.orders.fold(0.0, (s, o) => s + o.balance))}',
                style: TextStyle(
                  color: Colors.red[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAssociateMaterialDialog(BuildContext context, WidgetRef ref) {
    String? selectedMaterialId;
    final priceCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) {
        final materialsState = ref.watch(inventoryProvider);
        final materials = materialsState.materials;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.link, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text('Asociar Material'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedMaterialId,
                    decoration: const InputDecoration(
                      labelText: 'Material *',
                      prefixIcon: Icon(Icons.inventory),
                    ),
                    isExpanded: true,
                    items: materials
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(
                              '${m.code} — ${m.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setDialogState(() => selectedMaterialId = v);
                      if (v != null) {
                        final mat = materials.firstWhere((m) => m.id == v);
                        if (mat.costPrice > 0) {
                          priceCtrl.text = mat.costPrice.toStringAsFixed(2);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Precio de Compra (\$)',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: selectedMaterialId == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await ref
                            .read(supplierMaterialsProvider.notifier)
                            .upsertPrice(
                              supplierId: supplier.id,
                              materialId: selectedMaterialId!,
                              unitPrice: double.tryParse(priceCtrl.text) ?? 0,
                              isPreferred: true,
                            );
                      },
                child: const Text('Asociar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.borrador:
        return Colors.grey;
      case PurchaseOrderStatus.enviada:
        return Colors.blue;
      case PurchaseOrderStatus.parcial:
        return Colors.orange;
      case PurchaseOrderStatus.recibida:
        return Colors.green;
      case PurchaseOrderStatus.cancelada:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.borrador:
        return Icons.edit_note;
      case PurchaseOrderStatus.enviada:
        return Icons.send;
      case PurchaseOrderStatus.parcial:
        return Icons.inventory;
      case PurchaseOrderStatus.recibida:
        return Icons.check_circle;
      case PurchaseOrderStatus.cancelada:
        return Icons.cancel;
    }
  }
}
